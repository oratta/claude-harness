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

## change-2 (workflow-exec) Build フェーズ

### D-C2-1: Workflow テンプレートを 2 本に分割（review / build-verify）

- **日時**: 2026-06-12（change-2 TDD 実装）
- **コンテキスト**: D5（承認ゲートで workflow 分割）の実装形。1 本の workflow 内で AskUserQuestion 不可。
- **選択肢**: A: 1 本のテンプレートに全フェーズ（承認待ちを擬似化）/ B: review.workflow.js + build-verify.workflow.js の 2 本に分割し、Build Contract 承認はメインループ（exec.md）で挟む / C: フェーズ数だけ細分化（review/build/verify を 3 本）
- **決定**: B。plan.md / design.md D5 に明記済み（可逆性より plan 準拠を優先）。Build と Verify は承認ゲートを挟まないため 1 本に同居（build-verify）。Feedback Tier 確認は build-verify 完了後にメインループで実施。
- **理由**: ツール制約（workflow 内 AskUserQuestion 不可）に対する design 確定解。C は分割境界が増えるが承認ゲートは 1 箇所（Build Contract）のみなので過剰。runId 記録は workflow 起動ごと（2 行）で済む。
- **エビデンス**: `plugins/longrun/templates/workflow/{review,build-verify}.workflow.js`。bats `workflow-template.bats` 20 本 PASS。

### D-C2-2: 埋め込みプレースホルダを `${NAME}` ではなく `__NAME__` 形式にする

- **日時**: 2026-06-12
- **コンテキスト**: テンプレート充填の置換構文。当初 `${NAME}` を採用したが、生成スクリプトは JS であり `${round}` 等の**ランタイム テンプレートリテラル補間**を含む。`${VERIFY_MAX_ROUNDS}`（上限到達ログの補間）が全大文字のため、置換正規表現 `\$\{[A-Z_]+\}` が誤マッチして renderer がエラーになった（実測: `missing param for placeholder ${VERIFY_MAX_ROUNDS}`）。
- **選択肢**: A: `${NAME}` のまま、定数名を小文字化して衝突回避 / B: 置換構文を `__NAME__` に変える / C: 置換を JSON 注入ポイントだけに限定し本文補間を全て関数化
- **決定**: B（`__NAME__`）。renderer 正規表現 `__([A-Z][A-Z0-9_]*)__`。JS のランタイム `${...}` 補間と構文的に完全分離できる。
- **理由**: A は「上限がコードの条件式に現れる」可読性（D3）を損なう（定数を小文字化すると意図が薄れる）。C は過剰。B は可逆・最小・衝突ゼロ。reference §7（Date.now 不可）由来の args.timestamp 注入とも干渉しない。
- **エビデンス**: `scripts/render-workflow.mjs`。`workflow-template.bats` の「no leftover __NAME__ placeholders」「rendered passes node --check」PASS。

### D-C2-3: schema 検証層の機構拒否を最小バリレータ（validate-against-schema.mjs）で機械検証する

- **日時**: 2026-06-12（タスク 5.5）
- **コンテキスト**: 受け入れ条件 8a / spec「不正形式の成果物が機構的に拒否される」。Workflow ツールの `opts.schema` 強制は実走が必要だが、builder（サブエージェント）は Workflow を起動できない。bats で「不適合 fixture が拒否される」を機械検証する手段が要る。
- **選択肢**: A: ajv を devDependency に追加して厳密検証 / B: 外部依存なしの最小 draft-07 バリレータを自作（type/enum/required/additionalProperties:false/min/max/pattern/items）/ C: bats 内で jq 式を個別に書いて各制約を手検証
- **決定**: B。`scripts/validate-against-schema.mjs`（外部依存なし、Date.now/Math.random 不使用）。valid fixture は exit 0、invalid（enum 違反 / 余剰プロパティ / 必須欠落 / 範囲外 / verdict enum 違反 / severity enum 違反）は exit 1。
- **理由**: A はこのリポジトリ（プラグイン markdown 主体・npm 依存を持たない）に node_modules を持ち込む。C は schema とロジックが二重管理でドリフトする。B は schema を唯一ソースにしたまま実動作検証でき、ノードのみで完結（既存 bats も node 前提なし→ node は volta で利用可）。本バリレータは Workflow ツールの検証層の**同等物**であり、実走時の真の検証はツールが行う旨をスクリプト冒頭に明記。
- **エビデンス**: `schema-rejection.bats` 11 本 PASS（valid 3 受理 / invalid 7 拒否 + validator 存在）。

