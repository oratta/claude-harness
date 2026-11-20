# Tasks

この段階では未実装。R1 APPROVE と本体の実装指示を受けてから着手する。fixture は `mktemp -d` 等で repo 外に作成し、実機セッションの起動・実設定変更は行わない。

## 1. 承認欄と保存先を持つ収集入口

- [ ] 1.1 手順書に主が実行時に埋める承認欄（親/子/単発の本数、消費上限と単位、設定適用先/範囲、停止条件）と推奨、版/commit/役割別実効値・親の前後変化・子の起動指定の確認方法を追加する。設定操作は既存正本を参照する。CLI の metadata 入力項目と秘密値を含まない例、LLM_LOG_DIR の指定も説明する。受け入れ条件との対応と、未承認の実機操作を要求しないことを読み合わせて確認する。触る範囲: plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md（新規）
- [ ] 1.2 `--transcript` と `--metadata` を受け取る受動的な CLI、既知項目だけの型検査、LLM_LOG_DIR への保存を実装する。未設定/空・repo 内（cwd/plugin の repo、symlink 経由を含む）なら作成前に停止する。秘密値入り本文/tool 出力/未知キー/不正入力が結果・stdout/stderr に漏れず、元ログが変わらない Bats を同時に追加する。`bats plugins/dev-workflow/tests/idle-compaction-observation.bats` の該当ケースで確認する。触る範囲: plugins/dev-workflow/scripts/idle-compaction-observation.py（新規）、plugins/dev-workflow/tests/idle-compaction-observation.bats（新規）、plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md（新規）

## 2. 区間の観測と結果分類

- [ ] 2.1 開始位置の prefix に対して既存の `subagent-context.sh --file` を呼び、exit 0/2 の会話量を使用する。S < 行番号 <= E の JSON type/subtype による boundary 件数、時刻/経過秒、実際の閾値と出典、実行者の確認を保存する。過去の境界・文中の単語・終了後の追記を除外し、開始後の大きな usage で開始時不足を隠さないこと、未知の正常な type、壊れた JSON/切り詰め/計測不能を Bats で確認する。手順書に位置の取り方と会話量測定を記載し、`bats plugins/dev-workflow/tests/idle-compaction-observation.bats plugins/dev-workflow/tests/subagent-context.bats` で確認する。触る範囲: plugins/dev-workflow/scripts/idle-compaction-observation.py（新規）、plugins/dev-workflow/tests/idle-compaction-observation.bats（新規）、plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md（新規）
- [ ] 2.2 idle/config/normal-compact を分け、idle は全条件成立時に 0 件を observed、1 件以上を unexpected-boundary、それ以外を unverified と理由付きで保存する。閾値未満/ちょうど、3599/3600 秒、実効値未確認、スリープ・追加リクエスト・通常/手動 compact 混在と unknown、時刻/区間の不整合を Bats で確認する。単発設定確認と別区間の通常自動 compact・hook 案内/Read の確認を個別に保存できるケースも追加する。手順書に追加 API リクエストなしで外側から観測する方法、実際の閾値・最後のリクエスト時刻の確認元、別区間の記録、再試行の承認条件と exit 0 の限界を記載し、同 Bats 全件で確認する。触る範囲: plugins/dev-workflow/scripts/idle-compaction-observation.py（新規）、plugins/dev-workflow/tests/idle-compaction-observation.bats（新規）、plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md（新規）

## 3. 変更記録と結合確認

- [ ] 3.1 `changes/1388.md` に新しい手順書と CLI への入口、正本の参照、実機未実施・#1385 を完了扱いにしないことを記載する。手順書の入力例を外部 fixture で実行し、`bats plugins/dev-workflow/tests/idle-compaction-observation.bats plugins/dev-workflow/tests/subagent-context.bats plugins/dev-workflow/tests/develop-idle-compaction.bats`、`openspec validate idle-compaction-observation --type change --strict`、`git diff --check` が通ることを確認する。触る範囲: plugins/dev-workflow/changes/1388.md（新規）

## Workflow follow-up

- 実機セッションの起動・設定適用・#1385 の実機確認結果の記録は、この実装チェックリストの外で主が承認範囲を決めて実行する。fixture の合格では代替しない。
