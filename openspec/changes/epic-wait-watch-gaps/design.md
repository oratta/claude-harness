# Design

## Context

エピック #1826 の子 #1827 は、元の issue 5 本の受け入れ条件の和集合を 1 本の PR で満たす（分割しない理由: https://github.com/oratta/claude-harness/issues/1827#issuecomment-7212219013 ）。main で確かめた結果は次のとおり。

| 元の issue の条件 | main | 証拠 |
|---|---|---|
| #1084: 記録を残さず質問で止まった子を `wait --watch-stopped` が返す | 満たす | `bats plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats -f 'wait returns a recorded parent wait with no mark'` |
| #1084: 記録を残して止まった子の `stopped` の動きが変わらない | 満たす | `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'wait: --watch-stopped rewrites a stopped record to seen'` |
| #1182: `stop` 空・`running` の子が completed で閉じたら `notify-closed` が促して `notified` | 満たさない | `notify-closed` は `skipped <N> not-stopped`。テスト「notify-closed: a child that is not stopped gets nothing」がこの動きを固定している |
| #1182: `already-done` / `not-closed` / `not-completed` は変わらない | 満たす | `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'notify-closed'` の該当テスト |
| #1598: `stopped-seen` のまま閉じた子も推定する | 満たさない | `infer_done` が `stopped-seen` を外している。テスト「wait infer: waiting, stopped and stopped-seen children are not inferred」 |
| #1620: 親の操作を含む推奨は `stopped` で返る | 満たさない | 判断の値が 3 つだけ |
| #1620: 子の側の行動だけの止まりは通る | 満たす（壊さないことを確かめる） | `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'wait --resolve: a pass is sent'` |
| #1815: 新しいセッションで再開した子に `owner-away` を出さない | 満たさない | `detect_owner_away` は記録だけを見る |
| #1815: 今のセッションの返事待ちは今までどおり出す | 満たす | `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'wait owner-away'` |

## Goals / Non-Goals

Goals:
- 上の表の「満たさない」5 件を満たし、「満たす」の条件を壊さない
- 文書（`epic-loop.md`・`epic-stop.md`・`parent-pass-criteria.md`・`--help`・冒頭のコメント）を新しい振る舞いに合わせる

Non-Goals:
- `wait` が親の操作（子の起動など）を自分で行うこと
- 判断のモデルの読み誤りを機械で塞ぎ切ること
- #1084 の検知の仕組みを変えること（main で満たしている）

## Decisions

### #1182: `notify-closed` は完了の印の無い子に、止まった印の有無によらず促す

選んだ案: `status` が `done` でなければ、`stop` の値（空・`stopped`・`stopped-seen`・`resumed`）と `status`（`running`・`waiting`）によらず送る。`deliver_reply` は送る直前に止まった印・`stop_turn`・会話ログの進みを確かめて `skipped <N> not-stopped` を返すので、7 つ目の引数（`closed_notify` に 1）を足し、`notify-closed` だけがそれを渡す。`closed_notify` が 1 のとき、3 つの確かめ（と `launcher deliver` の直前の `stop_turn` の確かめ直し）はそのまま行い、どれかで止まっていないと決まったら、`skipped` を返さずに `relaunch` を 0 にして送り続ける。止まっていると決まった子は `--relaunch` の有無のとおりに送る。`reply` と `wait --resolve` の確かめは変えない。

理由: 促しは「記録先が閉じたので完了報告を書いて終える」で、主が子のタブで答えたかどうかに関係なく正しい。確かめで送るのを止めると、`stop_turn` が古い子や会話ログが進んだ子に届かず、#1182 と同じ取りこぼしが残る。一方、止まっていないと決まった子はターンの途中か、主が子のタブで会話中でありうる。そこに `--relaunch` を当てると端末を閉じて起動し直し、作業と会話を失わせる（main では 3 つの確かめが起動し直しを止まった子に限っていた）。`relaunch` を 0 にすれば、起動部品の `deliver` は端末があれば子のセッションの端末に送るだけで、閉じない（`epic-launch-orca.sh` の `cmd_deliver`。端末が 0 個なら作る）。