### D-C2-4: 縮退モードの spec 自己完結生成ロジックを exec.md 付録へ移管（orchestrator 解体に伴う保全）

- **日時**: 2026-06-12
- **コンテキスト**: change-1 が直前にマージされ、orchestrator SKILL.md に「縮退モード分岐」（specs/<change>/proposal.md + tasks.md 自己完結生成、verification-guide 生成、openspec/ 書き込み禁止 GATE）が追記されていた。change-2 は orchestrator を解体するため、この分岐の行き先が必要。
- **選択肢**: A: 縮退分岐を捨てる（change-1 の機能後退）/ B: exec.md 末尾の付録セクションへ逐語移管 / C: 別スキル新設
- **決定**: B。exec.md「付録: 縮退モードの spec 類自己完結生成（change-1 から移管）」に GATE・生成パス・テンプレート参照を保全。
- **理由**: A は change-1 の回帰（不可）。C は「スキル層を不要にする」D1 と矛盾。B は exec が縮退マーカーを見て分岐する既存設計（Step 0b）と整合し、orchestrator 由来のテスト（`degraded-artifacts.bats` の 4 本）を exec.md 参照に貼り替えるだけで保全できる。
- **エビデンス**: `degraded-artifacts.bats`（ORCH_MD → DEGRADED_MD=exec.md に貼り替え）13 本 PASS。

### D-C2-5: marketplace top-level version は 2.6.0 → 2.7.0 に bump

- **日時**: 2026-06-12（タスク 5.1）
- **コンテキスト**: tasks 5.1 は「2 箇所同期（plugin.json + marketplace plugins[]）」を必須とし、top-level の bump 要否は「別途判断」とする。change-1 が既に 2.5.1 → 2.6.0 に上げていた。
- **選択肢**: A: top-level 据え置き（2.6.0）/ B: 2.7.0 に bump
- **決定**: B（2.7.0）。
- **理由**: longrun・lr とも v6.0.0 BREAKING を含む新リリースであり、過去に「3 箇所同期漏れ事故」（PR #5）があった運用方針に沿って top-level も上げる方が一貫する。既存 bats（`> 2.5.1` を要求）も満たす。可逆（PR 未マージならクローズで戻せる）。
- **エビデンス**: `release-and-readme.bats`「marketplace top-level bumped above 2.5.1」PASS。jq 構文 OK。

## change-3: mvp-plan-split

### D-3-1: Gap Analysis / Interview 方法論は references に切り出し、longrun-plan 本文は温存

- **日時**: 2026-06-12
- **コンテキスト**: design.md Open Questions「方法論の切り出し vs 複製」の実装時判断。spec は option (a) 共有reference / (b) インライン複製 + divergence防止コメント の両方を許容。task 3.3 は「git diff でフルモード Step 1〜8 に差分なし」を要求。
- **選択肢**:
  - A: `plugins/longrun/references/plan-interview-methodology.md` を新設、両スキルから Read
  - B: 新 SKILL.md にインライン複製 + divergence 防止コメント
  - C: 純 option (a)（longrun-plan の Step 3/4 も reference 参照に置換）
- **決定**: A をベースに、longrun-plan 本文は温存（reference は新スキルのみが Read）。C は不採用。
- **理由**: reference 切り出しの方が将来の single-source 化に繋がる。C は task 3.3 のフルモード本文 no-diff ガードと衝突するため却下（config 制約「移動と分離のみ・フルモード挙動不変」を最優先）。reference 冒頭に divergence 防止コメント（longrun-plan Step 3/4 と同期せよ）を置く。新スキルは references を Read するのみで `skills/longrun-plan/SKILL.md` を実行時 Read しない（S25 充足）。
- **可逆性**: reference ファイルは追加のみ。longrun-plan 側無変更なので regression 面で安全。

