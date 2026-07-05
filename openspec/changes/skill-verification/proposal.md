# Proposal: skill-verification

## Why

公式記事「Getting started with loops」は、ターンベースループ（人間がプロンプトし、エージェントが応答する最基本のループ）の最適化として「**スキルに検証ステップを組み込み、自己検証能力を向上させる**」ことを挙げている。公式例は「フロントエンド変更を確認する前に dev サーバーを起動し、ブラウザで操作確認、コンソールエラーなしを確認」という具体的な粒度である。また `research/anthropic-agent-knowledge.md` ソース9 は「『成功した』と主張させず evidence を提示させる」ことを求めている。

現状、このリポジトリの成果物（コード・ファイル・レポート・設定）を出す主要スキルの SKILL.md には、「完了宣言の前に何をどう検証するか」が本文に明示されていないものがある。スキルが自己検証せずに完了を宣言すると、手戻り（人間による再確認・再依頼）が発生し、ターンベースループの効率が公式ベストプラクティスから乖離したままになる。

## What Changes

- **対象スキルの棚卸し**: `plugins/*/skills/*/SKILL.md` の全件について「成果物を出すスキルか」「完了宣言前の検証が本文に明示されているか」を監査し、対象/対象外（+理由）の棚卸しリストを確定する。最低でも longrun-plan / wt-setup / wt-clean / daily-report / weekly-report / infra-setup / e2s-distill（コマンド名。スキル実体は `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`）を対象に含める
- **共通原則リファレンスの新設**: `plugins/loops/references/self-verification.md` に検証の書き方の共通原則を 1 枚化する（「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」+ evidence の種別 + スキル側への記載ルール + 棚卸しリスト）
- **検証節の追加**: 検証が欠けている対象スキルの SKILL.md に「## 自己検証」節を追加する。各節は共通原則リファレンスへの 1 行参照 + そのスキル固有の検証手順（テスト・lint・生成物の存在と形式チェック・実行結果の evidence）のみで構成し、共通原則本文の重複コピーを禁止する
- **既存機能の不変**: 各スキルの機能・発火条件（frontmatter・既存本文）は一切変更しない。追加は検証節（および 500 行ルールによる references 分離ファイル）のみ
- バージョン bump・marketplace.json 同期は行わない（plan の責務分割により change-5: integration が一括で実施する）

## Capabilities

### New Capabilities

- `loops-self-verification-reference`: 自己検証の共通原則リファレンス `plugins/loops/references/self-verification.md` の内容要件（中核原則・evidence 種別・スキル側への記載ルール・対象スキル棚卸しリスト）と、共通原則本文の重複コピー禁止を定義する
- `skill-verification-sections`: 成果物を出す対象スキルの SKILL.md に追加する「## 自己検証」節の構成要件（固定見出し・参照 1 行 + スキル固有手順・汎用文言コピペ禁止・既存機能不変・500 行超過時の references 分離）を定義する

### Modified Capabilities

（なし。既存スキルの spec レベルの要件は変更しない。SKILL.md への追加は検証節のみで、機能・発火条件に影響しない）

## Impact

- **新規ファイル**:
  - `plugins/loops/references/self-verification.md`（共通原則リファレンス + 棚卸しリスト）
  - `plugins/loops/tests/self-verification-reference.bats` / `plugins/loops/tests/skill-verification-sections.bats`（bats テスト）
  - 500 行ルールに該当するスキル（少なくとも wt-clean、追加前 506 行）の検証詳細 references ファイル
- **変更ファイル**（「## 自己検証」節の追加のみ。既存行の削除・変更なし）:
  - `plugins/longrun/skills/longrun-plan/SKILL.md`
  - `plugins/worktree/skills/wt-setup/SKILL.md`
  - `plugins/worktree/skills/wt-clean/SKILL.md`
  - `plugins/daily-report/skills/daily-report/SKILL.md`
  - `plugins/weekly-report/skills/weekly-report/SKILL.md`
  - `plugins/infra/skills/infra-setup/SKILL.md`
  - `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（受け入れ条件の「e2s-distill」はコマンド名。実体はこの実パス）
  - 棚卸しで追加対象と判定されたその他スキル（あれば）
- **依存**: change-1（loops-plugin）。`plugins/loops/references/` が本 change の共通原則リファレンスとテストの置き場所であるため、change-1 の完了が前提
- **非対象**: 各プラグインの plugin.json version bump と marketplace.json 同期（change-5 が一括実施）。定期実行の機構・配線、独自ループランタイム（plan スコープ外）
