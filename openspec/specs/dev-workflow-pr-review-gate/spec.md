# dev-workflow-pr-review-gate Specification

## Purpose
TBD - created by archiving change promote-pr-review-gate-to-dev-workflow. Update Purpose after archive.
## Requirements
### Requirement: pr-review-gate スキルがプラグインとして全リポに配布される

dev-workflow プラグインは `skills/pr-review-gate/SKILL.md` を含み、`plugin.json` の skills 配列に登録することで、プラグイン導入済みの任意のリポで「PR を作った / レビューして / マージまで進めて / 保留を再開する」の文脈で発火させられる状態にする（SHALL）。スキル名は flatmate 版と同じ `pr-review-gate` とする（SHALL）。

#### Scenario: プラグイン導入リポでスキルが読める

- **WHEN** dev-workflow プラグインを導入したリポのセッションで pr-review-gate スキルを参照する
- **THEN** `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` が frontmatter（name: pr-review-gate と発火条件を含む description）付きで存在し、plugin.json の skills 配列に `./skills/pr-review-gate` が含まれている

#### Scenario: flatmate 版と手順の骨格が同一

- **WHEN** 移植版 SKILL.md を flatmate 版（PR #232）と比較する
- **THEN** 6 手順（前提を揃える → 別コンテキストレビュー → リスク宣言 → 動作確認 → 合格処理 → 保留処理）、ラベル名（`agent-review:passed` / `agent-review:pending` / `agent-review:failed` / `needs-approval`）、fail-closed の原則（宣言・証拠の HEAD SHA 実測確認まで passed を付けない）がすべて維持されている

### Requirement: スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する

移植版 SKILL.md は flatmate 固有のファイル・スクリプト・spec を無条件には参照しない（SHALL NOT）。flatmate にしか無い仕組み（pending ミラー等）は「リポに存在すれば従う・無ければ縮退手順」の条件分岐として記述する（SHALL）。auto-merge workflow が未配備のリポでは `agent-review:passed` 付与後のマージが人間操作になることを明記する（SHALL）。

#### Scenario: flatmate 固有参照の不在

- **WHEN** 移植版 SKILL.md を検査する
- **THEN** `genetta-inc/flatmate` の直書き URL が存在せず、`pending-mirror.sh` / `memory/pending-owner.md` / `channel-reply-policy` への参照はすべて「存在すれば」の条件付き記述の中にのみ現れる

#### Scenario: auto-merge 未配備リポでの縮退

- **WHEN** auto-merge workflow が配備されていないリポでスキルの手順 5（合格処理）まで到達する
- **THEN** スキルは「passed 付与後のマージは人間が行う（auto-merge 配備リポでは自動）」という縮退動作を案内しており、マージ API を LLM が直接叩くことは引き続き禁止されている

### Requirement: flatmate issue #240 の収束ルールが織り込まれている

移植版 SKILL.md は次の収束ルールを含む（SHALL）: ①レビューは既定 2 周（初回 + 差分再レビュー 1 回）で確定し、3 周目に入れるのは新規の高深刻度 blocking（安全機構の穴・データ破壊・無言の機能不全）のみ ②再レビューは前回指摘が閉じたかの差分確認に限定し、新規の気づきは follow-up issue に回す ③マージ後に issue で直せるものは blocking にしない ④リスク許容リンク経由の合格では、リンク先を実際に確認し、GitHub リンクなら `gh api` で author を実測して確認記録（確認者・確認日時）を宣言コメントに追記する ⑤リスク承認を待つ間に動作確認（手順 4）を並行して進めてよいことを明記する。

#### Scenario: 2 周キャップの規定が存在する

- **WHEN** 移植版 SKILL.md のレビュー手順を読む
- **THEN** 既定 2 周キャップ・3 周目の許可条件（新規の高深刻度 blocking のみ）・再レビューの差分限定・blocking 定義の限定（マージ後に直せるものは follow-up issue 化）が規定されている

#### Scenario: リスク許容リンクの真正性確認が存在する

- **WHEN** 主の許容回答リンク経由で合格処理（手順 5）を行う
- **THEN** スキルはリンク先を開いて主本人の発言と許容の意思を確認し、GitHub コメントの場合は `gh api` で author を実測する手順と、確認記録の書式（確認者・確認日時の追記）を規定している

