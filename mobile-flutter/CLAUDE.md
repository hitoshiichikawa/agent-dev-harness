# CLAUDE.md — mobile-flutter（Flutter + Riverpod + go_router、Go API クライアント）

@.claude/CLAUDE.common.md

## コマンド（必ずこれを使う）

```
make check        # 完了条件。format / analyze / test / 生成コード鮮度
make gen          # OpenAPI → dart-dio クライアント、build_runner（freezed / riverpod / json）
make test         # flutter test
make golden       # golden 画像を更新（UI 変更時。差分は目視して報告）
make run          # flutter run（起動中のシミュレータ / エミュレータに）
make screenshot   # 起動中のアプリのスクリーンショットを取る
```

`flutter build * --release`、fastlane、ストア提出はフックでブロックされている。

## 構成と依存方向

```
lib/main.dart                ProviderScope で包んで MaterialApp.router を返すだけ
lib/app/router.dart          go_router のルート定義。ここ以外にルートを書かない
lib/app/theme.dart           ThemeData
lib/core/api_client.dart     dio + 生成クライアントの Provider。認証インターセプタ
lib/core/auth/               トークン保管（secure storage）、refresh、AuthNotifier
lib/core/storage/            shared_preferences ラッパ
lib/features/<domain>/
  <domain>_page.dart         ConsumerWidget。ref.watch と UI だけ
  <domain>_notifier.dart     AsyncNotifier。ロジックはここ
  <domain>_repository.dart   生成クライアントの薄いラッパ。interface + 実装
  widgets/                   その機能専用の部品
lib/generated/               openapi-generator 出力。触らない
```

- 依存方向は **Page → Notifier → Repository → generated**。逆流・飛び越し禁止
- features 同士は import しない。共有が要るものは `core/` に下ろす
- Notifier は `@riverpod` アノテーション + `AsyncNotifier`。状態は `AsyncValue<T>`。例外は `AsyncValue.guard` で state に乗せ、UI は `when(data:, error:, loading:)` で分岐
- Repository は abstract class で宣言し、実装を Provider で注入。テストでは `overrideWith` で差し替える
- データクラスは freezed。可変クラスを作らない
- `setState` はアニメーションやフォーカスなど純粋な UI 状態のみ。サーバー由来のデータに使わない
- `async` の後に `context` を使うときは `context.mounted` を確認
- 文字列は `l10n` に出す（雛形では `AppLocalizations` 未導入なら定数ファイル）

## 契約

- API の変更は web 側の `openapi/openapi.yaml` が正。Flutter 側で型を手書きしない
- 変更後は `make gen` → analyze で壊れた箇所を直す

## テスト

- Notifier：`ProviderContainer` + Repository の fake で単体テスト
- Page：golden テスト。`test/goldens/` に画像を置く。UI を変えたら `make golden` で更新し、差分を報告に含める
- integration_test はログイン〜主要画面の smoke 1 本のみ。重いので増やさない

## 確認手段

- `make run` → `make screenshot` でシミュレータの画面を取る（ビルドが重いので完了時のみ）
- golden の差分画像（`test/failures/`）で見た目の変化を確認

## プロジェクト固有（新規プロジェクトでここを埋める）

- ドメイン用語：
- 主要画面と遷移：
- Firebase / push など外部サービス：
- 対応 OS 最低バージョン：
