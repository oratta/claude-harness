# Codex PreToolUse guard delta

## Purpose

Codex のツール実行前に、既存の判定が対象とする破壊的 git・秘密の表示・無人の質問を拒否する。Claude 固有の確認画面や親子許可に依存せず、入力の対応範囲と文書・fixture・実機それぞれの確認状態を区別する。

## 入力検査の共通守備範囲

以下は入力選別・git・秘密・無人質問の各要件に共通する検査範囲である。

| 要件 | 入力の出どころ | 拾う誤り | 範囲外でも通る具体例 |
|---|---|---|---|
| 入力選別 | Codex が hook の stdin に渡すツール実行前の JSON のツール名・引数 | 編集本文や無関係な引数をシェルコマンドと取り違えること、確認済み経路の選別漏れ | 型や必要フィールドが壊れた JSON は無出力で通る。`sh ./cleanup.sh` の本文や hook に届かない呼び出しは検査できない |
| git | 選別後の Bash `tool_input.command` の文字列 | 既存判定が検出する対象9種の破壊的 git を実行しようとすること | `sh ./cleanup.sh` 内部の `git reset --hard`、送り先を書かない `git push` は通り得る |
| 秘密 | 選別後の Bash `tool_input.command` の文字列 | 既存 Bash 判定の対象となる変数・環境一覧・秘密ファイル・Keychain・1Password の値を表示しようとすること | `ssh host 'op read op://vault/item/field'` のリモート実行や `sh ./show-secret.sh` の本文は追わず通り得る |
| 無人質問 | hook に届く確認済み質問経路のツール名・引数と、起動側から hook の環境へ継承された `DEV_WORKFLOW_UNATTENDED` | 無人の印があるセッションで主への質問を呼び出して待ち状態にすること | 実際は無人でも印が子や worker に未継承なら印なしとして質問が通る。hook に届かない質問経路も検査できない |

この4要件は、上記の穴を塞ぎ切ることを完了条件にしてはならない（MUST NOT）。完了条件は、限定した入力契約・非対象と検査不能の扱い・既存判定の正負例の再現を満たすこととする（MUST）。ただし、対象の同期・非同期質問経路の確認と印付きでの拒否という design の入力確認ゲートは維持し、確認不能なら対応未完了として返さなければならない（MUST）。

## ADDED Requirements

### Requirement: Codex の hook 入力をツールごとに選別する

hook は stdin の PreToolUse JSON の `tool_name` と `tool_input` を読み、Bash の文字列 `tool_input.command` だけをシェル判定へ渡さなければならない（MUST）。質問は確認した専用経路だけを扱い、`apply_patch` の本文をシェルコマンドや Read の `file_path` とみなしてはならない（MUST NOT）。`agent_id`・Claude の permission_mode・transcript の存在を前提にしてはならない（MUST NOT）。

#### Scenario: 文書形式の Bash 入力
- **WHEN** `hook_event_name=PreToolUse`、`tool_name=Bash`、`tool_input.command` が文字列で、`agent_id` と `permission_mode` のない Codex fixture を渡す
- **THEN** command が git と秘密の検査へ渡され、session_id・turn_id・tool_use_id・cwd が追加されても判定は変わらない

#### Scenario: 編集本文や無関係なツールをコマンドとして扱わない
- **WHEN** `apply_patch` の command に `git reset --hard` や `cat .env` という文字列を含むパッチ、または無関係な local/MCP ツールの引数を渡す
- **THEN** 本 guard は無出力で通し、パッチを実行せず、存在しない file_path を補わない

### Requirement: 拒否は Codex の deny 契約だけで返す

対象を拒否するとき、hook は exit 0 と `hookSpecificOutput`（`hookEventName=PreToolUse`、`permissionDecision=deny`、空でない理由）を返さなければならない（MUST）。`ask`、`continue:false`、`stopReason`、Claude の一回許可による `allow` は返してはならない（MUST NOT）。非対象は無出力・exit 0 とし、検査対象のコマンドを実行してはならない（MUST NOT）。

#### Scenario: 対話モードや親子情報によらず拒否する
- **WHEN** 破壊的 git fixture に default/bypassPermissions、`DEV_WORKFLOW_GIT_GUARD_FORCE=ask`、任意の agent_id、Claude 用 permit をそれぞれ加える
- **THEN** 検査が有効ならすべて deny になり、禁止出力のキーと値を含まず、permit の読み書き・消費・拒否回数の記録はない

#### Scenario: 複数の判定で片方が拒否する
- **WHEN** git または秘密の判定のいずれかが拒否する Bash fixture を渡す
- **THEN** 有効な deny JSON が一つ返り、もう片方の無出力で拒否が消えない

### Requirement: 既存 git 判定の対象と無害な操作を保つ

Codex guard は `rules/destructive-git-guard.md` の「hook との分担」と `destructive-git-hook` の対象9種の検出を再利用し、対象を deny にしなければならない（MUST）。同じ字句・連結・引用・dry-run の区別と既存の検査範囲を保ち、無害な git を一括拒否してはならない（MUST NOT）。ルール本文の全操作を機械検出できると表記してはならない（MUST NOT）。

