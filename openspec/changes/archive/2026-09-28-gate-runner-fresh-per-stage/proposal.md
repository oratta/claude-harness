## Why

develop のマージ前の検査担当（G）は、名前付きで 1 体起こされ、段が進むたびに本体から SendMessage で再開される（前提確認と重さ判定 → レビュー担当の要約を受けて照合と振り分け → 合格処理）。再開のたびに前の段の履歴が残るので、1 体目は 2 段目の途中でコンテキスト上限 150K に当たって後任に交代し、後任は指示書を読み直して同じ量を払い直す。genetta-inc/flatmate#762 の 1 本目の PR では G が 4 体交代し、直近 10 日で G の半数が上限を超えている。#553 で段ごとに読むファイルを小さくしたので、段ごとに新しい G を起こしても 1 体あたりの固定分は抑えられる。

## What Changes

- `skills/develop/SKILL.md` の (4) を、段ごとに新しい G を spawn する形にする。G は 4 つの段（前提確認と重さ判定・照合と振り分け・合格処理・保留の解除）のどれか 1 つだけを担当し、起動指示に `段: <段の名前>` を書く。G を SendMessage で再開する記述を無くす。
- Gate Result の共通欄に `段:` と `次の段:` を足し、Status に `次の段へ` を足す。本体は `次の段:` を読んで次の G を起こすだけにし、段の判断は G 側に置く。
- 段と段の間の受け渡しは PR コメントを正とする。`レビュー重量:` コメントに `固定 HEAD: <SHA>` の行を足し、照合と振り分けの G がレビューの三表を 1 行目 `レビュー三表:` のコメントとして投稿する。本体は前の段の `## Gate Result` ブロックをそのまま貼り、段に固有の入力（レビュー要約・裁定・主の回答・W の修正の要約）を渡す。
- `gate-runner.md` の「再開」節を、段ごとの起動と入力の定義に書き換える。`レビュー経路: adapter` で起動済みの同一 G が行の無い再開でも adapter 経路を保つ規則は、再開が無くなるので消す。
- G が `工程中断:` で返したら同じ段の新しい G を起こす。G を起こす前の `subagent-context.sh` による計測は W だけに残す。
- G の名前を `G-<PR>-<prepare|triage|pass|hold>-<n>`、description を `G: <段> for PR #N (#issue)` にする。
- 「レビュー実行者:」PR コメントの段落を `stages/prepare.md` から `stages/triage.md` へ移す。
- develop の役割の bats に、段ごとの起動があり G を SendMessage で再開する記述が無いことの検査を足す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: G を段ごとに新しく起こすこと、段の一覧と起動指示の書式、Gate Result の `段:` / `次の段:` と Status `次の段へ`、段と段の間の受け渡し、周回の引き継ぎ、`工程中断:` のときの扱い、G の名前と description を足す。G の再開を前提にした既存要件の読み替えを足す。
- `dev-workflow-pr-review-gate`: 決める役の裁定を渡して「G を再開する」と書いた既存要件と、G の「再開節」を指す既存要件を、段ごとに新しく起こす G の入力として読み替える要件を足す。

## Impact

- 編集: `plugins/dev-workflow/skills/develop/SKILL.md`、`skills/develop/references/roles/gate-runner.md`、`skills/develop/references/decision-criteria.md`、`skills/pr-review-gate/stages/prepare.md`・`triage.md`・`hold.md`・`pass.md`、`plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/dev-workflow/scripts/session-tripwires.sh`、`plugins/dev-workflow/tests/` の develop 系 bats、変更記録 `plugins/dev-workflow/changes/554.md`。
- 既存要件の本文は書き換えず、読み替えの要件で扱う（#553 と同じやり方）。
- auto-merge workflow と `対象 HEAD:` 規約の文言は変えない（固定した HEAD の行を `対象 HEAD:` にしないのはこのため）。
- 常時注入される `description` は変えないので、`tests/injection-budget.txt` は動かさない。
