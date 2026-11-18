#!/usr/bin/env bash
# ハーネスのフックと、初期プロンプト（各パターンの CLAUDE.md）の欄を試験する。
#
#   bash tests/run.sh
#
# README の手順どおりに各パターンを一時ディレクトリへ組み立て、settings.json に書かれた
# フックの呼び出しをそのまま実行して、終了コードと出力を確かめる。
# スクリプト単体ではなく「呼び出し方ごと」試すので、パスの書き間違いや組み立て手順のずれも落ちる。
#
#   - フックはプロジェクトルートではない場所から呼ぶ（エージェントが cd した後を想定）
#   - /bin/bash と PATH 上の bash の版が違えば両方で回す（macOS 標準の 3.2 と新しい版）
#
# 試験表は tests/cases/*.txt。必要なもの：jq
# ここで確かめるのはスクリプトの挙動まで。Claude Code がフックをどう呼ぶかは公式文書に拠っている。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/tests/cases"
ALL_PATTERNS="common web mobile-flutter desktop-mac desktop-windows-wpf"
EDIT_MATCHER='Edit|Write|MultiEdit'

command -v jq >/dev/null 2>&1 || { echo "tests/run.sh needs jq" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
ng() {
  FAIL=$((FAIL + 1))
  echo "  NG [$SH_LABEL] $1"
  [ -s "$WORK/stderr" ] && sed 's/^/       /' "$WORK/stderr" | head -3
  return 0
}

# README「新規プロジェクトの立ち上げ」と同じ並びに組み立てる
assemble() { # $1=パターン $2=出力先
  mkdir -p "$2/.claude/hooks" "$2/elsewhere"
  if [ "$1" = common ]; then
    cp "$ROOT/common/.claude/settings.json" "$2/.claude/settings.json"
  else
    cp -R "$ROOT/$1/.claude/." "$2/.claude/"
  fi
  cp -R "$ROOT/common/.claude/hooks" "$2/.claude/hooks/common"
  # settings.json からフックの呼び出しを抜き出しておく（1 行 1 コマンド）
  hook_commands "$2" PreToolUse Bash >"$2/.hooks-PreToolUse-Bash"
  hook_commands "$2" PreToolUse "$EDIT_MATCHER" >"$2/.hooks-PreToolUse-Edit"
  hook_commands "$2" PostToolUse "$EDIT_MATCHER" >"$2/.hooks-PostToolUse-Edit"
  hook_commands "$2" Stop "" >"$2/.hooks-Stop-All"
}

hook_commands() { # $1=プロジェクト $2=イベント $3=matcher（matcher を持たないイベントは空文字）
  jq -r --arg e "$2" --arg m "$3" '.hooks[$e][]? | select((.matcher // "") == $m) | .hooks[].command' "$1/.claude/settings.json"
}

# 標準入力のフック入力を、その matcher に登録された全フックへ渡して実行する。
# Claude Code と同じく、1 つでも終了コード 2 を返せばブロック（2 を返す）。
# stdout はそのまま、stderr は $WORK/stderr へ。
run_hook() { # $1=プロジェクト $2=イベント $3=Bash|Edit|All
  local list="$1/.hooks-$2-$3" input cmd rc worst=0
  : >"$WORK/stderr"
  [ -s "$list" ] || { echo "no hook for $2 [$3] in $1" >"$WORK/stderr"; return 99; }
  input="$(cat)"
  while IFS= read -r cmd <&4; do
    printf '%s' "$input" | (cd "$1/elsewhere" && CLAUDE_PROJECT_DIR="$1" PATH="$SHIM:$PATH" "$SH" -c "$cmd") 2>>"$WORK/stderr"
    rc=$?
    if [ "$rc" -eq 2 ]; then worst=2; elif [ "$rc" -ne 0 ] && [ "$worst" -eq 0 ]; then worst=$rc; fi
  done 4<"$list"
  return "$worst"
}

bash_input() { jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c, description: "test"}}'; }
edit_input() { jq -n --arg p "$1" '{tool_name: "Edit", tool_input: {file_path: $p}}'; }

expect_rc() { # $1=期待 $2=実際の終了コード $3=説明
  local want
  case "$1" in block) want=2 ;; allow) want=0 ;; *) want="?" ;; esac
  if [ "$2" = "$want" ]; then ok; else ng "$3: expected $1 (rc=$want), got rc=$2"; fi
}

