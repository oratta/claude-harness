# cost-ledger-attribution Specification

## Purpose
会話ログの 1 行から取る事実と、そこから帰属を導く関数の分離。帰属の鍵はブランチ（第 1 の鍵）と（リポジトリ識別子, issue 番号）の組（第 2 の鍵）の 2 本立てで、区間は `sessionId` ごとに投稿を境界にして切る。
## Requirements
### Requirement: 行から抽出する事実
システムは会話ログの各行から、帰属を導く前の**事実だけ**を抽出する段を持 MUST つ。区間の帰属は投稿が来るまで確定しないため、1 行ずつ追記する経路（後続の台帳）が書けるのは導いた帰属ではなく事実に限られる。抽出する事実は次のとおりと SHALL する。

- `requestId`（無ければ `uuid`）— 重複排除の鍵
- `timestamp` — 区間を並べる鍵
- `sessionId` — 区間を切る単位
- `isSidechain` — サブエージェントの行かどうか
- リポジトリ識別子 — `cwd` から導く（次の Requirement）
- `gitBranch`
- `message.model`
- トークン 5 種 — 入力 `usage.input_tokens`、出力 `usage.output_tokens`、キャッシュ書込 5m `usage.cache_creation.ephemeral_5m_input_tokens`、キャッシュ書込 1h `usage.cache_creation.ephemeral_1h_input_tokens`、キャッシュ読出 `usage.cache_read_input_tokens`
- 触った issue 番号の列 — その行のツール呼び出しから拾う（次の Requirement）
- 投稿の印 — その行が区間の境界かどうか（次の Requirement）

キャッシュ書込の 5m と 1h がどちらも無い、または両方 0 のとき、システムは `usage.cache_creation_input_tokens` を 5m 扱いで読 MUST む。

#### Scenario: 事実の抽出が帰属を含まない
- **WHEN** 1 行を読んで事実を抽出する
- **THEN** その行だけで確定する事実のみが得られ、区間の帰属先 issue は含まれない

#### Scenario: キャッシュ書込の内訳が無い古い行
- **WHEN** 行の `usage` に `cache_creation` が無く `cache_creation_input_tokens` だけがある
- **THEN** その値はキャッシュ書込 5m として読まれる

### Requirement: 区間分割は事実の列に対する関数
システムは区間分割を、抽出済みの事実の列だけを入力とする関数と SHALL する。会話ログを再度読み直さずに、事実の列から同じ区間分割が再現でき MUST る。

#### Scenario: 事実の列だけから区間が再現できる
- **WHEN** 抽出済みの事実の列を入力として区間分割を実行する
- **THEN** 会話ログを読み直さずに、同じ区間と同じ帰属が得られる

### Requirement: 会話ログの読み取りと重複排除
システムは Claude Code の会話ログを読み、アシスタントメッセージの行から事実を抽出 SHALL する。ログのルートは `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects` と SHALL し、リポジトリ内のファイルに固定パスを書いてはなら MUST NOT ない。同一の行が複数のファイルに現れることがあるため、`requestId` を鍵として重複を排除 MUST する。

期待する形になっていない行（有効な JSON だが `message` や `usage` の型が違う行など）で集計を中断してはなら MUST NOT ない。その行は集計から外し、**外した件数を出力に出** SHALL す。黙って捨てると、集計から何がこぼれたのかが誰にも見えなくなる（リポジトリ不明・未帰属と同じ扱い）。

#### Scenario: 構造が壊れた行がログに混ざる
- **WHEN** 有効な JSON だが `message.usage` が文字列になっている行がログにある
- **THEN** 集計は中断せず、その行は外され、外した件数が出力に出る

#### Scenario: 同じ requestId が複数ファイルに現れる
- **WHEN** 同一の `requestId` を持つ行が 2 つ以上のログファイルに存在する
- **THEN** その行のトークンは 1 回だけ集計される

#### Scenario: 設定ディレクトリを移した環境
- **WHEN** `CLAUDE_CONFIG_DIR` が既定と異なる場所に設定されている
- **THEN** その配下の `projects` が読まれる

#### Scenario: リポジトリ内に固定パスが無い
- **WHEN** リポジトリ内を検索する
- **THEN** ログのルートを固定した絶対パスがどのファイルにも書かれていない

### Requirement: ブランチによる帰属（第 1 の鍵）
システムは各行の `gitBranch` を第 1 の帰属の鍵と SHALL する。サブエージェントの行（`isSidechain: true`）にも `gitBranch` が入るため、サブエージェントの消費も同じブランチへ帰属 MUST する。

#### Scenario: サブエージェントの行を含めて集計する
- **WHEN** あるブランチのコストを求め、そのブランチに `isSidechain: true` の行が含まれている
- **THEN** サブエージェントの行のトークンも合計に含まれる

#### Scenario: gitBranch を持たない行
- **WHEN** 行に `gitBranch` が無い、または空文字である
- **THEN** その行はブランチへ帰属せず、集計から静かに落ちずに未帰属として扱われる

### Requirement: リポジトリ識別子と worktree の畳み込み
システムは各行の `cwd` から `git -C <cwd> rev-parse --path-format=absolute --git-common-dir` を用いてリポジトリ識別子を求め、worktree のコストを親リポジトリへ畳み込 MUST む。`--path-format=absolute` を省いてはなら MUST NOT ない。省くとメイン worktree で相対の `.git` が返り、識別子が cwd ごとに割れる。

