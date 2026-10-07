## MODIFIED Requirements

### Requirement: 行を積むきっかけ
システムは、PostToolUse の hook（`plugins/cost-ledger/scripts/gate-report.sh`）が受け取った `tool_input.command` に次のいずれかが含まれるとき、その対象の PR / issue に行を 1 行積 MUST む。行の「きっかけ」の欄には表の呼び名を SHALL 書く。

| コマンド | きっかけ |
|---|---|
| `gh pr comment` | `PR コメント` |
| `gh issue comment` | `issue コメント` |
| `gh pr ready`（`--undo` を除く） | `Ready` |
| `gh pr close` | `PR クローズ` |
| `gh pr merge` | `マージ` |
| `gh issue close` | `issue クローズ` |
| `gh issue reopen` | `issue 再オープン` |
| 合格ラベル `agent-review:passed` の付与（判定は `cost-ledger-gate-report`） | `ゲート通過` |

`ゲート通過` の対象は PR だけと SHALL する。PR でない issue に合格ラベルを付けても積まない。

これ以外のコマンド（`gh pr view`・`gh issue view`・`gh pr create`・`gh pr reopen`・`gh api` の直叩きでの投稿など）で行を積んではなら MUST NOT ない。コマンドの読み取りは `cost-ledger-gate-report` の付与の判定と同じ規則（同じコマンドの中の単純な代入と `for` の展開、サブシェルの扱い）に従い、コマンドを評価・再実行してはなら MUST NOT ない。文字列として含むだけ（`echo "gh pr comment 300"` など）のコマンドで積んではなら MUST NOT ない。

1 つのコマンドに同じ対象へのきっかけが複数あるとき、システムは行を 1 行だけ積み、きっかけを実行順に `+` でつな SHALL ぐ。

守備範囲: この判定が受け取る入力は、PostToolUse が渡す `tool_input.command`（Claude Code のセッションが Bash ツールで実行したコマンド文字列）に限る。拾いたい誤りは、表に無いコマンドで行を積むこと・コマンドを文字列として含むだけの Bash で行を積むこと・1 つのコマンドで同じ対象に行を 2 行以上積むことの 3 つ。次の入力は誤ったまま通ることを許す: `eval`・`bash -c '...'`・シェル関数・エイリアス・スクリプトファイルの中から実行された `gh pr comment` などは見えず、行が積まれない／`gh` を変数で呼んだもの（`$GH pr comment`）と、`gh` と `pr` のあいだにオプションを置いたもの（`gh -R x pr comment`）は行が積まれない／`false && gh pr comment 300 --body x` のように実行されなかったコメントのコマンドでも行が積まれる（数字は正しく、きっかけの名前だけが実際と合わない）／Bash ツール以外（別の端末、GitHub の画面、auto-merge）で行われた投稿や状態変更は、この hook では行が積まれない（このうち PR のマージと issue のクローズは、`cost-ledger-backfill` が次のセッション開始時に後追いで積む）。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 7 種のコマンドで同じコメントに 1 行ずつ増える
- **WHEN** 同じ PR に `gh pr comment`・`gh pr ready`・`gh pr close`・`gh pr merge` を、同じ issue に `gh issue comment`・`gh issue close`・`gh issue reopen` を、それぞれ別の hook 呼び出しとして順に流す（GitHub の応答は各コマンドが成功した状態を返す）
- **THEN** PR と issue のそれぞれで、コメントの新規作成は最初の 1 回だけで、以後は同じコメントが書き換えられ、流すたびに表の行が 1 行ずつ増える

