# cost-ledger-cost-command Specification

## Purpose
`/cost` の入力解釈と出力の契約。番号が PR か issue かを GitHub に問い合わせて振り分け、issue の経路は実行した作業ディレクトリのリポジトリで絞る。出力の 1 行目は後続のゲート連携がそのまま PR に貼れる固定書式にする。
## Requirements
### Requirement: `/cost <番号>` の入力解釈
システムは `/cost <番号>` を受け取り、その番号が PR か issue かを GitHub に問い合わせて判別 SHALL する。PR ならその PR のヘッドブランチのコストを、子 issue を持たない issue ならその issue を触った区間のコスト合計と、その issue を閉じた PR の分を合わせた合計（閉じた PR があるとき）を、子 issue を持つ issue なら「子 issue を持つ issue では、子 issue ごとの内訳と合計を返す」が定める合計と内訳を返 MUST す。子 issue を持つかどうかは、番号の判別に使う issue の問い合わせ（REST の `repos/{owner}/{repo}/issues/<番号>`）の応答の `sub_issues_summary.total` が 1 以上かどうかで決め SHALL、判別のための `gh` の呼び出しを増やしてはなら MUST NOT ない。この値が応答に無いか整数として読めないときは、子 issue を持たない issue として扱 MUST う。

**子 issue を持たない issue の閉じた PR。** システムは、子 issue を持たない issue と判別したときに限り、その issue を閉じた PR を `gh api graphql` の 1 回の問い合わせ（`closedByPullRequestsReferences(first: 100)` の番号・ヘッドブランチ・`isCrossRepository`・`baseRepository.nameWithOwner`。`nameWithOwner` はその応答のリポジトリ名）で SHALL 取る。owner・name・番号は変数で渡し、問い合わせの文字列に埋め込んではなら MUST NOT ない。数える PR は、ベースが作業ディレクトリのリポジトリで `isCrossRepository` が偽のものだけで、同じヘッドブランチが複数あれば番号の小さい方だけを数える（`cost_ledger.py issue` の `--closing-pr` と同じ入力にして `cmd_issue` に渡す）。この問い合わせを、PR 番号・子 issue を持つ issue・番号なしの `/cost` で行ってはなら MUST NOT ない。

**1 行目は変えない。** 閉じた PR があっても、1 行目（`headline()`）の金額・帰属先・種別（`区間`）は、閉じた PR を数えない場合と同じ SHALL。合計と内訳（PR ごとの額と PR の外の額）は、spec `cost-ledger-attribution` の「issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である」が定める 2 行目以降の 1 行で出る。

**閉じた PR が 0 件のときの互換。** 通常出力（`--json` 無し）は、この要件を足す前と 1 文字も違わない MUST（読めなかった旨の行も出さない）。`--json` は既存の鍵の値を変えず、`closing_prs` は空の配列、`closing_prs_error` は `false` を足す（鍵が増えるのは `--json` だけ）。

**読み切れないとき。** 閉じた PR の問い合わせが失敗した・応答が JSON でない・期待する形でない（1 件でも形が崩れている）・`pageInfo.hasNextPage` が真のときは、終了コード 0 のまま閉じた PR を数えない出力を返す。表し方は出力の種類で分ける。通常出力は、標準出力に `  閉じた PR を読めなかったため、PR の分は合計に入っていません。` の行を 1 行 SHALL 足す（合計の行は出さない）。`--json` は標準出力を JSON だけに保ち MUST（警告行を混ぜない）、`closing_prs` を空の配列、`closing_prs_error` を `true` にする。区間の分が読めているのに、PR の分が読めないことで区間の額まで返さなくなってはなら MUST NOT ない。

**利用者への見せ方。** `commands/cost.md` は、`/cost <issue番号>` の結果に合計の行（`合計（閉じた PR 込み）:`）または読めなかった旨の行があるとき、1 行目に続けてその行も利用者に見せるよう指示 SHALL する（1 行目だけを見せる既存の指示のままでは、合計が利用者に届かない）。PR に貼るのは引き続き 1 行目だけ。

