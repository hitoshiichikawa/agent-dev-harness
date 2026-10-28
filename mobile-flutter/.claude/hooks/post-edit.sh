#!/usr/bin/env bash
# 編集した .dart を format して、そのファイルだけ analyze する。
set -u
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

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
          echo "annotated file changed: run 'make gen' (build_runner) before relying on generated code." >&2
        fi ;;
    esac
    ;;
  *openapi*.yaml|*openapi*.yml)
    echo "OpenAPI changed: run 'make gen' to regenerate the dart client." >&2 ;;
esac
exit 0
