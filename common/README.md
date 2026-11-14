# common — 全パターン共通の層（A 層）

| ファイル | 役割 |
|---|---|
| `CLAUDE.md` | 作業手順、完了の定義、確認を取る判断、禁止事項、Git 運用。全プロジェクトで同じ |
| `.claude/settings.json` | 権限の許可/拒否とフック定義の基底。各パターンの settings.json はこれを含んだ完全版 |
| `.claude/hooks/guard-bash.sh` | Bash 実行前に破壊的・本番向けコマンドをブロック。パターン固有の追加は `.claude/hooks/extra-deny.txt` に 1 行 1 正規表現で書く（スクリプトが自分で読む） |
| `.claude/hooks/guard-edit.sh` | 生成コード・秘密情報・ロックファイル・`.xcodeproj` への直接編集をブロック |
| `brownfield.md` | 既存システムの隣に作るときの評価手順（コピー・レイヤ違反・時刻変換の測り方）と、新しいコードに課す「唯一の定義場所」の規約 |

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

## フックを書くときの決まり

Claude Code の仕様から来る 4 点。守らないと「動いているように見えて効いていない」フックになる。

- **スクリプトは `${CLAUDE_PROJECT_DIR}` 基準で呼ぶ**。フックは現在のディレクトリで実行されるので、`bash .claude/hooks/x.sh` と相対パスで書くと、エージェントが `cd` した後に見つからなくなる。スクリプトの中でも現在のディレクトリを当てにしない
- **止めるときは終了コード 2**。0 と 2 以外（1 や、スクリプトが無いときの 127）は「フックの不具合」として処理が続行される。ガードは途中で落ちても 2 を返すようにし、settings.json 側も `|| exit 2` を付ける
- **エージェントに伝えるには 2 通り**。失敗は stderr に書いて終了コード 2。注意喚起は stdout に `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}` を出して終了コード 0。終了コード 0 の stderr はエージェントに届かない
- **1 つのフックに 1 つのスクリプト**。`a.sh && b.sh` とつなぐと、a が標準入力を読み切って b には何も渡らない。settings.json の `hooks` 配列に別々に並べる

変えたらリポジトリルートで `bash tests/run.sh`。各パターンを一時ディレクトリに組み立て、settings.json の呼び出しをそのまま実行して確かめる。

## 昇格させてもいいもの

`CLAUDE.md` の内容は個人・組織で固定できるなら `~/.claude/CLAUDE.md` に置くとプロジェクトごとのコピーが不要になる。フックも `~/.claude/settings.json` に置けば全プロジェクトに効く。ただしその場合、プロジェクトをクローンした他の人には効かないので、チーム開発ではプロジェクト側に置く。