守備範囲: この判別が受け取る入力は、利用者が `/cost` に渡した番号と、その番号について `gh` が返す GitHub の応答（PR の問い合わせ・issue の問い合わせ・閉じた PR の問い合わせ）に限る。拾いたい誤りは、PR を issue として・issue を PR として集計すること、存在しない番号を 0 と表示すること、子 issue を持つ issue を区間だけの額（ほぼ 0）で返すこと、閉じた PR があるのに PR の分を黙って落として合計に見せることの 4 つ。次のことは誤ったまま通ることを許す: issue の問い合わせの応答に `sub_issues_summary` が無い・`total` が整数でない（古い応答の形、テスト用の偽の `gh` など）ときは、実際に子 issue があっても子を持たない issue として扱う／GitHub の子 issue の仕組みに登録されていない issue（本文の表に書いてあるだけ）は子として見ない／判別のあとで子 issue が足された・外されたことは、その実行には反映されない／閉じた PR を GraphQL が返さない issue（PR 本文の `Closes` を使わず手でリンクしたものなど）の PR の分は数えられない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: PR 番号を渡す
- **WHEN** 利用者が既存の PR の番号を `/cost` に渡す
- **THEN** その PR のヘッドブランチに帰属するコストが返り、閉じた PR の問い合わせ（GraphQL）は 0 回

#### Scenario: issue 番号を渡す
- **WHEN** 利用者が、子 issue を持たない既存の issue の番号を `/cost` に渡す
- **THEN** その issue を触った区間のコスト合計が 1 行目に返る

#### Scenario: 子 issue を持つ issue の番号を渡す
- **WHEN** issue の問い合わせの応答の `sub_issues_summary.total` が 2 である issue #10 の番号を `/cost` に渡す
- **THEN** 1 行目の帰属の種別は `子 issue 込み` で、2 行目以降に子 issue ごとの行があり、閉じた PR だけを問い合わせる GraphQL は呼ばれない（エピックの経路の問い合わせだけ）

#### Scenario: 子 issue の数が応答に無い
- **WHEN** issue の問い合わせが番号だけを返す（`sub_issues_summary` が無い）issue #12 の番号を `/cost` に渡し、閉じた PR の問い合わせは 0 件を返す
- **THEN** 出力は `cost_ledger.py issue 12` と同じで、GraphQL の呼び出しは閉じた PR の問い合わせの 1 回だけ

#### Scenario: 閉じた PR が 1 件ある issue
- **WHEN** 子 issue を持たない issue #12 を閉じた PR #300（ヘッドブランチ `feat/a`、同じリポジトリ）があり、`/cost 12` を実行する
- **THEN** 終了コード 0 で、1 行目は閉じた PR を数えない場合と同じ書式（種別 `区間`）で、2 行目以降に合計・`PR #300` の額・`PR 外` の額を含む行が 1 行ある

#### Scenario: 閉じた PR が 0 件の issue
- **WHEN** 閉じた PR の問い合わせが 0 件を返す issue #12 に `/cost 12` を実行する
- **THEN** 出力は `cost_ledger.py issue 12`（`--closing-pr` なし）と完全に同じ

#### Scenario: 閉じた PR の問い合わせが失敗する
- **WHEN** 閉じた PR の問い合わせ（`gh api graphql`）が失敗する状態で `/cost 12` を実行する
- **THEN** 終了コードは 0 で、区間の分の出力はそのまま返り、`閉じた PR を読めなかったため、PR の分は合計に入っていません。` の行が 1 行あり、合計の行は無い

#### Scenario: 別のリポジトリやフォークの PR は数えない
- **WHEN** 閉じた PR の応答に、ベースが別のリポジトリの PR と `isCrossRepository` が真の PR が含まれる
- **THEN** それらの PR の分は合計にも内訳にも入らない

#### Scenario: 存在しない番号を渡す
- **WHEN** 渡された番号の PR も issue も存在しない
- **THEN** コストを 0 と表示せず、番号が見つからないことを利用者に伝える。閉じた PR の問い合わせは行わない

### Requirement: issue の経路はリポジトリで絞る
issue 番号はリポジトリ内でしか一意でないため、`/cost <issue番号>` は**実行した作業ディレクトリのリポジトリ識別子と一致する行だけ**に絞 MUST る。全リポジトリの同じ番号を合算してはなら MUST NOT ない。

リポジトリ識別子が「不明」に落ちた行（`cwd` が削除済みで、`git rev-parse` でも `cwd` の文字列からの推定でも決まらなかった行）は、黙って除外しても黙って合算しても MUST NOT ならない。システムはその件数と金額を出力に別立てで示 SHALL す。

