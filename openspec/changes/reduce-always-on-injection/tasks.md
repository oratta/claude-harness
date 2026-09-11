## 1. path スコープの実機確認（最初に行う。結果で 3 と 4 の要否が変わる）

- [x] 1.1 検証用ルールの実体を harness の外（`/tmp` 等）に 1 本置き、`~/.claude/rules/<name>.md` から**その実体への symlink** を張る（本番の配布形と同じ。実ファイルを直接置かない）。frontmatter に design の候補 glob を書き、本文に検索しやすい固有の文字列を入れる
- [x] 1.2 対象パスに一致するファイルを読むセッションを起動し、その固有文字列が載るか確認する（証拠のテキストを控える）
- [x] 1.3 対象パスに一致するファイルを読まないセッションを起動し、その固有文字列が**載らない**ことを確認する。ここが「載る」なら path スコープは効いていない
- [x] 1.4 harness 以外のリポジトリを cwd とするセッションから `~/.claude/plugins/marketplaces/oratta-claude-harness/` 配下の絶対パスのファイルを読み、一致するか確認する（`plugin-editing` の主用途がこの場面。ここで一致しないなら採用しない）
- [x] 1.5 検証用の symlink と実体を片付け、3 つの確認結果と採否の判断を issue #260 にコメントする（証拠つき）
- [x] 1.6 採用しない場合は 3 と 4 を飛ばす。飛ばした旨と理由を issue #260 に残す

## 2. rules の縮約と移設（常時性を手放せない 3 本は触らない）

移設先はすべて「任意の cwd から解決できる形」で書く。skill はスキル名、references / docs は `~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`。リポジトリ相対パスを書かない。

- [x] 2.1 `rules/plugin-editing.md`（5,376）を縮約する。開発場所の詳細は `CLAUDE.md` の「開発場所」節と `docs/worktree-recovery.md` が既に持つので、rules 側は発火条件と禁止事項の要点まで削り、移設先を `~/.claude/plugins/marketplaces/oratta-claude-harness/docs/worktree-recovery.md` と書く
- [x] 2.2 `rules/communication-style.md`（4,833）を縮約する。サブエージェント向けの要点だけにし、全文の正本 `output-styles/readable.md` へのポインタを残す
- [x] 2.3 `output-styles/readable.md` の「両方を直すときは同時に直す」に相当する相互参照の文を、縮約後の関係（rules は要点・readable は全文で 1 対 1 対応しない）に合わせて直す。`rules/communication-style.md` 側の同じ文も同時に直す（readable.md 側には相互参照の文が存在しなかったため、1 文を新規に足して関係を両側で揃えた）
- [x] 2.4 `rules/subagent-model-selection.md`（3,219）を縮約する。ティア対応表と「`model` 必須」を残し、経緯・適用範囲・強制層の説明を `plugins/dev-workflow/references/model-tiers.md` へ移す
- [x] 2.5 `rules/perspective-casting.md`（2,710）を縮約する。5 手順の見出しを残し、各手順の説明を `plugins/casting/skills/casting/SKILL.md` へ移す
- [x] 2.6 `plugins/casting/skills/casting/SKILL.md` の正本宣言を反転する。description（3 行目付近）と本文（58 行目付近）の「5 手順の正本は `rules/perspective-casting.md`」を、SKILL.md 側が正本である形に直す。description は集計対象なので反転の文言を短くする
- [x] 2.7 `rules/git-commit-policy.md`（2,383）を縮約する。「承認なしに実行しない操作の一覧」を残し、PR 運用 / ローカル main 運用の判定手順を `plugins/dev-workflow/references/commit-and-pr-operations.md`（新規）へ移す。pr-review-gate の SKILL.md へは移さない（そのスキルは PR ができた後に読まれるが、運用の判定は最初の commit 時に要る）
- [x] 2.8 `rules/browser-infra-env-capture.md`（2,070）を縮約する。「表示された次のアクションで保存」と gitignore 確認を残し、1Password への昇格手順を `capability-registry:capability-registry` へ移す。`paths:` は付けない
- [x] 2.9 `rules/link-when-requesting-review.md`（859）を縮約する。書式の注意（裸 URL を括弧で囲まない）を残し、理由の説明を削る
- [x] 2.10 `rules/destructive-git-guard.md` と `rules/dev-server.md` は常時注入に残す。削減対象に入れていないことを確認する
- [x] 2.11 縮約した各ルールの本文に移設先を 1 行で書き、その解決先（スキル、または展開後のファイル）が実在することを確認する。リポジトリ相対パスが残っていないことも確認する
- [x] 2.12 縮約後の `rules/` 配下に `injection-budget` の語が 1 件も無いことを確認する（`the budget convention is not placed under rules/` テストが fail する）
- [x] 2.13 `rules/README.md` のファイル一覧表に、ルールごとの移設先を同じ解決できる形で書き足す

## 3. path スコープの適用（1 で採用と判断した場合のみ） — **不採用のためスキップ**