guard_cases() { # $1=bash|edit $2=試験表
  local expect pattern input targets p proj rc
  while read -r expect pattern input <&3 || [ -n "${expect:-}" ]; do
    case "${expect:-}" in '' | '#'*) continue ;; esac
    if [ "$pattern" = all ]; then targets="$ALL_PATTERNS"; else targets="$pattern"; fi
    for p in $targets; do
      proj="$BASE/$p"
      if [ "$1" = bash ]; then
        bash_input "$input" | run_hook "$proj" PreToolUse Bash >/dev/null
      else
        edit_input "$proj/$input" | run_hook "$proj" PreToolUse Edit >/dev/null
      fi
      rc=$?
      expect_rc "$expect" "$rc" "$1 guard, $p: $input"
    done
  done 3<"$2"
}

post_edit_cases() { # $1=試験表
  local pattern rel text proj out rc
  while read -r pattern rel text <&3 || [ -n "${pattern:-}" ]; do
    case "${pattern:-}" in '' | '#'*) continue ;; esac
    proj="$BASE/$pattern"
    mkdir -p "$(dirname "$proj/$rel")"
    : >"$proj/$rel"
    out="$(edit_input "$proj/$rel" | run_hook "$proj" PostToolUse Edit)"
    rc=$?
    if [ "$rc" != 0 ]; then
      ng "post-edit, $pattern: $rel: expected rc=0, got rc=$rc"
    elif [ "$text" = "-" ]; then
      if [ -z "$out" ]; then ok; else ng "post-edit, $pattern: $rel: expected no output, got: $out"; fi
    elif printf '%s' "$out" | jq -e --arg s "$text" \
      '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | contains($s))' >/dev/null 2>&1; then
      ok
    else
      ng "post-edit, $pattern: $rel: additionalContext should contain '$text', got: $out"
    fi
  done 3<"$1"
}

# ガードが動けないときは、通すのではなく止まること
fail_closed_cases() {
  local proj p

  proj="$BASE/broken-missing"
  cp -R "$BASE/web" "$proj"
  rm "$proj/.claude/hooks/common/guard-bash.sh" "$proj/.claude/hooks/common/guard-edit.sh"
  bash_input "ls -la" | run_hook "$proj" PreToolUse Bash >/dev/null
  expect_rc block $? "guard-bash.sh が無い"
  edit_input "$proj/README.md" | run_hook "$proj" PreToolUse Edit >/dev/null
  expect_rc block $? "guard-edit.sh が無い"

  for p in $ALL_PATTERNS; do
    proj="$BASE/$p"
    printf 'not json' | run_hook "$proj" PreToolUse Bash >/dev/null
    expect_rc block $? "$p: フック入力が JSON でない（Bash）"
    printf 'not json' | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc block $? "$p: フック入力が JSON でない（Edit）"
    : | run_hook "$proj" PreToolUse Bash >/dev/null
    expect_rc block $? "$p: フック入力が空（Bash）"
    : | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc block $? "$p: フック入力が空（Edit）"
  done

  proj="$BASE/broken-regex"
  cp -R "$BASE/web" "$proj"
  printf '%s\n' 'foo(' >>"$proj/.claude/hooks/extra-deny.txt"
  bash_input "ls -la" | run_hook "$proj" PreToolUse Bash >/dev/null
  expect_rc block $? "extra-deny.txt の正規表現が壊れている"

  # Windows で改行が CRLF になっても、コメント行があってもパターンが効くこと
  proj="$BASE/crlf"
  cp -R "$BASE/web" "$proj"
  printf '# comment\r\n\r\ngoose[[:space:]]+up\r\n' >"$proj/.claude/hooks/extra-deny.txt"
  bash_input "goose up" | run_hook "$proj" PreToolUse Bash >/dev/null
  expect_rc block $? "extra-deny.txt が CRLF"
  bash_input "ls -la" | run_hook "$proj" PreToolUse Bash >/dev/null
  expect_rc allow $? "extra-deny.txt が CRLF でも無関係なコマンドは通る"

  # 編集ガードのプロジェクト固有の追加（extra-deny-paths.txt）。後から導入した既存リポジトリは、
  # 生成コードが generated/ 以外にあるので、ここで守る場所を足す
  for p in common web; do
    proj="$BASE/paths-$p"
    cp -R "$BASE/$p" "$proj"
    printf '# 生成コード\r\n\r\n(^|/)src/lib/data/(func|table)/\r\n' >"$proj/.claude/hooks/extra-deny-paths.txt"
    edit_input "$proj/src/lib/data/func/f_get.ts" | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc block $? "$p: extra-deny-paths.txt に足した場所"
    edit_input "$proj/src/lib/data/api/handler.ts" | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc allow $? "$p: extra-deny-paths.txt に無い場所"
    edit_input "$proj/src/generated/x.ts" | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc block $? "$p: extra-deny-paths.txt があっても基底の対象は止まる"
    printf '%s\n' 'foo(' >>"$proj/.claude/hooks/extra-deny-paths.txt"
    edit_input "$proj/README.md" | run_hook "$proj" PreToolUse Edit >/dev/null
    expect_rc block $? "$p: extra-deny-paths.txt の正規表現が壊れている"
  done
}

