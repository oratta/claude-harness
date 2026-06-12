# Decisions — harness 大型改修 run

全 change の設計判断を集約する。各判断にはエビデンス（実行コマンドと出力）を必須とする。

## Setup フェーズ

### D-S1: openspec のバージョン乖離を発見、change-1 実機検証の検証対象に追加

- **日時**: 2026-06-12 11:09
- **エビデンス**:
  ```
  $ which openspec
  /Users/oratta/.volta/bin/openspec
  $ openspec --version
  1.2.0
  $ npx --no-install openspec --version
  0.23.0
  ```
- **判断**: volta グローバル（1.2.0）と npx 解決（0.23.0）が別物。plan.md の change-1 は `npx openspec` を前提条件チェックの対象としているため、実機検証タスクで「どちらを正とするか + バージョン差による挙動差」を確定する。Setup 時点ではどちらも動くため進行に支障なし。

### D-S2: ベースライン 3 スイート全 PASS を確認してから開始

- **日時**: 2026-06-12 11:11
- **エビデンス**: e2s 24 ok / daily-report 48 ok / harvest 313 ok（checkpoint.md 参照）
- **判断**: 回帰判定の基準線として記録。plan.md の「既存 bats スイートを壊さない」（change-5 config rules）の比較対象は harvest 313 本。

## Build Contract フェーズ

### D-BC1: longrun-reviewer 判定 APPROVE、指摘 3 件を全て採用（バイアス緩和ガード判定込み）

- **日時**: 2026-06-12 11:17
- **エビデンス**: longrun-reviewer Agent (a0db2a4dc44e611c5) のレビュー結果。BLOCKER 0 / SHOULD_FIX 2 / NOTE 1
- **指摘ごとの (a)採用 / (b)反論 判定**:
  - **指摘1（採用 (a)・契約の穴）**: 受け入れ条件11の grep 対象に `.claude-plugin/marketplace.json` が漏れていた。実機確認で marketplace.json L40 の lr description に `/lr:s, /lr:d` 文字列が現存 → grep 対象に追加修正
  - **指摘2（採用 (a)・事実誤認）**: 「実測約230本」は bats **ファイル数**で、実 `@test` 数は 313。母数の混在は回帰見逃しリスク → plan.md の 3 箇所を 313 本基準に統一
  - **指摘3（採用 (a)・事実誤認）**: `templates/plan-template.md` の実パスは `plugins/longrun/templates/plan-template.md`。リポジトリ直下 `templates/` には rules/ しかない → フルパスに修正
  - 嗜好レベルの指摘（(b) 反論対象）は今回なし。3 件とも事実ベースのため全採用は過剰受容バイアスに該当しない
- **補足メモ（builder への引き継ぎ）**: reviewer の実機確認によると `plugins/lr/commands/e.md` は既に exec.md への単純委譲形であり「インライン展開ハック」は exec.md 側（SKILL.md を読んでインライン実行する構造）に存在する。change-2 では e.md の微修正 + exec.md の全面書き換えが実体。re-review は不要（APPROVE 済みのため 2 ラウンド目はスキップ）。

## Build フェーズ

### D-B1: PR 分割と「各 PR マージ後に次の worktree」の自律実行内での解釈

- **日時**: 2026-06-12 11:25
- **背景**: plan.md は「PR は change ごとに分け、各 PR マージ後に次の change の worktree を切る」と記すが、マージは承認制（git-commit-policy）のため、文字どおり実行すると change-1 の PR マージ待ちで自律実行がブロックされる。
- **判断**:
  - claude-harness 側（change-1〜4）: SKILL.md の標準パターンどおり、run ブランチ `longrun-workflow-setup` から `_worktrees/<change>` を切って直列ビルドし、完了ごとに `--no-ff` マージで run ブランチに統合する（change 単位の diff はマージコミットで追跡可能）。main への per-change PR 分割は **Feedback フェーズでユーザーに確認**してから行う（マージ承認が必要な操作のため、どのみちユーザー対話が必須）。run ブランチは既存 Draft PR #6 で常時バックアップされる。
  - marketing-harness 側（change-5）: 独立リポジトリのため計画どおり worktree + feature branch + Draft PR を新設して並行ビルド。
