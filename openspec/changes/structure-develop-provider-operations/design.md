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
### 移行する本文の設計（X / Y）
今回の再設計は試行3、対象コードは固定HEADのまま。X は局所条件の直後に操作ごとの契約をその場で展開する。Y は同じ契約を中立台帳へ一度だけ置き、本文に局所条件と操作参照を残す。X/Yとも本体別の具体的な道具・探索順は対応2ファイルへ移す。Z（元本文を残す読み替え）は本文禁止の受け入れ条件を変えるため不採用のまま。以下の before は固定HEADの範囲を指し、引用は抜粋、after は予定本文の例であって実装済みの主張ではない。

#### 役の起こし方と名前付きの再開
before: `references/codex-develop.md:27-29`（空行込み3行）の新規起動は「返った model で Agent を起動する」、再開は「同じ phase と…格の入力…で request を呼び直し」「SendMessage で再開」と、監査値・種別対応・model変更時freshの説明を長い2段落で持つ。保持する局所条件は、canonical phase、初回のprofile/account指定、失敗段、独立レビュー/role変更のfresh境界と、工程完了または停止確認後に渡すこと。台帳へ集めるのは起動の入力/出力、監査値の区別、再開可否、失敗/停止時の扱い。本体別対応へ集めるのは種別、道具、CLI/通知の具体的方法。

X の after（5論理行、同じ場所に契約を展開）:
```text
canonical phase・固定した実行先・失敗段を使い、独立レビュー/role変更はfresh、切替は工程完了または停止確認後に限る。
role-start: role/phase/HEAD/記録先/名前/解決済みtupleを渡す。
要求値と適用値・reasonを分け、本体別対応で起動して結果を回収する。
role-resume: 同じphase/格入力/実行先で再解決してcontextを確認する。
tier低下またはmodel変更ならfresh、それ以外だけ名前で再開し、要求tupleは保持する。
```
Y の after（2論理行）:
```text
canonical phase・固定した実行先・失敗段を使い、独立レビュー/role変更はfresh、切替は工程完了または停止確認後に限る。
[op:role-start](<台帳>#op-role-start) / [op:role-resume](<台帳>#op-role-resume) に名前と上の条件を渡す。
```
Y はこの範囲を −3/+2、X は −3/+5と数える。さらに同ファイル33-47（15行、起動CLI・入出力説明・コード枠を含む）は、phase/固定tuple/輸送と品質を区別する局所1行＋起動契約で X −15/+3、Y −15/+2。CLIの実際の書式と結果フィールドは対応へ移す。単なるヒット行置換ではない。13行と31行の重複説明も別hunkで数え、すべての開始/終了行を migration-plan.json に残した。

#### 主への聞き方
before: `skills/develop/references/channel.md:7` は「channel の本体は AskUserQuestion を呼ばない」に続けて、元のchat_id、返信ツール、ターン終了と次メッセージでの返事を説明する。局所には channel というモード、元依頼のchat_id、記録すべき問いへのURL、連絡先不明時の停止を残す。送信/返事回収/承認の扱いは owner-ask の契約と本体別対応へ集める（12/14行の呼び直し禁止と例外の条件も消さない）。
X after（当該hunk −1/+3）:
```text
channelでは元依頼のchat_idを宛先とし、記録を要する問いは先にコメントしてURLを渡す。連絡先不明時の停止は下の局所条件に従う。
owner-ask: モードの連絡正本に従い主へ問いを渡す。
実際の返事だけを承認として扱い、workerはreturnで本体へ返す。
```
Y after（−1/+2）:
```text
channelでは元依頼のchat_idを宛先とし、記録を要する問いは先にコメントしてURLを渡す。連絡先不明時の停止は下の局所条件に従う。
[op:owner-ask](<台帳>#op-owner-ask) に上の宛先・問い・実行モードを渡す。
```

#### プラグインの置き場の解決
before: `commands/develop.md:18-30,54-66` はそれぞれ13行のコード枠で同じ探索手段を展開する。局所に残すのは読む対象が develop / issueify であること、同一plugin限定、issueifyのfail-soft、起票前承認。rootの決定方法と探索順は plugin-root 対応へ一度だけ移す。
X は各13行を、本体別対応で解決する操作説明へ置換する（両範囲 −26/+26）。例（コード枠込み13行）:
```text
対象を skills/<develop または issueify>/SKILL.md に束縛する。
現在の本体を入口の確定値から得る。
その本体の plugin-root 対応を読む。
対応に従いインストール済みplugin rootを解決する。
rootが同じdev-workflowの実体か確かめる。
rootから対象の絶対パスを作る。
対象が存在するか確かめる。
存在すれば本文を直接読む。
読めた本文に従い共通手順へ進む。
不存在/読取不能は局所のfallback条件へ返す。
探索と起票の承認を混同せず、起票前承認は局所に残す。
```
Y は各範囲を次の1行にする（−26/+2）:
```text
[op:plugin-root](<台帳>#op-plugin-root) で同じpluginの skills/<develop または issueify>/SKILL.md を解決して読み、局所の不存在時処理へ返す。
```
入口抽出は両案ともcommand本文を74行削除して共通入口に移す。X は入口74行、Y はこの24行削減を反映した50行を追加する。その他の引継ぎ優先・5分岐・PR明示照会・fail-softの判断は移動先に保持し、入口テスト100行とspec50行の予定枠にPR照会の失敗/不存在の別fixtureも含める。

