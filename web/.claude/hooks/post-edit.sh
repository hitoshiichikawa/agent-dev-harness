#!/usr/bin/env bash
# PostToolUse フック（matcher: Edit|Write|MultiEdit）
# 編集したファイルの種類に応じてフォーマッタと軽い静的検査を回す。
# 失敗は stderr に出して終了コード 2 → エージェントにフィードバックされる。
# 重い処理（テスト、golangci-lint 全体）はここに入れない。それは `task check`。

set -u
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

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
      */db/queries/*) echo "sqlc input changed: run 'task gen' before relying on generated code." >&2 ;;
      */db/migrations/*) echo "migration changed: do NOT apply it; ask the user to run 'task migrate:up'." >&2 ;;
    esac
    ;;
  *openapi*.yaml|*openapi*.yml)
    echo "OpenAPI changed: run 'task gen' so Go stubs and TS client are regenerated." >&2
    ;;
esac
exit 0
