#!/usr/bin/env bash
# 歯止め（ratchet）。数えられる違反を、今の数から増やさない。check コマンドの中から呼ぶ。
#
#   bash .claude/hooks/common/ratchet.sh
#
# 既存のコードにハーネスを後から入れると、守らせたい決まりへの違反がすでにある。
# 全部を直すまで check を落としておくと、check を完了の合図として使えない。
# そこで違反の数を .claude/ratchet.txt に書き留め、今の数がそれと一致することを確かめる。
#   - 増えたら落ちる（新しい違反が入った）
#   - 減っても落ちる（書き留めた数を下げさせる。数がいつも今の実数になり、文章の「現状」のように古くならない）
#
# .claude/ratchet.txt の書式（空白区切り、1 行 1 件。# で始まる行と空行は読み飛ばす）:
#   <数> <名前> <パス> <拡張正規表現（行末まで）>
#   4 queryRaw-in-commands server/src/handler/api/app/commands queryRaw
#
# 数えるのは、パス（実在するファイルかディレクトリ）の下で正規表現に当たった箇所の数。
# 追跡ファイルと、無視されていない未追跡ファイルを見る（新しく足したファイルも数える）。
# 終了コード 0 = すべて一致、または ratchet.txt が無い。1 = ずれている、または行が読めない。
# 上限を上げて通すこともできてしまうので、ratchet.txt の差分は人が読む。

set -u
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
cd "$root" 2>/dev/null || { echo "ratchet: cannot enter project root '$root'" >&2; exit 1; }
file="${RATCHET_FILE:-.claude/ratchet.txt}"
[ -f "$file" ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ratchet: not a git repository, cannot count" >&2; exit 1; }

failed=0
checked=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in '' | '#'*) continue ;; esac
  limit="" name="" path="" regex=""
  read -r limit name path regex <<EOF
$line
EOF
  case "$limit" in '' | *[!0-9]*) echo "ratchet: cannot read line (the first field must be a number): $line" >&2; failed=1; continue ;; esac
  if [ -z "$regex" ]; then echo "ratchet: cannot read line (need: <count> <name> <path> <regex>): $line" >&2; failed=1; continue; fi
  if [ ! -e "$path" ]; then echo "ratchet: $name: path '$path' does not exist" >&2; failed=1; continue; fi

  matches="$(git grep --untracked -nE -e "$regex" -- "$path" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then echo "ratchet: $name: invalid regex '$regex' (git grep exit $rc)" >&2; failed=1; continue; fi
  count="$(git grep --untracked -hoE -e "$regex" -- "$path" 2>/dev/null | wc -l | tr -d '[:space:]')"
  checked=$((checked + 1))

  if [ "$count" -gt "$limit" ]; then
    echo "ratchet: $name: $limit -> $count. The count went UP. Do not add a new occurrence of /$regex/ under $path; use the place this project defines for it. Current occurrences:" >&2
    printf '%s\n' "$matches" | cut -c1-200 | head -20 | sed 's/^/  /' >&2
    failed=1
  elif [ "$count" -lt "$limit" ]; then
    echo "ratchet: $name: $limit -> $count. The count went down. Lower the number for '$name' in $file to $count and include that change." >&2
    failed=1
  fi
done <"$file"

[ "$failed" -eq 0 ] || exit 1
echo "ratchet: $checked item(s) match $file"
exit 0
