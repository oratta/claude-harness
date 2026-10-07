# cost-ledger-attribution Specification

## Purpose
会話ログの 1 行から取る事実と、そこから帰属を導く関数の分離。帰属の鍵はブランチ（第 1 の鍵）と（リポジトリ識別子, issue 番号）の組（第 2 の鍵）の 2 本立てで、区間は `sessionId` ごとに投稿を境界にして切る。
## Requirements
### Requirement: 行から抽出する事実
システムは会話ログの各行から、帰属を導く前の**事実だけ**を抽出する段を持 MUST つ。区間の帰属は投稿が来るまで確定しないため、1 行ずつ追記する経路（後続の台帳）が書けるのは導いた帰属ではなく事実に限られる。抽出する事実は次のとおりと SHALL する。

- `requestId`（無ければ `uuid`）— 重複排除の鍵
- `uuid` — その行の `uuid`（無ければ空文字）。同じ応答の複製された先頭の行と後続行を区別する鍵（次の節の Requirement）
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
1 セッションが複数の issue を触るため、システムはコストを区間に分割して帰属させ MUST る。区間は **`sessionId` ごとに `timestamp` 順に並べて**切 MUST る。ブランチ全体を時刻順に並べて切ってはなら MUST NOT ない。利用者は複数セッションを並行して走らせるため、ブランチ単位で並べると別セッションの行が互いの区間に混ざる。同じ `timestamp` の事実の並びは、同じ応答の補足の事実について「同じ応答の 2 行目以降の issue と投稿の印」の要件が定める。

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
第 1 の鍵（ブランチ）と第 2 の鍵（リポジトリ識別子と issue 番号の組）は独立で、同じ行が両方に帰属すること SHALL がある。feature ブランチ上で `gh issue view 273` を実行した行は、そのブランチにも issue 273 にも帰属する。したがって `/cost <PR番号>` と `/cost <issue番号>` の値は重なることがあり、足し合わせて総額としてはなら MUST NOT ない。2 つの鍵の値を合わせた額を出してよいのは、「issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である」が定める issue の合計だけと MUST する（重なる行を区間の側から除いてから足す）。

#### Scenario: feature ブランチ上で issue を触る
- **WHEN** feature ブランチ上のセッションで `gh issue view 273` が実行されている
- **THEN** その行のコストはブランチの合計にも issue 273 の合計にも含まれる

### Requirement: 同じ応答の 2 行目以降の issue と投稿の印
Claude Code は 1 回の API 応答を、中身のブロックごとに別の行として会話ログに書き、どの行も同じ `requestId` を持つ。システムは、各会話ログのファイルの中で同じ `requestId` が最初に現れる行を**先頭の行**とし、先頭の行から通常の事実を 1 つ出 MUST す（今までどおり。事実は先頭の行の `uuid` を `uuid` の欄に持つ）。同じファイルでそれより後に現れる行を**後続行**と呼ぶ。

後続行が、触った issue 番号の列か投稿の印を持つとき、システムはその行のぶんの**補足の事実**を 1 つ出 MUST す。補足の事実は、その行から `scan_tool_calls` と同じ規則（実行された `Bash` の `command` だけを見る）で拾った issue 番号と投稿の印、`timestamp`・`sessionId`・`isSidechain`・リポジトリ識別子・`gitBranch`・`message.model` を持ち、トークン 5 種は全部 0 と SHALL する。`request_id` は `<元の requestId>#<その行の uuid>`、`continuation` は真と SHALL する。さらに、補足の事実は元の会話ログのファイルの中でのその行の行頭のバイト位置を `source_offset`（ファイルの先頭を 0 とする整数）として持 MUST つ。位置はデコードや行の絞り込みより前の生のバイトから数え、日本語・不正な UTF-8・CRLF があってもずれてはならない。通常の事実は `source_offset` を持たない。issue 番号も投稿の印も持たない後続行や、`uuid` を持たない後続行は、補足の事実を出さず捨てて MUST よい。

別のファイルに複製された（resume・fork による）会話ログでは、複製された先頭の行も、そのファイルの中では先頭の行である。複製された先頭の行から補足の事実を出してはなら MUST NOT ない。この区別のため、システムは通常の事実の `uuid`（先頭の行の `uuid`）を台帳の行に持 MUST つ。既に台帳にある応答の先頭の行を、別のファイルや後の同期で読んだときは、その行の `uuid` が台帳の先頭の行の `uuid` と同じなら先頭の行として捨て、違えば後続行として扱う。台帳に `uuid` の無い古い行は、読み直し（`ledger-sync --rescan`）の中で、そのファイルで最初に現れる行を先頭の行として扱う。

