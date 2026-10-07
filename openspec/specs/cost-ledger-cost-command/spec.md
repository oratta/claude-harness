# cost-ledger-cost-command Specification

## Purpose
`/cost` の入力解釈と出力の契約。番号が PR か issue かを GitHub に問い合わせて振り分け、issue の経路は実行した作業ディレクトリのリポジトリで絞る。出力の 1 行目は後続のゲート連携がそのまま PR に貼れる固定書式にする。
## Requirements
### Requirement: `/cost <番号>` の入力解釈
システムは `/cost <番号>` を受け取り、その番号が PR か issue かを GitHub に問い合わせて判別 SHALL する。PR ならその PR のヘッドブランチのコストを、issue ならその issue を触った区間のコスト合計を返 MUST す。

#### Scenario: PR 番号を渡す
- **WHEN** 利用者が既存の PR の番号を `/cost` に渡す
- **THEN** その PR のヘッドブランチに帰属するコストが返る

#### Scenario: issue 番号を渡す
- **WHEN** 利用者が既存の issue の番号を `/cost` に渡す
- **THEN** その issue を触った区間のコスト合計が返る

#### Scenario: 存在しない番号を渡す
- **WHEN** 渡された番号の PR も issue も存在しない
- **THEN** コストを 0 と表示せず、番号が見つからないことを利用者に伝える

### Requirement: issue の経路はリポジトリで絞る
issue 番号はリポジトリ内でしか一意でないため、`/cost <issue番号>` は**実行した作業ディレクトリのリポジトリ識別子と一致する行だけ**に絞 MUST る。全リポジトリの同じ番号を合算してはなら MUST NOT ない。

リポジトリ識別子が「不明」に落ちた行（`cwd` が削除済みで `git rev-parse` が失敗した行）は、黙って除外しても黙って合算しても MUST NOT ならない。システムはその件数と金額を出力に別立てで示 SHALL す。

PR の経路はブランチ名だけで引いて SHALL よい。PR のヘッドブランチが main になることはなく、リポジトリで絞らなくても他リポジトリの行を拾わないため、削除済み worktree の行も落とさずに済む。

#### Scenario: 別リポジトリの同じ番号を合算しない
- **WHEN** 別のリポジトリにも同じ番号の issue があり、そちらにもコストがある状態で `/cost <その番号>` を実行する
- **THEN** 返る値は実行した作業ディレクトリのリポジトリの行だけから計算される

#### Scenario: リポジトリ不明の行がある
- **WHEN** その issue 番号を触った行のうち、`cwd` が削除済みでリポジトリ識別子が不明な行がある
- **THEN** その件数と金額が「リポジトリ不明」として出力に別立てで示される

#### Scenario: PR の経路は worktree の削除に強い
- **WHEN** PR のヘッドブランチで作業した worktree が既に削除されている
- **THEN** そのブランチの行は落ちず、`/cost <PR番号>` の合計に含まれる

### Requirement: 番号を渡さずに呼んだときの既定動作
`/cost` を番号なしで呼んだとき、システムは**作業ディレクトリの現在のブランチ**のコストを返 MUST す。使い方だけを表示して終わってはなら MUST NOT ない。作業中にその場で叩く用途が主であり、リポジトリの文脈は既に作業ディレクトリから定まっているため。

このときブランチ名はリポジトリ内でしか一意でない（`main` や `develop` はどのリポジトリにもある）ので、**作業ディレクトリのリポジトリ識別子と一致する行だけ**に絞 MUST る。別リポジトリの同名ブランチを合算してはなら MUST NOT ない。リポジトリ識別子が「不明」に落ちた行は、除外も合算もせず、その件数と金額を出力に別立てで示 SHALL す。

#### Scenario: 番号なしで呼ぶ
- **WHEN** feature ブランチの作業ディレクトリで `/cost` を番号なしで実行する
- **THEN** そのブランチに帰属するコストが返る

#### Scenario: 別リポジトリの同名ブランチを合算しない
- **WHEN** 別のリポジトリにも同じ名前のブランチがありコストがある状態で、片方のリポジトリの作業ディレクトリから `/cost` を番号なしで実行する
- **THEN** 返る値は実行した作業ディレクトリのリポジトリの行だけから計算される