### 数量の再計算と比較
`migration-plan.json` は実装成果でなくレビュー用の見積根拠。124 hunk の source path/start/end/操作集合と削除/追加行数、および台帳・両対応の予定本文全文を保持する。K/R/H/P/G の source削除140行には、ヒット以外の起動説明/コード枠16行も含む。各hunkの局所条件を1論理行、Xは異なる操作ごとに契約2行、Yはまとめた参照1行を追加する。複数の操作を持つ行、15行のコード枠などを別々に数え、ファイル数には比例させない。Markdownの論理行の計画値であり、実装diffでは改行の増減も再計上する。

|範囲|hunk|削除|X追加|Y追加|共通追加（回帰/spec/記録/state）|X L|Y L|
|---|---:|---:|---:|---:|---:|---:|---:|
|K|36|52|118|72|102 =60+20+10+12|272|226|
|R|29|29|91|58|102 =60+20+10+12|222|189|
|H|23|23|71|46|102 =60+20+10+12|196|171|
|P|13|13|39|26|102 =60+20+10+12|154|141|
|G|23|23|73|46|102 =60+20+10+12|198|171|

I は87 inventory＋110 checker＋80 tests＋20 spec＋10 record＋20 registry skeleton＋20 fragment loader/schema＝347。M はX:対応37×2＋60 tests＋20 spec＋10 record＝164、Y:台帳74＋対応37×2＋同じ90＝238（全文はmigration-plan.jsonの reference_drafts）。D は削除74＋入口X74/Y50＋wrapper12＋routing tests100＋spec50＋record10＋state12＝X332/Y308。他は既存の出力責務別の積上げにstate/fixture登録12行を加える。N1=154、N2=160、Q/V=各122、E=170、F=212。見積りを実装時に超えたら再計算し、値を合わせるため本文や検査を省かない。

新設本文の予定読取は台帳1,834文字→1,193 tokens、Claude対応1,101文字→716、Codex対応853文字→555（Bash出力のceil(chars×0.65)）。Xは対応両方1,271、Yは台帳込み2,464をI以外の各itemに明示計上。両案とも前回の既存読取（全文/行範囲/regex±2行の全出力）を削らない。前回context_extra=20,000は元から新設/先行本文・render結果・spec等を保持する枠なので、そのうち上の読取をFへ振り替え、残りをX18,729/Y17,536とする。同じ出力をFとextraで二重計上しないためで、20,000の総保持量を減らしていない。Iは20,000のまま。従ってCは同じだが、F/Tと参照先の内訳は異なる。共有出力はgroup内だけ一度、別groupで再計上する。C=30,000 startup＋15,000 reserve＋F＋extra。現在のClaude transcript値やusage=0は使わない。

上限は両override未設定、subagent-context.sh:174-196 / pr-token-budget.sh:244-264 → token_thresholds.py:50-91の既定150,000/30,000,000。OWNER開始記録 issuecomment-7234027004 も30M。計画上限120,000/24,000,000と係数1799-v1-policy-0.8を維持する。実行ファイルは `mktemp -d /tmp/issue1856-spec.XXXXXX` で作ったrepo外のディレクトリへ置いた。

|案|候補（出現/ヒット行/ファイル）|具体化した本文hunk（K/R/H/P/G）|全体L|group|合計S|unplaced|最大同時group|
|---|---|---:|---:|---:|---:|---|---:|
|X 局所展開・共有管理更新|193/151/42|124（−140/+392）|2,825|14|267,978,000|空|1|
|Y 台帳参照・共有管理更新|193/151/42|124（−140/+248）|2,731|14|265,173,040|空|1|
|Y-fixed 台帳先行確定＋担当別断片（推す）|193/151/42|124（−140/+248）|2,731|14|265,173,040|空|10|

いずれもCLI exit0。候補数は同じでも、本文の操作説明144行と入口24行の追加がYで減り、台帳74行が増えるため、差引Lは94行減、Sは2,804,960減。見積りは実消費/品質の保証ではない。入力JSON全文と出力全文の保存URLは下の実行記録に記す。