**推定で数えた行。** spec `cost-ledger-attribution` の「リポジトリ識別子と worktree の畳み込み」の推定、または spec `cost-ledger-persistence` の「台帳を読むときに補正行を当てる」で識別子が決まった行（事実の `repo_inferred` が `true` の行）は、識別子が一致すれば合計に入れ MUST る。ただし黙って合算してはなら MUST NOT ない。`cost_ledger.py issue <番号>`（`/cost <issue番号>` が子を持たない issue に対して呼ぶ経路）は、その issue に帰属して数えた区間の行のうち `repo_inferred` が `true` の行の件数（補足の事実は数えない）と金額を、次の形で示 SHALL す。

- 表示: 件数が 1 以上のとき、「リポジトリ不明」の行が置かれる位置の直後に `  推定で数えた行: <件数> 件 <額>（cwd が削除済みで、パスからリポジトリを推定した。合計に入れている）` を 1 行。額は `$` と小数 2 桁、3 桁区切り。件数が 0 のときは出さない
- `--json`: `inferred_repo_usd` と `inferred_repo_messages` を常に出す（無ければ 0）

この行の金額は合計の内数で MUST ある（合計に足しても引いてもならない）。

PR の経路はブランチ名だけで引いて SHALL よい。PR のヘッドブランチが main になることはなく、リポジトリで絞らなくても他リポジトリの行を拾わないため、削除済み worktree の行も落とさずに済む。

#### Scenario: 別リポジトリの同じ番号を合算しない
- **WHEN** 別のリポジトリにも同じ番号の issue があり、そちらにもコストがある状態で `/cost <その番号>` を実行する
- **THEN** 返る値は実行した作業ディレクトリのリポジトリの行だけから計算される

#### Scenario: リポジトリ不明の行がある
- **WHEN** その issue 番号を触った行のうち、`cwd` が削除済みでリポジトリ識別子が不明な行がある
- **THEN** その件数と金額が「リポジトリ不明」として出力に別立てで示される

#### Scenario: 推定で数えた行は合計に入り、件数と額が示される
- **WHEN** その issue 番号を触った行のうち、`cwd` が削除済みで、推定によって実行した作業ディレクトリのリポジトリに決まった行がある状態で `cost_ledger.py issue <番号>` を実行する
- **THEN** その行は合計に入り、「リポジトリ不明」には数えられず、`推定で数えた行:` の行にその件数と金額が出る。`--json` の `inferred_repo_messages` と `inferred_repo_usd` も同じ値になる

#### Scenario: 推定の行が無ければ行を出さない
- **WHEN** その issue に帰属した行がすべて `git rev-parse` で識別子の決まった行である
- **THEN** 出力に `推定で数えた行:` の行は無く、`--json` の `inferred_repo_messages` は 0

#### Scenario: 追記したあとで cwd を消しても合計は変わらない
- **WHEN** `cwd` が存在するうちに台帳へ追記し、そのあとで `cwd` のディレクトリを消して `cost_ledger.py issue <番号>` を実行する
- **THEN** その行は合計に入り、合計は消す前と同じで、`推定で数えた行:` の行は出ない（識別子は追記した時点で決まっている）

#### Scenario: 別リポジトリに推定された同じ番号の行を数えない
- **WHEN** 別のリポジトリの置き場の削除済みの `cwd` で同じ番号の issue を触った行があり、推定でその別のリポジトリに決まる状態で `cost_ledger.py issue <番号>` を実行する
- **THEN** その行は合計にも「リポジトリ不明」にも `推定で数えた行:` にも入らない

#### Scenario: PR の経路は worktree の削除に強い
- **WHEN** PR のヘッドブランチで作業した worktree が既に削除されている
- **THEN** そのブランチの行は落ちず、`/cost <PR番号>` の合計に含まれる

### Requirement: 番号を渡さずに呼んだときの既定動作
`/cost` を番号なしで呼んだとき、システムは**作業ディレクトリの現在のブランチ**のコストを返 MUST す。使い方だけを表示して終わってはなら MUST NOT ない。作業中にその場で叩く用途が主であり、リポジトリの文脈は既に作業ディレクトリから定まっているため。

このときブランチ名はリポジトリ内でしか一意でない（`main` や `develop` はどのリポジトリにもある）ので、**作業ディレクトリのリポジトリ識別子と一致する行だけ**に絞 MUST る。別リポジトリの同名ブランチを合算してはなら MUST NOT ない。リポジトリ識別子が「不明」に落ちた行は、除外も合算もせず、その件数と金額を出力に別立てで示 SHALL す。合計に入れた行のうち `repo_inferred` が `true` の行があれば、「issue の経路はリポジトリで絞る」の「推定で数えた行」と同じ形の 1 行を、「リポジトリ不明」の行が置かれる位置の直後に示 SHALL す（件数が 0 なら出さない。金額は合計の内数）。

