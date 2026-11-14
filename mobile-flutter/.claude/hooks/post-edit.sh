#!/usr/bin/env bash
# PostToolUse フック（matcher: Edit|Write|MultiEdit）
# 編集した .dart を format して、そのファイルだけ analyze する。
#
# エージェントへの伝え方は 2 通り：
#   検査の失敗 … stderr に出して終了コード 2
#   注意喚起   … note で貯め、最後に additionalContext の JSON として stdout に出す（終了コード 0）
# 終了コード 0 の stderr はエージェントに届かない。`echo ... >&2` だけでは伝わらない。
set -u
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
  */generated/*|*.g.dart|*.freezed.dart) exit 0 ;;
  *.dart)
    dart format "$path" >/dev/null
    if ! out="$(dart analyze --fatal-infos "$path" 2>&1)"; then
      echo "dart analyze failed:" >&2; echo "$out" >&2; exit 2
    fi
    case "$path" in
      *_notifier.dart|*_repository.dart|*/models/*)
        if grep -Eq '@(riverpod|freezed|JsonSerializable)' "$path"; then
          note "annotated file changed: run 'make gen' (build_runner) before relying on generated code."
        fi ;;
    esac
    ;;
  *openapi*.yaml|*openapi*.yml)
    note "OpenAPI changed: run 'make gen' to regenerate the dart client." ;;
esac
emit_notes
exit 0