#### Scenario: 対象9種と変形を拒否する
- **WHEN** checkout のパス破棄、restore の作業破棄、reset --hard、clean -f、main/master への push、force push（--force-with-lease/+refspec を含む）、branch -D、--no-verify、--no-gpg-sign の各 fixture を渡す
- **THEN** 各々 deny となり、別 remote 名、`git -C`、env/command の前置き、連結、コマンド置換、shell -c でも既存の検出範囲は維持される

#### Scenario: 無害な git とデータの記述は通す
- **WHEN** status、diff、log、通常 commit、feature への通常 push、restore --staged、clean/push の有効な dry-run、echo の引用文または heredoc のデータ部分だけに危険な git の語がある fixture を渡す
- **THEN** git 判定は無出力となる（独立した秘密表示判定が該当する場合はそちらの契約による）

#### Scenario: 既存の限界を対応済みにしない
- **WHEN** push 済み amend、rebase -i、送り先を書かない push、変数・alias・スクリプト内部など既存の検査範囲外を説明する
- **THEN** 自動拒否を保証せず、ルールによる事前承認が依然必要と明記し、これらを成功 fixture として数えない

### Requirement: 秘密を画面に出す Bash を拒否し値を使う操作を通す

Codex guard は `capability-registry-secret-guard` の Bash 検査を再利用し、対象の値表示を deny にしなければならない（MUST）。値を出さない利用・存在確認・テンプレート表示を通し、検査のために実際の秘密やファイル内容を取得してはならない（MUST NOT）。Codex のシェル読み取りを Claude の Read 入力に置換してはならない（MUST NOT）。

#### Scenario: 秘密の表示を拒否する
- **WHEN** `echo "$GH_TOKEN"`、`printf %s ${MY_API_KEY}`、printenv、裸 env、cat .env、cat ~/.npmrc、裸 op read、op item get --fields、security find-generic-password -w の文字列 fixture を渡す
- **THEN** 各々 deny になり、ダミー値の展開もコマンド実行も行わない

#### Scenario: 値を出さない操作は通す
- **WHEN** `echo "${GH_TOKEN:+SET}"`、`echo "${#GH_TOKEN}"`、cat .env.example、env FOO=1 ls、コマンド置換で秘密を変数へ入れて利用する既存の正例を渡す
- **THEN** 秘密判定は無出力となる

### Requirement: 確認した質問経路を無人の印に従って拒否する

Codex guard は、実装対象版で確認した主への質問ツールを `DEV_WORKFLOW_UNATTENDED` の印があるとき deny にしなければならない（MUST）。前後空白を除いて未設定・空・`0` は印なし、その他は印ありとする。git の FORCE/NO_ASK/off で質問の判定を変えてはならない（MUST NOT）。拒否理由は打ち直さず運用の連絡先へ質問して止まること、子なら本体へ返すことを案内する（MUST）。

#### Scenario: 無人の質問と対話の質問を区別する
- **WHEN** 確認した質問経路の同一 fixture を、印が未設定・空白・` 0 `・`1`・` true `・yes の環境でそれぞれ渡す
- **THEN** 最初の3つは無出力、残りは deny となり、git off と FORCE=ask を付けても結果は変わらない

#### Scenario: 質問名の推測では対応完了にしない
- **WHEN** request_user_input / request_user_input_async、名前空間付きの公開名、code mode 内の nested call と実際の hook 名の対応が実測されていない
- **THEN** 候補の合成 fixture は合成と明示し、実経路の対応テスト完了や本体での質問拒否成功と表記しない。経路が確認できなければ質問対応は未完了として記録して止まる

### Requirement: 非対象と検査不能の扱いを既存契約から広げない

guard は非 PreToolUse・非対象名・壊れた JSON・非オブジェクト・Bash command が文字列でない入力を無出力で通さなければならない（MUST）。依存判定を実行できないときは stderr へ未検査理由を示して無出力・exit 0 とする（MUST）。起動環境の git off は git のみ、secret off は秘密のみを無効化し、コマンド文字列中の代入で無効化してはならない（MUST NOT）。

#### Scenario: 非対象や壊れた入力
- **WHEN** 別 event、空 stdin、不正 JSON、配列、null、Bash の tool_input/command が欠落・別型の fixture を渡す
- **THEN** exit 0・無出力となり、成功した検査とは記録しない

#### Scenario: 無効化と依存失敗を区別する
- **WHEN** git/secret の片方だけを起動環境で off にする、または依存 script を一時コピーで欠落させる
- **THEN** 他の検査と質問は有効であり、欠落は stderr で未検査と分かる。入力 command の `DEV_WORKFLOW_GIT_GUARD=off git reset --hard` だけでは拒否を回避しない

### Requirement: 判定の証拠と配布の証拠を分けて引き継ぐ

テストと変更記録は、文書で確認した入力、合成 fixture、実測した入力を識別しなければならない（MUST）。一覧は対象3登録の判定の達成状態と移植先だけを更新し、本体・native subagent・worker の未取得の配布・信頼・実機証跡を確認済みにしてはならない（MUST NOT）。G002 の結果と残作業を共用 `changes/1858.md` に追記する（MUST）。

#### Scenario: fixture のみ成功した段階
- **WHEN** adapter の正負 fixture が通るが #1863 の配布・信頼・対象別の実機証跡がない
- **THEN** 判定テストの成功だけを記録し、3対象は未確認のまま残し、#1863 が必要な入口・依存スクリプト・確認済み入力と未確認経路を追跡できる