他の案:
- 3 つの確かめを飛ばし、`--relaunch` もそのまま当てる（仕様レビュー 1 周目の前の案）。作業中の子の端末を閉じて起動し直すので採らない
- 記録で今のターンが終わっていると読める子だけ起動し直す（仕様レビューの案 (b)）。「終わっている」の読み方を新しく決めることになり、止まりの確かめと二重になるので採らない
- 端末を閉じることも通してよいと守備範囲に書く（仕様レビューの案 (c)）。要件「Orca 経路の親は止まった子を解決し…」の、主が子のタブで打った入力から始まったターンでは端末を閉じず起動し直さない（MUST）と向きが逆なので採らない
- `stop` が空の子だけを足す（`resumed` と `waiting` は今までどおり外す）。`waiting` はまさに主にマージを頼んだ子の印で、外すと #1182 の場面の半分が残るので採らない
- `deliver_reply` を使わず `notify-closed` に送信の処理を書き直す。起動し直し・別リポジトリの頭・`launcher` の扱いが二重になるので採らない

要件名「止まった印のまま completed で閉じた子に…」は変えない。dev-workflow-develop の他の要件（「Orca 経路」の読み替えの段落）が名前で参照しているため、名前を変えると参照が切れる。中身は「完了の印の無い子」に広げる。Scenario「止まっていない子が閉じたときは返事を送らない」も名前を残し、今も成り立つ場合（`stop` が空で完了の印を付けた子は `already-done` で送らない）に中身を差し替える。落とせるかは `openspec validate epic-wait-watch-gaps --type change --strict` で確かめた: MODIFIED の塊からこの Scenario を外すと「omits scenario(s) the current spec still has」で exit 1 になり、archive も落とすのを拒むと出る（名前を変えるのも同じ）。Scenario「既に完了の印を付けた子には返事を送らない」とは `stop` の値（空と `stopped-seen`）で分ける。推定の要件の Scenario「waiting の子と止まった印の子は推定しない」は、dev-workflow-epic-state の用語（止まった印 = `stopped`、受けた印 = `stopped-seen`）で読めば名前のまま成り立つ。

起動し直しの表 `skills/develop/references/reply-after-idle.md`「そのまま送るか、起動し直すか（子）」との関係: 表の前置きは「表の対象は状態の記録で止まりと決まった子だけ。主が子のタブで始めたターンの子には何も送らず、端末を閉じず、起動し直さない」で、`notify-closed` は本体が表で分類して `--relaunch` を付けるとある。この change のあと `notify-closed` は止まっていない子にも送るので「何も送らず」と食い違う。「端末を閉じず、起動し直さない」は上の選んだ案で守られる。前置きの文は `tests/develop-skill.bats` がそのままの文字列で検査しているので変えず、その後ろに「`notify-closed` の完了の促しだけは止まっていない子にも送る。その子には `--relaunch` を付けても端末を閉じず、起動し直さない」の 1 文を足す（tasks 5.3）。本体が表で `--relaunch` を選んでも、止まっていない子には `notify-closed` が当てないので、表の分類は止まっている子にだけ効く。

main の spec のうち、この振る舞いと食い違う文は、notify-closed の要件の優先の段落で上書きする: 要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」の「`notify-closed` はすでに同じ確認をしており、出力は変わらない」、要件「epic-loop.md は出力語を受けた動作指示を残す」の手順 4 の `skipped <N> not-stopped` の扱い、要件「Orca 経路の親は止まった子を解決し…」の主のタブのターンに返事を送らない文（止まりの解決の規定として残し、端末を閉じない部分は `notify-closed` にも当てる）。dev-workflow-epic-state の spec に `notify-closed` が `not-stopped` を返す・送る直前の確かめを `notify-closed` に掛けると書いた文は無かった（`not-stopped` の行は `mark resumed` と声かけのもの）。要件「dismiss の守備範囲を限る」と要件「Orca 経路の親は止まった子を解決し…」と `epic-stop.md` 手順 8 の「戻さないと記録が `stopped-seen` のまま残り、完了の推定が止まり」は、この change のあと閉じた子には当たらなくなる。spec の文は理由の説明で振る舞いの規定ではないので残し、`epic-stop.md` の文だけを tasks 3.5 で直す。

