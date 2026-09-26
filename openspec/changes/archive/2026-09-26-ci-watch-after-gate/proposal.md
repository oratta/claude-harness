# ゲート合格後に CI を見張り、落ちたらやり直すか直す

## Why

ゲート（pr-review-gate）に合格した PR の CI が落ちても、そのセッションは起こされず、オーナーが見に戻るまで誰も直さない（エピック #512。実例は genetta-inc/flatmate PR #891 で、合格後の CI が 3 回落ちた）。落ちた PR の分類と次の一手を決める判断は #521 で `plugins/dev-workflow/scripts/pr-state.sh`（`observe` / `decide` / `annotations`）として main に入ったが、それを呼んで CI の完了を待ち、判定どおりに動く側がまだ無い（#522）。

判断の部分とは別に、呼ぶ側には決めることが 4 つある。

- 待つのは誰か。名前付きのサブエージェントは自分が起動した背景タスクの完了では起こされない（`plugins/dev-workflow/references/subagent-waiting.md`）ので、G が待つと止まる
- 前回の状態（`decide` の入力）をどこに置くか。`pr-state.sh` は状態の保存を呼び出し側に任せている
- `--unrelated`（PR の変更に関わらない失敗としてやり直しに回す）をいつ渡すか。#521 で、手がかりの無い失敗はやり直さずに直しに回すことになり、エピックの「たまに落ちるテストなら 1 回やり直す」はこの呼び出し側の責務になった（#522 のコメント）
- 後続の #523（「CI が通ったらマージして」と頼まれた PR を見張る入口）が同じ待ち方と仕分けを呼べる形にすること

## What Changes

- `plugins/dev-workflow/scripts/ci-watch.sh` を新設する。サブコマンドは 2 つ:
  - `wait <owner/repo> <PR番号> [--until-merged]`: PR の CI が決着するまで（`observe` の `state` が `wait` でなくなるか、PR が閉じる・マージされるか、上限時間に達するまで）間隔を空けて `gh pr view` を繰り返し、決着したときだけ 1 行の JSON を出す。本体が Bash ツールの `run_in_background` で起動し、完了通知で起こされる前提の「待つだけのループ」で、途中経過を会話に出さない。`--until-merged` は自動マージの見届け用で、マージされるか閉じるか上限時間まで待つ
  - `next <owner/repo> <PR番号> [--unrelated <チェック名>]...`: その時点の PR を `annotations` → `observe` → `decide` に通し、PR ごとの状態ファイルから前回の状態を読んで、`decide` の `next` を書き戻し、`decide` の出力をそのまま出す
- 共有 reference `plugins/dev-workflow/references/ci-watch.md` を新設する。中身は、待つのは本体だけという約束、`wait` → `next` → 一手ごとの動き（`rerun`: `gh run rerun <run> --failed` してもう一度待つ／`fix`: 直し方の手順で直してゲートを取り直し、もう一度待つ／`escalate`: PR のリンクを添えてオーナーに 1 アクションで頼む／`ready`: 自動マージが配備済みなら見届け、無ければオーナーにマージを頼む／`none`: 状況に応じて待ち直すか止まる）、`--unrelated` を渡す基準、直し方の手順（flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を harness 向けに移したもの）
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順 5（合格処理）のあとに、CI の見張りを始める手順を足す。ゲートをメインセッションで回しているなら自分で `ci-watch.sh wait` を `run_in_background` で起動し、サブエージェント（develop の G）なら見張りを始めずに `passed` を return して呼び出し側の本体に任せる
- `plugins/dev-workflow/skills/develop/SKILL.md` の (4) に、G が `passed` を返したあと本体が見張りを始め、`fix` なら W に直させて G を取り直すことを足す。G の指示書 `skills/develop/references/roles/gate-runner.md` に、G は見張りを始めないことを 1 行足す
- 変更記録 `plugins/dev-workflow/changes/522.md` を書く

## Capabilities

### New Capabilities

- `dev-workflow-ci-watch`: 合格後の CI の待ち方（`ci-watch.sh wait`）・次の一手の取り出しと状態の保存（`ci-watch.sh next`）・一手ごとの動き・`--unrelated` を渡す基準・直し方の手順（共有 reference）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 合格処理のあとに CI の見張りを始める（メインセッションなら自分で、サブエージェントなら呼び出し側に任せる）要件を足す
- `dev-workflow-develop`: (4) で G が `passed` を返したあと本体が CI を見張り、`fix` なら W に直させて G を取り直す要件を足す

## Impact

- `plugins/dev-workflow/scripts/ci-watch.sh`（新設）と `plugins/dev-workflow/tests/ci-watch.bats`（新設。PATH 先頭の `gh` の偽物で試す）
- `plugins/dev-workflow/references/ci-watch.md`（新設）
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`・`plugins/dev-workflow/skills/develop/SKILL.md`・`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（手順の追記）と、それを確かめる bats の追記
- `plugins/dev-workflow/changes/522.md`（変更記録）
- `pr-state.sh` と `openspec/specs/dev-workflow-pr-state` は変えない（入出力は spec のとおりに使う）
- 前提: `gh` の認証（PR と checks の読み取り、やり直しには対象リポの Actions への書き込み）、`jq`、Bash ツールの `run_in_background` で起動した背景タスクの完了通知でメインセッションが起こされること
- unmanned モード（develop の `--unmanned`）は (4) を回さないので対象外。住人（flatmate の pr-watch）は genetta-inc/flatmate#976 で `pr-state.sh` を直接呼ぶ
