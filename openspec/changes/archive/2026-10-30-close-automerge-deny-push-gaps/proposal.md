# Proposal

## Why

issue #629: auto-merge テンプレートの deny は前置形 7 件のみで、後置された force / no-verify オプションと main/master 宛ての明示 refspec を覆わない。単純な広い glob の追加は `feature:main-fix` 等も拒否するため、引数境界を含む照合方法と検証の限界を記録する。

## What Changes

- 既存 7 件を保持し、危険オプションの後置形と main/master 宛て refspec に一致する deny を追加する。通常の feature push と似た名前の別ブランチを拒否しない。
- 公式仕様に基づく決定論的な照合の再現を Bats 内に追加し、一致・不一致の両方を固定する。Claude Code 実マッチャーの実測とは区別して記録する。
- README の件数・配布用運用ガイドの deny 表・変更記録を更新する。版は上げない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-automerge-templates`: 既存の「deny 設定が auto-merge 配線と同じ場所から配布される」を MODIFIED。オプション位置・refspec 宛先境界・通常 push の非拒否・照合証拠を明文化する。

## Impact

実装対象は次の 5 ファイル。新たな実行時依存や hook は導入しない。

- `plugins/dev-workflow/templates/auto-merge/.claude/settings.json`
- `plugins/dev-workflow/tests/automerge-templates.bats`
- `plugins/dev-workflow/templates/auto-merge/README.md`
- `plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`
- `plugins/dev-workflow/changes/629.md`

triage が `docs/auto-merge.md:338-346` と呼ぶ deny 表は、固定 HEAD では配布用の `plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md:338-349` にある。ルートの `docs/auto-merge.md` には deny 表がないため、実物の配布用ガイドを更新する。

分割判断: 単一 change。issue の拒否範囲拡張と通常 push の維持は同一 capability の境界設計 1 件で、検証・文書更新まで 1 PR で完結する。仕様化判断の記録: https://github.com/oratta/claude-harness/issues/629#issuecomment-6513947431
