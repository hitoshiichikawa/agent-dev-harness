#!/usr/bin/env bash
# check の門番。「変更したのに check を通していない」まま終わるのを止める。
#
#   check-gate.sh mark             PostToolUse（Edit|Write）から呼ぶ。エージェントがファイルを変えた印を付ける
#   check-gate.sh record           check コマンドの最後から呼ぶ。「この中身で check が通った」と記録する
#   check-gate.sh gate [コマンド名]  Stop フックから呼ぶ。印があり、今の中身で check が通っていなければ終了を止める
#
# 仕組み：
#   - 作業ツリーの中身（追跡ファイルと、無視されていない未追跡ファイル）から指紋を作る。
#     中身だけを見るので、git add や git commit をしても指紋は変わらない
#   - record が指紋を保存する。gate は今の指紋と比べ、違えば終了を止める（JSON の decision: block）
#   - 同じ中身で 2 回目に終わろうとしたら通す。質問のために止まる、どうしても通らず報告して止まる、
#     という場合の逃げ道。このときは利用者に警告を出す（「check が通っていないまま終わった」と人に見える）
#   - 止めるたびに中身が変わっている必要があるので、無限に止め続けることはない
#
# check そのものはここでは走らせない。エージェントが自分で走らせ、出力を見て直す。
# 状態は .git の下に置く（追跡も指紋への混入もしない）。git リポジトリでなければ何もしない。
# ガードと違い、この門番が壊れたときは止めない（終われなくなるより、通すほうが害が小さい）。
# そのため止める合図に終了コード 2 を使わず、settings.json 側も `|| exit 1` で 2 を返さないようにする。

set -u
mode="${1:-gate}"
check_cmd="${2:-}"
# 既定値の文言にアポストロフィを入れない（bash が ${2:-...} の中の ' を引用の開始として読む）
[ -n "$check_cmd" ] || check_cmd="the project check command"

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
cd "$root" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
state="$gitdir/harness"
mkdir -p "$state" || exit 0

# 作業ツリーの中身の指紋。ファイル名の一覧と、各ファイルの中身のハッシュから作る
fingerprint() {
  local list="$state/files.tmp"
  git ls-files -z -c -o --exclude-standard | tr '\0' '\n' | LC_ALL=C sort -u |
    while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done >"$list"
  { cat "$list"; git hash-object --stdin-paths <"$list"; } | git hash-object --stdin
  rm -f "$list"
}

read_state() { [ -f "$state/$1" ] && cat "$state/$1"; }

case "$mode" in
  mark)
    : >"$state/edited"
    ;;

  record)
    fingerprint >"$state/passed"
    rm -f "$state/edited" "$state/blocked" "$state/warned"
    ;;

  gate)
    cat >/dev/null # フック入力は使わない
    [ -f "$state/edited" ] || exit 0
    now="$(fingerprint)"
    [ -n "$now" ] || exit 0

    if [ "$now" = "$(read_state passed)" ]; then
      rm -f "$state/edited" "$state/blocked" "$state/warned"
      exit 0
    fi

    if [ "$now" = "$(read_state blocked)" ]; then
      # この中身については一度止めた。2 回目は通し、人に見える形で警告する（同じ中身では 1 回だけ）
      if [ "$now" != "$(read_state warned)" ]; then
        printf '%s' "$now" >"$state/warned"
        printf '{"systemMessage":"harness: files changed, but %s has not passed. The agent stopped without a passing check."}\n' "$check_cmd"
      fi
      exit 0
    fi

    printf '%s' "$now" >"$state/blocked"
    # 止める合図は JSON で出す（終了コードは 0）。終了コード 2 を合図にすると、構文エラーなどで
    # このスクリプトが壊れたとき（bash は 2 を返す）にも終了を止めてしまう。
    # 文言に " と \ を入れない（JSON にそのまま埋め込む）
    printf '{"decision":"block","reason":"harness: files changed since the last passing check. Run %s and fix what fails before you finish. If you are stopping to ask the user something, or the check cannot pass, do not claim the work is complete: say which step fails and why, then stop again (a second stop without further changes is allowed)."}\n' "$check_cmd"
    exit 0
    ;;

  *)
    echo "check-gate.sh: unknown mode '$mode'" >&2
    exit 1
    ;;
esac
exit 0
