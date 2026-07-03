# Design: longrun-v5-cleanup

## Context

`plugins/longrun/` は plan.md 付録 C に列挙された 7 件の findings を持つ（`_longruns/2026-07-03_plugin-review-fixes/plan.md` 付録 C 参照）。本 change はそれらを 3 capability に整理して実装する。前提となるベースは change-2（longrun-browser-verify-restore）マージ後の状態（`exec.md` / `README.md` / `plugin.json` が browser-verifier 復帰・workflow-tool-reference.md 移動を反映済み）。

現状確認済みの事実（builder は再調査不要）:
- `grep -rn "update-checkpoint.sh" plugins/` の呼び出し元はスクリプト自身のコメントのみ。hooks.json からの参照もゼロ（dead code 確定）
- `grep -rn "longrun-orchestrator" plugins/` は現状 8 箇所ヒットする内訳: README.md 版履歴内 3 箇所（:32,:37,:69。CHANGELOG.md へ移設対象）、`commands/exec.md:9`（historical 注記、書き換え対象）、`tests/backlog-cleanup.bats:18-19` / `tests/exec-workflow.bats:25-26,108` / `tests/legacy-removal.bats:83`（既存テスト自身の検索パターン。後述 D2 で対応方針を定義）
- `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/` は現状 30+ 箇所ヒットする内訳: README.md（版履歴内 + 現行 MVP セクション内の deprecation サブセクション）、`skills/longrun-plan/SKILL.md` の GATE ブロック、`plugins/lr/commands/p.md:11`、`tests/mvp-plan-split.bats` / `tests/legacy-removal.bats`（既存テスト自身の検索パターン）。`commands/plan.md` と `commands/mvp.md` は現状ヒットゼロ（付録 C finding 3 が挙げる 5 ファイルのうちこの 2 つは既に無変更で条件を満たしている）

## Goals / Non-Goals

**Goals:**
- 受け入れ条件 9 の 3 チェック（`longrun-orchestrator` 参照ゼロ / `update-checkpoint.sh` 不存在 / `mode=mvp` 参照ゼロ）を、既存の正当な用途（regression テストの自己参照パターン）を破壊せずに達成する
- README の版履歴を CHANGELOG.md に分離し、現行版ドキュメントの可読性を回復する
- plugin.json description を 1〜2 文に圧縮する
- checkpoint.md の位置づけを「任意の人間向けメモ」に統一する。`workflow-runs.jsonl` / `resumeFromRunId` フローは一切変更しない
- 影響を受ける既存 bats（`mvp-plan-split.bats` / `release-and-readme.bats` / `legacy-removal.bats`）を削除せず、検証意図を保ったまま新仕様のアサーションに更新する

**Non-Goals:**
- Verify フェーズ・Build Contract・4 軸評価ロジック自体の変更（残骸除去は記述レベルの修正のみ）
- `schemas/*.schema.json` / `templates/workflow/*.js` の変更
- `marketplace.json` の同期（version・description とも change-7 が担当。本 change は `plugins/longrun/.claude-plugin/plugin.json` と `plugins/lr/.claude-plugin/plugin.json` のみ編集する）
- `exec-workflow.bats` / `exec-step0.bats` / `verify-loop.bats` の変更（調査の結果、checkpoint.md 節の書き換え後も両ファイルの既存アサーションは通り続けることを確認済み。詳細は D5）

## Decisions

### D1: 受け入れ条件 9 の「`longrun-orchestrator` 参照ゼロ」はテスト自己参照とCHANGELOG履歴記述を除いた scoped zero とする

**問題**: 受け入れ条件 9 は `grep -rn "longrun-orchestrator" plugins/` の 0 件を要求する。しかし `plugins/longrun/tests/*.bats` には「`longrun-orchestrator` という文字列が存在しないことを検証する」既存テストが複数あり、検証対象の文字列自体をテストコード内に持たざるを得ない（grep で探す対象は必然的にソースへ literal に埋め込まれる）。この制約はテストコードを削除しない限り解消できない一方、config.yaml rule は「既存 bats テストは削除でなく新仕様に更新する」と明記しており、削除は選択肢にない。

