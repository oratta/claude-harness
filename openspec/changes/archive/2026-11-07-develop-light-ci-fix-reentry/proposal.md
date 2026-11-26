# Proposal

## Why

軽い通し方で W を起こさずに作った PR は、G の passed 後に CI 見張りが `fix` を返すと、存在しない W を `段: implement` で再開する手順に入ってしまう。issue #1589 の担当・起動段・判断記録の空白を埋め、通常経路の既存 W の復帰と両立させる。

## What Changes

- 軽い通し方の `fix` は同じ worktree に新しい W を `段: spec` で起こす。W は `通し方:` のない仕様化判断を同じ記録先へ投稿し直し、以後は通常の通し方でテスト・実装・必要な仕様レビューを通す。
- 通常経路の `fix` は既存 W を `段: implement` で再開する。再開できない場合の手渡し条件は既存の正本に従い、CI の `fix` だけを理由に仕様化判断をやり直さない。
- develop の passed 分岐・軽い通し方の正本・CI 見張りの共有 reference を接続し、両経路を Bats の文書契約テストで確かめる。
- push 後の同じ PR・同じ見張り状態ファイルによる `wait` → `next` → `ready` → G の前提確認と重さ判定、という既存の取り直しを維持する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 「G が passed を返したら本体が CI を見張る」に、W 未起動と既存 W の担当・段・判断記録の分岐を定める。

## Impact

- 手順: `plugins/dev-workflow/skills/develop/SKILL.md`、同 `references/decision-criteria.md`、`plugins/dev-workflow/references/ci-watch.md`。
- 仕様: `openspec/specs/dev-workflow-develop/spec.md`。`dev-workflow-ci-watch` の共有手順は既に直し手を develop の W と定めている。今回足すのは develop がその W を用意する規則であり、CI 分類・一手・状態管理の要件は変更しない。
- テスト: `plugins/dev-workflow/tests/develop-trivial-light-path.bats` を主に拡張し、既存の CI 見張りと develop の関係テストで接続を確認する。
- 分割判定: issue の受け入れ条件は develop の CI 修正への復帰という単一機能に閉じる。独立した設計判断は復帰段の選択 1 件であり、単一 change・単一 PR とする。
- 起動時予算: SKILL.md は現状 86,397 / 86,400 bytes。追記が予算を超えたら、既存文の圧縮で相殺せず `tests/develop-startup-budget.txt` の該当行を追記による増加分まで上げ、finish 工程の PR 本文に理由と https://github.com/oratta/claude-harness/issues/1586 を記す。常時注入予算は変更しない。
- #1583 の `commands/develop.md` の説明文・受け入れ条件、#1590、CI スクリプトの判定ロジックは対象外。