#### Scenario: worktree 上の作業を親リポジトリに寄せる
- **WHEN** `cwd` が親リポジトリの worktree を指している
- **THEN** そのコストは worktree ごとではなく親リポジトリの集計に含まれる

#### Scenario: メイン worktree でも同じ識別子になる
- **WHEN** 同じリポジトリのメイン worktree と副 worktree の両方に行がある
- **THEN** 両方が同一のリポジトリ識別子に畳まれる

#### Scenario: cwd が既に存在しない
- **WHEN** `cwd` のディレクトリが削除済みで `git rev-parse` が失敗する
- **THEN** 集計は中断せず、その行のリポジトリ識別子は「不明」として記録される

### Requirement: issue による帰属（第 2 の鍵）
issue 番号はリポジトリ内でしか一意でないため、システムは第 2 の帰属の鍵を **（リポジトリ識別子, issue 番号）の組** と SHALL する。issue 番号だけを鍵にしてはなら MUST NOT ない。

issue 番号は各行の `Bash` ツールの `command` から、`gh issue view`・`gh issue comment`・`gh issue edit`・`gh issue close`・`gh issue develop` に渡された番号として拾 SHALL う。拾うこの 5 つのサブコマンドは設計の根拠になった計測（測り方と数字は archive 済みの change `cost-ledger-aggregation` の design に記録。計測スクリプトは change `cost-ledger-gate-report` で削除した）と一致させるが、走査する場所は**実行されたコマンド**に限 SHALL る。その計測はツール呼び出しの入力全体を文字列にして当てていたため、サブエージェントへの指示文やファイル編集の中身に書かれた `gh issue view <番号>` という文字列にも反応した。実行していないコマンドの文字列を根拠に帰属させてはなら MUST NOT ない。

#### Scenario: 実行していないコマンドの文字列は帰属しない
- **WHEN** `Agent` の指示文や `Edit`・`Write` の本文に `gh issue view 999` という文字列が含まれるが、そのコマンドは実行されていない
- **THEN** その行は issue 999 に帰属しない

#### Scenario: 別リポジトリの同じ番号が混ざらない
- **WHEN** リポジトリ A の issue 108 とリポジトリ B の issue 108 の両方に行が存在する
- **THEN** それぞれの組は別の帰属先として扱われ、合算されない

#### Scenario: main 上の作業が issue に帰属する
- **WHEN** main ブランチ上のセッションで `gh issue comment 148` が実行されている
- **THEN** そのセッションの該当区間のコストは、そのリポジトリの issue 148 へ帰属する

#### Scenario: close と develop も鍵になる
- **WHEN** セッション中に `gh issue close 273` または `gh issue develop 273` だけが実行されている
- **THEN** その区間は issue 273 へ帰属する

#### Scenario: issue 番号を一度も触っていないセッション
- **WHEN** セッション中に上記 5 つのコマンドが一度も実行されていない
- **THEN** そのセッションのコストはどの issue にも帰属せず、未帰属として扱われる

### Requirement: セッションごとの区間分割
1 セッションが複数の issue を触るため、システムはコストを区間に分割して帰属させ MUST る。区間は **`sessionId` ごとに `timestamp` 順に並べて**切 MUST る。ブランチ全体を時刻順に並べて切ってはなら MUST NOT ない。利用者は複数セッションを並行して走らせるため、ブランチ単位で並べると別セッションの行が互いの区間に混ざる。

区間の境界は投稿とし、投稿は `gh pr comment`・`gh issue comment`・`gh pr create`・`gh pr ready` の 4 つと SHALL する。この 4 つは設計の根拠になった計測（測り方と数字は archive 済みの change `cost-ledger-aggregation` の design に記録）が境界にしていた集合と一致させる。区間ごとに、その区間で直近に触った issue へコストを寄せる。

ブランチの総額は、そのブランチに属する各セッションの区間の合計を足したものと SHALL する。

#### Scenario: 1 セッションが複数 issue を触る
- **WHEN** 1 セッションで issue 148 に投稿したあと issue 213 に投稿している
- **THEN** 最初の投稿までの区間は issue 148 へ、そのあとの区間は issue 213 へ帰属する

#### Scenario: 並行する 2 セッションの区間が混ざらない
- **WHEN** 同じブランチで 2 つのセッションが時刻の重なる区間を持つ
- **THEN** 区間は `sessionId` ごとに切られ、一方の投稿が他方の区間を区切ることはない

#### Scenario: Draft から Ready への切り替えが境界になる
- **WHEN** セッション中に `gh pr ready 271` が実行されている
- **THEN** その行は区間の境界として扱われる

#### Scenario: 区間の合計がブランチの総額と一致する
- **WHEN** あるブランチの区間ごとのコストをすべて足す
- **THEN** その合計はそのブランチの総額と一致する（丸め誤差を除く）

### Requirement: 2 つの鍵は独立である
第 1 の鍵（ブランチ）と第 2 の鍵（リポジトリ識別子と issue 番号の組）は独立で、同じ行が両方に帰属すること SHALL がある。feature ブランチ上で `gh issue view 273` を実行した行は、そのブランチにも issue 273 にも帰属する。したがって `/cost <PR番号>` と `/cost <issue番号>` の値は重なることがあり、足し合わせて総額としてはなら MUST NOT ない。

#### Scenario: feature ブランチ上で issue を触る
- **WHEN** feature ブランチ上のセッションで `gh issue view 273` が実行されている
- **THEN** その行のコストはブランチの合計にも issue 273 の合計にも含まれる

