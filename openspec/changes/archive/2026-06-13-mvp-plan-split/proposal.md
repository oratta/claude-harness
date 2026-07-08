# Proposal: mvp-plan-split — MVP モードの独立スキル分離

## Why

`longrun-plan` スキルは現在、フルモード（自律実行用 plan.md 作成）と MVP モード（`--mode=mvp`、人間実装向け軽量 plan.md 作成）を 1 つの SKILL.md にモード分岐として同居させている。両モードは共通点が少なく（テンプレート・レビュー体制・OpenSpec 連携・ハンドオフがすべて異なる）、同じファイルをオプションで分岐させる構造は、(a) 片方の変更がもう片方に regression を起こすリスク、(b) それぞれの独立最適化（将来の MVP フロー Workflow 化判断を含む）の妨げ、になっている。MVP モードを独立スキル `longrun-mvp-plan` + 専用コマンド `/longrun:mvp`（短縮 `/lr:m`）に分離し、別々に進化できるようにする。

## What Changes

- 新スキル `longrun-mvp-plan` を新設（`plugins/longrun/skills/longrun-mvp-plan/SKILL.md`、名詞形命名）。現行 `longrun-plan` SKILL.md 末尾の「MVP モード（--mode=mvp）」セクションの内容を**ロジック変更なし**で移設し、自己完結したステップ群として記述する
- 新コマンド `/longrun:mvp`（`plugins/longrun/commands/mvp.md`）と短縮コマンド `/lr:m`（`plugins/lr/commands/m.md`）を新設。Skill tool 経由で `longrun:longrun-mvp-plan` に委譲する
- **BREAKING**: `/longrun:plan` の `--mode=mvp` フラグを廃止。旧フラグ指定時は「`/longrun:mvp` に移動した」旨の移行案内を出力して終了する（サイレント無視・フルモードへの暗黙フォールバックはしない）
- MVP 用 agent 3 種（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer`）と `templates/plan-template-mvp.md` を新スキル帰属に整理（ファイル配置は現状維持、記述上の帰属・参照を `/longrun:plan --mode=mvp` から `/longrun:mvp` に更新）
- `<!-- mvp-mode -->` マーカーと `/longrun:archive` 側のマーカー分岐は**現状維持**（成果物形式は不変）
- Gap Analysis / Interview の方法論は共通参照ドキュメントへの切り出し（または少量なら複製）で両スキルが自己完結に参照できるようにする（実装時判断、design.md 参照）
- `plugins/longrun/README.md` の MVP モードセクションを `/longrun:mvp` エントリポイントに書き換え
- バージョン同期: longrun 6.0.0 → 6.1.0、lr 6.0.0 → 6.1.0（plugin.json / marketplace.json top-level / marketplace.json plugins[] の 3 箇所 × 2 プラグイン）

## Capabilities

### New Capabilities

- `longrun-mvp-plan-skill`: 独立した MVP プラン作成スキル。スキル本体・`/longrun:mvp`・`/lr:m` コマンド・MVP 用 agent 3 種とテンプレートの帰属・`<!-- mvp-mode -->` マーカー埋め込み・方法論の自己完結参照・バージョン同期を定義する

### Modified Capabilities

- `longrun-plan-skill`: `--mode=mvp` ディスパッチ要件と MVP モード関連要件群を削除（新 capability へ移設）。旧フラグ指定時の移行案内要件を追加。README の MVP ドキュメント要件を `/longrun:mvp` ベースに変更
- `longrun-mvp-research`: 呼び出し元の参照を `longrun-plan` SKILL から `longrun-mvp-plan` SKILL に変更（agent の動作契約自体は不変）
- `longrun-mvp-plan-reviewer`: 入力の出所の参照を `longrun-plan` SKILL Step 5 から `longrun-mvp-plan` SKILL Step 5 に変更（agent の動作契約自体は不変）

## Impact

- `plugins/longrun/skills/longrun-mvp-plan/SKILL.md`（新規）
- `plugins/longrun/skills/longrun-plan/SKILL.md`（MVP セクション削除 + モード分岐を移行案内に書き換え）
- `plugins/longrun/commands/mvp.md`（新規）、`plugins/lr/commands/m.md`（新規）
- `plugins/longrun/commands/plan.md` / `plugins/lr/commands/p.md`（`--mode=mvp` 透過転送の記述を削除・移行案内に更新）
- `plugins/longrun/agents/longrun-mvp-{research,plan-reviewer,bestpractice-reviewer}.md`（description / 呼び出し元記述の帰属更新のみ。契約は不変）
- `plugins/longrun/templates/plan-template-mvp.md`（生成情報のモード表記を `/longrun:mvp` に更新。マーカー・divergence 防止コメント・セクション構成は不変）
- `plugins/longrun/README.md`（MVP セクション書き換え）
- `plugins/longrun/.claude-plugin/plugin.json` / `plugins/lr/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`（skills[] / commands[] / version 更新）
- `/longrun:archive` のマーカー分岐・`/longrun:exec`: 変更なし（成果物形式不変のため）
- 依存: change-2（workflow-exec、longrun/lr v6.0.0）マージ後に着手（plugin.json / README の同時編集コンフリクト回避のための直列化。論理的依存はない）