# 歯止め（ratchet.sh）。書き留めた違反の数と今の数が一致するときだけ通ること
ratchet_expect() { # $1=pass|fail $2=プロジェクト $3=説明 [$4=出力に含まれるはずの文字列]
  local out rc got
  out="$(cd "$2/elsewhere" && CLAUDE_PROJECT_DIR="$2" "$SH" "$2/.claude/hooks/common/ratchet.sh" 2>&1)"
  rc=$?
  : >"$WORK/stderr"
  if [ "$rc" -eq 0 ]; then got=pass; elif [ "$rc" -eq 1 ]; then got=fail; else got="rc=$rc"; fi
  if [ "$got" != "$1" ]; then ng "ratchet, $3: expected $1, got $got: $out"
  elif [ -n "${4:-}" ] && ! printf '%s' "$out" | grep -Fq -- "$4"; then ng "ratchet, $3: 出力に '$4' が無い: $out"
  else ok; fi
}

ratchet_cases() {
  local proj="$BASE/ratchet"
  cp -R "$BASE/common" "$proj"
  mkdir -p "$proj/src/cmd" "$proj/src/lib"
  printf 'a = queryRaw(1)\nb = queryRaw(2); c = queryRaw(3)\n' >"$proj/src/cmd/one.ts"
  printf 'x = queryRaw(9)\n' >"$proj/src/lib/ok.ts"

  ratchet_expect pass "$proj" "ratchet.txt が無ければ何もしない"
  printf '# 数 名前 パス 正規表現\r\n\r\n3 raw-sql src/cmd queryRaw\r\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect fail "$proj" "git リポジトリでない" "not a git repository"

  (cd "$proj" && scratch_git init -q && scratch_git add -A && scratch_git commit -q -m init) >/dev/null 2>"$WORK/stderr" ||
    { ng "ratchet: 試験用リポジトリを作れない"; return; }
  ratchet_expect pass "$proj" "数が一致（1 行に 2 箇所あれば 2 と数える。CRLF とコメント行も読める）" "1 item(s)"

  # 新しい未追跡ファイルに違反を足しても数える
  printf 'd = queryRaw(4)\n' >"$proj/src/cmd/two.ts"
  ratchet_expect fail "$proj" "未追跡ファイルで増えた" "3 -> 4"
  printf 'd = 4\n' >"$proj/src/cmd/two.ts"
  ratchet_expect pass "$proj" "元に戻した"

  # 減ったときも落として、書き留めた数を下げさせる
  printf 'a = queryRaw(1)\n' >"$proj/src/cmd/one.ts"
  ratchet_expect fail "$proj" "減った" "to 1"
  printf '1 raw-sql src/cmd queryRaw\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect pass "$proj" "数を下げた"

  # 空白を含む正規表現は行末までを 1 つとして読む
  printf '1 raw-sql src/cmd queryRaw\n1 assign src/cmd a = query\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect pass "$proj" "空白を含む正規表現" "2 item(s)"

  # 読めない行・無いパス・壊れた正規表現は、読み飛ばさずに落とす
  printf 'x raw-sql src/cmd queryRaw\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect fail "$proj" "数が数字でない" "cannot read line"
  printf '1 raw-sql src/cmd\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect fail "$proj" "正規表現が無い" "cannot read line"
  printf '1 raw-sql src/nowhere queryRaw\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect fail "$proj" "パスが無い" "does not exist"
  printf '0 broken src/cmd foo(\n' >"$proj/.claude/ratchet.txt"
  ratchet_expect fail "$proj" "正規表現が壊れている" "invalid regex"
}