### 推す案 Y と操作の組み立て
Y-fixed を推す。初回の候補箇所数は減らないが、局所の判断と操作契約を分離できる。XとのL/S差だけでなく、操作変更時に台帳と対応2ファイルに修正を集中できること、共有管理更新による不要な直列化を除けることを理由とする。Yの共有manifest方式は内容が同じでも管理上の競合を残す。Zは安くても本文禁止条件を満たさず、新しい既知語の呼出し追加を表の語集合だけでは落とせないため採らない。受け入れ条件は変えない。
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
### 意味上の依存と管理ファイルの競合
意味上はI（対象/検査契約）→M（全操作と両対応の確定）が先行する。その後K/R/H/P/G/Q/V/N1/N2/EはMとIの契約だけを読み、直前担当の本文やfixtureは要らない。Dは同じSKILL.mdを編集するKの完了を待つ（入口接続先の確定とファイル競合の両方）。Eは取り込む正本の現時点hashを測り、未移行の取り込みをIの凍結で認識するためR/N1/N2の完了を先行条件にしない。N1もtemplateの現時点を読み、Kの禁止表現が残る間は未移行として検査する。最終Fだけは全担当の完了を必要とし、最新HEADのhash/出力を再生成して未移行ゼロと全回帰/実機を照合する。必要な先行成果はこのDAGで示し、共有ファイルの編集順を意味上の依存と呼ばない。

管理方式の比較:
- X/Y control: 1つの移行manifestと1つのbats本体を各担当が更新する。意味上のDAGとは別に I→M→K→R→H→P→G→Q→V→N1→N2→E→D→F の編集競合順をdepends_onへ足す（入力のcontrol条件）。最終のshared更新も数える。最大並列1。
- Y-fixed（選択）: Iで対象87件/所有者/凍結hashをmanifestに固定し、未移行はその初期状態で表す。担当は `references/develop-procedure-state/<item>.json` を新設し、移行済み/出力fixture登録を追記する。Iの検査器が全断片を集め、未知所有者・重複・対象削除/後退を拒否する。登録しないまま完了とはできない。台帳と両対応はMで全操作を確定し、以後の担当はread-only。追加batsは `tests/develop-operations-<item>.bats`、新しいfocused spec delta/変更記録も担当changeごとのファイルにする。Iの検査器/bats本体を各担当が編集する計画は採らない。既存担当回帰のファイル所有権は元のまま。shared manifestの最終書直しは不要、Fは全断片を読む。
- 台帳/manifestを最初に全確定し移行状態すら更新しない案: 途中の凍結/移行済みの切替を識別できないので、段階移行契約を保つには結局上記の担当別状態が必要。断片方式なら操作台帳の可変性を増やさずに済む。

`max_parallel=16`は実際の `bash plugins/dev-workflow/scripts/epic-dispatch.sh max-parallel` のexit0出力（EPIC_DISPATCH_MAX_PARALLEL未設定、64GiB/4）。`occupied=0`はこの仕様工程が終わった後に本件の実装群だけを開始する計画上の仮定であり、現在の全世界の空き枠の実測ではない。他Wの占有を確認して実行直前に再計算する。今回のspawn禁止を値の根拠にしない。CLIのavailable=16で並列比較を有効にし、Y-fixedのDAGの幅は10（slot上限内）、X/Yは編集競合のため1となる。

集約後の再併合もCLIに任せて比較した。Y-fixedでは非聖域/承認待ち無しの11 item間の55組について、共通read_idを一度だけ数えた上でもCは125,691〜165,327で、全組が120,000を超える。最小CのM+KはC125,691/S26,965,760で両方超過、最小SのQ+VもC152,887/S20,400,960で文脈超過。従って14groupが残る理由は管理競合ではなく容量。G/N1/N2の聖域・承認待ちsingletonは併合候補から外す。extraの二重枠を併合のために勝手に減らさず、必要な出力保持を維持する。CLIの代理makespanはcontrol Y 169,264,854、Y-fixed 60,220,120（時間ではなくTの代理、最短保証無し）。

### 選んだ案のgroupと分割候補（レビュー後に本体が判断）
全groupは1 itemずつ。以下の「意味依存」が選択案のdepends_on。F以外の各行は直前行の完了を要求しない。CはX/Y共通、FはYの新設参照込み、L/SはXと選択Y-fixedを併記。非聖域のQ/Vは既存hookを読むだけ、fixture/断片のみ編集する。