### #1598: 推定の対象に `stopped-seen` だけを加え、`stopped` は外したまま

選んだ案: `infer_done` と排他の中の確かめ直しで、外す `stop` を `stopped` だけにする。推定で書くのは `status`・`done_inferred_at`・`done_inferred_last_activity` だけで、`stop`・`stop_uuid`・`stop_at`・`stop_turn` は変えない。

理由: `stopped` は親がまだ受けていない止まりで、`--watch-stopped` の `stopped` として先に親に渡すべきもの。`stopped-seen` は親が受け済みで、記録先が completed で閉じて閾値を過ぎていれば片付けてよい。`stop` を消さないのは、推定の根拠と止まりの経緯を記録に残すため（`status` が `done` なら `wait`・`reap` は `stop` を見ない）。

他の案:
- `stopped` も含める。親が止まりを受ける前に推定すると、止まりの判断（`--resolve`）が飛ばされるので採らない
- 推定のときに `stop` を `resumed` に書き換える。止まりの経緯が消え、Orca の印の写しも 2 回になるので採らない

### #1620: 判断に `判断: 親が動く` を足し、`wait --resolve` はそれを `stopped` で返す

選んだ案: `stop-judge.sh` が 1 行目に `判断: 親が動く` を受け付ける（問いではないのような使える範囲の制限は掛けない）。基準のファイルが「通してよい止まりのうち、推奨が親の操作（この子への返事以外で親がすること）を含むときに出す」と定める。`resolve_stopped` はこの値で子に送らず、子 issue に `親の判断: 親の操作が要る`（止まりの発言・停止の記録・理由・送るはずだった返事の行つき）を投稿し、`stopped <N>` で返す。起こされた親は `epic-stop.md` の手順 8 で、理由の操作を行ってから送るはずだった返事を `reply --as parent` で送り、エピックに通した行を残す。

手順 8 の中の順番: 今の手順 8 は `dismiss` の判定・`通すが送れなかった` の件・PR トークン上限・マージ待ち・委任・照らし直しの順に並ぶ。`親の判断: 親の操作が要る` の件は、今回の止まった理由が `PR トークン上限（`・`PR のマージ待ち（` で始まるものを除いて、`dismiss` の判定・主の委任・基準への照らし直しより先に扱い、照らし直さない。判断のモデルは止まりを通してよいと読んでいて、残っているのは親の操作だけなので、照らし直しは要らない。`dismiss` を先にすると、止まりの JSON の無い止まりで操作が行われずに戻される。PR トークン上限とマージ待ちは親の権限と主の承認を確かめる手順なので、`親の操作が要る` でも先に当てる。起動し直した親が `pending-owner` で拾い直した子も、「pending-owner の復元」で同じく操作をしてから送る（今の文面のままだと、照らし直して操作をせずに通しうる）。

#1620 の要件は、openspec の 1 要件 500 字の上限に合わせて、判断の値・基準のファイル・`wait --resolve`・親の手順 8・手順 8 の中の順番・守備範囲の 6 つの ADDED 要件に分けた。

理由: 親の操作は依存グラフ・枠・起点ブランチなど本体の文脈で決まり、`wait` の中のスクリプトでは安全に実行できない。判断のモデルは既に推奨を読んでいるので、値を 1 つ足すのが一番小さい。子 issue の書式は `親の判断: 主に上げる` と同じ並びにし、手順 8 が同じ読み方で扱えるようにする。

