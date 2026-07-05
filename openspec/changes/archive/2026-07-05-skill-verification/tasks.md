# Tasks: skill-verification

## 1. 対象スキルの棚卸し

- [x] 1.1 `plugins/*/skills/*/SKILL.md` 全件（現時点 10 件）を列挙し、「成果物を出すスキルか」「完了宣言前の検証が本文に明示されているか」を監査して、対象/対象外（+理由）の棚卸しリストを下書きする。対象には最低でも longrun-plan / wt-setup / wt-clean / daily-report / weekly-report / infra-setup と、**「e2s-distill」のスキル実体 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`**（e2s-distill はコマンド名であり、この名前のスキルディレクトリは存在しない。棚卸し・検証節追加・テストはすべてこの実パスで参照する）を含める
- [x] 1.2 各対象スキルについて「成果物（何を出すか）× 検証手段（テスト・lint・生成物の存在と形式チェック・実行結果 evidence）」の対応表を下書きする（汎用文言コピペを防ぐための執筆素材。公式例の粒度: 「dev サーバーを起動し、ブラウザで操作確認、コンソールエラーなしを確認」）
- [x] 1.3 各対象 SKILL.md の現在行数を記録し、500 行ルールの適用対象（追加後 500 行超。少なくとも wt-clean=506 行）を確定する

## 2. bats テスト作成（RED）

- [x] 2.1 `plugins/loops/tests/self-verification-reference.bats` を作成する: `plugins/loops/references/self-verification.md` の存在、中核原則「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」、evidence 4 種（テスト出力 / exit code / 生成物の実在と形式チェック / 実行結果ログ）、スキル側への記載ルール（1 行参照 + 固有手順のみ・原則本文コピー禁止）、「対象スキル一覧」節に 7 スキルの実パス（`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` を含む。`e2s-distill` をパスに含む記載が 0 件）があることを grep で検証する
- [x] 2.2 `plugins/loops/tests/skill-verification-sections.bats` を作成する: 7 スキルの実パス各 SKILL.md に「## 自己検証」見出しがちょうど 1 件、節内に `loops/references/self-verification.md` への参照 1 行、中核原則文言の重複が `plugins/*/skills/*/SKILL.md` 全体で 0 件、節本文（参照行除く）の完全一致ペアが 0 組、**各節内にバッククォート付き検証コマンドまたは成果物パスが最低 1 つ存在すること**（spec Requirement / design D7 (3) 対応）、追加後 500 行超の SKILL.md では節が 15 行以内 + 同プラグイン `references/` に分離ファイルが存在することを検証する
- [x] 2.3 テストを実行し、リファレンス未作成・節未追加の現状で FAIL（RED）することを確認する

## 3. 共通原則リファレンスの作成

- [x] 3.1 `plugins/loops/references/self-verification.md` を作成する: 中核原則、evidence 4 種、スキル側への記載ルール（1 行参照 + スキル固有手順のみ・共通原則本文のコピー禁止）を 1 枚化する
- [x] 3.2 同ファイルに「対象スキル一覧」節を追加し、1.1 の棚卸し結果（実パス + 対象/対象外判定 + 対象外理由）を記録する。e2s-distill のエントリは実パス `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` で記載する
- [x] 3.3 `plugins/loops/tests/self-verification-reference.bats` が PASS（GREEN）することを確認する

## 4. 各対象スキルへの「## 自己検証」節の追加

- [x] 4.1 `plugins/longrun/skills/longrun-plan/SKILL.md` に「## 自己検証」節を追加する（参照 1 行 + plan.md 生成物固有の検証手順。1.2 の対応表に基づく。既存行の削除・変更なし）
- [x] 4.2 `plugins/worktree/skills/wt-setup/SKILL.md` に「## 自己検証」節を追加する（worktree 作成・Draft PR 等の成果物固有の検証手順）
- [x] 4.3 `plugins/worktree/skills/wt-clean/SKILL.md` に「## 自己検証」節を追加する。**追加前から 506 行のため 500 行ルールを適用**: 検証詳細を `plugins/worktree/references/` 配下に分離し、SKILL.md 内の節は 15 行以内（参照 1 行 + 要点）に収める
- [x] 4.4 `plugins/daily-report/skills/daily-report/SKILL.md` に「## 自己検証」節を追加する（生成される diary 等の成果物固有の検証手順。追加後 500 行超なら 4.3 と同じ分離ルールを適用）
- [x] 4.5 `plugins/weekly-report/skills/weekly-report/SKILL.md` に「## 自己検証」節を追加する（週次レポート生成物固有の検証手順）
- [x] 4.6 `plugins/infra/skills/infra-setup/SKILL.md` に「## 自己検証」節を追加する（インフラ設定・デプロイ確認固有の検証手順）
- [x] 4.7 **実パス** `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` に「## 自己検証」節を追加する（生成される SKILL.md の形式・サニタイズ結果固有の検証手順。コマンド名 e2s-distill からパスを組み立てない）
- [x] 4.8 棚卸し（1.1）で追加対象と判定されたその他のスキルがあれば、同じ構成（参照 1 行 + 固有手順・500 行ルール）で節を追加し、bats テストの対象リストにも追加する

## 5. 統合検証

- [x] 5.1 `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行し、本 change の 2 テストを含む全テストが PASS することを確認する
- [x] 5.2 `git diff` で全対象 SKILL.md の変更が「## 自己検証」節（+ references 分離ファイルの新規追加）のみであること、frontmatter・既存本文行の削除・変更が 0 件であることを確認する
- [x] 5.3 各節の固有手順が 1.2 の対応表と対応し、どのスキルにも当てはまる汎用文言だけの節が 0 件であることをレビューする（受け入れ条件 8 の evidence として結果を記録）
