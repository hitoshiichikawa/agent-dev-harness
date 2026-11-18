# ハーネス無しで作ってきたリポジトリに、後から入れるとき（後付け導入）

ハーネス無しでエージェントに書かせてきたリポジトリ（いわゆるバイブコーディングの産物）に、統制のためのハーネスを後から入れる手順。
開発はそのリポジトリの中で続ける。隣に新しいリポジトリを作る場合は [`brownfield.md`](brownfield.md) を使う。

2026-11-18 に `fms-local-server`（TypeScript のサーバー、追跡ファイル 1,065 本、コミット 100 件、`CLAUDE.md` あり）へ入れたときの手順をまとめた。
実行の記録は `docs/trials/2026-11-18-fms-local-server.md` にある。

## 考え方

新規の立ち上げと違い、守らせたい決まりへの違反がすでにコードの中にある。次の 4 つを軸にする。

- **`check` は初日から緑にする。** 中身は「今すでに通る検査」だけで始める。赤いままの `check` は完了の合図に使えない
- **既存の違反は直さずに凍結する。** 数を書き留め、増えたら落とす（歯止め）。直すのは、その場所を触るとき
- **「現状」は文章でなく数で持つ。** 「今は A が B を直接呼んでいる」のような記述は、直した後も残って嘘になる。数えられるものは歯止めに移す
- **続けてきた流儀は、基底より優先する。** 基底は既定値で、ブランチ名やコミットの書式を変えさせるためのものではない

タイプの雛形は使わない。置くのは基底だけで、タイプが埋める 12 欄もこのリポジトリが自分で埋める。

## 1. 今の状態を測る

何も変えずに、次を確かめて控える。作業はブランチで行う。

| 確かめること | 使い道 |
|---|---|
| 今すぐ通る検査は何か（型チェック、lint、テスト、ビルド） | 手順 3 で `check` の中身にする |
| 既存の `CLAUDE.md` や規約の文書があるか | 手順 6 で 12 欄に振り分ける |
| 生成コードはどこにあるか。手書きのファイルと混ざっていないか | 手順 4 で編集を止める |
| 人間だけが叩くべき操作は何か（配備、データを消す操作） | 手順 4 で止める |
| 消えたら取り返せないデータはどこにあるか | 同上 |
| 続けてきた流儀（ブランチ名、コミットの書式、PR の進め方） | 手順 6 で「基底より優先する決まり」に書く |

検査が 1 つも通らないときは、通るところまで範囲を狭める（特定のディレクトリだけ型チェックする、など）。それも無理なら、構文チェックだけで始める。

## 2. 基底を置く

`<harness>` は agent-dev-harness を clone した場所。リポジトリのルートで実行する。

```bash
mkdir -p .claude/hooks .claude/rules
cp -R <harness>/common/.claude/hooks      .claude/hooks/common
cp    <harness>/common/.claude/settings.json .claude/settings.json
cp    <harness>/common/CLAUDE.md          .claude/CLAUDE.common.md
```

既存の `CLAUDE.md` は、手順 6 で組み直すまでそのまま置いておく。
人ごとの設定がコミットされないことを確かめる。

```bash
git check-ignore -q .claude/settings.local.json || echo '.claude/settings.local.json' >> .gitignore
```

## 3. `check` を作る

入口を 1 つにする。既存のタスクランナーがあればそれに足し、無ければ `Makefile` を置く。

```make
.PHONY: check typecheck ratchet

# 全部通ったら「この中身で check が通った」と記録する。終了時の門番がこれを見る
check: typecheck ratchet
	@test ! -f .claude/hooks/common/check-gate.sh || bash .claude/hooks/common/check-gate.sh record

typecheck:
	cd server && node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json

ratchet:
	@bash .claude/hooks/common/ratchet.sh
```

- 最後の行（`check-gate.sh record`）は必ず入れる。門番は、編集した後にこれが呼ばれていなければ終了を止める
- 起動に時間がかかる確認（コンテナを使う通し確認など）は入れない。`CLAUDE.md` の「確認手段と証拠」に書く
- フォーマッタを `check` や編集後のフックに入れるのは、全体を 1 度整形するコミットを人が入れた後にする。先に入れると、触った行と無関係な差分が大量に出る

`.claude/settings.json` を 2 か所直す。

- `permissions.allow` に、`check` とふだん使う確認のコマンドを足す（`Bash(make check:*)` など）
- `hooks.Stop` の `check-gate.sh gate` の後ろに、案内に出すコマンド名を足す（`gate 'make check'`）

## 4. 守る場所と、止める操作を足す

基底のガードが止めるのは、`generated/` という名前のディレクトリ、ロックファイル、秘密情報、配備の一般的なコマンドまで。このリポジトリ固有のものを足す。どちらも 1 行 1 拡張正規表現。

`.claude/hooks/extra-deny-paths.txt`（編集を止める場所）:

```
# 自動生成。元の定義を直して再生成する。同じ場所の index.ts は手書きなので、名前の形で分ける
(^|/)server/src/fms-lib/data/(func|table|redshift)/(.*/)?[A-Za-z0-9]+_[^/]*\.ts$
# パスワード
(^|/)\.secrets/
```

`.claude/hooks/extra-deny.txt`（止める操作）:

