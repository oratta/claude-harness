# claude-role-launch Specification

## Purpose
Codex の本体が Claude の役を独立した print モードのセッションとして起こし、Agent 経路と同じ役制限・計測・停止契約を保つ。session と会話ログを本体に渡し、終了の輸送結果と工程の完了を区別できるようにする。

## 検査・判定の守備範囲

### 起動前に役と model の上限を検査する

守備範囲: 入力元は本体が渡す担当種別・profile role・解決済み model・worktree・工程指示と、同じ配布物の model 対応表である。拾う誤りは担当と profile role の不整合、未知の役・model、格上限超過、decider 以外の Fable、表の欠損、および要求 model の黙った置換である。通してよい具体例は、worker 定義の既定値が sonnet でも許可された opus を指定する入力と、本体が別作業の指示を誤って渡していても担当・profile role・model の組合せ自体は許可範囲にある入力である。工程指示の意味から役選択の正しさを再判定したり、対応表自体の設計の妥当性まで証明したりする検査にはしない。これらの穴の完全封鎖を完了条件にしない。

### 役の本文とツール制限を保ち孫を起こさせない

守備範囲: 入力元は配布物の役本文・ツール定義、使用する CLI / plugin と、その print モードの実機検証出力・ログである。拾う誤りは定義名の受理だけを読込成功にすること、実効 model・本文・ツール集合の不一致、Agent の混入、および decider への書込み系ツールの付与である。通してよい具体例は、専用 agent 定義を読めない版でも同じ本文・ツール集合の明示経路が実機検証を通る入力と、正しい役本文を読み込んだが工程指示に事実誤認が残る入力である。本文に書かれた事実や役の全出力の正しさはこの読込検査では保証しない。これらの穴の完全封鎖を完了条件にしない。

### 同じ session の再開前に自身のログを測る

守備範囲: 入力元は再開対象 session に登録された自身ログのパス、そのログの assistant usage、および `subagent-context.sh --file` の計測結果・終了コードである。拾う誤りは別 session のログによる代用、ログの欠損・読取不能・有効 usage の欠落、上限超過、および計測不能を 0 消費として再開することである。通してよい具体例は、壊れた行が混在していても既存の計測規則で最新の有効 usage を読めて上限以内と判定できるログと、書込み遅延により最新のリクエストがまだ反映されていないが登録ログの有効 usage は上限以内の入力である。provider のログの即時反映や、形式を保った usage 改変の検出までは保証しない。これらの穴の完全封鎖を完了条件にしない。

### turn 上限と終了理由を工程結果に変換する

守備範囲: 入力元は本体指定の max-turns、使用する CLI のパス・版と plugin 内容に紐付く実機検証記録、実行時の CLI 終了理由・終了コード、役の return、および所有グループの回収結果である。拾う誤りは不正な turn 数、未検証または変更後の CLI / plugin の使用、上限の拒否・不作動、CLI exit 0 だけによる工程完了判定、および中断・無宣言・回収失敗の見落としである。通してよい具体例は、検証済み CLI に正整数の大きな上限を指定して上限未満で正常終了する入力と、正常終了・回収成功に加えて正本どおりの完了宣言があるが成果に誤りを含む return である。有限の probe による全実行条件の証明や、完了宣言の内容の品質合格判定は行わず、品質は本体と独立レビューに残す。これらの穴の完全封鎖を完了条件にしない。

## Requirements

### Requirement: 起動前に役と model の上限を検査する
起動スクリプトは解決済みの役・model・対象 worktree・工程指示を受け、`tier_caps.py` と同じ配布物の対応表で検査した model を `claude -p --model` に MUST 渡す。spec-write / implement の格上限超過、decider 以外への Fable、未知の役・model、表の欠損は起動前に MUST 拒否する。model や account を別の値へ黙って替えてはならない（MUST NOT）。入力検査・判定の守備範囲は、上記「検査・判定の守備範囲」の同名節に従う。