実機確認の結果、`~/.claude/rules/` に置いた `paths:` 付きルールはどのファイルを読んでも一度も注入されなかった（`**/*.md` という何にでも一致する glob でも載らない）。証拠は https://github.com/oratta/claude-harness/issues/260#issuecomment-5628061387 。`rules/*.md` のいずれにも `paths:` を付けない。

- [x] 3.1 `rules/plugin-editing.md` に `paths:` を付ける（design の候補 glob。リテラルのパスセグメントを含む形）。`browser-infra-env-capture.md` には付けない
- [x] 3.2 `scripts/sync.sh` を回したあと、本番ルール `plugin-editing.md` 1 本で両方向をもう一度確認し、結果を issue #260 に証拠つきでコメントする（検証用ファイルでの確認だけで完了としない）

## 4. 予算テストの集計変更（path スコープの採否にかかわらず実装する）

仕様レビュー R1 の NOTE に従い、`paths:` を今回採用しなくても集計と glob 検査は入れる。将来 `paths:` が動くようになったときに、広い glob で削減を偽装できない状態を先に作っておくため。

- [x] 4.1 常時注入の集計が `paths:` 保持ファイルを除き、配布対象の集計は除かないことをテストとして先に書く（Red）
- [x] 4.2 `paths:` の各 glob がリテラルのパスセグメント（ワイルドカード文字を含まず英数字を含む `/` 区切りの要素）を 1 つ以上持つことを検査し、`**`・`*`・`**/*`・`**/*.md` を fail にするテストを書く（Red）
- [x] 4.3 除外分を TAB を含まない注記行として出し、`sum_breakdown` に通しても合計に戻らないことをテストで確認する（Red）
- [x] 4.4 集計ヘルパと `report` を直して 4.1〜4.3 を通す（Green）
- [x] 4.5 `paths:` を持つルールが無いときに `rules/*.md` の合計が README を除く全ファイルの和と一致し、注記行が 1 行も出ないことを確認する
- [x] 4.6 内訳が 8 行のままで `the over-budget report lists all eight categories` が通ることを確認する

## 5. description の縮約

- [x] 5.1 `plugins/worktree/skills/wt-clean/SKILL.md`（1,297）の description を発火条件だけに削り、手順と背景を本文冒頭へ移す
- [x] 5.2 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（1,022）を同様に縮約する
- [x] 5.3 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（756）を同様に縮約する
- [x] 5.4 `plugins/daily-report/skills/daily-report/SKILL.md`（756）を同様に縮約する
- [x] 5.5 `plugins/dev-workflow/skills/develop/SKILL.md`（712）を同様に縮約する
- [x] 5.6 `plugins/worktree/commands/wt-clean.md`（691）・`plugins/skill-pack/skills/skill-pack/SKILL.md`（544）・`plugins/dev-workflow/skills/issueify/SKILL.md`（470）・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`（435）を同様に縮約する（casting の SKILL.md は 2.6 で扱う）
- [x] 5.7 `.claude/skills/openspec-*/SKILL.md` と `.claude/commands/opsx/*.md` は触らない（`openspec update` の生成物で再生成で戻る）
- [x] 5.8 縮約した skill のうち 1 件を、その skill が想定する実際の依頼文で呼び、起動することを確認する（証拠を控える）

## 6. CLAUDE.md の縮約

- [x] 6.1 `CLAUDE.md`（5,732）を縮約する。開発場所と PR 運用の要点を残し、経緯と長い説明を `docs/` へ移す
- [x] 6.2 予算ファイルの変更手続きの文（`injection-budget` と `本文に理由` を含む 1〜2 文）を残す。`CLAUDE.md documents how to move the budget file` テストがこの 2 語を要求する
- [x] 6.3 `AGENTS.md` に同じ内容を反映する（`tests/agents-md-sync.bats` が同一性を強制する）

## 7. 測定と予算の引き下げ

- [x] 7.1 `scripts/test.sh injection-budget` で削減後の実測と内訳を取り、合計が 36,395 バイト以下であることを確認する
- [x] 7.2 届いていなければ 2 と 5 に戻って追加で削る（どこを削ったかを記録する）
- [x] 7.3 `tests/injection-budget.txt` を削減後の実測に対して上下どちらのラチェットにも当たらない値（実測 × 1.05 前後）に引き下げる。予算ファイルは聖域なので、PR 本文に引き下げの理由と着手前後の実測を書く

## 8. 仕上げ

- [x] 8.1 `scripts/test.sh` 全件を実行し、exit code 0 を確認する（`rules-sync` と `agents-md-sync` を含む）
- [x] 8.2 変更したプラグインの `plugin.json` のバージョンを上げる（merge-base からの bump を S131 が要求する）
- [ ] 8.3 openspec スキルの二重掲載を本 change の対象外とした理由（repo 内の生成物だが再生成で戻ること、develop がコマンド名に依存すること、`opsx:archive` と `opsx:bulk-archive` がスキル本文を参照していること）を PR 本文に書く
- [ ] 8.4 着手前の内訳・削減後の内訳・移設対応表・path スコープの採否と証拠を PR 本文に載せる
