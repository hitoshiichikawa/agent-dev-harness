#!/usr/bin/env bash
# PreToolUse フック（matcher: Bash）
# 破壊的・本番向け操作をコマンド文字列で機械的にブロックする。
# 終了コード 2 = ブロック（stderr がエージェントに返る）。0 = 許可。
#
# Claude Code は 0 と 2 以外の終了コードを「フックの不具合」とみなして処理を続行する。
# このスクリプトが途中で落ちたときに素通しにならないよう、EXIT トラップで 2 に変える。
#
# パターン固有の追加は .claude/hooks/extra-deny.txt に 1 行 1 正規表現（拡張正規表現）で書く。
# このファイル自体は共通なので編集しない。
#
# これは善意のエージェントの事故を防ぐガードレールで、越えられない境界ではない
# （`bash -c '...'` のような書き方は見ない）。境界が要るものは権限側で作る。

set -u
fail_closed() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
    echo "BLOCKED by harness guard: the guard script itself failed (exit $rc), so this command was not checked. Do not work around it. Tell the user that .claude/hooks/common/guard-bash.sh is broken." >&2
    exit 2
  fi
}
trap fail_closed EXIT

input="$(cat)"
# Claude Code は必ず JSON を渡す。空なら配線の誤り（入力を別のスクリプトが先に読んだ等）なので止める
[ -n "$input" ] || exit 3

extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.command // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))'
  else
    printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p'
  fi
}
# 入力を読めなかったら「コマンドなし」と区別して止める（トラップが 2 にする）
if ! cmd="$(extract)"; then exit 3; fi
[ -z "$cmd" ] && exit 0

# コマンドの先頭位置：行頭、区切り（; & | ( `）の直後、then / do / else の直後。
# 前に環境変数の代入（FOO=1 cmd）が付いていてもよい。
# 文中の単語（コミットメッセージ中の "sudo" など）には一致させないために使う。
CMD_START='(^|[;&|(`][[:space:]]*|(then|do|else)[[:space:]]+)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
# rm に渡すと危険な対象：/ ~ $HOME . .. と、その直下すべて（/* など）、裸の *
RM_TARGET='(["'"'"']?(/|~|\$HOME|\$\{HOME\}|\.\.?)/?\*?["'"'"']?|\*)'
# git とサブコマンドの間にオプションが入る形（git -C dir push ...）も拾う
GIT='git[[:space:]]+([^|;&]*[[:space:]])?'

PATTERNS=(
  "${GIT}push[^|;&]*--force"
  "${GIT}push[^|;&]*[[:space:]]-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|\$)"
  "${GIT}push[^|;&]*[[:space:]]\\+[^[:space:]]"
  "${GIT}reset[[:space:]]+--hard"
  "${GIT}clean[[:space:]]+-[a-z]*f"
  "${GIT}branch[[:space:]]+-D"
  "${CMD_START}rm[[:space:]]+([^;&|]*[[:space:]])?${RM_TARGET}([[:space:];&|)]|\$)"
  'cdk[[:space:]]+(deploy|destroy)'
  'terraform[[:space:]]+(apply|destroy)'
  'aws[[:space:]]+[a-z0-9-]+[[:space:]]+(delete|terminate|put-|update-|create-)'
  'curl[^|]*\|[[:space:]]*(ba)?sh'
  'chmod[[:space:]]+-R[[:space:]]+777'
  "${CMD_START}sudo[[:space:]]"
)

# パターン固有の追加を読む。プロジェクトに置かれた場合（.claude/hooks/common/ の 1 つ上）と、
# このスクリプトがプロジェクト外から配られた場合（CLAUDE_PROJECT_DIR 基準）の両方を見る。
# 現在のディレクトリには依存しない（エージェントが cd していても効く）。
script_dir="$(cd "$(dirname "$0")" && pwd)"
for extra_file in "${CLAUDE_PROJECT_DIR:-}/.claude/hooks/extra-deny.txt" "$script_dir/../extra-deny.txt"; do
  [ -f "$extra_file" ] || continue
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    PATTERNS+=("$line")
  done < "$extra_file"
  break
done

for pat in "${PATTERNS[@]}"; do
  printf '%s' "$cmd" | grep -Eq -- "$pat"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "BLOCKED by harness guard: command matches '$pat'. This operation is reserved for a human. Explain what you wanted to do and ask the user to run it. If the match is only text that mentions the operation (a commit message, a search pattern), rephrase the text or put it in a file." >&2
    exit 2
  elif [ "$rc" -ne 1 ]; then
    # 正規表現が壊れている。黙って読み飛ばすとそのパターンが効かなくなるので止める
    echo "harness guard: invalid deny pattern '$pat' (grep exit $rc)" >&2
    exit 3
  fi
done

# 秘密情報らしきものを書き出そうとしていないか
if printf '%s' "$cmd" | grep -Eq -- '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{20,})'; then
  echo "BLOCKED by harness guard: command appears to contain a credential. Never write secrets into files or commands." >&2
  exit 2
fi

exit 0