1 つの応答のトークンと金額は先頭の行の分だけを数え、後続行のトークンを数えてはなら MUST NOT ない。補足の事実はメッセージ数（`messages`）に数えて MUST NOT ならない。補足の事実の鍵に `uuid` を使うのは、同じ応答の別の後続行が同じ `timestamp` を持つことがあるため（実ログの計測は design の決定 2）。

区間分割（`split_intervals`）は、同じ `sessionId` の事実を次の順で比べて並べ MUST る: `timestamp`、元の `requestId`（補足の事実では `request_id` の末尾の `#<uuid>` を除いたもの）、通常の事実を先・補足の事実を後、補足の事実どうしは `source_offset` の数値順（同値なら `request_id` 順）。これにより、同じ応答の同じ `timestamp` の後続行は元の会話ログの順に並び、`uuid` の辞書順で投稿の印の前後が入れ替わらない。異なる `requestId` の間には、元の会話ログの順を保証せず辞書順を使う。`source_offset` を持たない補足の事実（位置を保存する前の版が書いたもの）が混ざる、同じ `timestamp`・同じ元の `requestId` のグループは、順序を復元できないので、そのグループ全体を `request_id` 順に戻 SHALL す。別のファイルから出た同じ応答の補足の事実どうしでは `source_offset` が共通の尺度にならないので、順序は保証しない（守備範囲の外）。

守備範囲: 入力は、Claude Code が書く会話ログの assistant 行で、同じ `requestId` が複数の行に現れるもの。拾いたい誤りは、後続行にだけある `gh issue view/comment/edit/close/develop <番号>` と投稿（`gh pr comment`・`gh issue comment`・`gh pr create`・`gh pr ready`）が帰属と区間に反映されないことと、複製された会話ログの先頭の行から補足の事実が増えて区間が余分に切れること。通ることを許す入力は、複製された履歴で行の `uuid` が元と異なるもの（実ログで 207 件中 3 件。補足の事実が重複し、区間が 1 つ余分に切れることがある。トークンも金額も 0）、同じ応答の行が別のファイルに分かれて書かれたもの、`uuid` が台帳に無い古い行を `--rescan` を使わずに読んだ場合の後続行の取りこぼし、後続行が `uuid` を持たない行（補足の事実を出さない）、位置を保存する前の版が台帳に書いた補足の事実（`source_offset` が無く、同時刻のグループの順序を復元できない）である。後続行のトークンの取り込みと、会話ログの中身が正しいかの検証はしない。新しく見つかった複製や取りこぼしの穴を塞ぎ切ることを、この要件の完了条件にしない。

#### Scenario: 2 行目以降にだけ gh issue view がある
- **WHEN** 同じ `requestId` の 1 行目（考えた内容）に issue の記述が無く、2 行目に `gh issue view 42` を実行する `Bash` がある
- **THEN** 事実の列に、`issues` が `["42"]` の補足の事実が 1 つ入る

#### Scenario: トークンと金額は 1 回分のまま
- **WHEN** 同じ `requestId` の 3 行が全部同じ `usage` を持ち、2 行目に `gh issue view 42` がある
- **THEN** 事実の列のトークンの合計と金額は 1 行だけの場合と同じで、補足の事実のトークンは 5 種とも 0

#### Scenario: 2 行目以降にだけ投稿の印がある
- **WHEN** 同じ `requestId` の 2 行目にだけ `gh pr comment 300` を実行する `Bash` がある
- **THEN** 区間はその行で閉じる

#### Scenario: 実行していない文字列は拾わない
- **WHEN** 後続行が、`Edit` の本文や `Agent` の指示文に `gh issue view 999` という文字列を含むだけで、`Bash` で実行していない
- **THEN** 補足の事実は出ず、issue 999 へは帰属しない

#### Scenario: メッセージ数に数えない
- **WHEN** 応答 1 つ（3 行、2 行目に `gh issue view 42`）を集計する
- **THEN** メッセージ数は 1 で、事実の列の件数（補足を含む）とは別に数えられる

#### Scenario: 同じ会話ログを 2 回読んでも補足の事実は 1 つ
- **WHEN** 同じ会話ログの行の列を、同じ `seen` を共有して 2 回読む
- **THEN** 補足の事実は 1 つだけ出る

#### Scenario: 複製されたログの先頭の行は後続行ではない
- **WHEN** 会話ログ A に応答の 1 行目（`gh pr comment 300` を実行する `Bash` を持つ）と 2 行目があり、会話ログ B に A と同じ `uuid` の同じ 2 行が複製されている
- **THEN** 事実の列は、1 行目の通常の事実 1 つだけ（2 行目に印が無ければ補足の事実は 0）で、区間は印の位置で 1 回だけ閉じる