# check の門番（check-gate.sh）。変更したのに check を通していないまま終わるのを止めること。
stop_input() { printf '%s' '{"hook_event_name": "Stop", "stop_hook_active": false}'; }
scratch_git() { git -c user.name=harness-test -c user.email=harness-test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

# 門番の判定を確かめる。stop = 終了を止める / pass = 黙って通す / warn = 通すが利用者に警告を出す
# 止める合図は JSON（decision: block）で、終了コードは常に 0 のはず
gate_expect() { # $1=stop|pass|warn $2=プロジェクト $3=説明
  local out rc got
  out="$(stop_input | run_hook "$2" Stop All)"
  rc=$?
  if [ "$rc" != 0 ]; then got="rc=$rc"
  elif [ -z "$out" ]; then got=pass
  elif printf '%s' "$out" | jq -e '.decision == "block" and (.reason | length > 0)' >/dev/null 2>&1; then got=stop
  elif printf '%s' "$out" | jq -e '.systemMessage | length > 0' >/dev/null 2>&1; then got=warn
  else got="unexpected output"; fi
  if [ "$got" = "$1" ]; then ok; else ng "gate, $3: expected $1, got $got: $out"; fi
}

gate_cases() {
  local p proj rc
  for p in $ALL_PATTERNS; do
    # git リポジトリでなければ何もしない
    proj="$BASE/$p"
    : >"$proj/notes.md"
    edit_input "$proj/notes.md" | run_hook "$proj" PostToolUse Edit >/dev/null
    gate_expect pass "$proj" "$p: git リポジトリでない"

    proj="$BASE/gate-$p"
    cp -R "$BASE/$p" "$proj"
    (cd "$proj" && scratch_git init -q && printf 'one\n' >notes.md && printf 'x\n' >"日本語 の名前.md" &&
      scratch_git add -A && scratch_git commit -q -m init) >/dev/null 2>"$WORK/stderr" ||
      { ng "gate, $p: 試験用リポジトリを作れない"; continue; }

    gate_expect pass "$proj" "$p: 何も編集していない"

    # エージェントが編集した（PostToolUse が印を付ける）→ check を通すまで終われない
    printf 'two\n' >>"$proj/notes.md"
    edit_input "$proj/notes.md" | run_hook "$proj" PostToolUse Edit >/dev/null
    gate_expect stop "$proj" "$p: 編集したまま終わろうとした"

    # 同じ中身で 2 回目は通す。利用者への警告を 1 回だけ出す
    gate_expect warn "$proj" "$p: 同じ中身で 2 回目"
    gate_expect pass "$proj" "$p: 同じ中身で 3 回目"

    # 中身が変われば、また止める（ファイル名に空白や日本語があっても拾う）
    printf 'y\n' >>"$proj/日本語 の名前.md"
    gate_expect stop "$proj" "$p: さらに変更して終わろうとした"

    # check が通った（check コマンドの最後が record を呼ぶ。プロジェクトルートから、環境変数なしで）
    (cd "$proj" && PATH="$SHIM:$PATH" bash .claude/hooks/common/check-gate.sh record)
    gate_expect pass "$proj" "$p: check が通った後"

    # コミットしても中身は同じなので通る
    edit_input "$proj/notes.md" | run_hook "$proj" PostToolUse Edit >/dev/null
    (cd "$proj" && scratch_git add -A && scratch_git commit -q -m change) >/dev/null 2>&1
    gate_expect pass "$proj" "$p: check の後にコミットしただけ"

    # 未追跡のファイルを足しても止める
    edit_input "$proj/notes.md" | run_hook "$proj" PostToolUse Edit >/dev/null
    printf 'new\n' >"$proj/added.md"
    gate_expect stop "$proj" "$p: 未追跡ファイルを足して終わろうとした"

    # 門番が壊れているとき・無いときは、終了を止めない（終了コード 2 を返さず、block も出さない）
    printf '#!/usr/bin/env bash\nif then (\n' >"$proj/.claude/hooks/common/check-gate.sh" # 構文エラー（bash は 2 を返す）
    stop_input | run_hook "$proj" Stop All >/dev/null
    rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then ok; else ng "gate, $p: 壊れた門番は止めずにエラーを返すはず (rc=$rc)"; fi
    rm "$proj/.claude/hooks/common/check-gate.sh"
    stop_input | run_hook "$proj" Stop All >/dev/null
    rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then ok; else ng "gate, $p: 門番が無いときは止めずにエラーを返すはず (rc=$rc)"; fi
  done
}

# 各パターンの check コマンドが「通った」の記録を呼び、門番の案内がそのコマンド名を指していること
template_cases() {
  local p file label
  for p in web mobile-flutter desktop-mac desktop-windows-wpf; do
    if [ "$p" = web ]; then file="$ROOT/$p/template/Taskfile.yml" label="task check"; else file="$ROOT/$p/template/Makefile" label="make check"; fi
    : >"$WORK/stderr"
    if grep -q 'check-gate\.sh record' "$file"; then ok; else ng "template, $p: check が check-gate.sh record を呼んでいない"; fi
    if grep -Fq "gate '$label'" "$BASE/$p/.hooks-Stop-All"; then ok; else ng "template, $p: Stop フックの案内が '$label' になっていない"; fi
    # 人ごとの設定（既存リポジトリの場所など）がコミットされないこと
    if grep -Fxq '.claude/settings.local.json' "$ROOT/$p/template/.gitignore"; then ok; else ng "template, $p: .gitignore に .claude/settings.local.json が無い"; fi
  done
}

# settings.json のフック呼び出しが、組み立て後のプロジェクトで実在するスクリプトを指していること
settings_cases() {
  local p proj cmds cmd script missing
  for p in $ALL_PATTERNS; do
    proj="$BASE/$p"
    : >"$WORK/stderr"
    if ! jq -e . "$proj/.claude/settings.json" >/dev/null 2>"$WORK/stderr"; then
      ng "settings, $p: settings.json が JSON として読めない"
      continue
    fi
    cmds="$(jq -r '.hooks[][] | .hooks[].command' "$proj/.claude/settings.json")"
    missing=""
    while IFS= read -r cmd; do
      case "$cmd" in
        *'${CLAUDE_PROJECT_DIR}'*) ;;
        *) missing="$missing [CLAUDE_PROJECT_DIR を使っていない: $cmd]" ;;
      esac
      for script in $(printf '%s' "$cmd" | grep -Eo '\$\{CLAUDE_PROJECT_DIR\}/[^"[:space:]]+\.sh' | sed 's/^\${CLAUDE_PROJECT_DIR}\///'); do
        [ -f "$proj/$script" ] || missing="$missing [スクリプトが無い: $script]"
      done
    done <<EOF
