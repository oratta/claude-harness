# Decisions — anthropic-knowledge-reflect run

## D-E1: 全 change を単一 worktree（この cwd）で直列実施

- 日付: 2026-07-05
- 背景: cwd 自体が専用 worktree（branch `oratta/anthropic論文をハーネスに反映`、Draft PR #9 バックアップ済み）。change 依存は 1 → {2,3} → 4 → 5 の直列支配的な DAG。
- 判断: change ごとの worktree 分割はせず、全 builder がこのブランチに順次コミットする。CHANGES_JSON の worktree は全 change で cwd を指す。
- 理由: (1) build-verify workflow は 1 起動内で直列に builder を回すため、change 間依存（後続が前段の成果物の上に建つ）は同一ブランチが自然。(2) Draft PR #9 への逐次 push で CLAUDE.md のバックアップ運用を満たす。(3) マージ操作（要明示承認）を run 中に挟まなくて済む。

## D-E2: モデル割り当ての単一値への縮約（テンプレート制約）

- 日付: 2026-07-05
- 背景: plan.md の割り当て表は change × ロールの 15 セル（builder: change-2/3/5=sonnet, change-1/4=inherit。verifier: change-1/4=sonnet, change-2/3/5=haiku。reviewer: 全て inherit）。一方 v6 の build-verify テンプレートはロール毎に 1 つの `*_MODEL` 埋め込みポイントしか持たない（exec.md D6: 本 change ではデフォルト固定）。
- 判断:
  - `BUILDER_MODEL = null`（inherit）— plan が「安全設計が critical」とする change-1/4 の要求に全体を合わせる（安全性 > コスト最適化）。
  - `VERIFIER_MODEL = 'sonnet'` — Verify ループは run 全体の検証であり、sonnet を要求する change-1/4 を含むため要求中の最上位ティアを採用。
  - `BROWSER_VERIFIER_MODEL = null` — 割り当て表に行が無いため render の既定値（inherit）。
  - `REVIEWER_MODEL = null` — 表の全行が inherit。
- 理由: plan.md の意思決定ガイドライン「安全性 > 忠実さ > シンプルさ」。ティア縮約はコスト面の劣化のみで品質面の劣化はない（下位ティア指定 change を上位で実行する方向の縮約）。
- 備考: change 毎の `opts.model` 粒度対応はテンプレート側の将来課題（openspec/backlog.md 行き）。

## D-1a: State 規約は独立 references 文書に置く（recipe-format には同梱しない）

- 日付: 2026-07-05 / change: loops-plugin
- 背景: spec（loops-state-convention）は「規約は `references/recipe-format.md` または独立した references 文書のいずれかに記載」と選択肢を許容。
- 選択肢: (A) recipe-format.md に同梱 / (B) 独立 `references/state-convention.md` / (C) templates 側に規約も書く。
- 判断: (B) 独立文書 `plugins/loops/references/state-convention.md`。
- 理由: 関心の分離（レシピ形式と State は別概念で、参照する主体も異なる: State は change-4 のプロアクティブ/長期ループが参照）。YAGNI に反しない範囲で、recipe-format.md の肥大化を防ぎ、change-4 からの単一責務参照を可能にする。可逆（後で統合も分割も容易）。

## D-1b: /loops:design・/loops:goalify は commands ではなく skills として登録

