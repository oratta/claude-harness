# Proposal: Codex Build Agent PoC

## Why

longrun の Build フェーズ担当 Agent (`longrun-builder`, model: opus, bypassPermissions) は現状 Opus トークンを消費する。Codex CLI（v0.130.0、別途サブスクで定額枠あり）を委譲先として利用できれば運用コストを下げられる可能性がある。一方で、

- Codex が longrun-builder と同等の TDD 規律（RED→GREEN→REFACTOR）を守れるか
- Codex サブスクが使えない / 失敗した時に Opus にフォールバックできるか
- Codex 実行が `plugins/longrun/` などのリポ本体を破壊しないか

は plan 時点で未検証である。本 change は **Phase 1 PoC** として上記を実証することのみを目的とし、本実装（`longrun-builder-codex` Agent 新設 + orchestrator 分岐）は別 change（Phase 2）に委ねる。

PoC は本リポジトリ (`oratta-claude-harness`) の `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` 内に閉じ、`plugins/longrun/` / `plugins/codex/` / `openspec/specs/` / `~/.codex/` を一切変更しない。

## What Changes

- 新規 capability `codex-build-poc` を ADDED として追加（PoC 用、Phase 2 完了後にアーカイブ予定）
- 影響範囲は `_longruns/2026-05-13_codex-build-agent-eval/` 配下のみ
- 既存コード・スキル・Agent への変更なし
- backlog / 既存 active changes（`experience-to-skill-plugin`, `infra-setup-skill`）への影響なし

## Capabilities

- **codex-build-poc**: PoC harness（Bash + Bats）+ sandbox サンプル change（TypeScript + Vitest）+ TDD 忠実度計測スクリプト + フォールバック検証スクリプト + 評価レポート生成

## Impact

- Affected specs: なし（PoC は delta なしで完了。Capabilities は本 change 内 specs/ に限定）
- Affected code: なし（既存ソースコードに変更なし）
- Affected docs: `_longruns/2026-05-13_codex-build-agent-eval/` 配下に `evaluation.md` / `prompts.md` / `summary.md` / `verification-guide.md` を新規作成
- Risk:
  - Codex CLI 実行時に意図せず `~/.codex/` や `plugins/` を書き換える可能性 → `run-poc.sh` の事前ガード + Bats #12 で多層防御
  - サンプル change が Codex で完走しない場合 → No-Go と判定し evaluation.md に記録、Phase 2 plan は起票しない
