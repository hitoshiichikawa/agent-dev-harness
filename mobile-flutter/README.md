# mobile-flutter — 典型的なモバイルアプリケーション（iOS / Android）

web パターンと同じ Go API を使うクライアント。オフライン対応はスコープ外（必要になったら drift を足す。Repository を interface にしてあるのでキャッシュ層を後から差し込める）。

## 決定事項

| 項目 | 決定 | 見送ったもの | 理由 |
|---|---|---|---|
| 対象 | **iOS + Android** | Flutter desktop / web | mac / Windows はネイティブの別パターン |
| 状態管理 / DI | **Riverpod**（`riverpod_generator`） | Bloc | 記述量が少なく学習量も多い。DI も兼ねるのでツールを増やさない |
| ルーティング | **go_router** | auto_route | Flutter 公式メンテ。ディープリンク対応 |
| API クライアント | **openapi-generator (dart-dio)** | Retrofit 手書き | web と同じ `openapi.yaml` から生成。手書きゼロ |
| データクラス | **freezed + json_serializable** | 手書き | 不変データクラスの事実上標準 |
| ローカル永続化 | **shared_preferences**（設定）+ **flutter_secure_storage**（トークン） | drift, Hive, Isar | オフライン非対応なので DB 不要。トークンは Keychain / Keystore |
| HTTP | **dio** | http | インターセプタで認証ヘッダと refresh を一元化 |
| テスト | **flutter_test** + golden test + integration_test | Patrol | golden はエージェントの「見た目の確認」手段 |
| Lint | **very_good_analysis** | flutter_lints | より厳格。エージェントの出力を縛る |
| CI / 配布 | **fastlane + GitHub Actions**、TestFlight / Play 内部テスト | Codemagic | 枯れている。mac パターンと fastlane を共通化 |

## 構成

```
template/
├── Makefile                 # make check / gen / test  ← エージェントのエントリポイント
├── analysis_options.yaml    # very_good_analysis + 追加ルール
├── pubspec.yaml             # 依存の意図（flutter create 後にマージ）
├── openapi-generator.yaml   # dart-dio 生成設定（入力は ../openapi/openapi.yaml を参照）
├── build.yaml
├── lib/
│   ├── main.dart            # ProviderScope + ルーター起動だけ
│   ├── app/                 # router.dart / theme.dart
│   ├── core/                # api_client.dart / auth/ / storage/
│   ├── features/<domain>/   # <domain>_page.dart / <domain>_notifier.dart / <domain>_repository.dart
│   └── generated/           # openapi-generator 出力（触らない）
├── test/
│   ├── features/<domain>/   # notifier テスト、golden テスト
│   └── goldens/
└── fastlane/Fastfile
```

依存方向：**Page → Notifier → Repository → 生成 API クライアント**。Page は Notifier の state を `ref.watch` するだけ。Notifier はビジネスロジック、Repository は生成クライアントの薄いラッパ。

Clean Architecture のフル構成（UseCase 層、Entity/Model の二重化）は「典型的なアプリ」には過剰なので入れない。

## scaffold 手順

```bash
flutter create --org com.example --platforms ios,android --empty my_app && cd my_app
# template の設定で上書き
cp -r dev-harness/mobile-flutter/template/* .
cp dev-harness/mobile-flutter/CLAUDE.md .
cp -r dev-harness/mobile-flutter/.claude .
cp -r dev-harness/common/.claude/hooks .claude/hooks/common
cp dev-harness/common/CLAUDE.md .claude/CLAUDE.common.md
# pubspec.yaml は template の dependencies を flutter create 生成物にマージする
flutter pub get
make gen && make check
```

OpenAPI の契約は web プロジェクトの `openapi/openapi.yaml` を参照する（同じモノレポに置くか、別リポなら git submodule / コピー）。`openapi-generator.yaml` の `inputSpec` を合わせる。

## 検証ループ

| タイミング | 何が走るか |
|---|---|
| 編集のたび（PostToolUse フック） | `dart format` → `dart analyze`（そのファイル） |
| `make check`（完了条件） | format 差分なし、`flutter analyze`、`flutter test`（golden 含む）、生成コードの鮮度 |
| `openapi.yaml` 変更時 | `make gen` → 生成コードの差分 → analyze で壊れを検出 |
| UI 変更時 | golden テストを更新（`make golden`）して差分を目視。シミュレータでのスクリーンショットは完了時のみ（ビルドが重い） |
| リリース | `flutter build` の `--release`、署名、ストア提出はフックでブロック。人間が fastlane を叩く |

## エージェントが間違えやすい点

- `StatefulWidget` + `setState` でサーバー状態を持つ → Notifier（`AsyncNotifier`）に置く
- Page から直接 Repository や dio を呼ぶ → 必ず Notifier 経由
- `.g.dart` / `.freezed.dart` / `lib/generated/` を手で直す → `make gen`
- `BuildContext` を async の後で使う → `if (!context.mounted) return;`
- 画面遷移を Page にハードコード → `context.go('/path')` は Page でよいが、ルート定義は `app/router.dart` のみ
- 例外を `catch (e) {}` で握る → `AsyncValue.guard` で state に乗せる
