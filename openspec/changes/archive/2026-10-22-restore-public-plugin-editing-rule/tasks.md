## 1. 公開版のルールを戻す

- [x] 1.1 `rules/plugin-editing.md` を新規に作る。proposal の 5 点だけを短く書く。`CLAUDE_HARNESS_DEV_DIR`・`/wt-setup`・`sync.sh`・`claude-harness-oratta`・`Draft PR` を書かない。触る範囲: `rules/plugin-editing.md`（新規）。元の本文は `git show 647caaf0:rules/plugin-editing.md`
- [x] 1.2 `rules/README.md` の一覧表の `plugin-editing.md` の行を公開版の要点に合わせ、「（個人版が入っていれば）」を外す。触る範囲: `rules/README.md:42`
- [x] 1.3 `CLAUDE.md`・`AGENTS.md` の関連の行から「個人版が入っていれば。」を外す（聖域。PR 本文に理由を書く）。`docs/worktree-recovery.md` の冒頭の「個人版が入っていれば」を外す。触る範囲: `CLAUDE.md:41`、`AGENTS.md:43`、`docs/worktree-recovery.md:3`

## 2. 仕分けの文書と検査

- [x] 2.1 `docs/public-private-split.md`: 仕分けの表に `rules/plugin-editing.md` を「公開版」で足す（理由は Decision 1）。「個人版に移した部品」の表の `rules/plugin-editing.md` の行を外し、表のあとの段落に移した部分・移した先 `rules/harness-dev.md`・写し元の commit `647caaf088409abc68cc8c45587b1310e31e34f7` を書く。触る範囲: `docs/public-private-split.md:55-64`、`docs/public-private-split.md:96-112`
- [x] 2.2 `tests/public-private-split.bats`: 「戻すと落ちる」のテストを `fmtoken.sh` のパスに替える。移した行の検査の `want` と「移した先が空」のテストを `rules/plugin-editing.md` から別の部品（`plugins/weekly-report/`）に替える。公開版のルールの中身の検査（ファイルの存在・禁止語・復旧の手順の語・表の分類）と、その異常系のテストを足す。触る範囲: `tests/public-private-split.bats:380-455`
- [x] 2.3 `tests/plugin-release-convention.bats` の `CONVENTION_DOCS` に `rules/plugin-editing.md` を戻す（版上げ指示が無いことだけを確かめる。changes の記録の指示を求める検査があれば `rules/plugin-editing.md` を除く）。触る範囲: `tests/plugin-release-convention.bats:21-24` と、`CONVENTION_DOCS` を使う箇所
- [x] 2.4 `tests/always-on-injection-scope.bats` の目印の表と一覧に、`plugin-editing.md` の目印 `手動で削除しない` を足す。触る範囲: `tests/always-on-injection-scope.bats:45-60`、`:115-125`

## 3. 予算

- [x] 3.1 `scripts/test.sh`（または `bats tests/injection-budget.bats`）で実測を取り、推奨値（実測 + 約 5%）に `tests/injection-budget.txt` を動かす（聖域。PR 本文に、何を戻し、なぜその値かを書く）。触る範囲: `tests/injection-budget.txt:1`

## 4. 記録と個人版

- [x] 4.1 `plugins/dev-workflow/changes/1218.md` の `rules/plugin-editing.md` に関する記述（移した部品の一覧、予算の数値、オーナーの張り替えの手順）を、新しい形（公開版に短く残す・個人版は `rules/harness-dev.md`・張り替え不要）に直す。触る範囲: `plugins/dev-workflow/changes/1218.md:7`、`:20`、`:29`
- [x] 4.2 個人版のリポジトリ（作業ディレクトリ `/Users/oratta/orca/workspaces/claude-harness-oratta`）で feature ブランチを切り、`rules/plugin-editing.md` を `rules/harness-dev.md` に改名して Harness 開発者向けの部分だけに削り、README に言及があれば直し、Draft PR を作る（main に直接 push しない。マージは主）。公開版の PR 本文に個人版の PR の URL を書く
- [x] 4.3 PR #1218 の本文を新しい形に直す（`rules/plugin-editing.md` の扱い、予算の理由、個人版の Draft PR の URL）

## 5. 確かめる

- [x] 5.1 `openspec validate restore-public-plugin-editing-rule --type change --strict` と `scripts/test.sh` の関連 bats（`public-private-split`・`always-on-injection-scope`・`plugin-release-convention`・`injection-budget`）が通る
- [x] 5.2 個人版の `scripts/check-public-leak.sh <公開版の作業ツリー>` が終了コード 0 で、結果を PR 本文に載せる