|item / change候補|意味依存|聖域/承認待ち|F|X L / S|Y L / S|C（共通）|
|---|---|---|---:|---:|---:|---:|
|I-inventory-guard / `provider-i`|なし|なし|38,765|347 / 23,474,480|347 / 23,474,480|103,765|
|M-operation-mappings / `provider-m`|I|なし|45,619|164 / 18,013,760|238 / 20,221,920|108,155|
|K-core / `provider-k`|M|なし|36,469|272 / 21,236,480|226 / 19,863,840|99,005|
|R-roles / `provider-r`|M|なし|47,949|222 / 19,744,480|189 / 18,759,760|110,485|
|H-wait / `provider-h`|M|なし|43,993|196 / 18,968,640|171 / 18,222,640|106,529|
|P-epic-wording / `provider-p`|M|なし|49,853|154 / 17,715,360|141 / 17,327,440|112,389|
|G-gate / `provider-g`|M|あり / あり|54,592|198 / 19,028,320|171 / 18,222,640|117,128|
|Q-other-hook-fixtures / `provider-q`|M|なし|40,070|122 / 16,760,480|122 / 16,760,480|102,606|
|V-permission-hook-fixtures / `provider-v`|M|なし|51,479|122 / 16,760,480|122 / 16,760,480|114,015|
|N1-startup-text / `provider-n1`|M|あり / あり|34,746|154 / 17,715,360|154 / 17,715,360|97,282|
|N2-guard-text / `provider-n2`|M|あり / あり|32,990|160 / 17,894,400|160 / 17,894,400|95,526|
|E-worker-prompt / `provider-e`|M|なし|44,022|170 / 18,192,800|170 / 18,192,800|106,558|
|D-shared-entry / `provider-d`|M / K|なし|43,979|332 / 23,026,880|308 / 22,310,720|106,515|
|F-discovery-evidence / `provider-f`|I / M / K / R / H / P / G / Q / V / N1 / N2 / E / D|なし|50,000|212 / 19,446,080|212 / 19,446,080|112,536|

最小C余裕はGの2,872、最小S余裕はIの525,520。各担当が選ばれた後、最新先行HEADで同じ範囲を取り直して再計算する。見積りを超えたら停止して本体へ返す。子issue作成/着手の決定はこの仕様工程では行わない。

### 粒度CLI実行の記録
[X 入力JSON/出力全文](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7237015131)、[Y 入力JSON/出力全文](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7237015423)、[Y-fixed 入力JSON/出力全文](https://github.com/oratta/claude-harness/issues/1856#issuecomment-7237015718)。各コメントは省略無しでCLI入力と標準出力、exit0を含む。保存本文を再取得してローカルJSONと照合する。
## Migration Plan
I で全対象を登録し未移行本文を固定 HEAD の hash で凍結、M で全操作と対応を揃える。以後の担当は担当ファイルを丸ごと移行済みにし、所有者別状態断片で凍結解除と本文禁止・操作整合検査を一緒に切り替える。削除・対象外扱い・未移行への逆戻りで検査を避けられないよう負例を置く。最終 F は未移行ゼロを要求する。hook は実出力全分岐、生成依頼は全 phase と取り込み正本/hash を検査する。
各 group は担当回帰と `changes/<番号>.md` を持ち、文面 assertions を変えたテスト名・意味を記す。F は `scripts/test.sh` と `python3 -B plugins/dev-workflow/tests/test_codex_develop.py` の exit 0、本文へ Agent 呼出し追加/片側操作削除/対象外ファイル追加の非0、Claude の実機 1 件で Draft PR 作成とゲート通過の URL/HEAD/工程・exit/記録を #1856 へ集約する。実機で merge は要求しない。
この change は仕様比較の成果であり、全14group（直列ではなく上記DAG）の実装着手の許可ではない。独立 R1 のレビューを本体が手配し、採用後に分割を判断する。子 issue の作成・親付替え・Closes/精算は本体が別途既存規則で行い、この工程では操作しない。各実装開始時に先行 HEAD から入力を再計測し、容量外なら停止。rollback は作業 PR を差し戻し、凍結台帳と両対応の組を戻す。条件・閾値・工程を変えて回避しない。
## Risks / Trade-offs
[台帳の参照を読み飛ばす] → host 対応の先読みと op ID/リンク検査、#1850 の Orca での観測は別 issue。[最初の移行量は大きい] → 実測分母を維持し段階移行、14group の容量と固定費を隠さない。[本体ごとの機能不足] → #1857 等が未提供なら blocked、外見だけ通して成功にしない。[既存仕様の path 固定シナリオ] → 各 group の focused delta で参照先だけ移し、既存の承認・role・phase・tuple 契約を弱めない。
受け入れ条件の追加・変更は 0。委任された設計上の選択は Y-fixed、台帳先行確定と所有者別状態/fixture断片、計画上の枠16/占有0、台帳/2対応の置き場と op ID、段階移行の凍結、同一入口と明示リンク公開、出力責務の14分割。実行先や承認/品質規則の新仕様は発明していない。