#### Scenario: 番号なしで呼ぶ
- **WHEN** feature ブランチの作業ディレクトリで `/cost` を番号なしで実行する
- **THEN** そのブランチに帰属するコストが返る

#### Scenario: 別リポジトリの同名ブランチを合算しない
- **WHEN** 別のリポジトリにも同じ名前のブランチがありコストがある状態で、片方のリポジトリの作業ディレクトリから `/cost` を番号なしで実行する
- **THEN** 返る値は実行した作業ディレクトリのリポジトリの行だけから計算される

#### Scenario: 番号なしでリポジトリ不明の行がある
- **WHEN** 現在のブランチと同名の行のうち、`cwd` が削除済みでリポジトリ識別子が不明な行がある
- **THEN** その行は合計に入らず、件数と金額が「リポジトリ不明」として出力に別立てで示される

#### Scenario: 番号なしで推定の行がある
- **WHEN** 現在のブランチと同名の行のうち、`cwd` が削除済みで、推定によって作業ディレクトリのリポジトリに決まった行がある
- **THEN** その行は合計に入り、件数と金額が `推定で数えた行:` の行に出る

#### Scenario: git リポジトリの外で呼ぶ
- **WHEN** git リポジトリでないディレクトリで `/cost` を番号なしで実行する
- **THEN** ブランチが決まらないことを利用者に伝える

### Requirement: 出力の 1 行目は固定書式
後続の pr-review-gate 連携が出力をそのまま PR へ貼れるよう、システムは出力の**1 行目を固定書式**と MUST する。1 行目だけを取れば貼れる形にし、2 行目以降に内訳を置く。1 行目には金額（USD と円）、用いた換算レート、帰属先（PR 番号または issue 番号とリポジトリ）、帰属の種別（`ブランチ`・`区間`・`子 issue 込み` のいずれか）を含め MUST る。

書式の例:

```
コスト: $108.23 / ¥16,235 @150 — PR #271 (oratta/token-optimize) 帰属: ブランチ
```

#### Scenario: 1 行目だけで貼れる
- **WHEN** `/cost` の出力から 1 行目だけを取り出す
- **THEN** 金額・換算レート・帰属先・帰属の種別がすべてその 1 行に含まれる

#### Scenario: 内訳は 2 行目以降にある
- **WHEN** 子 issue を持たない issue の番号を渡してコストが返る
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

集計スクリプトの探索は、コマンド本文の置換で絶対パスになる作業中のプラグインのルートを先頭の候補にし MUST、インストール済みのコピーは後ろの候補にとどめる（Bash の実行環境にはプラグインのルートの環境変数が渡らないので、環境変数の形で先頭に置くと、版の違う旧コピーが選ばれる）。

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

### Requirement: 子 issue を持つ issue では、子 issue ごとの内訳と合計を返す
システムは、`cost_ledger.py cost <番号>` に子 issue を持つ issue（以下「エピック」）の番号が渡されたとき、エピック自身と子孫の issue ごとの額と、その合計を返 MUST す。合計と issue ごとの額の定義は spec `cost-ledger-attribution` の「エピックの合計は、エピック自身と子孫の issue が数える行を 1 回ずつ足した額である」に従 SHALL う。子 issue を持たない issue と PR の番号を渡したときの出力と `gh` の呼び出しは、変えてはなら MUST NOT ない。`cost_ledger.py issue`・`cost_ledger.py timeline` は子 issue を調べてはなら MUST NOT ない。

**子 issue の辿り方。** 子 issue と、それぞれを閉じた PR は、`gh api graphql` で SHALL 問い合わせる。1 回の問い合わせで、ある issue の `subIssues(first: 100)` と、その子 1 件ごとの番号・題名・状態・リポジトリ（`repository.nameWithOwner`）・子の数（`subIssuesSummary.total`）・閉じた PR（`closedByPullRequestsReferences(first: 100)` の番号・ヘッドブランチ・`isCrossRepository`・`baseRepository.nameWithOwner`）を取り、エピック自身への問い合わせでは、エピック自身を閉じた PR と、作業ディレクトリのリポジトリの `nameWithOwner` も同じ 1 回で取る。owner・name・番号は変数で渡し、問い合わせの文字列に埋め込んではなら MUST NOT ない。