#### Scenario: 複製されたログの後続行は 1 つだけ
- **WHEN** 会話ログ A と B に同じ `uuid` の後続行（`gh issue view 42`）が複製されている
- **THEN** 補足の事実は 1 つだけ出る

#### Scenario: 同じ時刻の別の後続行がどちらも残る
- **WHEN** 同じ応答の 2 つの後続行が同じ `timestamp` を持ち、それぞれ `gh issue view 42` と `gh issue view 43` を実行する
- **THEN** 補足の事実は 2 つ出る（`uuid` が違うので鍵が衝突しない）

#### Scenario: 同じ時刻の後続行は元の会話ログの順で区間を切る
- **WHEN** 同じ `requestId`・同じ `timestamp` の後続行が、会話ログの順に `gh issue view 41`（`uuid` が `u2`）、`gh pr comment 300`（`uuid` が `uz`）、`gh issue view 42`（`uuid` が `ua`）で並んでいる（`uuid` の辞書順は実行順と逆）
- **THEN** 区間は投稿の行で閉じ、閉じた区間の issue は 41、次の区間の issue は 42。通常の事実が先頭で、トークン・総額・メッセージ数は 1 応答ぶん

#### Scenario: 事実の入力順を逆にしても区間は同じ
- **WHEN** 上の事実の列を逆の順で `split_intervals` に渡す
- **THEN** 区間の帰属と `request_ids` の並びは同じ

#### Scenario: 位置は生のバイトから数える
- **WHEN** 日本語の行、読み捨てられる行、CRLF の行、書きかけの最後の行を含む会話ログから補足の事実を出す
- **THEN** 各補足の事実の `source_offset` は、ファイルの先頭からその行の行頭までのバイト数と一致する（直読み・同期・分割した同期のどれでも同じ）

#### Scenario: 位置の無い補足の事実はそのグループだけ request_id 順に戻る
- **WHEN** 同じ `timestamp`・同じ元の `requestId` の補足の事実のうち 1 つ以上が `source_offset` を持たない
- **THEN** そのグループは通常の事実が先、補足の事実は `request_id` 順に並ぶ。別の `timestamp` や別の `requestId` のグループには影響しない

#### Scenario: 補足の事実はキャッシュを含む 5 種のトークンが全部 0
- **WHEN** 先頭の行の `usage` の 5 種（入力・出力・キャッシュ書き込み 5 分と 1 時間・キャッシュ読み取り）が全部非ゼロで、後続行に `gh issue view 42` がある
- **THEN** 補足の事実の 5 種は全部 0 で、金額とメッセージ数は先頭の行だけの場合と同じ

#### Scenario: 同期が分かれても先頭の行は後続行にならない
- **WHEN** 1 回目の取り込みで応答の 1 行目だけを読み、2 回目の取り込みでその 2 行目を読む
- **THEN** 2 行目だけが補足の事実になり、1 行目は 2 回目では事実を出さない

#### Scenario: 単純な和は issue の合計と一致しない
- **WHEN** issue #12 に帰属する区間の行が 3 行（各 $1.00）あり、そのうち 1 行がブランチ `feat/a` の行で、ブランチ `feat/a` の行が全部で 3 行（各 $1.00）ある会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a --json` を実行する
- **THEN** `combined_total_usd` は 5.0 で、`total_usd`（3.0）と PR の分（3.0）の和 6.0 より、重なった 1 行の $1.00 だけ小さい

### Requirement: issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である
システムは「issue の合計」を、次の 2 つの和と SHALL 定める。

- **PR の分**: 渡された PR 1 件ごとに、行のブランチ名がその PR のヘッドブランチと一致する行の合計。`/cost <PR番号>` と同じ引き方で、リポジトリでは絞らない
- **PR の外の分**: その issue に帰属した区間の行（「issue による帰属（第 2 の鍵）」が数える行）のうち、行のブランチ名が、渡された PR のどのヘッドブランチとも一致しない行の合計

システムは同じ行を 2 回数えてはなら MUST NOT ない。同じヘッドブランチを持つ PR が複数渡されたときは、番号のいちばん小さい PR だけを数え、残りは PR の分にも内訳にも入れてはなら MUST NOT ない。PR が 1 件も渡されないとき、issue の合計は `/cost <issue番号>` の値（区間の合計）と同じで MUST ある。入出力トークンとキャッシュトークンの合計も、金額と同じ行の集合から数え SHALL る。

`cost_ledger.py issue <番号>` は `--closing-pr <PR番号>:<ヘッドブランチ>`（繰り返し可）を受け、JSON 出力に次の鍵を足 MUST す。既存の鍵（`total_usd`・`intervals` など）の値と、表示の 1 行目は変えてはなら MUST NOT ない。

