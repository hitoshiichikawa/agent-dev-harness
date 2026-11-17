# CLAUDE.md — mobile-flutter（Flutter + Riverpod + go_router、Go API クライアント）

@.claude/CLAUDE.common.md

## 責任範囲と境界

- 担当はこのリポジトリ（Flutter クライアント）の中だけ。サーバーのコードは編集しない
- 契約の正はサーバー側の `openapi/openapi.yaml`。このリポジトリは版を取り込むだけで、型を手書きしない（取り込み元は `openapi-generator.yaml` の `inputSpec`）
- 契約を変えたいときは、変えたい内容と理由を書いてサーバー側に依頼する。手元の契約を書き換えて先へ進めない

## 実行環境と前提

- ローカルで動かす。iOS のビルドとシミュレータには macOS と Xcode が要る
- `make run` と `make screenshot` は、起動中のシミュレータかエミュレータが要る。`make check` には要らない
- 起動できない環境では golden の差分で見た目を確かめ、画面を起動して確かめていないことを報告する

## コマンド（必ずこれを使う）

```
make check        # 完了条件。format / analyze / test / 生成コード鮮度
make gen          # OpenAPI → dart-dio クライアント、build_runner（freezed / riverpod / json）
make test         # flutter test
make golden       # golden 画像を更新（UI 変更時。差分は目視して報告）
make run          # flutter run（起動中のシミュレータ / エミュレータに）
make screenshot   # 起動中のアプリのスクリーンショットを取る
```

## 人間だけが叩く操作

- `flutter build` の `--release`、fastlane、署名、ストア提出。フックが止める
- 必要になったら、叩くコマンド・理由・戻し方を書いて依頼する。別の書き方で回避しない

## 構成と依存方向

```
lib/main.dart             ProviderScope で包んで MaterialApp.router を返すだけ
lib/app/                  router.dart（ルートを書くのはここだけ）、theme.dart
lib/core/                 api_client.dart、auth/、storage/、native/。features から共有するもの
lib/features/<domain>/    <domain>_page.dart / <domain>_notifier.dart / <domain>_repository.dart / widgets/
lib/generated/            openapi-generator 出力。触らない
test/features/<domain>/   Notifier のテスト、golden テスト
```

- 依存方向は **Page → Notifier → Repository → generated**。逆流・飛び越し禁止
- Page は `ref.watch` と UI だけ。ロジックは Notifier、Repository は生成クライアントの薄いラッパ
- features 同士は import しない。共有が要るものは `core/` に下ろす
- ファイルごとの書き方は `.claude/rules/`（`dart.md`、`pubspec.md`）。該当するファイルを開くと読み込まれる

## 手本と追加手順

- 手本は `lib/features/example/` と `test/features/example/`。機能を足すときはこれを真似る
- 順番：契約の版を取り込む → `make gen` → Repository → Notifier とテスト → Page と golden → `app/router.dart` にルート → `make check`

## 唯一の定義場所

| 概念 | 場所 |
|---|---|
| 列挙値（種別・状態） | 生成クライアントの enum。無いものは `core/` の `enum`。画面表記はその enum の拡張 |
| 判定（超過・警告の要否） | サーバー。応答に含まれる値を表示するだけで、画面で比べ直さない |
| 時刻の解析・整形 | `core/time_fmt.dart`。サーバーの文字列形式はここだけが知る |
| 他システムに合わせる検証ルール・項目一覧 | `core/rules.dart`。`// SYNC:` でコピー元を記し、テストを書く。画面は呼ぶだけ |
| 永続化のキー | `core/storage/` の `static const`。`SharedPreferences` を外に出さない |
| ネイティブ連携（MethodChannel / EventChannel） | `core/native/` 先頭の表（メソッド名・イベント名・キー・iOS/Android の有無）。変更は Dart・Swift・Kotlin を同じコミットで |
| オフライン送信 | 1 つのキュー機構。「溜めて後で送る」データを足すときに再送処理を新設しない |

## 使わないもの

- `setState` でサーバー由来のデータを持つ → `AsyncNotifier`
- Bloc など別の状態管理 → Riverpod
- `http` パッケージ → dio（認証は `core/api_client.dart` のインターセプタ）

## テスト

- Notifier：`ProviderContainer` + Repository の fake で単体テスト
- Page：golden テスト。`test/goldens/` に画像を置く。UI を変えたら `make golden` で更新する
- integration_test はログイン〜主要画面の smoke 1 本のみ。重いので増やさない

## 止まって確認する判断

- OS の権限を足す（`Info.plist` の利用目的、`AndroidManifest.xml` の permission）
- ネイティブ側のコード（Swift / Kotlin、MethodChannel）を足す・変える
- 対応 OS の最低バージョンを変える

## 互換性の制約

- 古い版のアプリが利用者の端末に残る。サーバーが先に新しくなる前提で、応答に知らない項目や列挙値が増えても落ちないように書く
- 端末に保存したデータは、更新後のアプリが読む。永続化のキーや形式を変えるときは移行を書く（SQLite はスキーマ変更ごとに `version` と `onUpgrade`）

## 確認手段と証拠

- `make run` → `make screenshot` でシミュレータの画面を取る（ビルドが重いので完了時のみ）
- golden の差分画像（`test/failures/`）で見た目の変化を確かめ、報告に添える

## プロジェクト固有（ここを埋める。当てはまらない欄は「該当なし」と書く）

- 目的と利用者、やらないこと：
- ドメイン用語：
- 主要画面と遷移：
- 破ってはならない業務ルール：
- 契約の段階（0〜2）、相手リポジトリ、契約の版：
- 外部連携と、ローカルでの代わり（スタブ）：
- 環境（ローカル / 検証 / 本番）と、エージェントが届く範囲：
- 外に出ている版（互換の対象）と、対応 OS の最低バージョン：
- 触ってはいけない場所：
- 依頼の入口と、状態・決定の記録先：