### D-3-2: /lr:m は p.md と同じ Skill tool 直接委譲パターン（Read 経由にしない）

- **日時**: 2026-06-12
- **コンテキスト**: lr プラグインの短縮コマンドは 2 系統ある。p.md/f.md は Skill tool 直接委譲、e.md/a.md は commands/*.md を Read してインライン実行。
- **決定**: m.md は p.md と同じ Skill tool 直接委譲（`longrun:longrun-mvp-plan` を $ARGUMENTS 付きで起動、Agent tool 禁止明記）。
- **理由**: tasks 2.3 が「既存 p.md と同じ Skill tool 委譲パターン」を明示。mvp は Skill であり、Skill tool で直接呼べる（e/a はコマンド= Skill tool で呼べないため Read 経由だった）。
- **可逆性**: 新規ファイル追加のみ。

### D-3-3: marketplace top-level は 2.7.0 → 2.8.0 に bump

- **日時**: 2026-06-12
- **コンテキスト**: spec「Marketplace top-level bump」は本 change 適用前の値より厳密に大きいことを要求。change-2 が 2.7.0 まで上げている。
- **決定**: 2.8.0 に bump。
- **理由**: longrun/lr とも 6.1.0 の新リリースを含むため top-level も上げる（過去の同期漏れ事故対策の運用方針に沿う）。可逆。

---

## change-4: model-allocation の自律判断

### D-4-1: exec のモデル割り当て消費を専用スクリプト resolve-model-allocation.mjs に切り出す

- **日時**: 2026-06-12
- **コンテキスト**: tasks 4.x は exec が plan.md のモデル割り当て表を読んで opts.model を反映する処理を求めるが、exec.md は散文の control-plane であり、生成 workflow スクリプトのレンダリングは render-workflow.mjs の決定論的スクリプトに集約されている（change-2 の設計）。tasks 4.4 は「生成 workflow スクリプトの opts.model 有無・値」を fixture 5 系で機械検証することを要求しており、純散文の手順記述だけでは静的検証できない。
- **選択肢**:
  - A: exec.md に手順を散文で書くのみ（テストは grep で文言確認）
  - B: パース＋ティア解決を `scripts/resolve-model-allocation.mjs` に実装し、render-workflow.mjs に MODEL_OVERRIDES を渡す経路を作る。exec.md はこのスクリプトを呼ぶ手順を記述
  - C: render-workflow.mjs 自体に plan.md パースを埋め込む
- **決定**: B。`scripts/resolve-model-allocation.mjs`（plan.md + model-tiers.md → `{change, role, tier, model|null, warnings[]}` の JSON を出力）を新設。テンプレートには `opts.model` を条件付きで出力できる構造（agent 呼び出しに model キーを動的付与する仕組み）を追加し、render が解決結果を埋める。
- **理由**: change-2 が確立した「決定論的レンダリング＋bats 静的検証」のパターンに揃える（fixture 5 系の opts.model 有無を node/grep で検証可能）。C は render-workflow.mjs の単一責務（プレースホルダ置換）を壊し、change-2 の既存 20 本テストの前提と衝突する。D5 fail-soft の警告も B なら stderr/JSON で機械検証できる。
- **可逆性**: 新規スクリプト追加 + テンプレートへの非破壊的追加（inherit 時は従来どおり model キー無し = 現行挙動）。6.1.0 へ戻しても害なし。

### D-4-2: テンプレートのモデル注入は per-role の MODEL_* プレースホルダ + スプレッド方式

- **日時**: 2026-06-12
- **コンテキスト**: build-verify テンプレートは builder/verifier、review テンプレートは reviewer の agent() 呼び出しを持つ。inherit はキー自体を省略する必要がある（D2）。JS で「条件付きでキーを含める」には `...(model ? {model} : {})` のスプレッドが最も簡潔。
- **選択肢**:
  - A: テンプレートに `__BUILDER_MODEL_OPT__` 等の「opts 断片文字列」を埋め込む（inherit 時は空文字）
  - B: `...__BUILDER_MODEL_SPREAD__` のスプレッドで、render が `model: 'sonnet',` か空を埋める
  - C: model 値を変数として埋め、`...(BUILDER_MODEL ? {model: BUILDER_MODEL} : {})` をテンプレ側に固定で書く
- **決定**: C。テンプレートに `const builderModel = __BUILDER_MODEL__;` を置き（render が `'sonnet'` または `null` を埋める）、agent opts で `...(builderModel ? { model: builderModel } : {})` をテンプレ固定コードにする。
- **理由**: C はテンプレートが常に node --check を通る正当な JS のままで、inherit（null 埋め）でも sonnet（'sonnet' 埋め）でも構文が壊れない。スプレッド条件式がテンプレに固定されるので「inherit はキー省略」(D2) がコードの構造で保証され、bats で `model:` の有無を生成結果に対して検証できる。A は空文字断片が node --check を壊すリスク、B は render 側ロジックが増える。
- **可逆性**: テンプレ追加行のみ。__*_MODEL__ に null を渡せば現行と同一出力。

### D-4-3: opts.model の渡し値はエイリアス（'haiku' / 'sonnet'）を採用

- **日時**: 2026-06-12
- **コンテキスト**: model-tiers.md のティア→ID 解決値を確定する必要。workflow-tool-reference.md §3 line 44 は `model: 'haiku'` を実機検証済み、`'sonnet' | 'opus'` も同じ機構（組み込みドキュメント由来）と明記。
- **選択肢**: (a) フルモデル ID（claude-...）/ (b) エイリアス（'haiku'/'sonnet'）
- **決定**: (b) エイリアス。haiku→`'haiku'`、sonnet→`'sonnet'`、inherit→キー省略（null）。
- **理由**: reference の実機検証値がエイリアス。エイリアスは世代交代に追従するため model-tiers.md の更新すら不要になりやすい（D3 のドリフト排除をさらに強化）。フルID が必要と判明しても model-tiers.md 1 行変更で吸収できる（D3）。config.yaml rule「モデル ID のハードコード散在禁止」にも合致（そもそも ID を書かない）。
- **可逆性**: model-tiers.md の解決値 1 箇所変更で切替可能。

### D-4-4: version bump で change-3 の version-pin テストを 6.2.0 へ更新、lr は据え置き、mvp-plan SKILL.md も 6.2.0 に揃える

- **日時**: 2026-06-12
- **コンテキスト**: change-4 で longrun を 6.1.0 → 6.2.0 に bump する。change-3 が追加した mvp-plan-split.bats に「longrun version=6.1.0」「plan/mvp-plan SKILL.md とも 6.1.0」「lr version=6.1.0」を pin するテストがあり、bump で 3 本が落ちる。
- **選択肢**:
  - A: longrun のみ 6.2.0、mvp-plan SKILL.md は 6.1.0 据え置き、change-3 テストを「plan=6.2.0 / mvp-plan=6.1.0」に分離
  - B: longrun plugin に属する SKILL.md は両方 6.2.0 に揃える（mvp-plan も bump）。lr は instruction どおり据え置き
  - C: lr も 6.2.0 に上げる
- **決定**: B。longrun の plugin.json / marketplace longrun エントリ / 両 SKILL.md frontmatter を 6.2.0 に揃える。lr は「変更なし」の instruction どおり 6.1.0 据え置き。change-3 テストの pin 値を更新。
- **理由**: SKILL.md frontmatter version は marketplace キャッシュ無効化のためにプラグイン version と揃える運用（過去 commit の慣行）。同一プラグイン内で plan=6.2.0 / mvp-plan=6.1.0 が混在すると、どちらが新リリースか不明瞭になりキャッシュ事故の温床。mvp-plan の内容は変えないが version だけ揃えるのは既存の bump 慣行（例: v5.2 で SKILL.md のみ bump）と整合。lr 据え置きは instruction の明示指示。C は instruction 違反。
- **可逆性**: version 数値変更のみ。テストの pin 値更新も可逆。
