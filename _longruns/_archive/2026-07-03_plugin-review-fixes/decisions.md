# Decisions: plugin-review-fixes

## D-exec-1: 単一 worktree + 単一 Draft PR 方式（2026-07-03, exec）
全 7 change は同一リポジトリ（marketplace dir）対象で、生成 workflow の Build ループは直列実行。
change 間依存（2→3、5→6、{1,3,4,6}→7）も直列順序 1..7 で自然に満たされるため、
worktree を change ごとに分けず `~/.superset/worktrees/plugin-review-fixes`（branch
`longrun/plugin-review-fixes`）1 本に集約する。CLAUDE.md の Draft PR バックアップ運用は
この 1 branch に対して適用する。change-7 の marketplace.json 最終同期も同一 branch 上で
競合なく実行できる。

## D-exec-2: モデル割り当ての消費方法（2026-07-03, exec）
`resolve-model-allocation.mjs` の解決結果（warnings 0 件）を反映。ただしテンプレの
埋め込みポイントはロール単位グローバル（`__BUILDER_MODEL__` 等が 1 個）で、plan.md の
表は change × ロール単位のため、以下のとおり消費した:

- **reviewer**: 全 change inherit → `REVIEWER_MODEL = null`（表どおり）
- **builder（Build ループ）**: 生成後スクリプトに `builderModelByChange` マップ
  （change-1/3/5/6 = 'sonnet'、change-2/4/7 = null）を追記し、change ごとに表どおり適用
- **builder（Verify 修正ループ）**: change 横断の修正依頼のため表の単一行に対応しない
  → 安全側の inherit（null）
- **verifier**: Verify ループは run 全体を毎周検証するグローバル呼び出しで、change 別
  ティア（haiku ×6 / sonnet ×1）を機構的に適用できない → 安全側の inherit（null）。
  haiku へ寄せると change-2 の schema/agent 整合確認（sonnet 指定）が降格するため採らない

エイリアス文字列のみ使用（モデル ID 直書きなし。GATE 遵守）。編集後 `node --check` PASS。

## D-change2-1: schema 4 軸分担は「1 schema の部分返却」（候補1）を採用（2026-07-03, builder change-2）
design.md D2 は候補1（`verifier-score.schema.json` 単一のまま `required` を verdict のみへ緩和し、
各 verifier が自分の 2 軸 + verdict を返す。workflow が 2 返却をマージして 4 軸を合成）と
候補2（static/browser の 2 schema へ分割）を提示し、最終判断を builder に委ねていた。
以下の理由で **候補1** を採用した:
- **単一ソース維持**: 4 軸の定義・しきい値が `verifier-score.schema.json` 1 本に残り、
  「schema は外部ファイルを唯一のソースとする」GATE と一覧性を最もクリーンに保てる（design.md でも 推奨寄り）
- **YAGNI / シンプルさ**: schema ファイルを増やさず、既存 `__VERIFIER_SCHEMA__` 埋め込みポイントを
  両 verifier で共用できる。テンプレの埋め込みポイント追加が最小
- **可逆性**: `required` の緩和のみで、旧成果物（archive）が参照する `verifier-score.schema.json` の
  名前・プロパティ定義は不変。将来 2 分割へ移行する余地も残る
- **軸欠落の担保**: 「どの軸が欠けているか」は schema では強制されないが、静的/ブラウザ各 agent の
  担当宣言（verifier.md=quality/completeness、browser-verifier.md=functionality/ux）と
  workflow のプロンプト・マージロジックで担保する（design.md 候補1 の既知トレードオフを許容）
`required` は `["verdict"]` へ緩和し、4 軸の property 定義・しきい値 description（functionality=100 /
quality=100 / completeness=80 / ux=70）はそのまま保持。総合 verdict = 静的 verdict ∧ ブラウザ verdict。

## D-exec-3: OpenSpec spec 生成のタイミング（2026-07-03, exec）
通常モード。Review（Build Contract）承認後、Build workflow 起動前に exec が change ごとの
OpenSpec change（proposal/tasks/spec、longrun-tdd schema 準拠）と verification-guide.md を
生成する（旧 orchestrator の「Build 前半で生成」を exec 側で踏襲）。

