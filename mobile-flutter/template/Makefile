# エージェントのエントリポイント
.PHONY: check gen test golden run screenshot format analyze

check: format-check analyze test gen-check

format:
	dart format lib test

format-check:
	dart format --output=none --set-exit-if-changed lib test

analyze:
	flutter analyze --fatal-infos

test:
	flutter test

golden:
	flutter test --update-goldens test/

gen:
	openapi-generator generate -c openapi-generator.yaml
	dart run build_runner build --delete-conflicting-outputs

gen-check: gen
	git diff --exit-code -- lib/generated '*.g.dart' '*.freezed.dart' || (echo "generated code is stale: commit the output of 'make gen'" && exit 1)

run:
	flutter run

# 起動中の iOS シミュレータ / Android エミュレータの画面を取る
screenshot:
	mkdir -p screenshots
	@if xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then \
	  xcrun simctl io booted screenshot screenshots/ios-$$(date +%s).png; \
	elif adb devices 2>/dev/null | grep -q device$$; then \
	  adb exec-out screencap -p > screenshots/android-$$(date +%s).png; \
	else echo "no booted simulator/emulator"; exit 1; fi
	@ls -t screenshots | head -1