- `closing_prs`: 数えた PR の `{"number", "branch", "usd"}` の配列。番号の昇順。`--closing-pr` が無ければ空の配列
- `outside_pr_usd`: PR の外の分。`--closing-pr` が無ければ `total_usd` と同じ値
- `combined_total_usd`: issue の合計。`closing_prs` の `usd` の和と `outside_pr_usd` の和に等しい

`--closing-pr` を渡した表示（`--json` 無し）では、1 行目の下に、合計と内訳（PR ごとの額と、PR の外の額）を 1 行で SHALL 出す。`--closing-pr` の値は最初の `:` で 2 つに分け、前が 1 以上の整数、後ろが空でない文字列のときだけ受け、それ以外は標準エラーに理由を書いて終了コード 2 を返 MUST す。

守備範囲: この計算が受け取る入力は、台帳または会話ログの行と、`--closing-pr` の引数（hook の裏のプロセスが GitHub の応答から組み立てたもの、または人が手で打ったもの）に限る。拾いたい誤りは、同じ行を PR の分と区間の分の両方で数えること・同じブランチの行を 2 件の PR で 2 回数えること・形の崩れた `--closing-pr`（`704`・`:feat`・`x:feat`・`704:`）を黙って読み飛ばして、PR を数えていない値を合計として返すことの 3 つ。次の入力は誤ったまま通ることを許す: 実在しない PR 番号や、その PR のものではないブランチ名を渡した `--closing-pr`（`999:main` など）は、そのブランチの行の合計がその番号の PR の分として出る（PR とブランチの対応は `gh` を呼ばないと確かめられない）／同じ名前のブランチを別の作業や別のリポジトリで使い回しているときは、その行も PR の分に入る（`/cost <PR番号>` と同じ）／手元の台帳に無い作業（別の PC や別の人の作業）は数えられず、その PR の分は 0 になる／1 本の PR が複数の issue を閉じるときは、その PR の分が各 issue の合計に全額入る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 重なった行を二重に数えない
- **WHEN** issue #12 に帰属する区間の行が 3 行（各 $1.00。2 行はブランチ `main`、1 行はブランチ `feat/a`）あり、ブランチ `feat/a` の行が全部で 3 行（各 $1.00。うち 1 行が前述の区間の行）ある会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a --json` を実行する
- **THEN** `total_usd` は 3.0、`closing_prs` は `[{"number": 300, "branch": "feat/a", "usd": 3.0}]`、`outside_pr_usd` は 2.0、`combined_total_usd` は 5.0（6.0 ではない）

#### Scenario: 閉じた PR が 0 件なら `/cost` と同じ値
- **WHEN** issue #12 に帰属する区間がある会話ログで、`--closing-pr` を付けずに `cost_ledger.py issue 12 --json` と `cost_ledger.py cost 12` を実行する
- **THEN** `closing_prs` は空の配列で、`combined_total_usd` と `outside_pr_usd` は `total_usd` と同じ値であり、その金額は `cost 12` の 1 行目の金額と一致する

#### Scenario: PR が 2 件
- **WHEN** 重なった行を二重に数えない Scenario の会話ログに、ブランチ `feat/b` の行が 2 行（各 $1.00。どれも issue #12 の区間の外）あり、`cost_ledger.py issue 12 --closing-pr 301:feat/b --closing-pr 300:feat/a --json` を実行する
- **THEN** `closing_prs` は番号 300・301 の順で `usd` が 3.0・2.0、`outside_pr_usd` は 2.0、`combined_total_usd` は 7.0

#### Scenario: 同じヘッドブランチの PR が 2 件
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、`cost_ledger.py issue 12 --closing-pr 305:feat/a --closing-pr 300:feat/a --json` を実行する
- **THEN** `closing_prs` は番号 300 の 1 件だけで、`combined_total_usd` は 5.0

#### Scenario: 手元に行が無い PR
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、どの行にも無いブランチ名を渡して `cost_ledger.py issue 12 --closing-pr 300:feat/none --json` を実行する
- **THEN** `closing_prs` は `usd` が 0 の 1 件で、`outside_pr_usd` と `combined_total_usd` は 3.0

#### Scenario: 表示に合計と内訳が出る
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a` を実行する
- **THEN** 1 行目は `--closing-pr` を付けない場合と同じで、出力に `$5.00`・`PR #300 $3.00`・`PR 外 $2.00` を含む行が 1 行ある

#### Scenario: 形の崩れた `--closing-pr`
- **WHEN** `cost_ledger.py issue 12 --closing-pr 300` を実行する（`:` とブランチ名が無い）
- **THEN** 終了コードは 2 で、標準出力は空