## D-change1-1: infra plugin.json / SKILL.md のバージョンは 0.3.0 へ bump（2026-07-03, builder change-1）
design.md D7 は「plugin.json の bump 後の値と SKILL.md frontmatter を一致させる」とのみ規定し、具体的な
bump 幅は builder 判断に委ねられていた（tasks.md 6.1「内容量に応じて bump」）。本 change は Phase 2/4/5
の複数エージェントに機能追加（service_role key 取得・投入）とバグ修正（.env.production.local 方式統一・
secrets 一致・Actions バージョン）を含み、後方非互換の破壊的変更ではないため semver minor bump
（0.2.0 → 0.3.0）を採用した（YAGNI: patch では変更量を過小評価、major は破壊的変更向けで該当しない）。
marketplace.json への同期は change-7 の責務（plan.md 付録 F）のため本 change では行わない。

## D-change1-2: infra plugin に bats テストを新規追加（2026-07-03, builder change-1）
plan.md はテストフレームワークとして bats-core（既存: longrun/daily-report/experience-to-skill）+
grep ベースの参照ゼロ検証を指定しているが、`plugins/infra/` には既存の `*.bats` が無かった
（tasks.md 7.3 は「無ければ skip」を許容）。TDD ルール（テストファースト・RED→GREEN）を厳守するため、
「skip」ではなく `plugins/infra/tests/infra-fixes.bats` を新規作成し、31 Scenario（S1-S31）すべてを
grep/awk ベースのアサーションとして先に実装（RED: 現状ファイルに対して 26/31 件が失敗することを確認済み）
してから本文修正を行い、全 31 件 PASS（GREEN）に到達した。Actions バージョンの YAML パース検証は
python3+pyyaml が本環境に無く、Ruby 標準の `YAML` ライブラリが利用可能だったため `ruby -ryaml` を採用
（design.md が例示した python3 実装は代替手段として明記されており可逆的な選択）。

## D-change3-1: longrun-orchestrator / mode=mvp の scoped-zero 残存確認（2026-07-03, builder change-3）
design.md D1/D2（longrun-v5-cleanup）で定義された scoped-zero ポリシーに従い、本 change 完了後の
状態を確認した。

- `grep -rn "longrun-orchestrator" plugins/`（unscoped、plan.md 受け入れ条件 9 の文字どおりの表現）は
  **依然として非ゼロ**。ヒットは全て `plugins/longrun/tests/*.bats`（`backlog-cleanup.bats` /
  `legacy-removal.bats` / `exec-workflow.bats` / `orphan-cleanup.bats`）の自己参照検索パターン
  （「この文字列が存在しないこと」を検証する regression test 自身のソース）に限定される。
- `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/`（unscoped）も同様に非ゼロで、ヒットは全て
  `plugins/longrun/tests/{mvp-plan-split,legacy-removal,orphan-cleanup,docs-restructure}.bats` の
  自己参照検索パターンに限定される。
- config.yaml rule「既存 bats テストは削除でなく新仕様に更新する」により、これらのテストファイル自体を
  削除して文字通りのゼロを達成する選択肢は採らない（テストの検証意図＝「この文字列が生きた参照として
  存在しないこと」を保つ実装詳細として、検索パターン literal はテストコード内に残る）。
- 実際に本 change が達成した検証コマンドは scoped 版:
  `grep -rln "longrun-orchestrator" plugins/ | grep -v '/tests/'` → 空
  `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` → 空
  （`plugins/longrun/tests/orphan-cleanup.bats` の該当テストで機械検証済み。「動作確認完了」はこの
  scoped-zero 達成をもって満たしたと判断する。unscoped-zero を求めるなら対象テストの削除が必要になり
  config.yaml rule と衝突するため、本 change ではこの縮退を意図的な最終状態として採用する）。
- 同じ理由で `update-checkpoint.sh`（S9, 受け入れ条件本文は unscoped `grep -rn "update-checkpoint.sh" plugins/`
  を要求）についても、本 change が新規追加した regression test（`orphan-cleanup.bats`）自身がファイル名を
  検索パターンとして埋め込むため、同一の scoped-zero ポリシー（`| grep -v '/tests/'`）を適用した。

## D-change3-2: longrun-orphan-cleanup / longrun-docs-restructure 用に新規 bats を追加（2026-07-03, builder change-3）
openspec/changes/longrun-v5-cleanup/tasks.md セクション 8 は既存 3 ファイル（mvp-plan-split.bats /
release-and-readme.bats / legacy-removal.bats）の更新のみを明示し、`longrun-orphan-cleanup` /
`longrun-docs-restructure` capability 向けの新規 bats 作成は明示指定していなかった。しかし harness の
TDD ルール（spec Scenario から失敗するテストを先に書く）と、両 spec ファイルが定義する Scenario 群
（S1-S9, S16-S17, S19-S28 相当）を機械検証可能にするため、`plugins/longrun/tests/orphan-cleanup.bats`
（12 tests）と `plugins/longrun/tests/docs-restructure.bats`（15 tests）を新規追加した。既存 bats の
「削除しない」ポリシーには抵触しない（新規追加のみ）。

