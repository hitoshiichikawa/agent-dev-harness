---
paths:
  - "lib/**/*.dart"
  - "test/**/*.dart"
  - "integration_test/**/*.dart"
---

# Dart / Flutter の書き方

- Notifier は `@riverpod` アノテーション + `AsyncNotifier`。状態は `AsyncValue<T>`。例外は `AsyncValue.guard` で state に乗せ、UI は `when(data:, error:, loading:)` で分岐
- Repository は abstract class で宣言し、実装を Provider で注入。テストでは `overrideWith` で差し替える
- データクラスは freezed。可変クラスを作らない
- `setState` はアニメーションやフォーカスなど純粋な UI 状態のみ。サーバー由来のデータに使わない
- `async` の後に `context` を使うときは `context.mounted` を確認
- ルート定義は `app/router.dart` だけ。Page から `context.go('/path')` を呼ぶのはよい
- 文字列は `l10n` に出す（雛形では `AppLocalizations` 未導入なら定数ファイル）
- `.g.dart` / `.freezed.dart` / `lib/generated/` は手で直さない。元を直して `make gen`