他の案:
- `wait` が判断の推奨どおりに操作を代わりに行う（issue の概要の 2 つ目の案）。自由文の推奨からコマンドを作ることになり、誤った起動や依存の張り替えを主の目の届かない所で行うので採らない
- `返事:` の文面に「親が」「起動」などの語があれば機械で止める（文字列の照合だけで止める案、または `判断: 通す` に掛ける安全網）。子への返事は「親が見張りを続ける」のように親の操作でない文でも「親が」を含み、逆に「#12 を起動してから」のように主語の無い文もあるので、取りこぼしと誤検知の両方が出る。判断のモデルの値で分けるほうが基準のファイルで直せるので、照合は足さない（R1 で安全網が要ると判断されたら足す）

### #1815: `owner-away` の判定は、新しいセッションで再開した子を外す

選んだ案: `detect_owner_away` は、記録だけの条件（今の `owner_away` の述語）を満たした子についてだけ `record_log_json`（`child-log-read.py`）を読む。最新の本体のログの `session` が空でなく `turn_state.session_id` と違い、`last_input_at` が `turn_state.recorded_at` より新しければ、知らせず `owner_away_told` も書かない（戻り値 1）。ログを読めない・`python3` が無い・値が空なら今までどおり知らせる。時刻は秒で比べ、`last_input_at` の小数秒は切り捨てる。

理由: 子を新しいセッションで再開すると、新しいセッションのフックが `turn_input` を書き直すまで、記録には古いセッションの `主の返事待ち` が残る。古い問いはもう主を待っていない。ログを読めないときに知らせる側に倒すのは、今の動き（知らせる）を変えないため。

他の案:
- 記録の `turn_input` と `turn_state` のセッションの食い違いだけで決める。再開しても記録が書き直されていない場面が問題なので、記録だけでは見分けられない
- 新しいセッションのログが存在するだけで外す（入力の時刻を比べない）。主の入力が無いまま開いただけのセッションでも外れ、古い問いを知らせなくなるので採らない
- 外したときに `owner_away_told` を書いて二度読みを避ける。今回のターンを「知らせた」と記録すると、あとで古いセッションに戻ったときに知らせが出なくなるので書かない（費用は候補の子 1 件ごとのログ読み 1 回）

## Risks / Trade-offs

- `notify-closed` が作業中の子にも促しを送る: 記録先が閉じたあとも子のターンが動いている、または主が子のタブで会話していると、そのセッションに促しが届く。主が PR をマージせず issue を手で閉じたときに加えて、通常のマージでも、子が `mark done` を付ける前に親が `closed` を処理すれば起きる（子はマージを `--until-merged` の見張りで待つので、マージから印を付けるまでの間に親が起きることはよくある）。端末を閉じず起動し直さないので作業と会話は残り、子は完了報告を書くか続きを報告する。ターンの途中の端末に送ったときに起動部品がターンの開始を確かめられるかは確かめていない。確かめられなければ `failed <N> send` になり、親が主に報告する（主の手間が 1 回増える）。調べ方は tasks 6.1 のテストではなく、実際の Orca でターンの途中の子に `orca terminal send --wait-submit` を打ったときの出力の `stages` を見る
- `stopped-seen` の推定: 親が主に問いを上げたまま記録先が閉じた子は、閾値を過ぎると主の返事の前に片付く。閉じた記録先の件に返事は要らず、`reap` の安全確認（未コミットの変更・マージに入っていない commit）は変えない
- 判断のモデルの読み誤り: 親の操作を含む推奨を `判断: 通す` と読めば今までどおり通る。同じ止まりが繰り返されれば基準の「繰り返していない」で親に上がるので、最悪でも今の動きと同じ
- owner-away のログ読み: 記録の条件を満たした候補の子についてポーリングごとに 1 回ログを読む。候補は主が子のタブで答えずに 1 時間たった子だけなので、件数は少ない
