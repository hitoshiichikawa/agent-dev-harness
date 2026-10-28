# common — 全パターン共通の層（A 層）

| ファイル | 役割 |
|---|---|
| `CLAUDE.md` | 作業手順、完了の定義、確認を取る判断、禁止事項、Git 運用。全プロジェクトで同じ |
| `.claude/settings.json` | 権限の許可/拒否とフック定義の基底。各パターンの settings.json はこれを含んだ完全版 |
| `.claude/hooks/guard-bash.sh` | Bash 実行前に破壊的・本番向けコマンドをブロック。パターン固有の追加は `EXTRA_DENY` 環境変数で渡す |
| `.claude/hooks/guard-edit.sh` | 生成コード・秘密情報・ロックファイル・`.xcodeproj` への直接編集をブロック |

## 使い方

プロジェクトでは `.claude/hooks/common/` にこの `hooks/` をコピーする。パターン側の settings.json はそのパスを参照している。

```
my-app/.claude/
├── settings.json        # パターン側からコピー
└── hooks/
    ├── common/          # ← common/.claude/hooks/ をコピー
    │   ├── guard-bash.sh
    │   └── guard-edit.sh
    └── <pattern固有>.sh # パターン側からコピー
```

## 二重防御の考え方

- `permissions.deny` はコマンド名の前方一致。素直なケースを止める
- `guard-bash.sh` は正規表現。`deny` をすり抜ける書き方（`git push origin main --force` など引数順の違い）を止める

どちらか一方では漏れるので両方持つ。指示文（CLAUDE.md）の「禁止事項」は 3 段目で、人間が読んで意図を理解するためのもの。

## 昇格させてもいいもの

`CLAUDE.md` の内容は個人・組織で固定できるなら `~/.claude/CLAUDE.md` に置くとプロジェクトごとのコピーが不要になる。フックも `~/.claude/settings.json` に置けば全プロジェクトに効く。ただしその場合、プロジェクトをクローンした他の人には効かないので、チーム開発ではプロジェクト側に置く。
