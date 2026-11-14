#!/usr/bin/env bash
# PreToolUse フック（matcher: Edit|Write|MultiEdit）
# EF Core の Migrations は手で編集しない。
# 終了コード 2 = ブロック。0 と 2 以外は続行扱いなので、途中で落ちたら EXIT トラップで 2 に変える。
set -u
fail_closed() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
    echo "BLOCKED by harness guard: the guard script itself failed (exit $rc), so this edit was not checked. Do not work around it. Tell the user that .claude/hooks/guard-edit-wpf.sh is broken." >&2
    exit 2
  fi
}
trap fail_closed EXIT

input="$(cat)"
# Claude Code は必ず JSON を渡す。空なら配線の誤り（入力を別のスクリプトが先に読んだ等）なので止める
[ -n "$input" ] || exit 3
extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.file_path // empty'
  else
    printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))'
  fi
}
if ! path="$(extract)"; then exit 3; fi
[ -z "$path" ] && exit 0
case "$path" in
  */Data/Migrations/*|*/Migrations/*.Designer.cs|*ModelSnapshot.cs)
    echo "BLOCKED: EF Core migrations are generated with 'make migrate name=Xxx'. Do not edit them by hand." >&2; exit 2 ;;
esac
exit 0
