#!/usr/bin/env bash
# 編集した .swift を format + lint。project.yml を変えたら xcodegen を回す。
set -u
input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
else
  path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)"
fi
[ -z "$path" ] || [ ! -f "$path" ] && exit 0

case "$path" in
  *.swift)
    swiftformat --quiet "$path"
    if ! out="$(swiftlint lint --quiet --strict "$path" 2>&1)"; then
      echo "swiftlint failed:" >&2; echo "$out" >&2; exit 2
    fi
    case "$path" in
      */Packages/Domain/*)
        if grep -Eq '^import (SwiftUI|AppKit|UIKit)' "$path"; then
          echo "Domain package must not import SwiftUI/AppKit. Keep it Foundation + GRDB only." >&2; exit 2
        fi ;;
    esac
    ;;
  */project.yml)
    if ! out="$(xcodegen generate --quiet 2>&1)"; then
      echo "xcodegen failed:" >&2; echo "$out" >&2; exit 2
    fi
    echo "project.yml changed: .xcodeproj regenerated." >&2
    ;;
  *.entitlements)
    echo "entitlements changed: this affects sandbox/App Store review. Confirm with the user." >&2 ;;
esac
exit 0