## D-change3-3: bash 3.2 の `!` 否定 + errexit 相互作用バグへの対応（2026-07-03, builder change-3）
macOS のデフォルト `/bin/bash`（3.2.57、bats-core が `env bash` で解決する実行シェル）には、1 つの
テスト本体内で bare `! command` を複数回使うと、2 個目以降の否定コマンドの失敗が errexit
相当のテスト失敗として伝播しない既知の挙動がある（`! grep -q X; ! grep -q Y` の 2 行構成で、1 行目が
本来 FAIL すべき条件でも bats が `ok` と誤判定するケースを実機で確認・再現した）。新規追加した
`orphan-cleanup.bats` / `docs-restructure.bats` はこのリスクを避けるため、否定アサーションを
`run command; [ "$status" -ne 0 ]` 形式に統一した。既存ファイル（`mvp-plan-split.bats` 等）に元々
存在した複数 `!` パターンはそのまま残置している（既存ファイルの再現条件がすべて「真の negative」で
現状 PASS しており、本 change のスコープ外の regression リスクとして許容。将来別 change でこのシェル差異
に起因する false-positive が発覚した場合は同様に `run` 方式へ移行すること）。

## D-change4-1: bats @test タイトルは ASCII のみ（2026-07-03, builder change-4）
plugins/worktree/tests/ を新設。macOS の bats-core 1.13.0（`env bash` 3.2 実行）は @test
タイトルに日本語（マルチバイト）を含むと `bats: unknown test name` で当該テストを実行できない実機挙動を
確認。したがって「検証A/B/C」等を含めたいテストはタイトルを `kensho A/B/C` 等の ASCII に置換し、
grep パターン本体（日本語）は @test ボディ内に置いた。否定アサーションは decisions.md D-change3-3 に従い
`run <cmd>; [ "$status" -ne 0 ]` 形式で統一（bash 3.2 の bare `!` + errexit false-positive 回避）。

