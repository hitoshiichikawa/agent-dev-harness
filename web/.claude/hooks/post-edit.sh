#!/usr/bin/env bash
# PostToolUse フック（matcher: Edit|Write|MultiEdit）
# 編集したファイルの種類に応じてフォーマッタと軽い静的検査を回す。
# 重い処理（テスト、golangci-lint 全体）はここに入れない。それは `task check`。
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
  */generated/*) exit 0 ;;
  *.go)
    gofmt -w "$path"
    dir="$(dirname "$path")"
    if ! out="$(cd "$dir" && go vet ./... 2>&1)"; then
      echo "go vet failed:" >&2; echo "$out" >&2; exit 2
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json)
    # frontend か infra のどちらかに属する
    root="$path"
    while [ "$root" != "/" ] && [ ! -f "$root/biome.json" ]; do root="$(dirname "$root")"; done
    if [ -f "$root/biome.json" ]; then
      if ! out="$(cd "$root" && npx --no-install biome check --write "$path" 2>&1)"; then
        echo "biome check failed:" >&2; echo "$out" >&2; exit 2
      fi
    fi
    ;;
  *.sql)
    case "$path" in
      */db/queries/*) note "sqlc input changed: run 'task gen' before relying on generated code." ;;
      */db/migrations/*) note "migration changed: do NOT apply it; ask the user to run 'task migrate:up'." ;;
    esac
    ;;
  *openapi*.yaml|*openapi*.yml)
    note "OpenAPI changed: run 'task gen' so Go stubs and TS client are regenerated."
    ;;
esac
emit_notes
exit 0
