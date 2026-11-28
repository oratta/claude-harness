# Design
## Context
固定 HEAD: `93543270038cdf040edb6cd9d3a8b4b41a540ae4`。記録先 [#1856](https://github.com/oratta/claude-harness/issues/1856)。[主の返事](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236709345) と [追加比較案](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236716735) に従う。仕様化は試行 2。実行指定は `--profile codex-standard --account-home current=/Users/oratta/.codex` を維持する。動機は proposal.md。
## Goals / Non-Goals
共有手順・入口・品質条件を一つに保ち、操作の意味と本体ごとの実行方法を分離する。#1850/#1855/#1857、実行係数・上限・予算値の変更は対象外。以下は実装計画であり、実消費・実機成功・仕様レビュー承認の主張ではない。
## Decisions
### 固定 HEAD の数え方
`git ls-tree -r --name-only <HEAD>` で `skills/develop/**/*.md`（roles を含む）と `skills/pr-review-gate/stages/**/*.md`、`templates/escalation-tripwires.md`、`commands/develop.md` を列挙する。以下のパスはすべて `plugins/dev-workflow/` 相対。追加は `references/codex-develop.md`、生成依頼へ取り込まれる `agents/decider.md`、`scripts/codex-develop.py`、`hooks/hooks.json` とそこに登録された 15 個の script。合計 87 パスを固定する。
各語は下表の正規表現で非重複出現数を数える。同じ行の異なる語は別出現、書換行は行番号の和集合。raw はファイル全体、本文は frontmatter を除く Markdown（コード例を含む）と emitted instruction だけ。hook の payload キー・matcher・イベント名・コメント・実装の環境変数参照は実行構文であり、本文として書き換えない。`allowed-tools` と hooks.json の機械配線も維持する。
script の本文判定範囲: session-tripwires:113-114,144-153、agent-model-guard:108-111,119-122,130-134、subagent-stop-guard:58-65、team-mode-warning:16（hookEventName を除く二つの本文）、unattended-ask-guard:34、codex-develop.py:689-721。残りは全文検索と転送元を確認し、この語集合の本文出現なし。動的 root の展開結果・template の転送は実装時に render fixture でも検査し、検索のみで出力検査の合格にしない。
|略号・語（regex）|raw|本文（X/Y の書換候補）|
|---|---:|---:|
|t1 `Agent` (`\bAgent\b`)|28|20|
|t2 `subagent_type` (`subagent_type`)|58|52|
|t3 `SendMessage` (`SendMessage`)|43|40|
|t4 `AskUserQuestion` (`AskUserQuestion`)|28|23|
|t5 `isolation:` (`isolation\s*:`)|5|5|
|t6 `TaskStop` (`TaskStop`)|5|3|
|t7 `run_in_background` (`run_in_background`)|9|8|
|t8 `~/.claude/projects` (`~\/\.claude\/projects`)|2|2|
|t9 `/wt-setup` (`/wt-setup`)|3|3|
|t10 `CLAUDE_PLUGIN_ROOT` (`CLAUDE_PLUGIN_ROOT`)|49|15|
|t11 `Monitor` (`\bMonitor\b`)|6|6|
|t12 `WorktreeCreate` (`WorktreeCreate`)|3|3|
|t13 `SessionStart` (`SessionStart`)|22|7|
|t14 `UserPromptSubmit` (`UserPromptSubmit`)|12|1|
|t15 `.claude/settings.local.json` (`\.claude/settings\.local\.json`)|4|4|
|t16 `The Claude coordinator` (`The Claude coordinator`)|1|1|
本文は 42 ファイル・193 出現・151 行。親の 8efd9a688e6a での 39 ファイル・156 箇所とは revision と範囲・語集合・機械構文の扱いが異なる。比較の分母には混ぜない。
|パス（上記接頭辞相対）|本文出現の内訳|書換行数 X/Y|
|---|---|---:|
|`agents/decider.md`|t1=1 t2=2|2|
|`commands/develop.md`|t4=5 t10=3|8|
|`references/codex-develop.md`|t1=5 t2=3 t3=7|5|
|`scripts/agent-model-guard.sh`|t1=1 t2=4|5|
|`scripts/codex-develop.py`|t1=1 t3=1 t16=1|2|
|`scripts/session-tripwires.sh`|t2=2 t3=2 t10=2|6|
|`scripts/subagent-stop-guard.sh`|t6=1 t7=1|2|
|`scripts/team-mode-warning.sh`|t2=2|1|
|`scripts/unattended-ask-guard.sh`|t4=2|1|
|`skills/develop/SKILL.md`|t1=1 t2=7 t3=8 t4=2 t5=2 t9=1 t10=1 t11=1 t12=2 t13=2|19|
|`skills/develop/references/channel.md`|t4=5|3|
|`skills/develop/references/child-background-wait.md`|t6=2 t7=1 t11=5|6|
|`skills/develop/references/decision-criteria.md`|t2=3 t3=4 t5=1 t8=1 t13=2|10|
|`skills/develop/references/epic-child-stop.md`|t4=2|1|
|`skills/develop/references/epic-loop.md`|t3=1 t7=2|3|
|`skills/develop/references/epic-merge-wait.md`|t2=1|1|
|`skills/develop/references/epic-subagent.md`|t5=1|1|
|`skills/develop/references/epic-worker-slots.md`|t3=1|1|
|`skills/develop/references/fix-check.md`|t2=1 t4=2|3|
|`skills/develop/references/gate-result.md`|t2=3|3|
|`skills/develop/references/handover.md`|t3=4|4|
|`skills/develop/references/light-path.md`|t9=1|1|
|`skills/develop/references/parent-merge-criteria.md`|t2=1|1|
|`skills/develop/references/pr-token-budget.md`|t1=1 t3=3|4|
|`skills/develop/references/pre-classification.md`|t1=1 t2=1|2|
|`skills/develop/references/reply-after-idle.md`|t8=1 t15=4|5|
|`skills/develop/references/roles/gate-runner.md`|t2=1 t7=1|2|
|`skills/develop/references/roles/screen-checker.md`|t2=1|1|
|`skills/develop/references/roles/spec-reviewer.md`|t1=2 t2=4 t4=1|5|
|`skills/develop/references/roles/worker.md`|t3=1|1|
|`skills/develop/references/roles/worker/common.md`|t2=2 t3=1 t4=1 t5=1 t9=1 t12=1 t13=1|4|
|`skills/develop/references/spec-decision.md`|t4=1|1|
|`skills/develop/references/worker-recovery.md`|t3=4 t10=1|2|
|`skills/pr-review-gate/stages/carryover-judge.md`|t1=1 t2=1|2|
|`skills/pr-review-gate/stages/no-point-check.md`|t1=1 t2=2|3|
|`skills/pr-review-gate/stages/pass.md`|t7=1|1|
|`skills/pr-review-gate/stages/prepare-reviewer.md`|t2=2|1|
|`skills/pr-review-gate/stages/prepare.md`|t10=2|2|
|`skills/pr-review-gate/stages/review-run.md`|t1=4 t2=3 t7=2|7|
|`skills/pr-review-gate/stages/triage-escalation.md`|t1=1 t2=4 t3=1|6|
|`skills/pr-review-gate/stages/triage.md`|t2=1 t3=1|1|
|`templates/escalation-tripwires.md`|t2=1 t3=1 t4=2 t10=6 t13=2 t14=1|12|
以下も固定対象（本文ヒット 0、書換候補 0）。新規ファイル検出では除外しない。
- `hooks/`: `hooks.json`
- `scripts/`: `context-tripwire.sh`, `develop-compact-reread.sh`, `epic-child-state.sh`, `git-destructive-guard.sh`, `git-guard-base-write-guard.sh`, `model-switch-recache-notice.sh`, `prompt-tripwires-refresh.sh`, `rm-permission-guard.sh`, `subagent-start-context.sh`, `unclear-reply-rephrase.sh`
- `skills/develop/references/`: `epic-delegation.md`, `epic-granularity.md`, `epic-keepalive-watch.md`, `epic-keepalive.md`, `epic-multirepo.md`, `epic-stop.md`, `epic.md`, `idle-compaction-observation.md`, `parent-pass-criteria.md`, `return-declaration.md`, `roles/worker/finish.md`, `roles/worker/implement.md`, `roles/worker/spec.md`, `token-thresholds.md`
- `skills/pr-review-gate/stages/`: `authenticity-conversation.md`, `authenticity-delegated.md`, `authenticity-relayed.md`, `authenticity.md`, `carryover.md`, `comment-parts.md`, `gate-triage-partitions.md`, `gate-triage.md`, `hold-categories.md`, `hold-resume.md`, `hold.md`, `issue-approved.md`, `pass-wording.md`, `prepare-light.md`, `prepare-partitions.md`, `reviewer-brief.md`, `triage-convergence.md`, `triage-epic.md`, `triage-nonblocking.md`, `triage-row3.md`
### 構造と数量の比較
X は各使用箇所で論理操作へ置き換え、局所の role/root/待機の束縛を残す。Y は中立台帳に操作の入出力・前提・停止・結果回収を集約し、使用箇所は操作名とその場固有の引数・判断条件だけにする。Z（親の追加案 B）は元本文を残し、Codex 側で道具名を読み替える。
|案|既存本文の書換候補（出現/行/ファイル）|全体 L|CLI exit|group|合計 S|unplaced|
|---|---|---:|---:|---:|---:|---|
|X|193 / 151 / 42|2,669|0|14|263,322,960|空|
|Y|193 / 151 / 42|2,591|0|14|260,995,440|空|
|Z|8 / 8 / 1（入口のみ。185出現/143行を残す）|1,147|0|4|86,706,480|空|
L は追加＋削除。本文は 1 行削除＋置換 1 行を基礎とし、台帳・対応・検査・仕様・変更記録も計上する。I=87 manifest+110 checker+80 tests+20 spec+10 record+20 registry/skeleton=327。M は X=240 provider+50 tests+20 spec+10 record=320、Y=80 ledger+140 provider+60 tests+20 spec+10 record=310。K/R/H/P/G は `2×書換行数 + (X:4,Y:2)×ヒットファイル数 +60 tests+20 spec+10 record`。これは将来 diff の見積もりで、実測 diff ではない。その他の内訳は各入力の estimate_source。
C は startup=30,000（新規 dispatch の依頼・role/common/spec/rules）、reserve=15,000、各 item の追加保持=20,000（新設・先行変更本文、fixture 出力・生成依頼・仕様と実機/回帰要約）、F は列挙した予定 shell 出力の `ceil(文字数×0.65)`。全文/行範囲/regex±2行（重複行併合）の識別と文字数を入力に残した。既存同一出力は group 内一度、異なる出力・group は再計上。C=65,000+F。Claude transcript の現在値や usage=0 は使わない。
上限は現環境で両 override 未設定、subagent-context.sh:174-196 / pr-token-budget.sh:244-264 → token_thresholds.py:50-91 の既定 150,000 / 30,000,000。[OWNER の開始記録](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7234027004) も 30M。計画上限 120,000 / 24,000,000、係数は `1799-v1-policy-0.8` のまま。`python3 plugins/dev-workflow/scripts/epic-granularity.py --input <mktemp-dir>/<案>.json` をリポジトリ外で実行した。
初回の hook 一括担当は exit 2、C=165,619、S=17,894,400、unplaced=[N-hook-text]。全文読取を捨てず、起動注入・拒否文の移行と、既存の他 hook 出力・権限 hook 出力の fixture 担当へ分けた。これは出力責務の分離であり、同じ担当の名目上の読取分割ではない。既存の検査条件や権限規則は変更しない。
入力 JSON 全文: [X](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236780554)、[Y](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236780830)、[Z](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236781106)、[配置不能だった初回](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236790361)。[CLI 出力全文](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7236788730)。
### 推す案 Y と操作の組み立て
Y を推す。初回の必須書換候補は X と同じであり、台帳化だけで 151 行を消せない。差は L=78（約2.9%）、S=2,327,520（約0.9%）で group 数は減らない。判断理由は、今後の変更を操作単位で一箇所に集め、局所の条件を保ったまま二つの実行方法のずれを検査できること。X は最小の局所編集だが再開や代理投稿の規約を各所で言い直す。Z は安いが、既知の Agent 呼出しを一行足すと表に既にある語なので通ってしまい、本文禁止条件も満たさない。出現単位の凍結を加えて負例だけ通しても本文に専用語が残る。条件を変えず採用できない。
配置: plugin 直下 `references/develop-operations.md` を中立台帳、`references/develop-providers/claude.md` と `codex.md` を対応 2 ファイルにする。develop と gate が読むため共通 references に置く。台帳の見出し `op:<id>` を一意な操作 ID とし、対応にも同じ ID を一回ずつ持たせる。本文の参照は `[op:<id>](<台帳>#op-<id>)`、未知・重複・片側欠落を失敗させる。品質判断・工程順は既存正本に残し、操作台帳に複製しない。
host（いまの本体）を入口で確定して対応を先に読む。role executor（resolver の返り値）とは別軸。単一 shell が host を推測して分岐する方式は採らない。対応は次の操作ごとの実行・結果・失敗のやり方だけを持ち、共通手順は host 別にコピーしない。
|操作 ID|Claude 本体用対応|Codex 本体用対応・境界|
|---|---|---|
|role-start / role-resume|canonical role→Agent種別、名前、model を束縛。再開前に resolver の tier/model と context を確認し SendMessage か fresh を選ぶ|Codex role は既存 foreground request/run と fresh phase。Claude role の起動・thread 再開は #1857 の提供契約へ接続、未提供なら理由付き停止。独立レビューと model 変更時の fresh 境界を維持|
|role-wait / role-stop|背景 task ID、前景回収、TaskStop と通知照合。名前付き役は同一ターンで待つ|利用できる foreground/thread の待機と取消を使う。元作業/実行/自己通知を区別し transport 完了を品質成功にしない。利用不能なら停止し偽の通知を作らない|
|owner-ask|interactive の AskUserQuestion、channel/unmanned は既存連絡正本に従う|host の質問手段で同じ問いを渡す。worker は return で本体へ返す。承認は実応答を必要とし、時間経過で代えない|
|workspace-prepare / idle-config|wt-setup、isolation worktree と既存 hooks、idleCompaction=false|本体が既存 worktree CLI のセットアップ相当を明示実行してから役へ渡す。存在しない hook を実行済みとしない。Claude 子の idle 設定を明示し、Codex 本体へ Claude 設定を擬装しない|
|context-refresh / plugin-root|SessionStart/UserPromptSubmit/compact の現行条件。CLAUDE_PLUGIN_ROOT 優先、既存探索順|入口・各 prompt/再開直前・compact 後に正本と残量を明示確認。インストールした skill の実体から root を解決し cwd や開発 clone を実行 root と取り違えない|
|usage-record / launch-account|Claude の現行ログと登録 account、印・上限を維持|Codex の実測 usage と固定 account-home、Claude 子はその起動結果の account を記録。本体 Codex を Claude active slot と見なさない。不明値を 0/別 account に補完しない|
|record-result|read-only の decider は本体代理、G 裁定の記録担当は既存正本|書込権限のある Codex writer は自分で投稿、read-only reviewer は本体へ返す。輸送成功と品質判定を分離|
`context-refresh` は Claude hook の判定ロジックを Codex 向けに複製しない。呼出しに必要な入力を同じスクリプト/正本へ渡し、host の会話を読めず計測できなければ測定不能で止まる。Codex の持つ容量を推測して現行計画 cap を上げない。
入口は `skills/develop/references/entry.md` に 5 分岐・PR の明示的な照会・引継ぎ優先・issueify を集約する。command と skill は同じ入口を読む。Codex の epic 検出は sub-issues/既存 route の証拠で行い、#1855 未導入なら子を起動する前に理由付き停止。通常の子 issue の実行は止めない。
Codex 公開は canonical skill directory へのリンクとし、手順コピーを作らない。`plugins/dev-workflow/scripts/link-codex-develop.sh --plugin-root P --skills-dir D` の明示先へ `develop` を結ぶ（実ファイル衝突は失敗）。repo の `.agents/skills` と利用者が指定した Codex の skills 先で発見を検証する。`scripts/sync.sh` は Claude の rules/style 配線であり Codex skill 配布と誤認しない。99件/25.6KB 相当の説明量でも `$develop` を明示起動できる実記録を求める。他 skill の削除や予算値変更はしない。
### 全 group の比較と分割案（レビュー後に本体が判断）
各セルは `C / S`。X/Y は同じ item→group 対応。F=C−65,000、L と出典は入力 JSON。すべて同一 repo、共有 manifest 更新を直列化し、下表の依存を持つ。Q/V はコード read-only で fixture/manifest のみ編集するため非聖域、G/N1/N2 は聖域かつ承認待ち singleton。
|group / item・範囲|依存 item|聖域|X C / S|Y C / S|
|---|---|---|---:|---:|
|G006 / I-inventory-guard（全対象・検査土台）|なし|なし|103,765 / 22,877,680|103,765 / 22,877,680|
|G008 / M-operation-mappings（台帳・本体別対応）|I-inventory-guard|なし|108,155 / 22,668,800|108,155 / 22,370,400|
|G007 / K-core（中核手順）|M-operation-mappings|なし|99,005 / 18,312,160|99,005 / 18,133,120|
|G013 / R-roles（役・判断）|K-core|なし|110,485 / 18,610,560|110,485 / 18,073,440|
|G005 / H-wait（待機・手渡し）|R-roles|なし|106,529 / 17,894,400|106,529 / 17,536,320|
|G011 / P-epic-wording（既存進行本文）|H-wait|なし|112,389 / 17,536,320|112,389 / 17,058,880|
|G004 / G-gate（ゲート本文）|P-epic-wording|あり|117,128 / 18,133,120|117,128 / 17,655,680|
|G012 / Q-other-hook-fixtures（他hook出力fixture）|G-gate|なし|102,606 / 16,402,400|102,606 / 16,402,400|
|G014 / V-permission-hook-fixtures（権限hook出力fixture）|Q-other-hook-fixtures|なし|114,015 / 16,402,400|114,015 / 16,402,400|
|G009 / N1-startup-text（起動注入文）|V-permission-hook-fixtures|あり|97,282 / 17,357,280|97,282 / 17,357,280|
|G010 / N2-guard-text（拒否理由文）|N1-startup-text|あり|95,526 / 17,536,320|95,526 / 17,536,320|
|G002 / E-worker-prompt（役への生成依頼）|N2-guard-text|なし|106,558 / 17,834,720|106,558 / 17,834,720|
|G001 / D-shared-entry（共通入口）|E-worker-prompt|なし|106,515 / 22,668,800|106,515 / 22,668,800|
|G003 / F-discovery-evidence（発見・回帰・実機証拠）|D-shared-entry|なし|112,536 / 19,088,000|112,536 / 19,088,000|
Z の参考 group C/S: G001 D-shared-entry: 106,515/22,668,800; G002 F-discovery-evidence: 112,536/19,088,000; G003 I-inventory-guard: 103,765/22,877,680; G004 M-operation-mappings: 108,155/22,072,000。AC不適合なので分割候補にはしない。
## Migration Plan
I で全対象を登録し未移行本文を固定 HEAD の hash で凍結、M で全操作と対応を揃える。以後の担当は担当ファイルを丸ごと移行済みにし、凍結解除と本文禁止・操作整合検査を一緒に切り替える。削除・対象外扱い・未移行への逆戻りで検査を避けられないよう負例を置く。最終 F は未移行ゼロを要求する。hook は実出力全分岐、生成依頼は全 phase と取り込み正本/hash を検査する。
各 group は担当回帰と `changes/<番号>.md` を持ち、文面 assertions を変えたテスト名・意味を記す。F は `scripts/test.sh` と `python3 -B plugins/dev-workflow/tests/test_codex_develop.py` の exit 0、本文へ Agent 呼出し追加/片側操作削除/対象外ファイル追加の非0、Claude の実機 1 件で Draft PR 作成とゲート通過の URL/HEAD/工程・exit/記録を #1856 へ集約する。実機で merge は要求しない。
この change は仕様比較の成果であり、全14groupの実装着手の許可ではない。独立 R1 のレビューを本体が手配し、採用後に分割を判断する。子 issue の作成・親付替え・Closes/精算は本体が別途既存規則で行い、この工程では操作しない。各実装開始時に先行 HEAD から入力を再計測し、容量外なら停止。rollback は作業 PR を差し戻し、凍結台帳と両対応の組を戻す。条件・閾値・工程を変えて回避しない。
## Risks / Trade-offs
[台帳の参照を読み飛ばす] → host 対応の先読みと op ID/リンク検査、#1850 の Orca での観測は別 issue。[最初の移行量は大きい] → 実測分母を維持し段階移行、14group の固定費を隠さない。[本体ごとの機能不足] → #1857 等が未提供なら blocked、外見だけ通して成功にしない。[既存仕様の path 固定シナリオ] → 各 group の focused delta で参照先だけ移し、既存の承認・role・phase・tuple 契約を弱めない。
受け入れ条件の追加・変更は 0。委任された設計上の選択は Y、台帳/2対応の置き場と op ID、段階移行の凍結、同一入口と明示リンク公開、出力責務の14分割。実行先や承認/品質規則の新仕様は発明していない。
