# Proposal

## Why

unmanned で W が主の判断を要するとき、指示書は Discord への直接送信を要求しているが、`dev-workflow:worker` の tools には Discord の道具が無い。質問できずに停止したり、判断を補って進めたりすることを防ぐため、W の return を受けた本体が質問を代理送信する責務を定める（issue #594 の triage 確定条件）。

## What Changes

- W は仕様の発明が 2 回に達したとき、または change の割り方を判断できないとき、質問文・理由を return に書く。記録先に `needs-approval` を付けて経緯をコメントし、作業を止めて本体に返す。
- 本体（unmanned では憲法のメイン）は W の return を受けて質問を Discord へ代理送信し、そのサイクルを終了する。この手順を develop の「実行モード」の unmanned の説明に加える。
- W に Discord への直接送信を求める記述を取り除き、`decision-criteria.md` の曖昧な分割時の記述も同じ責務分担に揃える。worker agent の tools に Discord の道具を追加しない。
- `tests/` に既存の `develop-*.bats` の命名に沿った回帰テストを置き、W の直接送信禁止と return の契約、本体による代理送信の手順を固定する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 実行モードの責務分割に、本体による Discord への代理送信と W の質問 return 契約を追加する。

## Impact

- 実装対象: `plugins/dev-workflow/skills/develop/references/roles/worker/common.md`・`spec.md`、同スキルの `references/decision-criteria.md`・`SKILL.md`、新規 `tests/develop-worker-question-proxy.bats`。
- 確認対象: `plugins/dev-workflow/agents/worker.md` の既存 tools、`openspec/specs/dev-workflow-develop/spec.md` に適用される delta。
- 実装段で `plugins/dev-workflow/changes/594.md` に変更記録を残す。バージョンは上げない。
- 受け入れ確認: 指定範囲の `grep -rn -i discord` の全ヒットが否定文脈のみ、SKILL.md の unmanned の節に本体の代理送信手順、bats と `./scripts/test.sh` の exit 0、`openspec validate worker-question-proxy-discord --type change --strict` の exit 0。