- 子の数が 1 以上の子 issue には、同じ問い合わせをもう 1 回行って、その子（孫）を辿 SHALL る。子の数が 0 の issue には問い合わせてはなら MUST NOT ない
- open の子も closed の子も数え MUST る
- リポジトリが作業ディレクトリのリポジトリと違う（`nameWithOwner` が大文字と小文字を区別せずに一致しない）子 issue は、数えず、その子も辿らず、出力に別立てで示 MUST す（issue に帰属する行は実行した作業ディレクトリのリポジトリの行に限るため）
- 一度出てきた番号の issue は、2 回目以降は数えず、辿ってもなら MUST NOT ない（循環で止まらなくなることと、同じ issue を 2 回数えることを防ぐ）
- 辿る深さはエピックから 8 段下まで（GitHub が許す入れ子の上限）と SHALL する
- issue を閉じた PR のうち数えるのは、spec `cost-ledger-timeline` の「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」と同じく、ベースのリポジトリが作業ディレクトリのリポジトリと一致し、`isCrossRepository` が偽の PR だけと MUST する

**読み切れないときは合計を出さない。** 次のときは、標準出力に何も書かず、標準エラーにどの issue で何が読めなかったかを書いて、終了コード 2 を返 MUST す（一部の子しか読めていない額を、エピックの合計として見せない）: GraphQL の呼び出しが失敗した／応答が JSON でない、または期待する形でない（番号が整数でない、ヘッドブランチが空など、1 件でも崩れている）／`subIssues` の `pageInfo.hasNextPage` が真／どれかの issue の `closedByPullRequestsReferences` の `pageInfo.hasNextPage` が真／エピックから 8 段下の issue がさらに子を持つ。

**表示（`--json` 無し）。** 1 行目は `headline()` で作り、金額はエピックの合計、帰属先は `issue #<番号> (<リポジトリ>)`、帰属の種別は `子 issue 込み` と MUST する。2 行目以降は次の順と SHALL する。

1. `  対象: issue #<番号>（<リポジトリ>）と子孫の issue <件数> 件`
2. `  子 issue の合計: <額>`。額は、エピック以外の対象の issue すべてに割り当てた額の和（エピックの直下の子の行の額の和と同じ値）
3. `  issue #<番号> 自身: <額>`。額は、エピック自身に割り当てた額
4. 対象の issue 1 件につき 1 行。最初がエピック自身で、あとは GitHub が返した子の順に、子を持つ issue の直後にその子を並べる。行は空白 2 つで始め、エピックから 1 段下がるごとに空白を 2 つ足す。中身は `#<番号> <状態> <額>` で、状態は `open` か `closed`、額はその issue と、その下の対象の issue すべてに割り当てた額の和（`$` と小数 2 桁、3 桁区切り）。子を持つ issue では続けて `（自身 <その issue に割り当てた額>）`、そのあとに ` — <題名>` を書く。題名が 40 文字を超えるときは、先頭 39 文字と `…` にする
5. 割り当てた額が単独の合計と違う issue の行の末尾には、`（単独 <単独の合計>` に続けて、その issue を閉じた PR のうち別の issue に割り当てられたもの 1 件ごとに `、PR #<番号> は #<割り当て先の issue の番号> に計上` を書き、`）` で閉じる
6. 数えなかった子 issue があれば `  数えていない子 issue: <owner/repo>#<番号>（別のリポジトリ）` を 1 行（複数あれば `、` でつなぐ）
7. 対象の issue の番号に帰属した区間の行のうち、リポジトリ識別子が不明で、どのヘッドブランチにも割り当てられなかった行があれば、その件数と金額を「リポジトリ不明」として 1 行（合計には入れない）
8. 対象の issue に割り当てた区間の行（ヘッドブランチの一致で割り当てた行を除く）のうち、`repo_inferred` が `true` の行があれば、その件数と金額を `  推定で数えた行: <件数> 件 <額>（cwd が削除済みで、パスからリポジトリを推定した。合計に入れている）` として 1 行（金額は合計の内数。件数が 0 なら出さない）
9. 額が区間分割による推定であることと、issue ごとの区間の内訳は `/cost <その issue の番号>` で見られることを伝える 1 行
10. 単価表のずれの知らせ（`--no-drift-check` を渡したときは突き合わせを行わない。突き合わせの対象は、合計に数えた行のセッション）

