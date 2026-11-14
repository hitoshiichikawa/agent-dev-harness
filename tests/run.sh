#!/usr/bin/env bash
# ハーネスのフックを試験する。
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
}

hook_commands() { # $1=プロジェクト $2=イベント $3=matcher
  jq -r --arg e "$2" --arg m "$3" '.hooks[$e][]? | select(.matcher == $m) | .hooks[].command' "$1/.claude/settings.json"
}

# 標準入力のフック入力を、その matcher に登録された全フックへ渡して実行する。
# Claude Code と同じく、1 つでも終了コード 2 を返せばブロック（2 を返す）。
# stdout はそのまま、stderr は $WORK/stderr へ。
run_hook() { # $1=プロジェクト $2=イベント $3=Bash|Edit
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

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
