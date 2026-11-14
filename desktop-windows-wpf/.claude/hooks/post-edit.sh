#!/usr/bin/env bash
# PostToolUse フック（matcher: Edit|Write|MultiEdit）
# .cs / .xaml を編集したら format して、そのプロジェクトだけビルドする（analyzer が警告=エラー）。
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
          note "code-behind should contain only InitializeComponent(). Move logic to the ViewModel."
        fi ;;
      */MyApp.Domain/*|*/*.Domain/*)
        if grep -Eq '^\s*using System\.Windows' "$path"; then
          echo "Domain must not depend on WPF (System.Windows). Move this to the app project." >&2; exit 2
        fi ;;
    esac
    case "$path" in
      */Models/*.cs)
        note "model changed: if it is an EF entity, run 'make migrate name=Xxx' and include the diff in your report." ;;
    esac
    ;;
esac
emit_notes
exit 0