「子 issue の合計」の行の額は、エピックの直下の子の行の額の和と一致 MUST する。1 行目の金額（エピックの合計）は、「子 issue の合計」の行の額に「自身」の行の額を足した値と一致 MUST する（エピック自身の番号を触った区間の額は実際にかかった額なので、合計から落とさない。エピック自身に割り当てた行が無ければ、1 行目の金額は子の行の額の和と同じになる）。エピック自身の行の額（その issue と下の issue すべての和）は 1 行目の金額と同じで MUST ある。表示の額は 1 行ずつ丸めるので、行の額の和が 1 セントずれることは SHALL 許す（`--json` の値で一致を確かめる）。

**題名とリポジトリ名の表示。** 内訳の行に出す題名と、「数えていない子 issue」の行に出すリポジトリ名は、表示の前に、制御文字（Unicode の一般カテゴリが `Cc`・`Cf`・`Zl`・`Zp` の文字。改行・タブ・ESC・双方向制御文字を含む）を空白 1 つに置き換え、連続する空白を 1 つに畳み、前後の空白を落と MUST す。題名を 40 文字に切るのは、そのあとと SHALL する。`--json` の `title` と `skipped` の `repo` は、GitHub から取った値のまま出 MUST す（機械が読む値を変えない）。

**`--json`。** 次の鍵を持つ JSON を出 MUST す。

- `issue`（番号の文字列）・`repo_id`・`repo_label`・`usd_jpy_rate`・`price_drift`: `cost_ledger.py issue --json` と同じ意味
- `total_usd`: エピックの合計
- `children_usd`: 子 issue の合計（エピック以外の対象の issue の `own_usd` の和。エピックの直下の子の `usd` の和と同じ値）
- `self_usd`: エピック自身に割り当てた額（エピック自身の `own_usd` と同じ値）
- `issues`: 対象の issue の配列（表示と同じ順）。1 件は `number`（整数）・`parent`（親の番号。エピック自身は null）・`depth`（エピック自身が 0）・`title`・`state`（`open` か `closed`）・`usd`（その issue と下の issue すべてに割り当てた額の和）・`own_usd`（その issue に割り当てた額）・`standalone_usd`（単独の合計）・`closing_prs`（数えた PR の配列。番号の昇順。1 件は `number`・`branch`・`usd`（そのヘッドブランチの行の合計）・`counted_in`（その行を割り当てた issue の番号））
- `skipped`: 数えなかった子 issue の配列。1 件は `repo`・`number`・`parent`
- `unknown_repo_usd`・`unknown_repo_messages`: 上の表示の「リポジトリ不明」と同じ行の金額と件数
- `inferred_repo_usd`・`inferred_repo_messages`: 上の表示の「推定で数えた行」と同じ行の金額と件数（無ければ 0。`total_usd` の内数）

`issues` の `own_usd` の和は `total_usd` と一致 MUST する。`children_usd` はエピックの直下の子（`parent` がエピックの番号の issue）の `usd` の和と一致 MUST し、`total_usd` は `children_usd` と `self_usd` の和と一致 MUST する。

守備範囲: この機能が受け取る入力は、`gh api graphql` が返す GitHub の応答と、台帳または会話ログの行に限る。拾いたい誤りは、エピックの額がエピックの番号を触った区間だけの額（ほぼ 0）のまま出ること・一部の子しか読めていない額を合計として出すこと・循環や深い入れ子で `gh` を呼び続けることの 3 つ。次のことは誤ったまま通ることを許す: GitHub の子 issue の仕組みに登録されていない issue（本文の表に書いてあるだけの issue）は子として数えない／別のリポジトリの子 issue は、その作業が手元の台帳にあっても数えない／open の子 issue では、結び付いている open の PR のブランチも数える（作業の途中の額になる）／`Closes` で結び付いていない PR は数えない／エピックのコメントに hook が積む行は、子 issue の分を含む（spec `cost-ledger-timeline` の「子 issue を持つ issue に積む行は子 issue の分を含む」）。hook が子を辿れなかった回の行は区間だけの累計で、きっかけの欄に `子 issue 照会失敗` が付く／子 issue を 1 件だけ `/cost <その番号>` で見た額（区間だけ）は、エピックの内訳のその issue の額（閉じた PR の分を含む）と一致しない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

守備範囲（題名とリポジトリ名の表示）: 出どころは、作業ディレクトリのリポジトリの issue の題名と、子 issue のリポジトリ名（どちらも `gh api graphql` の応答）。拾いたい誤りは、題名に入った改行で内訳に偽の行が足されて見えることと、ESC などの制御文字で端末の表示が書き換えられることの 2 つ。次のものは通す: 題名の自然文の内容（指示のように読める文を含む。文としての内容は検査しない）／絵文字や全角文字（ただしゼロ幅接合子 U+200D は `Cf` なので空白になり、接合子でつないだ絵文字は分かれて表示される）／`--json` の `title` と `repo`。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

