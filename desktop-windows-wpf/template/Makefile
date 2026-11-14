# エージェントのエントリポイント（Git Bash / WSL / Linux で動く）
SLN      := MyApp.sln
APP      := src/MyApp/MyApp.csproj
DOMAIN   := src/MyApp.Domain/MyApp.Domain.csproj

.PHONY: check format format-check build test test-domain run migrate screenshot clean

# 全部通ったら「この中身で check が通った」と記録する。終了時の門番（check-gate.sh）がこれを見る
check: format-check build test
	@test ! -f .claude/hooks/common/check-gate.sh || bash .claude/hooks/common/check-gate.sh record

format:
	dotnet format $(SLN)

format-check:
	dotnet format $(SLN) --verify-no-changes

build:
	dotnet build $(SLN) -nologo -warnaserror

test:
	dotnet test $(SLN) -nologo --no-build

test-domain:
	dotnet test tests/MyApp.Domain.Tests -nologo

run:
	dotnet run --project $(APP)

# EF Core マイグレーション生成。適用はアプリ起動時の Migrate()。
migrate:
	dotnet ef migrations add $(name) --project $(DOMAIN) --startup-project $(APP) --output-dir Data/Migrations

# 起動中の MyApp ウィンドウをキャプチャ（Windows のみ）
screenshot:
	mkdir -p screenshots
	powershell -NoProfile -ExecutionPolicy Bypass -File build/screenshot.ps1 -Out screenshots/$$(date +%s).png
	@ls -t screenshots | head -1

clean:
	dotnet clean $(SLN) -nologo