**採用**: 以下の 2 点を確定方針とする。
1. **プロダクション文書（README.md 現行部・CHANGELOG.md・agents/*.md・commands/*.md・skills/*.md）からは `longrun-orchestrator` という複合語を一切使わない。** 歴史的経緯を書く必要がある箇所（CHANGELOG.md の v6.0 エントリ等）は「旧 orchestrator スキル」のように `longrun-` 接頭辞を分離した言い回しで書く（本プラグイン自体の文脈が明らかなので情報は失われない）。これにより CHANGELOG.md への carve-out は不要になる
2. **テストファイル（`tests/*.bats`）内の検索パターンとしての `longrun-orchestrator` literal は許容する。** これは受け入れ条件が意図する「生きた誤誘導参照」ではなく、その不在を保証する regression test の実装詳細である
3. 本 change が実行する検証コマンドは `grep -rn "longrun-orchestrator" plugins/ | grep -v '/tests/'` とし、結果が空であることを確認する（`tests/test-suite-alignment` capability の task で bats 化する）。素の `grep -rn "longrun-orchestrator" plugins/`（`/tests/` 除外なし）は非ゼロのまま残ることを decisions.md に明記し、reviewer に承認を仰ぐ

**代替案**: テストファイル自体を `plugins/` の外（例: リポジトリ直下 `tests/`）に移動する —却下。bats の慣例配置（`plugins/<name>/tests/`）を崩す大規模な構成変更になり、本 change のスコープ（残骸掃除）を逸脱する

### D2: 受け入れ条件 9 の「`mode=mvp` 参照ゼロ」も同じ scoped zero ポリシーを適用する

D1 と同じ理由・同じ解法を `mode=mvp` にも適用する。README.md・CHANGELOG.md からは `--mode=mvp` / `mode=mvp` という文字列を完全に排除し、シムの歴史的経緯は「旧フラグ形式のモード切り替え」のような言い換えで記述する。`tests/mvp-plan-split.bats` の既存 residual テスト（`tests/mvp-plan-split.bats:396-406`）は既にこのパターン（自テストファイルを `grep -v` で除外）を採用済みであり、本 change はこの前例をそのまま新しい zero-tolerance 版に更新する（詳細は `longrun-test-suite-alignment` capability）。

検証コマンド: `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` が空であること。

### D3: exec.md:9 の historical 注記も書き換え対象に含める（付録 C finding 1 の明示リストにない追加スコープ）

付録 C finding 1 は `agents/longrun-verifier.md` / `agents/longrun-browser-verifier.md` / `agents/longrun-builder.md` の 3 ファイルのみを挙げるが、`commands/exec.md:9` の「v6.0.0 BREAKING: 旧 `longrun-orchestrator` SKILL.md の...」という一文も D1 の scoped-zero 達成に必須のため本 change のスコープに含める。内容は変えず、複合語 `longrun-orchestrator` を「旧 orchestrator スキル」に言い換えるのみ（情報の欠落なし、低リスク）。

### D4: `--mode=mvp` 完全撤去後のフォールバック挙動は「フラグを無視してフルモードを実行」

GATE ブロックを完全削除すると、`/longrun:plan --mode=mvp` を実行した場合の新しい挙動は「未知の引数として無視され、フルモードの Step 1〜8 がそのまま走る」になる（明示的なエラーや移行案内は出さない）。これは以前の「移行案内を出して終了」から後退した挙動だが、以下の理由で許容する:
- 受け入れ条件 9 が `mode=mvp` という文字列そのものの完全排除を要求しており、実行時チェック文字列を残す設計はどのみち採用できない
- v6.1 で 1 リリースサイクル分の移行案内は既に周知済み。marketplace はバージョン単位キャッシュのため恒久シムが不要という plan.md 自身の判断（付録 C finding 3 末尾）に沿う
- ユーザーは本 marketplace の唯一の開発・運用者であり、実害は限定的
- builder は GATE ブロックの直前に「なぜ削除するか」の 1 行コメントを残さない（コードコメントで由来を語らない一般ルールに従う）。事情は本 design.md と CHANGELOG.md に記録する

### D5: exec-workflow.bats / exec-step0.bats / verify-loop.bats は変更不要（確認済み）

`exec-step0.bats:54-56`（`grep -Eq 'checkpoint.md' "$EXEC_MD"` のみを検証）と `exec-workflow.bats:85-92`（`grep -Eq 'checkpoint.md を grep/sed|パースして制御フロー'` を検証）は、checkpoint.md を「任意の人間向けメモ」に格下げした後も exec.md がこれらのフレーズを保持し続ける限り無変更で通る。`verify-loop.bats:111` は comment 行のみで assertion 対象ではない。builder は checkpoint.md 節を書き換える際、「checkpoint.md を grep/sed でパースして制御フロー」という禁止文言（現 exec.md:243-244 相当）をそのまま残すこと。

### D6: version bump は `plugins/longrun/.claude-plugin/plugin.json` と `plugins/lr/.claude-plugin/plugin.json` のみ。数値は change-2 到達後の値からの straightforward minor bump とする

具体的な数値（例: 6.2.0 → 6.3.0）は change-2 が着地させた baseline に依存するため本 design では固定しない。builder は着手時点の `jq -r .version plugins/longrun/.claude-plugin/plugin.json` を読み、minor（3 桁目）を 1 つ上げた値を longrun・lr 両方に適用する（lr も `commands/p.md` を編集するため version bump 対象。lr の内容変更が p.md の 1 文削除のみであっても plugin-editing.md の「変更内容に応じてバージョンを上げる」原則に従い bump する）。`marketplace.json` は編集しない（change-7 が同期。D0 = plan.md 本文の依存関係節に明記済み）。

## Open Questions

なし（付録 C の 7 findings と受け入れ条件 9 の間の解釈上の緊張は D1・D2・D3 で解消済み）。