```
# 本番への配備は、このリポジトリからは行わない
(sls|serverless)[[:space:]]+(deploy|remove)
# 実走の記録が入ったボリュームを消す操作
docker[[:space:]]+compose[^|;&]*[[:space:]]down[^|;&]*[[:space:]](-v|--volumes)
```

- 生成物の正規表現は、書いた後に「生成物の全部に当たり、手書きのファイルに 1 つも当たらない」ことを数えて確かめる
- 止めすぎない。今エージェントにさせている操作（PR のマージ、検証環境への反映など）は、止めずに「止まって確認する判断」に書く

## 5. 歯止めを置く

守らせたい決まりのうち、正規表現で数えられるものを `.claude/ratchet.txt` に書く。`check` の中の `ratchet.sh` が今の数を数え、書き留めた数と一致しなければ落ちる。

```
# <数> <名前> <パス> <拡張正規表現（行末まで）>
4 queryRaw-in-commands server/src/handler/api/app/commands queryRaw
0 assertAdminRole-in-commands server/src/handler/api/app/commands assertAdminRole
33 any-in-app server/src/handler/api/app (: any|as any|<any>)([^A-Za-z0-9_]|$)
```

- **基準の数は、`ratchet.sh` の出力から取る。** 適当な数で 1 度走らせると、今の数を教えて落ちる。手元で別の数え方をした値を書かない（`fms-local-server` では、手で数えた 1 件が実際は 33 件だった）
- 0 件の項目も置く。「一度直したものを戻さない」検査になる
- 増えたら落ちる。減っても落ち、数を下げるよう求める。書き留めた数が、いつも今の実数になる
- 数えるのは追跡ファイルと、無視されていない未追跡ファイル。新しく足したファイルも数に入る
- 数を上げて通すこともできてしまう。`ratchet.txt` の差分は人が読み、「数を上げる・項目を消す」は止まって確認する判断に入れる
- 数えられない決まり（重複した関数の統合など）は、ルールの文章に残す

## 6. `CLAUDE.md` を 12 欄に組み直す

[`retrofit/CLAUDE.md`](retrofit/CLAUDE.md) を下敷きにする。欄の意味は `docs/design.md` 2 章。既存の `CLAUDE.md` の中身は、次のように振り分ける。

| 既存の記述 | 行き先 |
|---|---|
| 基底と同じ内容（コピーの禁止、唯一の定義場所の原則など） | 消す。基底が言っている |
| 概念と置き場所の対応 | 「唯一の定義場所」の表 |
| 特定のディレクトリの中での書き方 | `.claude/rules/<名前>.md`。先頭に `paths` を書く |
| 「現状は〜になっている」という記述 | コードと突き合わせる。直っていたら消す。残っていて数えられるなら歯止めへ |
| 完了条件のチェックリスト | 機械で確かめられるものは `check` へ。残りは該当する欄へ |
| 続けてきた流儀で、基底と食い違うもの | 末尾の「基底より優先する決まり」 |

- 既存の文書に無かった欄（実行環境と前提、手本と追加手順、互換性の制約など）は、README や引き継ぎ資料から拾って埋める。当てはまらない欄は「該当なし」と書く
- 手本には、いちばん新しくて決まりに沿っている縦 1 本を名指しする。古いコードを手本にさせない
- 決まりはあるが受け皿が無いもの（テストを求めているが、テストの仕組みが無い、など）は、今ある手段を正直に書く
- 基底と合わせて 200 行未満にする

## 7. 効いていることを確かめる

リポジトリのルートで実行する。

```bash
make check                                    # 緑になる
```

```bash
echo '{"tool_input":{"command":"git push --force"}}' | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/common/guard-bash.sh; echo "終了コード $?"
```

```bash
printf '{"tool_input":{"file_path":"%s/<生成物のパス>"}}' "$PWD" | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/common/guard-edit.sh; echo "終了コード $?"
```

- 2 つのガードは `BLOCKED` と表示され、終了コードが 2 になる
- 手書きのファイル（生成物と同じディレクトリのものも）は、終了コード 0 で通る
- 違反を 1 行足した未追跡のファイルを置くと `make check` が落ち、消すと緑に戻る
- `claude` を起動して生成物の編集を頼み、`BLOCKED by harness guard` が返ることを見る

## 8. 入れた後

- ここまでを 1 つの PR にする。コードの挙動は変えない。変えたのは、エージェントへの指示と検査だけ
- 気づいたことは `docs/harness-feedback.md` に書き留め、agent-dev-harness の `docs/learnings.md` に戻す
- `check` を育てる順番の目安：歯止めの数を下げる → テストの受け皿を作る → lint を足す → 整形を足す。どれも、足した時点で緑であることを保つ

## 確かめたこと、確かめていないこと

- **手順 1〜7 は `fms-local-server` で 1 度通した**（2026-11-18、Claude Code 2.1.282）。`make check` は約 9 秒で緑。ガードは直接の呼び出しと実際のセッションの両方で止まった。パス付きルールは、該当ファイルを開く前は読み込まれず、開いた後に読み込まれた
- 根拠は 1 件。別の言語、別の構成のリポジトリでは試していない
- 入れた後に開発を続けて、歯止めや欄が効くかは、まだ見ていない
- `CLAUDE.md` を持たないリポジトリ、検査が 1 つも通らないリポジトリでは試していない