以下の Scenario の共通のデータは、spec `cost-ledger-attribution` の「エピックの合計は、エピック自身と子孫の issue が数える行を 1 回ずつ足した額である」の Scenario の共通のデータと同じ（#10 の子が #11 と #12。どの行も $1.00）。題名は #10 が `epic`、#11 が `child a`、#12 が `child b`、状態は #10 と #12 が open、#11 が closed。

#### Scenario: 推定で数えた子 issue の行が合計に入り、件数と額が示される
- **WHEN** 子 issue #11 を触った行の `cwd` が削除済みで、推定によって作業ディレクトリのリポジトリに決まり、その行のブランチがどのヘッドブランチとも一致しない状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** その行の額は #11 の `own_usd` と `total_usd` に入り、`unknown_repo_messages` には数えられず、`inferred_repo_messages` と `inferred_repo_usd` がその行の件数と金額になる

#### Scenario: 別のリポジトリに推定された同じ番号の行はエピックに数えない
- **WHEN** 別のリポジトリの置き場の削除済みの `cwd` で子 issue と同じ番号の issue を触った行があり、推定でその別のリポジトリに決まる状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** その行は `total_usd` にも `unknown_repo_usd` にも `inferred_repo_usd` にも入らない

#### Scenario: 子ごとの額と合計が出る
- **WHEN** 共通のデータで、#11 を閉じた PR が #300（`feat/a`）、#12 を閉じた PR が #301（`feat/b`）のとき、`cost_ledger.py cost 10` を実行する
- **THEN** 1 行目は `コスト: $7.00 / ¥1,050 @150 — issue #10 (acme/ra) 帰属: 子 issue 込み` で、出力に `  #10 open $7.00（自身 $1.00） — epic`・`    #11 closed $4.00 — child a`・`    #12 open $2.00 — child b` の 3 行がこの順にある

#### Scenario: 合計が子の額の和と一致する
- **WHEN** 共通のデータから r4（issue #10 の区間の行）を除いた会話ログで、#11 を閉じた PR が #300（`feat/a`）、#12 を閉じた PR が #301（`feat/b`）のとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `total_usd` は 6.0 で、#11・#12 の `usd`（4.0・2.0）の和と一致し、`children_usd` は 6.0、`self_usd` は 0.0 で、表示の 1 行目の金額は `$6.00`、出力に `  子 issue の合計: $6.00` と `  issue #10 自身: $0.00` の行がある

#### Scenario: エピック自身の区間があるときは、子 issue の合計に自身の額を足す
- **WHEN** 「子ごとの額と合計が出る」と同じ状態（共通のデータ。issue #10 の区間の行 r4 がある）で `cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `children_usd` は 6.0 で #11・#12 の `usd`（4.0・2.0）の和と一致し、`self_usd` は 1.0、`total_usd` は 7.0（`children_usd` と `self_usd` の和。`issues` の `own_usd` の和とも一致）で、出力に `  子 issue の合計: $6.00` と `  issue #10 自身: $1.00` の 2 行がこの順にあり、1 行目の金額は `$7.00`

#### Scenario: 2 件の子が同じ PR を参照する
- **WHEN** 共通のデータで、#11 と #12 のどちらも PR #300（`feat/a`）が閉じたとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** `total_usd` は 6.0 で、表示の #12 の行は `    #12 open $1.00 — child b（単独 $3.00、PR #300 は #11 に計上）` であり、JSON の #12 の `closing_prs` は `[{"number": 300, "branch": "feat/a", "usd": 2.0, "counted_in": 11}]`

#### Scenario: 孫を辿る
- **WHEN** 共通のデータに、#12 の子 issue #13（題名 `grandchild`、open、閉じた PR なし）と、`main` で issue #13 の区間に帰属する行 r9（$1.00）を足し、#11 と #12 を閉じた PR が無いとき、`cost_ledger.py cost 10` を実行する
- **THEN** 出力に `    #12 open $2.00（自身 $1.00） — child b` と `      #13 open $1.00 — grandchild` がこの順にあり、1 行目の金額は `$5.00`

#### Scenario: 循環していても止まる
- **WHEN** #10 の子が #11、#11 の子が #10 だと `gh` が答える状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** 終了コードは 0 で、`issues` は #10 と #11 の 2 件で、GraphQL の呼び出しは 2 回

