# Proposal: longrun-v5-cleanup — longrun/lr の v5 残骸掃除

## Why

`plugins/longrun/` は v4.0 → v6.2 まで 7 世代のリファクタリングを経ており、各世代の断片が実装・ドキュメント両面に残存している。具体的には: (1) v6.0 で解体済みの `longrun-orchestrator` への修正依頼・コンテキスト復元指示が `longrun-verifier.md` / `longrun-browser-verifier.md` / `longrun-builder.md` に残り、Verify フェーズが FAIL したときの実際の復帰経路（Workflow による builder 再呼び出し）と矛盾した指示になっている、(2) 呼び出し経路がゼロの dead code `scripts/update-checkpoint.sh` が残置されている、(3) v6.1 で独立コマンド化された MVP モードの旧 `--mode=mvp` 移行シムが `longrun-plan` SKILL.md 他 5 ファイルに残り、marketplace のバージョン単位キャッシュ更新という恒久シムを不要にする仕組みと矛盾している、(4) README.md が v4.0〜v6.2 の全版履歴（80 行超）を抱えたまま現行版ドキュメントと同居し可読性を損ねている、(5) `plugin.json` の description が約 600 字あり 1 プラグインの説明として過大、(6) `commands/exec.md` の checkpoint.md 運用節がまだ「必須の監査ログファイル」という位置づけの語調を残しており、`resumeFromRunId` を状態復元の一次手段とする現設計と完全には整合していない。

これらは longrun-browser-verify-restore（change-2）が同じ 3 ファイル（`exec.md` / `README.md` / `plugin.json`）を編集するため、change-2 の後に直列実行する。放置すると Verify フェーズの FAIL 対応・再開手順を誤誘導し、marketplace のプラグイン説明が実態把握を妨げる。

## What Changes

**BREAKING**: なし。本 change は非機能的な残骸（存在しないコンポーネントへの参照・呼び出し経路ゼロの dead code・既に無効化済みシムの残存説明文）の削除と、ドキュメント構成の整理のみを行う。ユーザーに見える自律実行フロー（Review → Build → Verify → Feedback → Archive）・スキーマ契約・`resumeFromRunId` 再開フロー・`workflow-runs.jsonl` の記録形式には一切変更を加えない。`--mode=mvp` シムは v6.1 で既に「移行案内を出して終了」という非機能化がされており、本 change はその案内文自体を除去するのみ（フルモードへの暗黙フォールバックのような新しい実行時分岐は追加しない）。

- **orchestrator 残骸除去**: `agents/longrun-verifier.md`・`agents/longrun-browser-verifier.md` の「コンテキスト復元は checkpoint.md から」「FAIL 時は orchestrator に修正を依頼」という記述を、現構造（`{longrun-dir}/plan.md` + `decisions.md` 起点でコンテキスト復元、FAIL は Workflow が builder を再呼び出し）に書き直す。`agents/longrun-builder.md` の description の「checkpoint.mdを更新する」という実態と不一致な記述も修正する。`commands/exec.md:9` の historical 注記も `longrun-orchestrator` という複合語を使わない言い回しに書き換える（受け入れ条件 9 準拠、詳細は design.md）
- **dead code 削除**: `plugins/longrun/scripts/update-checkpoint.sh`（呼び出し経路ゼロを確認済み）を削除する
- **`--mode=mvp` シム完全撤去**: `skills/longrun-plan/SKILL.md` 冒頭の GATE ブロック（起動前チェック〜フルモード分岐、旧 8〜35 行目相当）、`plugins/lr/commands/p.md` の移行案内説明、`README.md` 内の `### --mode=mvp は廃止（deprecation）` サブセクションを削除する。`commands/plan.md` / `commands/mvp.md` は現状シム言及ゼロを確認する（無変更が期待値）
- **README → CHANGELOG.md 分離**: README.md の版履歴ブロック（v6.2〜v4.0、旧 5〜85 行目相当）を新設 `plugins/longrun/CHANGELOG.md` に移設する。README は現行版概要・コマンド表・アーキテクチャ図・命名規則・MVP プランモード・OpenSpec 縮退モードの現行ドキュメントのみを残す
- **description 圧縮**: `plugins/longrun/.claude-plugin/plugin.json` と `plugins/lr/.claude-plugin/plugin.json` の `description` を 1〜2 文に圧縮する（marketplace.json への反映は change-7）
- **checkpoint.md 節の格下げ**: `commands/exec.md` の checkpoint.md 運用節を「decisions.md に統合してもよい任意の人間向けメモ」という位置づけに書き換える。`workflow-runs.jsonl` の runId 記録・`resumeFromRunId` 再開フローの記述は一切変更しない
- **既存 bats の追随**: `tests/mvp-plan-split.bats`・`tests/release-and-readme.bats`・`tests/legacy-removal.bats` を新仕様（シム不在・版番号更新・CHANGELOG 分離後の README 構造）に更新する。テストは削除せず、検証意図を保ったまま新仕様のアサーションに置き換える

## Capabilities

### New Capabilities

- `longrun-orphan-cleanup`: orchestrator 残骸・dead code・`--mode=mvp` シムという「もう存在しない/機能しないコンポーネントへの生きた参照」を全廃する。受け入れ条件 9 の 3 つの grep/存在チェック（`longrun-orchestrator` 参照ゼロ・`update-checkpoint.sh` 不存在・`mode=mvp` 参照ゼロ）を機械検証可能な形で定義する
- `longrun-docs-restructure`: README の版履歴切り出し（CHANGELOG.md 新設）・plugin.json description 圧縮・exec.md checkpoint.md 節の任意メモ格下げという、ドキュメント/メタ情報の構成整理を扱う
- `longrun-test-suite-alignment`: 上記 2 capability によって無効化される既存 bats アサーション（シムの存在を前提にしたテスト・ハードコードされたバージョン番号）を新仕様に追随させる

## Impact

- `plugins/longrun/agents/longrun-verifier.md`（:37-39, :98 相当の書き換え）
- `plugins/longrun/agents/longrun-browser-verifier.md`（:101-103, :151, :187 相当の書き換え）
- `plugins/longrun/agents/longrun-builder.md`（description 修正）
- `plugins/longrun/scripts/update-checkpoint.sh`（削除）
- `plugins/longrun/skills/longrun-plan/SKILL.md`（GATE ブロック削除）
- `plugins/longrun/commands/plan.md` / `plugins/longrun/commands/mvp.md`（無変更を確認）
- `plugins/lr/commands/p.md`（移行案内説明の削除）
- `plugins/longrun/README.md`（版履歴削除、CHANGELOG 誘導追加、`--mode=mvp` deprecation サブセクション削除）
- `plugins/longrun/CHANGELOG.md`（新規）
- `plugins/longrun/.claude-plugin/plugin.json` / `plugins/lr/.claude-plugin/plugin.json`（description 圧縮、version bump）
- `plugins/longrun/commands/exec.md`（:9 の historical 注記、:262-271 相当の checkpoint.md 節）
- `plugins/longrun/tests/mvp-plan-split.bats` / `plugins/longrun/tests/release-and-readme.bats` / `plugins/longrun/tests/legacy-removal.bats`（新仕様への更新）
- 影響なし・変更しない: `workflow-runs.jsonl` 記録形式、`resumeFromRunId` 再開フロー、schemas/*.schema.json、`templates/workflow/*.js`、`.claude-plugin/marketplace.json`（change-7 が同期）
- 依存: change-2（longrun-browser-verify-restore）マージ後に着手（`exec.md` / `README.md` / `plugin.json` の同時編集コンフリクト回避のための直列化。論理的依存はない）