$cmds
EOF
    while IFS= read -r cmd; do
      case "$cmd" in
        *'|| exit 2') ;;
        *) missing="$missing [PreToolUse が失敗時に止まらない: $cmd]" ;;
      esac
    done <<EOF
$(jq -r '.hooks.PreToolUse[] | .hooks[].command' "$proj/.claude/settings.json")
EOF
    if [ -z "$missing" ]; then ok; else ng "settings, $p:$missing"; fi
  done
}

run_all() { # $1=試す bash のパス
  SH="$1"
  SH_LABEL="bash $("$SH" -c 'echo "$BASH_VERSION"')"
  BASE="$WORK/$(printf '%s' "$SH_LABEL" | tr -c 'A-Za-z0-9.' '_')"
  SHIM="$BASE/shim"
  mkdir -p "$SHIM"
  ln -s "$SH" "$SHIM/bash" # フック内の `bash ...` を試す対象の bash に向ける
  local p before=$PASS
  for p in $ALL_PATTERNS; do assemble "$p" "$BASE/$p"; done

  echo "== $SH_LABEL ($SH)"
  settings_cases
  guard_cases bash "$CASES/guard-bash.txt"
  guard_cases edit "$CASES/guard-edit.txt"
  post_edit_cases "$CASES/post-edit.txt"
  fail_closed_cases
  ratchet_cases
  gate_cases
  template_cases
  echo "   $((PASS - before)) ok"
}