- 日付: 2026-07-05 / change: loops-plugin
- 背景: plugin.json に skills[] と commands[] の両方を書ける。他プラグイン（daily-report）は commands + skills 併用。
- 選択肢: (A) skills のみ / (B) commands + skills 併用 / (C) commands のみ。
- 判断: (A) skills のみ（`skills/loops-design`・`skills/loops-goalify`）。
- 理由: proposal.md の Impact が列挙する新規ファイルは SKILL.md のみで commands/*.md は含まない（YAGNI: 最小構成に忠実）。スキルは自然言語トリガー（description）で起動でき、MVP スコープでは commands ラッパーは不要。反復利用で `/loops:xxx` の明示コマンドが欲しくなれば後付け可能（可逆）。

## D-1c: 設計/goalify デモは plugins/loops/recipes ではなく longrun demos/ に出力

- 日付: 2026-07-05 / change: loops-plugin
- 背景: recipes/ ディレクトリと正式レシピ集は change-3 スコープ。change-1 のデモで recipes/*.md を作ると change-3 の器と混線する。
- 判断: デモ生成物（recipe / goal ブリーフ / brain dump）は `_longruns/2026-07-04_anthropic-knowledge-reflect/demos/` に `*.demo.md` として置く。
- 理由: 受け入れ条件 5.2/5.3 は「ログを {longrun-dir} に残す」ことを要求。change 間のスコープ汚染を避け（plugins/loops/ には正式成果物のみ）、demo は longrun 配下に隔離。

## D-2a: 対象スキルは必須 7 件のみ。追加 5 件は全て対象外 + 理由記録（change: skill-verification）

- 日付: 2026-07-05 / change: skill-verification
- 背景: `plugins/*/skills/*/SKILL.md` は 12 件。受け入れ条件 8 は最低 7 件を対象と規定。残り 5 件（longrun-feedback / longrun-mvp-plan / loops-design / loops-goalify / skill-pack）の扱いを決める必要がある。
- 選択肢: (A) 5 件も対象化して検証節を追加 / (B) 7 件のみ対象、5 件は理由付き対象外。
- 判断: (B)。5 件は self-verification.md の「対象スキル一覧」に対象外 + 理由で記録。loops-design/loops-goalify は「既に検証ステップ/機械検証可能な成功基準が本文に明示」、longrun-feedback は「分類・振り分けロジックで独立成果物なし」、longrun-mvp-plan は「subagent レビュー + 人間ハンドオフが本文に組込済」、skill-pack は「設定編集のみで反映確認は Claude Code に委譲」。
- 理由: plan は 7 件を下限として固定し、それ以外は監査判断に委ねる。YAGNI + 可逆（後から対象化可能）+ 「追加は検証節のみ・既存本文不変」の不変条件を守るため、対象を最小化。全 5 件に honest な対象外理由があり S41 を満たす。

## D-2b: S39 のため loops-design SKILL.md の中核原則引用を参照に置換（change: skill-verification）

- 日付: 2026-07-05 / change: skill-verification
- 背景: change-1 で作った loops-design/SKILL.md 行 20 に「完了は主張であり証明ではない」の literal が既存。S39（中核原則文言は SKILL.md に 0 件、reference のみ）に抵触。
- 選択肢: (A) loops-design を放置し S39 を緩める / (B) 行 20 を reference 参照 + 言い換えに置換。
- 判断: (B)。「完了の宣言には evidence…の提示を伴わせる（`plugins/loops/references/self-verification.md`）」に書き換え、literal を除去。
- 理由: S39 は全 SKILL.md 対象の dedup 要件。原則本文は self-verification.md 1 箇所に集約する設計（D2）と整合。意味は保持し literal のみ除去する最小変更。loops-design は 7 対象外だが phrase-dedup は全ファイルに適用されるため正当。

## change-3 (goal-time-recipes) 実装時の判断

### D-GT1: cron レシピの「スケジューラ登録手順が無い」検証方法
- **文脈**: spec S70 は「特定のスケジューラ（セッション内 cron / launchd / `claude -p` 配線等）への登録手順が含まれていない」ことを要求。一方でレシピは責務分離を説明するため、これらのスケジューラ名を「スコープ外の例」として言及する必要がある。
- **選択肢**:
  1. レシピからスケジューラ名の言及を全て削除し、テストは名前の grep 0 件を要求 → Pros: テスト単純。Cons: plan/spec が使う具体名（launchd 等）を落とし情報量が減る。責務分離の説明が弱くなる。
  2. レシピは名前を「スコープ外の例」として残し、テストは実際の登録コマンド構文（`crontab -e`・`launchctl`・`.plist`）の 0 件を要求 → Pros: spec の意図「登録"手順"が無い」に忠実。名指しでスコープ外だと明示でき責務分離が伝わる。Cons: テストの denylist 設計が必要。
  3. セクション単位で判定 → Cons: 過剰。YAGNI。
- **決定**: 選択肢 2 を採用。spec の THEN は「登録手順が含まれていない」であり、名前の言及ではなく手順（実コマンド）の不在を検証するのが正しい解釈。加えて S70 は別途「スコープ外」「呼び出し側の責務」の明記も要求しており、名前をスコープ外の文脈で挙げることはむしろ整合的。
- **可逆性**: テストとレシピ文言の変更のみで可逆。

### D-GT2: bats @test 名は ASCII のみにする
- **文脈**: `@test` の説明文に日本語（ゴールベース/タイムベース/前提）を含めると bats がテスト関数名の解決に失敗し「Executed N instead of expected M」警告で一部テストが実行されない事象が発生。
- **決定**: `@test` の説明文は ASCII のみとし、日本語の意味はコメント行に書く。本文（grep 対象）の日本語は問題ないため維持。
- **可逆性**: 命名変更のみで可逆。

## change-4 (proactive-routines) 実装時の判断

### D-PR1: S88（long-build 起動コマンドの model ID 不在）検証で claude-progress.md の誤検出を回避
- **文脈**: routine-long-build は外部状態ファイル `claude-progress.md` を正当に参照する。既存 recipes-seed.bats の model ID 検出正規表現 `claude-[a-z0-9]` は `claude-progress` に誤マッチする。
- **選択肢**: (A) 状態ファイル名を変える（harnesses 論文の慣用名を捨てる）/ (B) テスト側の正規表現を実モデル ID 形（`claude-(opus|sonnet|haiku|[0-9])`）に精緻化。
- **決定**: (B)。harnesses 論文由来の `claude-progress.md` は変えず、テストの意図（モデル ID 直書き禁止）を保ったまま誤検出のみ除去する最小変更。
- **可逆性**: テスト正規表現のみで可逆。

### D-PR2: backlog-triage デモは処理数上限 1 件のサンドボックス方式
- **文脈**: design.md Open Questions / Risks の通り、実 backlog に対して実 Draft PR を量産すると意図しない PR が残る。
- **決定**: 実 backlog.md を discovery 入力に使いつつ、Draft PR はドライラン相当物で評価し非破壊制約の遵守を確認（受け入れ条件 10 を満たす）。design D5 の「スキル起動非依存の手動規約検査」も適用。

### D-PR3: recipe-miner デモは実ログ解析の結果「提案なし」で正常終了
- **文脈**: `~/.claude/projects/` の直近 7 日 jsonl を jq で圧縮集計（生ログをメインに載せない）。抽出候補は既存レシピ（backlog-triage / cron-*・goal-tests-green）でカバー済み or 実測データ不足だった。
- **決定**: spec の「候補ゼロ＝提案なしの正常終了」は正常系。新規性のある提案が無い場合に無理に提案を作らず、繰り越し候補を state に記録して正常終了とした（報酬ハッキング＝無理な提案生成の回避）。

## D-5a: version bump のベースラインは origin/main HEAD ではなく merge-base

- 日付: 2026-07-05 / change: loops-integration
- 背景: 実装時点で origin/main が本 run と無関係な PR #10（longrun ノンストップ実行）で先行しており、`longrun 6.4.0 / marketplace 2.10.0` へ進んでいた。本 run の分岐点（merge-base `cb9f2f0`）は `longrun 6.3.0 / marketplace 2.9.0`。design.md D7 は「`git diff origin/main` で変更プラグインを確定」としていたが、origin/main の先行差分（PR #10 の longrun 大量ファイル変更）が混入し「本 run が変更したプラグイン」を正しく判定できない。
- 選択肢: (A) origin/main HEAD を基準（spec 文言どおり） / (B) merge-base を基準 / (C) 目視で本 run の変更を列挙。
- 判断: (B) `git merge-base HEAD origin/main` を「main 時点」の基準とする。統合テストの bump 検証・変更プラグイン列挙は merge-base に対して行う。version パリティ（plugin.json == marketplace.json）は基準非依存の恒久検証として別途実装。
- 理由: D7 の意図は「本 run が実変更したプラグインだけを bump する（無関係な変更で無意味な bump をしない）」。merge-base は本ブランチが main を離れた点であり、この意図に正確に一致する。origin/main HEAD は無関係な先行差分を含むため誤判定する。可逆（マージ時に人間が最終 version を再調整する前提）。
- 波及: 本 run が変更したプラグイン = daily-report / experience-to-skill / infra / longrun / weekly-report / worktree（+ 新規 loops）。各を merge-base 版から patch/minor bump し marketplace.json と同期。longrun は origin/main の 6.4.0 とは別系統（本 run は自己検証節の追記のみ）のため 6.3.1（patch）とし、マージ時の version 再調整は人間の責務（本 change のスコープ外）とする。

## D-5b: 統合 bats のハードコード version 検証は本 run の bump に追随して更新する

- 日付: 2026-07-05 / change: loops-integration
- 背景: 既存テスト（longrun legacy-removal.bats / mvp-plan-split.bats / release-and-readme.bats、worktree setup-script.bats）が plugin.json version を文字列ハードコードで検証していた。本 change の bump によりこれらが FAIL する。
- 判断: design.md D6（FAIL は成果物側を最小修正、spec は緩めない）に従い、ハードコードされた期待 version 値を本 run の新 version に更新する（検証の意図＝「plugin.json が期待 version である」は維持し、期待値のみ追随）。SKILL.md frontmatter の version（6.2.0 等）は本 run で変更しないため据え置く。
- 理由: version 検証の意味を保ったまま bump と整合させる最小修正。テスト自体の削除・緩和はしない。

## D-5c: S48（additive-only）は frontmatter version 行を除外する

- 日付: 2026-07-05 / change: loops-integration
- 背景: infra プラグインの既存テスト S29 は「SKILL.md frontmatter version == plugin.json version」を強制する。change-5 が infra plugin.json を 0.3.0→0.3.1 に bump するため、S29 を保つには infra SKILL.md の frontmatter `version:` も 0.3.1 に上げる必要がある。しかし change-2 のテスト S48（additive-only: merge-base に対し削除行 0）は、この version 行の変更を「削除行」として誤検知し FAIL する。S29・S48・S131（bump 必須）が infra について同時成立しない。
- 選択肢: (A) infra を bump しない（S131 違反） / (B) plugin.json だけ bump し SKILL 据え置き（S29 違反） / (C) 両方 bump し S48 を version 行除外に精緻化。
- 判断: (C)。S48 の削除行カウントから frontmatter `version:` 行を除外（`grep -vE '^-version:'`）。
- 理由: S48 の文書化された意図は「change-2 の編集は『## 自己検証』節の追加のみで、スキルロジックの削除・書き換えをしない」こと。リリースメタデータの version bump は change-5 の正当な責務であり change-2 のロジック削除ではない。S48 は累積 diff を測るため両者を区別できない。version 行のみ除外することで S48 の本来の保証（スキルロジック追加のみ）を維持しつつ、必須の version bump と両立させる。スキルロジック行の削除・書き換えは引き続き 0 件を強制する。