- **エビデンス**: `gh pr list --head longrun-workflow-setup` → PR #6 (draft) 作成済み。git-commit-policy「マージ操作は明示承認が必要」。

### D-B2: Spec Review ラウンド1の判定と指摘の採否（バイアス緩和ガード判定込み）

- **日時**: 2026-06-12 13:15 頃
- **エビデンス**: longrun-reviewer Agent 5 体の並列 Spec Review 結果
  - change-1 openspec-degradation: **REQUEST_CHANGES**（BLOCKER 1: archive 縮退分岐の判定ソース不一致 + Impact 欠落 / SHOULD_FIX 2 / NOTE 1）
  - change-2 workflow-exec: **REQUEST_CHANGES**（BLOCKER 2: version 起点矛盾 5.3.0 vs 実体 5.2.0、schema 異常系 fixture タスク欠落 / SHOULD_FIX 2 / NOTE 1）
  - change-3 mvp-plan-split: **APPROVE**（NOTE 3。REMOVED 8 件・MODIFIED 全文コピーの正確性は実機突合せで確認済み）
  - change-4 model-allocation: **APPROVE**（NOTE 3。inherit = opts.model 省略の解釈は Workflow 仕様と整合）
  - change-5 harvest-structured-output: **APPROVE**（SHOULD_FIX 1: bats ディレクトリ形式は vendor 再帰で 1142 本になり母数 313 と矛盾 / NOTE 3）
- **採否判断**: 全指摘とも事実誤認・契約の穴・検証可能性の欠落であり嗜好レベルの指摘なし → (a) 採用。修正は元のドキュメント作成 Agent に SendMessage で委譲（コンテキスト保持・orchestrator はコードを書かない原則）
  - change-3 の NOTE は「引数透過維持の 1 文明記」のみ採用（builder が引数透過まで削除する実害リスクがあるため）。残り 2 NOTE は任意改善で実害なしと判断し不採用
  - change-4 の NOTE 3 件は「矛盾ではない・実害なし・change-2 確定待ち」のため不採用（reviewer 自身が任意と明記）
  - change-5 の指摘 4（.gitignore 二重要求）は reviewer の推奨どおり現状維持
- **再レビュー方針**: REQUEST_CHANGES の change-1 / change-2 のみラウンド2 再レビューを実施（レビューした同一 Agent に修正後ドキュメントを差し戻し）。APPROVE 済みの 3, 4, 5 は再レビューなし

### D-B3: Spec Review ラウンド2 — 全 5 change APPROVE 確定

- **日時**: 2026-06-12 13:40 頃
- **エビデンス**: 同一 reviewer Agent によるラウンド2再レビュー
  - change-1: **APPROVE**。BLOCKER（archive 判定ソース）は proposal/design/tasks の 3 ファイルで一貫解消を確認。新論点「常時 AskUserQuestion 1 問追加」は「従来挙動 = 実行フロー・成果物パス・形式の不変」を侵さず、proposal の Why（opt-out 手段の欠如）を解決する意図された仕様差分のため回帰に当たらないと判定。残 NOTE: 常用ユーザーの毎 run 1 タップ（デフォルト通常モード・Enter 即決 UX を実装時徹底。将来 always-normal スキップが欲しくなったら backlog 化）
  - change-2: **APPROVE**。BLOCKER 2 件解消確認。Requirement 名変更は ADDED のみの delta のため validate/archive 整合に影響なしを確認。残課題なし
- **判断**: 全 5 change の仕様確定。verification-guide.md 生成 → Build 後半（TDD 実装）へ進行
