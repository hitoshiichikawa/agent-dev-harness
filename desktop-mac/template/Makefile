# エージェントのエントリポイント
APP      := MyApp
SCHEME   := $(APP)
PROJECT  := $(APP).xcodeproj
DERIVED  := build/DerivedData

.PHONY: check gen build run test test-domain format format-check lint screenshot clean

# 全部通ったら「この中身で check が通った」と記録する。終了時の門番（check-gate.sh）がこれを見る
check: format-check lint test-domain test
	@test ! -f .claude/hooks/common/check-gate.sh || bash .claude/hooks/common/check-gate.sh record

gen:
	xcodegen generate

format:
	swiftformat App Packages AppUITests

format-check:
	swiftformat --lint App Packages AppUITests

lint:
	swiftlint lint --quiet --strict

test-domain:
	cd Packages/Domain && swift test

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) build | xcbeautify || xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) build

test: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) test

run: build
	open -a "$(DERIVED)/Build/Products/Debug/$(APP).app"

# 起動中のアプリの最前面ウィンドウをキャプチャ（Accessibility 権限が要る）
screenshot:
	mkdir -p screenshots
	osascript -e 'tell application "$(APP)" to activate'
	sleep 1
	screencapture -l $$(osascript -e 'tell application "System Events" to tell process "$(APP)" to get id of window 1') screenshots/$$(date +%s).png
	@ls -t screenshots | head -1

clean:
	rm -rf build $(PROJECT)