# 初期プロンプト（各パターンの CLAUDE.md）が docs/design.md 2 章の欄を同じ並びで持ち、短く保たれていること。
# フックと違って bash の版に依らないので 1 回だけ回す。
TYPE_SECTIONS='責任範囲と境界
実行環境と前提
コマンド
人間だけが叩く操作
構成と依存方向
手本と追加手順
唯一の定義場所
使わないもの
テスト
止まって確認する判断
互換性の制約
確認手段と証拠
プロジェクト固有'
PROJECT_FIELDS='目的と利用者
ドメイン用語
主要
破ってはならない業務ルール
契約の段階
外部連携
環境（
外に出ている版
触ってはいけない場所
依頼の入口'
PROMPT_MAX_LINES=200 # パターンの CLAUDE.md と基底の合計。これ未満

# paths のグロブを正規表現に直す。Claude Code の照合そのものではなく、書き間違いを見つけるための近似
glob_to_regex() {
  local re
  re="$(printf '%s' "$1" | sed -e 's/\./\\./g' -e 's#\*\*/#@@#g' -e 's#\*#[^/]*#g' -e 's#@@#(.*/)?#g' -e 's/{/(/g' -e 's/}/)/g' -e 's/,/|/g')"
  case "$1" in */*) printf '^%s$' "$re" ;; *) printf '^(.*/)?%s$' "$re" ;; esac
}

# ルールの frontmatter から paths の各パターンを 1 行ずつ出す
rule_paths() { awk 'NR > 1 && /^---$/ { exit } /^[[:space:]]*- / { sub(/^[[:space:]]*- /, ""); gsub(/"/, ""); print }' "$1"; }

prompt_cases() {
  SH_LABEL="prompt"
  local p file got field line i n rule name pattern re before=$PASS common_lines
  common_lines="$(wc -l <"$ROOT/common/CLAUDE.md")"
  echo "== 初期プロンプト"
  for p in web mobile-flutter desktop-mac desktop-windows-wpf; do
    file="$ROOT/$p/CLAUDE.md"
    : >"$WORK/stderr"

    # 欄の並び。見出しの後ろの括弧書きは見ない
    got="$(grep '^## ' "$file" | sed -e 's/^## //' -e 's/（.*//')"
    if [ "$got" = "$TYPE_SECTIONS" ]; then ok; else
      ng "$p: CLAUDE.md の欄が design.md 2 章の一覧と違う"
      diff <(printf '%s\n' "$TYPE_SECTIONS") <(printf '%s\n' "$got") | sed 's/^/       /'
    fi

    # 中身の無い欄が無いこと（当てはまらない欄は消さずに「該当なし」と書く）
    got="$(awk '/^## /{ if (h != "" && n == 0) print h; h = $0; n = 0; next } NF { n++ } END { if (h != "" && n == 0) print h }' "$file")"
    if [ -z "$got" ]; then ok; else ng "$p: 中身の無い欄がある: $got"; fi

    # プロジェクトが埋める欄。先頭の 10 個が共通の並び
    got="$(awk '/^## プロジェクト固有/{ f = 1; next } f && /^- /' "$file")"
    i=0
    while IFS= read -r field; do
      i=$((i + 1))
      line="$(printf '%s\n' "$got" | sed -n "${i}p")"
      case "$line" in "- $field"*) ok ;; *) ng "$p: プロジェクト固有の $i 番目が「${field}」で始まっていない: $line" ;; esac
    done <<EOF
