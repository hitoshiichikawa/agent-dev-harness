#!/usr/bin/env bash
# PostToolUse フック（matcher: Edit|Write|MultiEdit）
# 編集した .swift を format + lint。project.yml を変えたら xcodegen を回す。
#
# エージェントへの伝え方は 2 通り：
#   検査の失敗 … stderr に出して終了コード 2
#   注意喚起   … note で貯め、最後に additionalContext の JSON として stdout に出す（終了コード 0）
# 終了コード 0 の stderr はエージェントに届かない。`echo ... >&2` だけでは伝わらない。
set -u
# swiftlint は現在のディレクトリの .swiftlint.yml を読むので、プロジェクトルートに戻す
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

# note の文言に " と \ を入れない（JSON にそのまま埋め込む）
NOTES=""
note() { NOTES="${NOTES:+$NOTES }$1"; }
emit_notes() {
  [ -z "$NOTES" ] && return 0
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$NOTES"
}

case "$path" in
  *.swift)
    swiftformat --quiet "$path"
    if ! out="$(swiftlint lint --quiet --strict "$path" 2>&1)"; then
      echo "swiftlint failed:" >&2; echo "$out" >&2; exit 2
    fi
    case "$path" in
      */Packages/Domain/*)
        if grep -Eq '^import (SwiftUI|AppKit|UIKit)' "$path"; then
          echo "Domain package must not import SwiftUI/AppKit. Keep it Foundation + GRDB only." >&2; exit 2
        fi ;;
    esac
    ;;
  */project.yml)
    if ! out="$(cd "$(dirname "$path")" && xcodegen generate --quiet 2>&1)"; then
      echo "xcodegen failed:" >&2; echo "$out" >&2; exit 2
    fi
    note "project.yml changed: .xcodeproj regenerated."
    ;;
  *.entitlements)
    note "entitlements changed: this affects sandbox/App Store review. Confirm with the user." ;;
esac
emit_notes
exit 0
