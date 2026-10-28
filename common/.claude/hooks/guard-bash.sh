#!/usr/bin/env bash
# PreToolUse フック（matcher: Bash）
# 破壊的・本番向け操作をコマンド文字列で機械的にブロックする。
# 終了コード 2 = ブロック（stderr がエージェントに返る）。0 = 許可。
#
# 追加のパターンはパターン固有の guard（.claude/hooks/guard-bash.sh）で
# EXTRA_DENY に追記する。このファイル自体は共通なので編集しない。

set -u
input="$(cat)"

extract() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.command // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))'
  else
    printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p'
  fi
}
cmd="$(extract)"
[ -z "$cmd" ] && exit 0

# 共通の拒否パターン（拡張正規表現）
COMMON_DENY=(
  'git[[:space:]]+push[^|;&]*--force'
  'git[[:space:]]+push[^|;&]*-f([[:space:]]|$)'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-[a-z]*f'
  'git[[:space:]]+branch[[:space:]]+-D'
  'rm[[:space:]]+-[a-z]*r[a-z]*f?[[:space:]]+(/|~|\.\.|\.|\*)([[:space:]]|$)'
  'rm[[:space:]]+-[a-z]*f[a-z]*r?[[:space:]]+(/|~|\.\.|\.|\*)([[:space:]]|$)'
  'cdk[[:space:]]+(deploy|destroy)'
  'terraform[[:space:]]+(apply|destroy)'
  'aws[[:space:]]+[a-z0-9-]+[[:space:]]+(delete|terminate|put-|update-|create-)'
  'curl[^|]*\|[[:space:]]*(ba)?sh'
  'chmod[[:space:]]+-R[[:space:]]+777'
  '(^|[[:space:]])sudo[[:space:]]'
)

# パターン固有の追加（呼び出し側が環境変数で渡す）
IFS=$'\n' read -r -d '' -a EXTRA <<< "${EXTRA_DENY:-}" || true

for pat in "${COMMON_DENY[@]}" "${EXTRA[@]}"; do
  [ -z "$pat" ] && continue
  if printf '%s' "$cmd" | grep -Eq -- "$pat"; then
    echo "BLOCKED by harness guard: command matches '$pat'. This operation is reserved for a human. Explain what you wanted to do and ask the user to run it." >&2
    exit 2
  fi
done

# 秘密情報らしきものを書き出そうとしていないか
if printf '%s' "$cmd" | grep -Eq -- '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{20,})'; then
  echo "BLOCKED by harness guard: command appears to contain a credential. Never write secrets into files or commands." >&2
  exit 2
fi

exit 0
