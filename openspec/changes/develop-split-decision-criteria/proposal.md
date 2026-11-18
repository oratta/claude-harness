# Proposal

## Why

作業者（W）とゲート役（G）は起動のたびに `skills/develop/references/decision-criteria.md`（約 2 万字）を全文読むが、使うのは「コンテキスト上限（サブエージェントの手渡し）」節のうち return の 1 行目の宣言の書式 約 1,000 字だけで、残りは本体だけが使う規則（軽い通し方・CI 修正からの戻し方・残量モード・手渡しの許可）である。残量モードとコンテキスト上限の説明も複数のファイルに言い換えて置かれている。エピック #1682 の 1 番目の子（#1683）として、場面で使わない規則をその場面で読むファイルから外し、同じ規則の正本を 1 か所に寄せる。動きは変えない。

## What Changes

- `decision-criteria.md` を、読む場面ごとに次の 4 ファイルに分ける。
  - `skills/develop/references/return-declaration.md`（新規。W と G が読む）: return の 1 行目の宣言（`工程完了:` / `工程中断:`）の書式と選び方、通知・強制停止を受けたときの W と G の振る舞い。宣言の書式の文は一字一句変えない
  - `skills/develop/references/spec-decision.md`（新規。W が `段: spec` で読み、本体も読む）: Step B（仕様化する／しない・文言合わせの通し方・記録・変えないもの・迷ったら）と Step C（分割判定）と「判定に使わない材料」
  - `skills/develop/references/light-path.md`（新規。本体だけが読む）: Step B の「仕様化しないが軽く通す」と、G の failed と CI 見張りの fix からの戻し方。`handover.md`「CI 見張りの修正担当の引き継ぎ」と重なる手順（W を把握しない本体の読み取り、起動前の無効化と再許可）は `handover.md` に寄せ、こちらは分岐と参照だけにする
  - `skills/develop/references/decision-criteria.md`（残す。本体だけが読む）: コンテキスト上限の本体向けの部分（2 経路・閾値の環境変数・再開前チェック・手渡しの許可・停止確認と終端・途中計測の仕組み・fail-open）と、残量モードと共有枠モード（優先順位を 1 つの表にまとめる）・自動導出・モード不変ルール
- W と G の指示書（`worker/common.md`・`worker/spec.md`・`roles/gate-runner.md`）が「読め」と指すのを `return-declaration.md` と `spec-decision.md` に付け替え、`decision-criteria.md` を読む指示を無くす。`gate-runner.md` は参照先のパスの付け替えだけで本文は変えない（本文の縮小は #1687）
- 残量モードと共有枠モードの優先順位の表は `decision-criteria.md` 1 か所に置き、`pre-classification.md`・`spec-reviewer.md`・`worker/common.md`・`plugins/dev-workflow/references/model-tiers.md` は 1 行の要旨と参照にする
- `worker/spec.md` と `worker/common.md` のうち正本と同じ内容の要約・段落を参照 1 行にする
- 規則本文に混ざった経緯（日付・実測値・issue 番号）を、`decision-criteria.md`・`references/subagent-waiting.md`・`worker/common.md`・`fix-check.md`・`model-tiers.md`・`agents/decider.md` から削る（照合される 1 行目の書式・守備範囲の段落・`subagent-waiting.md` の雛形のコードは変えない）
- 参照先の付け替え: `SKILL.md`・`handover.md`・`channel.md`・`spec-reviewer.md`・`skills/pr-review-gate/declarations.md`（パスだけ）・`templates/escalation-tripwires.md`・`README.md`・hook とスクリプトのコメント。SubagentStart の hook（`subagent-start-context.sh`）が W と G に案内する正本を `return-declaration.md` に、Codex の phase に付ける正本（`codex-develop.py`）を `return-declaration.md`（spec の phase はさらに `spec-decision.md`）に替える
- 手順書の文言を検査する bats を、文を develop 配下の別ファイルへ移しただけでは落ちない形（develop 配下の手順書のどこかにあることを確かめる形）に直す。手渡し規則の逐語検査（`handoff-single-source.bats`）は正本を 2 か所（`decision-criteria.md` の節と `return-declaration.md`）に広げる
- W が段ごとに読むファイルの合計に予算を置き、超えると bats が落ちるようにする（新規 `tests/develop-worker-stage-budget.txt` と bats）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: コンテキスト上限の規則の置き場所（本体向けと W・G 向けの 2 ファイル）、軽い通し方と CI 修正からの戻し方の正本のファイル名、Codex の phase に付ける正本、channel の聞き方の対象文書、unmanned の W の質問の正本、W が段ごとに読むファイルの予算
- `dev-workflow-handoff-single-source`: 逐語検査の正本を 2 か所にする
- `dev-workflow-spec-review`: 文言合わせの通し方・軽い通し方・テスト作成の例外の正本のファイル名
- `dev-workflow-execution-strategy`: Step B の正本のファイル名、残量モードと共有枠モードの優先順位を 1 つの表にすること
- `dev-workflow-escalation-tripwires`: SubagentStart の hook が案内する正本のファイル名

## Impact

- 文書: `plugins/dev-workflow/skills/develop/references/` の `decision-criteria.md`（縮小）・新規 3 ファイル・`handover.md`・`channel.md`・`pre-classification.md`・`fix-check.md`・`roles/spec-reviewer.md`・`roles/worker/common.md`・`roles/worker/spec.md`・`roles/gate-runner.md`（パスのみ）、`skills/develop/SKILL.md`（パスのみ）、`plugins/dev-workflow/references/ci-watch.md`・`references/codex-develop.md`・`references/workflow-execution.md`（パスのみ）、`docs/codex-delegation-inventory.md`（パスのみ）、`skills/pr-review-gate/declarations.md`（パスのみ）、`plugins/dev-workflow/references/model-tiers.md`・`subagent-waiting.md`、`agents/decider.md`、`templates/escalation-tripwires.md`、`README.md`
- スクリプト: `scripts/subagent-start-context.sh`（案内するパス）、`scripts/codex-develop.py`（phase に付ける正本）、`scripts/context-tripwire.sh`・`subagent-context.sh`・`session-tripwires.sh`（コメントと案内のパス）
- テスト: `tests/lib/handoff-verbatim.py`・`handoff-single-source.bats`・手順書の文言を検査する bats（`develop-roles.bats`・`develop-skill.bats`・`develop-trivial-light-path.bats`・`develop-worker-stages.bats`・`spec-decision-and-review.bats`・`spec-wording-sync-light-path.bats`・`subagent-start-context.bats`・`test_codex_develop.py` など）と新しい予算の bats
- 範囲外: `skills/pr-review-gate/` 配下と `roles/gate-runner.md` の本文（#1687）、`references/epic.md`・`epic-child-stop.md`（#1684）、SKILL.md の本文の縮小（#1685）、スクリプト化（#1686）