#### Scenario: 上限超過は Claude を起動する前に拒否する
- **WHEN** spec-write または implement に上限を超える Fable を指定する
- **THEN** 非 0 で起動不可を返し、Claude の起動回数は 0 で、役・要求 model・上限が診断に含まれる

#### Scenario: 許可された model を定義の既定値で上書きしない
- **WHEN** worker の定義が sonnet で、解決済み model が許可された opus である
- **THEN** 実際の model は opus になり、要求値と適用値を区別して本体に返す

#### Scenario: 判断用の最上位は decider だけが使う
- **WHEN** 同じ Fable を decider と reviewer の各起動に指定する
- **THEN** decider だけが検査を通り、reviewer は起動前に拒否される

### Requirement: 役の本文とツール制限を保ち孫を起こさせない
起動スクリプトは canonical な担当（W・G・独立 PR レビュアー・R1・decider）と profile role を区別し、対応する役本文とツール集合を MUST 適用する。`--agent dev-workflow:<役>` の print モードでの定義読込を実機で確認し、使えなければ同じ本文・ツール集合と `--disallowedTools Agent` を MUST 指定する。どちらの経路も Agent による孫起動を許してはならず（MUST NOT）、decider は Read / Grep / Glob のみとする。入力検査・判定の守備範囲は、上記「検査・判定の守備範囲」の同名節に従う。

#### Scenario: プラグイン定義を読む経路を確認する
- **WHEN** 実装工程で開発用 plugin を読み込ませた print モードの worker / gate-runner / reviewer / decider を検証する
- **THEN** 選んだ定義・実効 model・ツール集合・Agent の不在を出力またはログで照合し、定義名を受理しただけで読込成功としない

#### Scenario: 定義を読めない場合の代替も孫を拒否する
- **WHEN** 定義読込が使えず、同じ役本文と明示ツール集合で起動して Agent の使用を要求する
- **THEN** `--disallowedTools Agent` が指定され、孫は実行されず、decider に Bash / Edit / Write / NotebookEdit が与えられない

### Requirement: 役の印と自身の session およびログを渡す
Claude の子環境へ `DEVELOP_ROLE=<profile role>` を MUST 設定し、親の環境を変更してはならない（MUST NOT）。起動前に session ID を確定して記録し、結果に同じ session ID と計測対象の自身の会話ログの絶対パスを MUST 出す。再開は同じ session を明示し、別 session のログ探索で欠損を補ってはならない（MUST NOT）。ログ・登録ファイル・実機証跡をリポジトリ内に置いてはならない（MUST NOT）。

#### Scenario: 独立した役に G001 の hook が掛かる
- **WHEN** agent_id のない print モードの役を起動する
- **THEN** 子と hook は役の印を持ち、G001 の自身ログ計測・役向け開始注入・Stop・git 拒否を使い、親の環境には新しい印が残らない

#### Scenario: 出力に対応するログだけを登録する
- **WHEN** session s1 のログと、別の新しい session s2 のログが存在する
- **THEN** s1 の結果・PR 集計の登録は s1 のログを指し、欠損時は欠測を返して s2 を選ばない

### Requirement: 同じ session の再開前に自身のログを測る
同じ session を再開する前は毎回、登録済みのログへ `subagent-context.sh --file <path>` を MUST 実行する。exit 2 は通常の再開を拒否して工程中断とし、既存の手渡し条件を本体に返す。exit 1 や usage のない履歴を上限以内・消費 0 と解釈して再開してはならない（MUST NOT）。途中計測の G001 の閾値と二段停止は変更しない。入力検査・判定の守備範囲は、上記「検査・判定の守備範囲」の同名節に従う。

#### Scenario: 再開前に上限を超えている
- **WHEN** 登録ログの最新の有効な usage の入力三項合計が共通の context cap を超える
- **THEN** `subagent-context.sh --file` が exit 2 を返し、起動スクリプトは Claude を再開せず工程中断と計測結果を返す

#### Scenario: ログがないか usage がない
- **WHEN** 再開対象のログが欠損、空、または有効な assistant usage を含まない
- **THEN** 計測不能として再開を行わず、fresh context や 0 消費と宣言しない

