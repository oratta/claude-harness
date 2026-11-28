## Purpose

Codex 用の既存拒否判定を本体と worker の実際の起動へ届け、native subagent を含む対象ごとの適用範囲と未確認を、隔離した実機検証の証拠によって利用者が判断できるようにする。

## ADDED Requirements

### Requirement: 明示した runtime へ既存の拒否判定を配布する

配布は既存 Codex hook 定義と adapter・git/秘密/無人質問の依存判定を解決し、明示した一時 CODEX_HOME に起動用設定を用意しなければならない（MUST）。通常 profile の設定を暗黙に複製・変更してはならない（MUST NOT）。worker は入口・必要な依存・実行系を検証してから App Server を起動し、配置不備なら非ゼロの既存形式の失敗 JSON を返さなければならない（MUST）。

#### Scenario: 依存を揃えて worker を起動する
- **WHEN** 全依存が存在する runtime で書込役と読取役を起動する
- **THEN** 起動時に hook が発見でき、入口と依存は配布元の絶対パスを指し、親の同名パス指定に左右されず、role の砂場・account 照合・無人の印と既存 off 設定の意味は保持される

#### Scenario: 入口または依存が欠ける
- **WHEN** adapter、既存判定、secret 判定の Python sibling、bash/python3 のいずれかが欠ける
- **THEN** 原因を秘密値なしで識別でき、worker は App Server/turn を開始せず失敗し、未検査の exit 0 を配布成功と扱わない

### Requirement: 信頼方式を隔離した実機比較で確定する

管理 hook と invocation 限定の hook trust bypass は、実行版における配置/読込と実際の拒否を一時 CODEX_HOME・repo で比較し、採用/不採用理由を記録しなければならない（MUST）。実ホームやシステム設定へ書かず、未検証の信頼方式を有効として接続してはならない（MUST NOT）。bypass は有効な source を事前確認した一時 runtime に限らなければならない（MUST）。

#### Scenario: 信頼候補を比較する
- **WHEN** CLI 本体と worker の app-server で候補を試す
- **THEN** 各候補の読込元・引数・版・拒否結果または使えない理由を残し、両方有効なら管理方式、管理方式が使えず bypass が有効なら確認済みの一時 runtime で後者を選び、いずれも使えなければ未完了として止まる

#### Scenario: 信頼の確認が足りない
- **WHEN** 引数の受理だけを確認したか、bypass の対象に未確認の追加 hook source がある
- **THEN** 信頼成立・実機拒否成功とは記さず、起動接続の完成扱いを止める

### Requirement: 本体導入は主が承認して適用できる手順として提供する

本体向け手順は既存登録を保つ設定差分・依存配置・信頼操作・再確認・戻し方を示さなければならない（MUST）。実ホームの hook/権限設定は主の承認を得て主が自ら、または承認後に適用する手順とし、本 change の自動処理や実機確認で実ホームの ~/.codex・~/.claude を書き換えてはならない（MUST NOT）。

#### Scenario: 既存 Orca hook のある本体へ導入する
- **WHEN** 主が導入手順を読む
- **THEN** 追加部分と信頼対象をレビューでき、既存 hook 登録と config/requirements を保った適用・追加部分の取消しが分かり、承認前の実ホーム変更は発生しない

### Requirement: 3対象の拒否と未実行を安全な実機証跡で区別する

git の拒否は本体・native subagent・worker、秘密表示の拒否は本体・worker の各対象で実測しなければならない（MUST）。試験は一時 repo/linked worktree・ローカル bare remote・ダミー秘密のみで行い、無害な対照を含めなければならない（MUST）。版・HEAD・対象・信頼状態・入力・時刻・exit code・拒否と未実行の証拠を残し、completed や hook exit 0 を成功の代用にしてはならない（MUST NOT）。

#### Scenario: 対象操作が拒否される
- **WHEN** 既存 git 検出対象9種と代表変形、ダミー秘密表示を各必須対象から要求する
- **THEN** 実 tool の拒否と前後の HEAD/status/対象ファイル hash/remote refs の不変を照合でき、秘密試験はダミー値も出力されず、対照操作が通った証拠がある

#### Scenario: 子で拒否されたことを確認する
- **WHEN** native subagent が隔離 repo で対象 git 操作を要求する
- **THEN** 子の起動とその tool 要求を親子の記録に結び、親の成功を子に流用せず、PreToolUse の agent_id の有無に依存せず対象を識別する

### Requirement: 未取得と確認済みを一覧と変更記録で揃える

一覧と共用 `changes/1858.md` は対象・操作ごとに実装/配布/信頼/実機確認を区別し、証跡または未取得理由・試したこと・主の再現手順を示さなければならない（MUST）。未取得セルを確認済みにし、AC の成功を宣言してはならない（MUST NOT）。実秘密・認証内容・会話ログを repo 内や公開コメントへ保存してはならない（MUST NOT）。

#### Scenario: 一部の証拠が取れない
- **WHEN** 子の起動不可、信頼未成立、hook 未到達、操作未試行などでセルの証拠を取得できない
- **THEN** 当該セルだけ未確認とし、版・試行結果・理由・主が隔離環境で再現できるコマンドと期待結果を #1863・一覧・1858.md に対応付け、未確認の質問経路や兄弟の成果を完了にしない
