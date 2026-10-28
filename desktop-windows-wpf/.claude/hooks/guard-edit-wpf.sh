#!/usr/bin/env bash
# EF Core の Migrations と appxmanifest の署名まわりは手で編集しない。
set -u
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] && exit 0
case "$path" in
  */Data/Migrations/*|*/Migrations/*.Designer.cs|*ModelSnapshot.cs)
    echo "BLOCKED: EF Core migrations are generated with 'make migrate name=Xxx'. Do not edit them by hand." >&2; exit 2 ;;
esac
exit 0