$PROJECT_FIELDS
EOF

    # 基底と合わせた行数。@ で取り込んでも読み込み量は減らないので合計で見る
    n=$(($(wc -l <"$file") + common_lines))
    if [ "$n" -lt "$PROMPT_MAX_LINES" ]; then ok; else
      ng "$p: CLAUDE.md と基底の合計が $n 行（$PROMPT_MAX_LINES 行未満にする。足すなら削るか .claude/rules/ に移す）"
    fi

    # パス付きルール。paths が無いと毎回読まれ、CLAUDE.md を短くした意味が無くなる
    for rule in "$ROOT/$p/.claude/rules"/*.md; do
      [ -f "$rule" ] || continue
      name="$(basename "$rule")"
      if [ "$(head -1 "$rule")" = "---" ] && [ -n "$(rule_paths "$rule")" ] && grep -q '^paths:' "$rule"; then ok; else
        ng "$p: rules/$name の先頭に paths が無い"
        continue
      fi
      if grep -Fq "\`$name\`" "$file"; then ok; else ng "$p: rules/$name が CLAUDE.md から名指しされていない"; fi
      # 各パターンが、雛形のどれかのファイルに当たること
      while IFS= read -r pattern; do
        re="$(glob_to_regex "$pattern")"
        if (cd "$ROOT/$p/template" && find . -type f | sed 's#^\./##' | grep -Eq "$re"); then ok; else
          ng "$p: rules/$name の paths「${pattern}」が雛形のどのファイルにも当たらない"
        fi
      done <<EOF
$(rule_paths "$rule")
EOF
    done
  done

  # 後付け導入の下敷き（retrofit/CLAUDE.md）。タイプと同じ欄を同じ並びで持ち、空の欄が無いこと
  file="$ROOT/common/retrofit/CLAUDE.md"
  : >"$WORK/stderr"
  got="$(grep '^## ' "$file" | sed -e 's/^## //' -e 's/（.*//')"
  if [ "$got" = "$TYPE_SECTIONS" ]; then ok; else
    ng "retrofit/CLAUDE.md の欄が design.md 2 章の一覧と違う"
    diff <(printf '%s\n' "$TYPE_SECTIONS") <(printf '%s\n' "$got") | sed 's/^/       /'
  fi
  got="$(awk '/^## /{ if (h != "" && n == 0) print h; h = $0; n = 0; next } NF { n++ } END { if (h != "" && n == 0) print h }' "$file")"
  if [ -z "$got" ]; then ok; else ng "retrofit/CLAUDE.md: 中身の無い欄がある: $got"; fi
  got="$(awk '/^## プロジェクト固有/{ f = 1; next } f && /^- /' "$file")"
  i=0
  while IFS= read -r field; do
    i=$((i + 1))
    line="$(printf '%s\n' "$got" | sed -n "${i}p")"
    case "$line" in "- $field"*) ok ;; *) ng "retrofit/CLAUDE.md: プロジェクト固有の $i 番目が「${field}」で始まっていない: $line" ;; esac
  done <<EOF
$PROJECT_FIELDS
EOF
  # 後付けでは基底と流儀が食い違いうるので、優先の決まりと、歯止めの数を上げるときの確認を下敷きが持つこと
  if grep -Fq '基底より優先する決まり' "$file" && grep -Fq 'ratchet.txt' "$file"; then ok; else
    ng "retrofit/CLAUDE.md に「基底より優先する決まり」か ratchet.txt への言及が無い"
  fi

  # 既存の隣に作る手順（brownfield.md）。写して使う設定の例が JSON として読め、既存側への Edit を絶対パスで拒否していること
  : >"$WORK/stderr"
  got="$(awk '/^```json$/{ f = 1; next } /^```$/{ f = 0 } f' "$ROOT/common/brownfield.md")"
  if printf '%s' "$got" | jq -e '.permissions.deny | map(select(startswith("Edit(//"))) | length > 0' >/dev/null 2>"$WORK/stderr"; then ok; else
    ng "brownfield.md: 設定の例が JSON として読めないか、Edit(//...) の拒否ルールが無い"
  fi
  # 基底が指す先は、プロジェクトに置いた後の場所であること
  if grep -Fq '`docs/brownfield.md`' "$ROOT/common/CLAUDE.md" && grep -Fq 'docs/brownfield.md' "$ROOT/common/brownfield.md"; then ok; else
    ng "common/CLAUDE.md か brownfield.md が、プロジェクト内の置き場所 docs/brownfield.md を指していない"
  fi
  echo "   $((PASS - before)) ok"
}

seen=""
for sh in /bin/bash "$(command -v bash)"; do
  [ -x "$sh" ] || continue
  v="$("$sh" -c 'echo "$BASH_VERSION"')"
  case " $seen " in *" $v "*) continue ;; esac
  seen="$seen $v"
  run_all "$sh"
done

prompt_cases

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
