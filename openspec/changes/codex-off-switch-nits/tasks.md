## 1. 仕様

- [x] 1.1 `openspec/specs/dev-workflow-pr-review-gate/spec.md` の要件「事前判定と障害時フォールバックを区別する」の括弧書きを置き換える。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:109
- [x] 1.2 `openspec/specs/usage-account-registry/spec.md` の「アカウントレジストリの所在と形状」の守備範囲の段落を参照 1 文にする。触る範囲: openspec/specs/usage-account-registry/spec.md:30
- [x] 1.3 archive 済み change の delta spec 2 本（pr-review-gate・usage-account-registry）を同じ文にする（spec 段で済み）。触る範囲: openspec/changes/archive/2026-10-12-codex-off-switch/specs/dev-workflow-pr-review-gate/spec.md:7、openspec/changes/archive/2026-10-12-codex-off-switch/specs/usage-account-registry/spec.md:27

## 2. 記録とテスト

- [x] 2.1 `plugins/dev-workflow/changes/978.md` の差分範囲に `refuse_explicit_codex_when_off`（`codex-develop.py:507-519`）を足す。触る範囲: plugins/dev-workflow/changes/978.md:30
- [x] 2.2 `statusline.bats` の `codex_off_env` に auth.json を置き、「codex off」の検査がオフ判定を消すと落ちることを確かめる（確かめ方: 一時的にオフ判定を外して落ちることを見て戻す）。触る範囲: plugins/statusline/tests/statusline.bats:185-202