### Requirement: turn 上限と終了理由を工程結果に変換する
すべての起動・再開に正整数の `--max-turns` を MUST 渡す。使用する CLI 版で上限の実停止を確認してから通常起動を許可し、未確認・オプション拒否・上限不作動は起動不可または工程中断とする（MUST）。無制限起動へ切り替えてはならない（MUST NOT）。結果は CLI の終了理由・役の return・回収結果を分け、turn 上限・強制停止・シグナル・異常終了・回収失敗を `工程中断:` として本体に MUST 返す。入力検査・判定の守備範囲は、上記「検査・判定の守備範囲」の同名節に従う。

#### Scenario: 小さい turn 上限で実際に止まる
- **WHEN** 実装工程の検証で、上限より多い逐次ツール呼出しを要求する
- **THEN** 指定上限で止まり、終了結果の上限到達が工程中断へ変換され、exit 0 の輸送や JSON の受領だけで工程完了とならない

#### Scenario: 上限が使えない CLI を通さない
- **WHEN** CLI が `--max-turns` を拒否するか、検証で指定上限を超えて継続する
- **THEN** 起動不可または工程中断を返し、同オプションを外した再試行をしない

#### Scenario: 正常な輸送でも役の完了宣言がない
- **WHEN** CLI は正常終了したが、役が工程中断を宣言したか、正本の完了宣言を確認できない
- **THEN** 正本に宣言義務のある役では工程完了にせず、宣言義務のない役も個別の成果契約を本体が確認する

### Requirement: 起動したプロセスグループだけを回収する
起動スクリプトは自身と分離した役用のプロセスグループを作り、その所有を記録する。通常終了・turn 上限・強制停止・INT / TERM を受けた終了では、そのグループの残留プロセスを猶予付きの終了要求と必要な強制停止で MUST 回収して待つ。親・別の役・無関係な Claude のグループを止めてはならない（MUST NOT）。回収不能は残留情報とともに工程中断を返す。

#### Scenario: 終了経路ごとに子孫が残らない
- **WHEN** 通常終了・turn 上限・強制停止・INT / TERM の各ケースで、同じグループに背景子プロセスを持つ役が終了する
- **THEN** 起動したグループに生存プロセスが残らず、グループ外の対照プロセスと本体は生存している

#### Scenario: 回収不能を成功として返さない
- **WHEN** 記録したグループの残留が回収後にも確認される
- **THEN** 回収失敗の診断と所有グループの情報を添えて工程中断を返す

### Requirement: テスト fixture の境界でだけ役の印を解除する
役の実行環境と役自身に掛かる hook では `DEVELOP_ROLE` を MUST 保持する。役が Bats を実行する場合、テスト runner が作る Bats の子環境または fixture の setup だけで印を明示解除し、役を模す fixture は必要な印を明示設定する。起動スクリプトや役セッション全体の印を外してテストを通してはならない（MUST NOT）。

#### Scenario: 印付きの役から通常 fixture を実行する
- **WHEN** `DEVELOP_ROLE=implement` の役が通常セッションと役セッションの両方の fixture を含む対象スイートを実行する
- **THEN** 通常 fixture は印なしで期待どおり動き、役 fixture は印付きの制約を検証し、テスト呼出し後の役自身の印と git 拒否は残る

### Requirement: 実機の git 拒否を実行前の証跡で示す
G002 の実装検証では、開発用 plugin とリポジトリ外の一時 repo で起動した `claude -p` の役に破壊的 git を試行させ、実行前の hook deny と操作前後の状態が不変である記録を issue #1857 に MUST 残す。agent_id を捏造した permit や役への許可再実行を行ってはならない（MUST NOT）。必要な承認後の操作は本体が行う。

#### Scenario: 本物の役の git reset が hook に拒否される
- **WHEN** 変更を残した一時 repo の役が `git reset --hard HEAD` を要求する
- **THEN** ツール実行前の deny、試行コマンド、CLI / plugin の版、session と外部ログの所在、前後の HEAD・status・対象内容の比較を記録し、変更が失われていないことを示す