#### Scenario: 別のリポジトリの子は数えない
- **WHEN** #10 の子が #11（acme/ra）と #5（acme/other。子を 3 件持つ）だと `gh` が答える状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** `issues` は #10 と #11 の 2 件、`skipped` は `[{"repo": "acme/other", "number": 5, "parent": 10}]` で、GraphQL の呼び出しは 1 回

#### Scenario: 子の問い合わせが失敗する
- **WHEN** issue の問い合わせは #10 の子の数を 2 と答え、GraphQL の呼び出しだけが失敗する状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 子が 100 件を超える
- **WHEN** `subIssues` の `pageInfo.hasNextPage` が真の応答を返す状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 応答の形が崩れている
- **WHEN** 子 #11 を閉じた PR の `headRefName` が空文字の応答を返す状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空

#### Scenario: 8 段より深い
- **WHEN** #10 から子を 1 件ずつ 8 段辿った先の issue が、さらに子を 1 件持つと `gh` が答える状態で `cost_ledger.py cost 10` を実行する
- **THEN** 終了コードは 2 で、標準出力は空で、GraphQL の呼び出しは 8 回

#### Scenario: 題名が長い
- **WHEN** 子 #11 の題名が 50 文字のとき `cost_ledger.py cost 10` を実行する
- **THEN** #11 の行の題名は先頭 39 文字と `…` の 40 文字

#### Scenario: 題名の制御文字は空白にして表示する
- **WHEN** 子 #11 の題名が `x`・ESC（U+001B）・`[2Ky`・改行・空白 4 つ・`#99 closed $9.00 — fake`・U+202E・`z` をこの順につないだ文字列のとき、`cost_ledger.py cost 10` と `cost_ledger.py cost 10 --json` を実行する
- **THEN** 標準出力に ESC と U+202E は無く、#11 の行は `    #11 closed $2.00 — x [2Ky #99 closed $9.00 — fake z` の 1 行で、内訳の行（`#<番号> <状態>` で始まる行）は #10 と #11 の 2 行だけであり、JSON の #11 の `title` は GitHub から取った値と一致する

#### Scenario: fork の PR は数えない
- **WHEN** 共通のデータで、#11 を閉じた PR として #300（`feat/a`、`isCrossRepository` が真）だけを返す状態で `cost_ledger.py cost 10 --json` を実行する
- **THEN** #11 の `closing_prs` は空の配列で、`own_usd` は 2.0

### Requirement: エピックの集計で呼ぶ `gh` は子を持つ issue ごとに 1 回で、台帳の読み取りは issue の数に比例しない
システムが `cost_ledger.py cost <エピックの番号>` 1 回で呼ぶ `gh` は、番号の判別の 2 回（PR の問い合わせと issue の問い合わせ）に、子を持つ対象の issue の数（エピック自身を含む）を足した回数で MUST ある。GraphQL の呼び出しは子を持つ対象の issue 1 件につき 1 回で、子を持たない子 issue の数と、issue を閉じた PR の数では増えてはなら MUST NOT ない（子が 1 件ずつ入れ子になった鎖では、子を持つ issue の数が段の数だけあるので、その数だけ呼ぶ）。`COST_LEDGER_PATH` があるとき、台帳への差分の追記は 1 回の呼び出しで 1 回だけと SHALL し、台帳を読み通す回数は子 issue の数にも PR の数にも比例してはなら MUST NOT ない（区間の行は対象の issue すべての分を、PR の分はヘッドブランチすべての分を、それぞれまとめて読む）。

#### Scenario: 子が 2 件で孫が無い
- **WHEN** 子 issue を 2 件持ち、それぞれに閉じた PR が 1 件ずつある issue #10 に `cost_ledger.py cost 10` を実行する
- **THEN** `gh` が呼ばれた回数は 3 回（うち GraphQL は 1 回）

#### Scenario: 子の 1 件が孫を持つ
- **WHEN** 「孫を辿る」の状態で `cost_ledger.py cost 10` を実行する
- **THEN** `gh` が呼ばれた回数は 4 回（うち GraphQL は 2 回）

#### Scenario: 子を持たない issue と PR の回数
- **WHEN** 子 issue を持たない issue #12 と、PR #300 に、それぞれ `cost_ledger.py cost <番号>` を実行する
- **THEN** `gh` が呼ばれた回数は issue が 3 回（うち GraphQL は閉じた PR の問い合わせの 1 回）、PR が 1 回で PR の GraphQL は 0 回