## D-change4-2: ラッパーは SKILL.md を Read（Skill tool は使わない）— lr/commands/e.md 方式（2026-07-03, builder change-4）
design.md D2 に従い、wt-clean / wt-setup の両 command を「`CLAUDE_PLUGIN_ROOT` 起点で SKILL.md の
絶対パスを特定 → Read tool でインライン実行」する薄いラッパーに置換。フォールバックは e.md と同一の 3 段
（`${CLAUDE_PLUGIN_ROOT}/skills/<name>` → marketplace/*/plugins/worktree/skills/<name> →
installed/*/worktree/skills/<name>）。bash 実機で CLAUDE_PLUGIN_ROOT 有/無の双方で SKILL.md 解決を
確認済み（zsh 実行では未マッチ glob がエラーになるが、command の ```bash ブロックは bash 実行前提のため
影響なし。e.md も同一パターンで運用実績あり）。安全性クリティカル記述（squash 検出 A/B/C・AskUserQuestion
別ターン絶対禁則）は SKILL.md にのみ残し command には要約もコピーしない（D3）。受け入れ条件 10 を
grep で構造的に満たすことを bats（command-wrapper.bats / skill-safety.bats）で検証。

## D-change4-3: wt-setup.sh は現状維持 + コメント明文化に倒す（付録 D-3, 2026-07-03, builder change-4）
design.md D4 の通り、`find -path "./$pattern"` グロブ（直下 1 階層のみ一致で既定パターンと整合）と
`settings.local.json` symlink（同一マシン・同一ユーザーの権限共有として望ましい）はいずれも実挙動確認の上
「現状維持 + 意図コメント追記」に倒した（意思決定ガイドライン「曖昧なら現状維持 + 文書化」準拠）。
`bash -n` 構文検証 PASS。plugin.json version は 2.1.1 → 2.2.0 に bump（marketplace.json 同期は
change-7 が担当、本 change は marketplace.json に触れない）。

## D-change5-1: 週次 native jsonl の project マッピングは source_path → `~/.claude/projects/` エンコードパスの直接変換（2026-07-03, builder change-5）
design.md D1 は「SKILL.md 本文への jq インライン記述」まで決定していたが、週次集計で各プロジェクトの
セッション jsonl をどう特定するかの具体パターンは未確定だった。Claude Code は cwd の `/` を `-` に
置換したディレクトリ名で `~/.claude/projects/<encoded>/` にセッション jsonl を保存する規約があるため、
レジストリの `source_path` を同じ規則（`sed 's#/#-#g'`）で変換して直接ディレクトリを特定する方式を採用
した（daily-report の `llm-log-compactor` は全プロジェクト横断で 1 日分を集計する設計のため、この
per-project 変換ロジックは持っていない＝週次側で新規に導出）。候補として「全 `~/.claude/projects/`
を舐めて cwd フィールドと突き合わせる」方式もあったが、jsonl 本文を Read/jq で開かないと cwd が
分からず summary 抽出と同じ 1 パスで済まないため、パス変換方式（O(1) ディレクトリ特定）を採用した。
`project_dir` が存在しない、または `jq` 不在の場合は当該プロジェクトの LLM セッションサブセクションを
省略するフェイルソフトとし、週次エラーハンドリング表に明記した。

## D-change5-2: 非対話モード節の判断ログは既存出力（週次ノート／diary.md）内の callout / blockquote に埋め込む（2026-07-03, builder change-5）
design.md D4 は「生成物本体に判断ログを埋め込む」までを決定していたが、weekly-report / daily-report で
書式が異なるため、各プラグインの既存の記法慣習に合わせて具体化した: weekly-report は「## 今週の実績
サマリ（自動生成）」冒頭に `> 判断ログ: ...` の blockquote 行、daily-report は diary.md の
frontmatter 直後・「## ひとことで」の前に `> [!info] 判断ログ` callout（既存の `> [!warning]` /
`> [!todo]` callout 記法と統一）を追加する方式とした。対話実行時（デフォルト値を使わなかった場合）は
この行/callout を一切出力しないことで、既存 Scenario の出力フォーマットに影響を与えない
（design.md Risks 節の懸念に対応）。

## D-change5-3: weekly-report/tests を daily-report/tests パターンで新設し、`report-noninteractive-mode` の共通 Scenario は両プラグインの tests に分割配置（2026-07-03, builder change-5）
spec の `report-noninteractive-mode` capability は S13/S14/S15 を daily/weekly 共通の Scenario として
1 本の spec ファイルに定義しているが、実装は別々の SKILL.md（daily-report / weekly-report）に分かれる
ため、bats テストも各プラグインの `tests/noninteractive-mode.bats` にそれぞれ配置し、両方の SKILL.md
に対して S13/S14/S15 相当のアサーションを重複実装した（1 spec = 2 実装ファイル = 2 テストファイルの
1:2:2 対応。daily-report 側の allowed-tools 検査で bats-core 1.13.0（bash 3.2 exec）が @test タイトルに
全角括弧を含む文字列を含めると `unknown test name` になる実機不具合を踏襲確認したため、decisions.md
D-change4-1 と同じ方針で @test タイトルを ASCII のみに統一した）。

## D-change6-1: bats テスト・退避スクリプトの置き場所は `_longruns/2026-07-03_plugin-review-fixes/{scripts,tests}/`（`plugins/` 配下ではなく run ディレクトリ直下）（2026-07-03, builder change-6）
design.md / tasks.md は llm-log-relocation・plugin-retirement-cleanup・retirement-handoff-docs 3 capability
の bats テスト置き場所を明示していなかった（既存 6 changes は全て `plugins/<plugin>/tests/` に配置してきたが、
本 change は特定の1プラグインに属さないリポジトリルート横断の変更のため、その慣習をそのまま踏襲できない）。
3案を比較した:
1. **`plugins/` 配下に新設**（例: 適当な既存プラグインの tests/ に間借り） — 却下。所有権が不明瞭になり、
   `find plugins -name '*.bats'` の実行対象には乗るが、削除対象プラグインへの参照掃除テストが別プラグインの
   tests/ に居座るのは筋が悪い
2. **リポジトリルートに新規 `tests/` を作る** — 却下。他の6 changeが誰も確立していない新しい永続的な
   トップレベル規約を1 changeだけのために導入するのは YAGNI 違反（今後この規約に他 change が追随する保証がない）
3. **`_longruns/2026-07-03_plugin-review-fixes/{scripts,tests}/` に co-locate**（採用） — 本 change の本質は
   「run-scoped の一度きりの移行作業（LLM/ 退避 + 2 プラグイン削除 + 参照掃除）」であり、恒久的なプラグイン機能を
   何一つ新設しない。過去の run（`_longruns/2026-06-12_harness-workflow-overhaul/` 等）が最終的に git 履歴へ
   コミットされている前例に倣い、本 run 専用のテスト・スクリプトも run ディレクトリに co-locate するのが
   最もスコープに忠実で可逆的（将来 change-7 等が同種の作業をする際もこの前例を踏襲するかは都度判断でよい）
`evacuate-llm-log.sh` は `snapshot` / `execute` の2サブコマンドに分割し、fixture（`mktemp -d`）に対して
S1-S8 の8シナリオを機械テストしてから実リポジトリの `LLM/` に対して実行した（実 `LLM/` は auto-save.py hook の
稼働実績があるため、fixture 経由のテストのみが安全に繰り返し実行可能）。`post-merge-steps.md` は
`{longrun-dir}/post-merge-steps.md` の実体（本 run のオーケストレーション用ディレクトリ、
`~/.claude/plugins/marketplaces/oratta-claude-harness/_longruns/2026-07-03_plugin-review-fixes/`）に加えて、
worktree ブランチにコミットする成果物として worktree 側の同名パスにも同一内容を複製した
（plan.md/decisions.md/checkpoint.md/verification-guide.md は exec セッション側のみで運用する前例を踏襲しつつ、
post-merge-steps.md は spec が要求する change-6 自身のデリバラブルであるため worktree 側にも残す）。

## D-change6-2: `openspec/backlog.md` の Skill 命名規則リファクタリング節は全削除＋`longrun-orchestrator` 消化済みの1文を残す形に統一（2026-07-03, builder change-6）
design.md D6 は「全削除」または「単一行の解消済みノート」のいずれかを builder 判断に委ねていた。当初は
節全体（対象7スキル表・作業手順込み）を完全削除する方針で実装したところ、既存の regression test
（`plugins/longrun/tests/backlog-cleanup.bats` の `records that orchestrator was consumed by change-2`、
change-3 で追加済み）が RED になった。このテストは「`longrun-orchestrator` が change-2 で消化済みである」旨の
文言が backlog.md のどこかに残っていることを要求しており、`longrun-orchestrator` は本 change の対象7スキルの
リストには含まれない（命名規則リファクタリングの発端ではあるが、change-2 で別途消化済みとして扱われていた）。
config.yaml rule「既存 bats テストは削除でなく新仕様に更新する」に従い、テスト側を変更するのではなく
backlog.md 側に `longrun-orchestrator` の消化経緯を1文で残す（対象7スキル名は個別列挙しない総称表現のみ、
S15/S21 の禁止対象である9個の旧 Skill 名の文字列とは重複しない）ことで両立させた。

## D-change-7-1: OpenSpec 4 系統重複の解決 = 分岐 C（現状維持縮退）（2026-07-03, change-7 builder）

OpenSpec 4 系統（`.claude/skills/openspec-*` ×10 / `.claude/commands/opsx/` ×10 /
`.agents/skills/openspec-*` ×10 / `.agents/skills/source-command-opsx-*` ×10 = 計 40 ファイル）
の生成元を実機調査した結果、全て openspec CLI 1.2.0 の生成物と確定（frontmatter
`author: openspec` / `generatedBy: "1.2.0"` / `compatibility: Requires openspec CLI`、
`.claude` と `.agents` は byte 単位一致、source-command 系は「migrated source command」表記、
`openspec --version`=1.2.0）。tool 選択を保持する `openspec/config.yaml` は gitignore + 不在で、
削除後の再生成挙動を git-tracked に固定・制御できないため、config.yaml rule に従い **分岐 C
（削除せず現状維持 + 文書化）** を採用。将来の抑制手順（`openspec init --tools claude` で tool
集合を絞る等）を含む詳細根拠は `openspec/changes/repo-cleanup-final/decisions.md`（git-tracked）
の D7-1/D7-2 に記録。

## D-change-7-2: docs/ 削除に伴う change-6 テスト追随（2026-07-03, change-7 builder）

change-7 が `docs/cooking-mvp-mode-plan.md` を削除し `docs/` ディレクトリが消滅したため、
change-6 の `plugin-retirement-cleanup.bats` S14（`grep ... plugins/ README.md docs/`）が
存在しないパスを走査してエラーになった。テスト意図（廃止プラグイン名の生存参照ゼロ）を保ち、
実在パスのみ走査するよう `[ -d docs ] && targets+=(docs/)` で更新（テスト削除でなく新構造への追随）。

## D-change-7-3: marketplace.json 最終同期（2026-07-03, change-7 builder）

8 プラグイン（infra/longrun/lr/worktree/daily-report/weekly-report/skill-pack/experience-to-skill）
の marketplace.json エントリの version・description を各 plugin.json（正）と完全一致させた。
skill-pack 0.1.0→0.2.0、experience-to-skill 0.2.0→0.3.0 を本 change で bump。廃止 2 プラグインの
エントリには一切触れていない（change-6 の責務）。受け入れ条件 5-16 の統合検証は全 PASS。