#### Scenario: 番号なしでリポジトリ不明の行がある
- **WHEN** 現在のブランチと同名の行のうち、`cwd` が削除済みでリポジトリ識別子が不明な行がある
- **THEN** その行は合計に入らず、件数と金額が「リポジトリ不明」として出力に別立てで示される

#### Scenario: git リポジトリの外で呼ぶ
- **WHEN** git リポジトリでないディレクトリで `/cost` を番号なしで実行する
- **THEN** ブランチが決まらないことを利用者に伝える

### Requirement: 出力の 1 行目は固定書式
後続の pr-review-gate 連携が出力をそのまま PR へ貼れるよう、システムは出力の**1 行目を固定書式**と MUST する。1 行目だけを取れば貼れる形にし、2 行目以降に内訳を置く。1 行目には金額（USD と円）、用いた換算レート、帰属先（PR 番号または issue 番号とリポジトリ）、帰属の種別（ブランチか区間か）を含め MUST る。

書式の例:

```
コスト: $108.23 / ¥16,235 @150 — PR #271 (oratta/token-optimize) 帰属: ブランチ
```

#### Scenario: 1 行目だけで貼れる
- **WHEN** `/cost` の出力から 1 行目だけを取り出す
- **THEN** 金額・換算レート・帰属先・帰属の種別がすべてその 1 行に含まれる

#### Scenario: 内訳は 2 行目以降にある
- **WHEN** issue 番号を渡してコストが返る
- **THEN** 区間ごとの内訳は 2 行目以降にあり、1 行目の書式は変わらない

### Requirement: 出力の形式
`/cost` の出力は API 換算コストを USD と円の両方で SHALL 示す。数字が推定であることを利用者が読み取れるよう、帰属の内訳（ブランチ単位か区間単位か）も示 MUST す。

#### Scenario: USD と円が両方出る
- **WHEN** `/cost` が値を返す
- **THEN** 出力には USD の金額と円の金額が両方含まれる

#### Scenario: issue 単位は推定であることが分かる
- **WHEN** issue 番号を渡してコストが返る
- **THEN** 出力には区間ごとの内訳が含まれ、その数字が区間分割による推定であることが分かる

### Requirement: プラグインの登録
`cost-ledger` は独立したプラグインとして `plugins/cost-ledger/.claude-plugin/plugin.json` を持ち、リポジトリルートの `.claude-plugin/marketplace.json` にも登録 MUST される。

#### Scenario: 両方に登録されている
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** plugin.json と marketplace.json の整合を検査する S131（`tests/marketplace-sync.bats`）を含めて全件 green（exit 0）になる

### Requirement: `/cost` はプラグイン設定の台帳パスを使う
`/cost` のコマンド本文は、userConfig の `LEDGER_PATH` の設定値を、集計スクリプトの呼び出しに環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として渡 MUST す。コマンド本文の Bash 実行にはこの環境変数が自動では渡らない（実機で確認済み）ので、本文の `${user_config.LEDGER_PATH}` が読み込み時に置換されることを使う。台帳パスの解決と優先順位は `cost-ledger-persistence` の規則のままで、`/cost` 側に別の解決を持ってはなら MUST NOT ない。

台帳が未設定のときの案内は、`/config` でのプラグイン設定「台帳ファイルのパス」を先に示 SHALL し、従来の方法（`~/.claude/settings.json` の `env` の `COST_LEDGER_PATH`）は次に示す。

#### Scenario: プラグイン設定だけが設定されている
- **WHEN** `COST_LEDGER_PATH` を設定せず userConfig の `LEDGER_PATH` だけを設定して `/cost` を実行する
- **THEN** `/cost` は台帳から読み、会話ログを直接読む動きにならない

#### Scenario: コマンド本文が値を渡している
- **WHEN** `commands/cost.md` の集計呼び出しを調べる
- **THEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` に `${user_config.LEDGER_PATH}` を渡す形になっている

#### Scenario: どちらも未設定
- **WHEN** プラグイン設定も `COST_LEDGER_PATH` も未設定で `/cost` を実行する
- **THEN** 会話ログを直接読んだ値が返り、台帳の置き場所を聞く案内は `/config` を先に示す

