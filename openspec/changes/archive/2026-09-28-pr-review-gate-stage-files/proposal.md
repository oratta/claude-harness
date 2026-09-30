## Why

マージ前の検査担当（develop の G）は、どの段で起こされても `skills/develop/references/roles/gate-runner.md`（28,359 バイト）と `skills/pr-review-gate/SKILL.md`（83,538 バイト）を全部読み、作業開始前に約 45K トークンを使う。SKILL.md には検査の全段の手順・本体向けの説明・レビュー担当に渡す指示・保留時の手順が同居しているが、1 回の起動で使うのはその一部だけである。直近 10 日で G の 5 割強がコンテキスト上限 150K を超え、genetta-inc/flatmate#762 では G が 4 体交代して検査だけで約 1,000 万トークンを使った。作業担当（W）も仕様宣言の書式を確かめるためだけに SKILL.md 全体を読んでいる（10 日で 274 回）。

## What Changes

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` を索引にする。索引は各段の目的・読むファイル・入口と出口の条件と、手順番号（1・2-0・2-1・2-2・3・3-b・3-c・4・5・6）からファイルへの対応表だけを持ち、手順の本文とコードブロックを持たない。`description` は変えない。
- 手順の本文を `skills/pr-review-gate/stages/` の段ごとのファイル 6 本に移す（前提確認と重さ判定・レビューの起動・レビュー担当向けの指示・照合と指摘の振り分け・合格処理・保留）。段の分け方の確定案は design.md。
- リスク宣言（手順 3）と仕様宣言（手順 3-b）の書式を独立したファイル `skills/pr-review-gate/declarations.md` に移し、G の合格処理と W の (3b) の両方がこのファイルを指す。
- 冒頭の「前提と理由」の各項目は、それを使う段のファイルに移す（索引には置かない）。
- `gate-runner.md` から「SKILL.md を Read して手順 1〜5 を実行する」指示を消し、G が各時点で読むファイルを段ごとの表で示す。G の段ごとの差分（needs-reviewer の payload・従来経路の実行者・Status ごとの return 書式など）は、その段のファイルの「G として動くとき」節に移す。
- 手順の中身（規則・閾値・雛形・コマンド）は変えない。同じ手順を 2 か所に書かない。
- 索引の構造を検査する bats を追加し、pr-review-gate の文言を検査している既存 bats の参照先を、その文言が移った段のファイルに付け替える。
- `scripts/codex-develop.py` が Codex に渡す正本の一覧を、段のファイルに合わせて付け替える。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: スキルの本文を「索引＋段ごとのファイル＋宣言の書式ファイル」に分ける要件、索引が持ってよいものと持ってはならないもの、段の構成と手順番号の対応、同じ手順を 2 か所に書かないこと、既存要件で「SKILL.md の手順 N」と書いた箇所を索引が指す段のファイルと読むこと、develop 以外で本体がスキルを直接使うときの読み方を足す。
- `dev-workflow-develop`: G が段ごとに必要なファイルだけを読むこと（SKILL.md 全体を読む指示を持たない）、G の段ごとの return 書式を段のファイルに置くこと、W の (3b) が宣言の書式ファイルを指すこと、Codex の gate / review phase に渡す正本の一覧を段のファイルに合わせることを足す。

## Impact

- 編集: `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`、新規 `plugins/dev-workflow/skills/pr-review-gate/stages/*.md`（6 本）と `declarations.md`、`skills/develop/references/roles/gate-runner.md`、`skills/develop/references/roles/worker.md`（(3b) の参照先だけ）、`skills/develop/SKILL.md` と `references/*.md` のうち SKILL.md のパスを直接指している行、`scripts/codex-develop.py`（正本一覧）、`tests/*.bats` と `tests/test_codex_develop.py` の参照先、変更記録 `plugins/dev-workflow/changes/553.md`。
- `openspec/specs/dev-workflow-pr-review-gate/spec.md` の既存要件の本文（「SKILL.md の手順 N を読む」等）は書き換えず、読み替えの要件で扱う。
- `tests/injection-budget.bats` の対象である SKILL.md の `description` は変えないので、予算ファイルは動かさない。
- auto-merge workflow（`templates/auto-merge/`）と `対象 HEAD:` 規約の文言は変えない。