#### Scenario: 対象外の gh コマンドでは積まない
- **WHEN** `gh pr view 300` や `gh pr create --title x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 文字列として含むだけでは積まない
- **WHEN** `echo "gh pr comment 300 --body x"` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 1 つのコマンドに複数のきっかけ
- **WHEN** `gh pr comment 300 --body x && gh pr ready 300` の hook JSON を流す
- **THEN** #300 に積まれる行は 1 行で、きっかけの欄は `PR コメント+Ready`

## ADDED Requirements

### Requirement: `--backfill` を付けた `timeline` は、既にある行を足さず、手元にコストが無ければ積まない
システムは `cost_ledger.py timeline` に `--backfill` を持 MUST つ。`--backfill` は後追い（`cost-ledger-backfill`）が渡すもので、`--at` には GitHub が記録した出来事の時刻（マージ・クローズの時刻）が入る。付けないときの振る舞いは、この要件で変えてはなら MUST NOT ない。

`--backfill` が付いているとき、システムは次の 2 つを、行を足す前に SHALL 判定する。

1. 既存の本文の表に、`--trigger` の呼び名を `+` 区切りの要素として含む行があり、その行の記録の時刻が「`--at` の 300 秒前」以降であるとき、システムは標準入力の本文をそのまま出力し、終了コード 0 を返 MUST す（行を足さない。合計の行も足さない）。記録と対応しない行（表の行数が記録の数より多いときの先頭の余りの行と、最終行が読めない本文のすべての行）は、時刻を見ずに呼び名だけで判定 SHALL する。合計の行（きっかけの欄が `合計（` で始まる行）は、この判定の対象にしない
2. 1 に当たらず、節目の行の累計の金額・入出力トークン・キャッシュトークンがすべて 0 で、合計の行を積む場合はその累計もすべて 0 のとき、システムは既存の本文があっても何も出力せず、終了コード 3 を返 MUST す

どちらにも当たらないとき、システムは `--backfill` を付けない場合と同じ本文を SHALL 返す（行の時刻・並び順・増分・合計の行・1 行目は既存の要件のまま）。

守備範囲: この判定が受け取る入力は、この hook 自身が書いたコメントの本文と、後追いが渡す `--at`（GitHub の時刻、秒単位）・`--trigger`（`マージ` か `issue クローズ`）に限る。拾いたい誤りは、手で `gh pr merge` / `gh issue close` を実行して積まれた行（時刻は hook が動いた手元の時刻）と同じ出来事の行をもう 1 行積むことと、作業していない PC が累計 0 の行を積んで、別の PC が積んだ累計を打ち消すように見せることの 2 つ。次の入力は誤ったまま通ることを許す: 手元の時計が GitHub の時計より 300 秒を超えて遅れていると、手で積んだ行があっても後追いの行が積まれ、同じ出来事の行が 2 行並ぶ（数字はどちらも正しい）／クローズ・再オープン・クローズが 300 秒以内に続いた issue では、2 回目のクローズの行が積まれない／`issue クローズ` の行はあるが合計の行が無い本文（閉じた PR の問い合わせが失敗した回）に、合計の行だけを後から足すことはしない／最終行が読めない本文では、同じ呼び名の行が 1 行でもあれば、どれだけ前のものでも積まない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 同じきっかけの行が近い時刻にある
- **WHEN** 表の行が 1 行（きっかけ `マージ`、記録の時刻 T+5 秒）の本文を標準入力にして、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 終了コードは 0 で、出力は標準入力の本文と同じ

#### Scenario: 複数のきっかけをつないだ行も見る
- **WHEN** 表の行が 1 行（きっかけ `PR コメント+マージ`、記録の時刻 T+5 秒）の本文を標準入力にして、同じコマンドを実行する
- **THEN** 出力は標準入力の本文と同じ

#### Scenario: 同じきっかけの行が無い
- **WHEN** 表の行が 1 行（きっかけ `PR コメント`、記録の時刻 T−600 秒、累計 $1.00）の本文を標準入力にして、ブランチ `feat/a` の T 以前の累計が $3.00 の会話ログで、同じコマンドを実行する
- **THEN** 表の行は 2 行で、2 行目のきっかけは `マージ`、金額は `$3.00 (+2.00)`

#### Scenario: 前のクローズの行は古い
- **WHEN** 表の行が 1 行（きっかけ `issue クローズ`、記録の時刻 T−3600 秒）の本文を標準入力にして、`timeline --issue 12 --trigger "issue クローズ" --at T --backfill` を実行する（issue #12 に帰属する区間のコストがある）
- **THEN** 表の行は 2 行で、2 行目のきっかけは `issue クローズ`

#### Scenario: 後ろに行があっても時刻の位置に入る
- **WHEN** 表の行が 2 行（`PR コメント` が T−600 秒・累計 $1.00、`PR コメント` が T+600 秒・累計 $3.00）の本文を標準入力にして、ブランチ `feat/a` の T 以前の累計が $2.00 の会話ログで、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 表の行は `PR コメント`・`マージ`・`PR コメント` の順で、`マージ` の行の金額は `$2.00 (+1.00)`、最後の行の金額は `$3.00 (+1.00)`

#### Scenario: 手元にコストが無ければ、既存の本文があっても積まない
- **WHEN** 表の行が 1 行（きっかけ `PR コメント`、累計 $39.62）の本文を標準入力にして、ブランチ `feat/none` の行が 1 つも無い状態で `timeline --pr 300 --branch feat/none --trigger マージ --at T --backfill` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: `--backfill` が無ければ今までと同じ
- **WHEN** 前の Scenario と同じ入力で、`--backfill` を付けずに実行する
- **THEN** 終了コードは 0 で、`マージ` の行が 1 行足された本文が出力される

#### Scenario: 区間が 0 でも閉じた PR の分があれば積む
- **WHEN** issue #13 に帰属する区間が無く、ブランチ `feat/a` に行がある会話ログで、表の行が 1 行（きっかけ `issue コメント`）の本文を標準入力にして `timeline --issue 13 --trigger "issue クローズ" --closing-pr 300:feat/a --at T --backfill` を実行する
- **THEN** 終了コードは 0 で、`issue クローズ` の行と合計の行が足された本文が出力される

#### Scenario: 最終行が読めない本文は呼び名だけで見る
- **WHEN** 目印の行の記録が壊れていて、表にきっかけ `マージ` の行が 1 行ある本文を標準入力にして、`timeline --pr 300 --branch feat/a --trigger マージ --at T --backfill` を実行する
- **THEN** 出力は標準入力の本文と同じ
