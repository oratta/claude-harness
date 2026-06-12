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

## change-1 (openspec-degradation) Build フェーズ

### D-C1-1: 実機検証で `openspec apply` 不在を確定、通常モードの apply 置換は本 change スコープ外

- **日時**: 2026-06-12（タスク 1.1）
- **コンテキスト**: orchestrator/builder の従来手順は `openspec apply <change>` 前提。実機検証で apply の有無と longrun-tdd スキーマの出所を確定する必要があった。
- **エビデンス**: `/tmp/openspec-init-probe` での実コマンド出力（`plugins/longrun/docs/openspec-cli-verification.md` セクション 2-4）。
  - `openspec init --tools claude` → `openspec/{changes,changes/archive,specs}` のみ生成、`schemas/` は作られない
  - `openspec schema fork spec-driven longrun-tdd` で初めて `longrun-tdd` が生成（init の成果物ではない）
  - 1.2.0・0.23.0 とも `apply` サブコマンド不在（root help にフォールスルー）。代替は `instructions tasks`
- **選択肢**: A: 本 change で通常モードの apply→instructions 置換も行う / B: 縮退モードのみ実装し、apply 置換は change-2 に委ねる
- **決定**: B
- **理由**: 本 change の制約は「通常モードの従来挙動を変えない（回帰なし）」。apply 置換は通常モードフローの書き換えであり回帰リスクがある。change-2 が exec を全面書き換えするのでそこで扱うのが適切（YAGNI / 可逆性）。縮退モードは CLI を一切呼ばないため apply 不在の影響を受けず、本 change 単独で完結できる。
- **リスク**: 通常モードで `openspec apply` を叩く既存手順が現 CLI で失敗する点は残るが、これは本 change 以前から存在する既知の問題であり change-2 で解消される。docs に明記済み。

### D-C1-2: preflight 検出は「command -v OR npx --no-install」の OR 条件

- **日時**: 2026-06-12（タスク 1.2）
- **コンテキスト**: design.md 暫定決定は「npx openspec 解決可能を正」。実機では volta グローバル 1.2.0（`which` で解決）と npx キャッシュ 0.23.0（`npx --no-install` で解決）が併存。
- **選択肢**: A: `npx` のみで判定 / B: `which`/`command -v` のみ / C: 両方の OR
- **決定**: C（`command -v openspec` OR `npx --no-install openspec`）。両方失敗で `NO_CLI`。
- **理由**: plan.md 受け入れ条件 5 は「npx openspec が解決できない環境で」と書くが、グローバル openspec が PATH にある環境（この環境）を「CLI 不可」と誤判定すると回帰になる。OR にすれば「いずれかで openspec が解決できれば通常モード可」となり実態に合う。`--no-install` でネットワーク/インストール待ちを避け純粋な解決可否のみ判定。検出系列はスクリプト 1 箇所に集約。
- **リスク**: なし（OR で広く拾うため誤って縮退に倒れることはない）。確定値は `openspec-cli-verification.md` に一本化。

## change-5 実装フェーズ（harvest-structured-output / marketing-harness）

### D-5.1: tasks 1.1 — 散文契約依存 bats の確定（書き換え対象 12 本）

- **日時**: 2026-06-12（TDD 実装開始時）
- **エビデンス**:
  ```
  $ bats plugins/harvest/tests/*.bats --count
  313
  $ grep -lE 'STATUS:|BEGIN_RAW_JSON|...|Status: (APPROVE|REQUEST_CHANGES)|Fact-check Findings|TOS Risk Findings|5 セクション|セクション固定' plugins/harvest/tests/*.bats
  bestprac_evaluator_agent.bats
  bestprac_researcher_agent.bats
  ```
- **コンテキスト**: design.md の事前概観（evaluator 8-10 / researcher 3-5 / refresh_flow 5-8 本推定）を実 @test 単位で確定する必要があった。
- **選択肢**: A: 推定どおり refresh_flow も書き換える / B: grep 実測ヒットの 2 ファイルのみに絞る / C: 全 63 本を機械的に再生成
- **決定**: B。grep ヒットは evaluator / researcher の 2 ファイルのみ。refresh_flow.bats は SKILL.md 側の契約消費記述を grep するが `Status:` リテラル / 5 セクション位置パースに直接依存する @test は無く、新 SKILL.md（`.status`/`validate-contract.sh evaluator` 参照）でも既存 32 本が全 PASS する設計。確定書き換えは evaluator 7 本 + researcher 5 本 = **12 本**。
- **理由**: 一覧外に触れない原則（design D8 / Risks）。refresh_flow を不必要に書き換えると過剰書き換えリスク。
- **リスク**: refresh_flow の S4.x が新 SKILL.md で PASS しなくなる可能性 → 6.2 のフルスイート実行で機械的に確認。

### D-5.2: redact フォールバック時の raw 残置と Step 0 クリーンアップの両立

- **日時**: 2026-06-12
- **コンテキスト**: spec（masking-atomicity）は「redact 失敗時に raw を手動調査用に残す現行例外を維持」しつつ「翌回起動時には残らない（受け入れ条件 18）」を要求する。
- **選択肢**: A: redact 失敗時に即削除 / B: 当該 run は残置、次回 run の Step 0 が削除（design D6）/ C: 別パス退避
- **決定**: B（design D6 を踏襲）。当該 run の redact 失敗時は `.property.raw.json` を残してパス報告、次回起動時の Step 0 クリーンアップが `.property.raw.json` / `.property.json` / `.property.md.tmp` を検出 → ユーザー通知 → 削除。
- **理由**: plan.md / design.md に明記済み。保守的（調査用残置の現行 UX を壊さない）。
- **リスク**: 正当な調査中ファイルを次回 run が消す → 削除前ユーザー通知を必須化（spec 準拠）。

### D-5.3: Step 0 残骸クリーンアップを knowledge-cleanup.sh ヘルパに切り出す

- **日時**: 2026-06-12（タスク 4.4 / 4.6）
- **コンテキスト**: 受け入れ条件 18「いかなる失敗パスでも翌回起動時に .property.raw.json が残らない」を bats で機械検証する必要があるが、クリーンアップロジックが SKILL.md 散文のみだとシミュレーション bats が「散文 grep」止まりになり、実際の削除動作を検証できない。
- **選択肢**: A: SKILL.md 散文に手順を書くだけ（grep 検査のみ）/ B: `scripts/knowledge-cleanup.sh` ヘルパに切り出し、SKILL.md Step 0 がそれを呼ぶ形にして bats で実動作検証 / C: bats 内に削除ロジックを複製
- **決定**: B。`plugins/harvest/scripts/knowledge-cleanup.sh <knowledge_dir>` を新設。`.property.raw.json` / `.property.json` / `.property.md.tmp` を検出 → 検出ファイル名を stdout に通知 → 削除。SKILL.md Step 0 がこれを呼ぶ。
- **理由**: 受け入れ条件 18 を「3 失敗パス × fixture で raw 残置 → cleanup 実行 → 不在」の実動作 bats で検証できる（C の複製はドリフトする）。ヘルパ化は redact-secrets.sh / bestprac-refresh.sh と同じ既存パターン（スクリプトに副作用を閉じ込め SKILL.md は手続き記述）。可逆（revert で SKILL.md 散文に戻せる）。
- **リスク**: スクリプト追加で表面積が増えるが、テスト容易性の利得が上回る。削除対象は引数 dir 配下のドットファイル 3 種に限定し誤削除を防ぐ。
