#!/usr/bin/env bash
# .cs / .xaml を編集したら format して、そのプロジェクトだけビルドする（analyzer が警告=エラー）。
set -u
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

find_csproj() {
  local d; d="$(dirname "$1")"
  while [ "$d" != "/" ] && [ "$d" != "." ]; do
    local hit; hit="$(ls "$d"/*.csproj 2>/dev/null | head -1)"
    [ -n "$hit" ] && { echo "$hit"; return; }
    d="$(dirname "$d")"
  done
}

case "$path" in
  */Migrations/*|*/obj/*|*/bin/*) exit 0 ;;
  *.cs|*.xaml)
    proj="$(find_csproj "$path")"
    [ -z "$proj" ] && exit 0
    case "$path" in
      *.cs) dotnet format "$proj" --include "$path" --no-restore >/dev/null 2>&1 ;;
    esac
    if ! out="$(dotnet build "$proj" --no-restore -nologo -v q -warnaserror 2>&1)"; then
      echo "dotnet build failed:" >&2; echo "$out" | tail -40 >&2; exit 2
    fi
    case "$path" in
      *.xaml.cs)
        if grep -Ev 'InitializeComponent|^\s*(using|namespace|public partial class|\{|\}|//)' "$path" | grep -Eq '\S'; then
          echo "code-behind should contain only InitializeComponent(). Move logic to the ViewModel." >&2
        fi ;;
      */MyApp.Domain/*|*/*.Domain/*)
        if grep -Eq '^\s*using System\.Windows' "$path"; then
          echo "Domain must not depend on WPF (System.Windows). Move this to the app project." >&2; exit 2
        fi ;;
    esac
    ;;
  */Models/*.cs)
    echo "model changed: if it is an EF entity, run 'make migrate name=Xxx' and include the diff in your report." >&2 ;;
esac
exit 0
