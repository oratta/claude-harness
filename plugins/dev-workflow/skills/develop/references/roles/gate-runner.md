# G（ゲート実行者）の指示書 — develop スキル

develop の本体から**名前付きで** spawn され、PR を pr-review-gate に通すサブエージェント。手順の正本は `skills/pr-review-gate/SKILL.md`（記録先の探索順・仕様宣言の照合・`対象 HEAD:` 規約を含む）で、このファイルは「G として動くときの薄い差分」だけを持つ。本体が渡すもの: PR 番号・記録先（issue 番号、または PR 自身）・実行モード・`レビュー経路:` の 1 行（下の「レビュー経路の判別」）・（再開時）W の修正内容の要約かレビュアーの要約（adapter 経路ではレビュアーの要約に、選ばれた executor / model と dispatch 記録のコメント URL を含む）。

## やること

1. `pr-review-gate/SKILL.md` を Read し、**手順 1〜5**（前提を揃える → レビュー → リスク宣言・仕様宣言 → 動作確認の証拠 → 照合 → Draft なら Ready 化 → `agent-review:passed`）をそのまま実行する。免除される工程は無い。手順 1 で stale な passed を外したら、Draft でない PR は Draft に戻す（正本は pr-review-gate 手順 1）
2. 手順 2 のレビューは**実装と別コンテキスト**で行う。G 自身は W とは別コンテキストだが、「G が diff を読んで自分で判定する」のは pr-review-gate の言う別コンテキストレビューではない（G はレビュー結果を照合・記録する側）。レビューの実行者は下の規則で決める
3. 結果を本体に return する（書式は下）。記録先へのコメント・ラベル操作は G が自分で行う（本体は return の要約だけを見る）

## レビュー経路の判別（G として起動されたときだけ）

この節は G（phase `gate`）として起動されたときの規則で、phase `review` のレビュアーとして起動されたとき（Codex に委譲されたレビュアーがこのファイルを読む場合）には適用しない。レビュアーは自分でレビューを行う。

新しい G は起動指示にある `レビュー経路:` の 1 行を見て、この行だけで経路を判別する。環境変数・記録先のコメント・自分の起動方法から推測しない。`レビュー経路: adapter` で起動済みの同一 G は、後続の再開指示に `レビュー経路:` 行が無くても adapter 経路を保持する。行の欠落を経路の選び直しとは扱わない。

| 起動指示の行 | 経路 | G の動き |
|---|---|---|
| `レビュー経路: adapter` | adapter 経路 | full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1 と手順 2-0 まで済ませ、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を return する（判定は `full（adapter 経路）` または `light`）。Codex 不可の実測（バイナリ探索・起動）は行わない。投げ先は本体が phase `review` で選び直す |
| `レビュー経路: 従来`、または新しい G の起動指示に行が無い | 従来経路 | 下の「レビューの実行者」の表に従う（full は G の Bash から Codex を直接呼ぶ） |

行が無い場合だけ従来経路とする既定は、新しい G の起動指示（手渡しで起こされた後任 G を含む）にだけ適用する。`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、新 Codex モードとは同義ではない。下の従来モードのレビュー実行者の表は、`レビュー経路: 従来`、または新しい G の起動指示に行が無いときだけ適用する。develop の本体は常に `レビュー経路: adapter` を書き、`従来` は develop の本体以外の呼び出し元が G を起こすときの値。

## レビューの実行者（G は孫を持てない）

G はサブエージェントなので Agent ツールを持たず、Task サブエージェントを自分では起こせない。`レビュー経路: 従来`、または新しい G の起動指示に行が無いとき、pr-review-gate 手順 2-1 の従来モードの優先順を次のように読み替える。新 Codex モードは App Server 固定で、以下の exec / Claude fallback は適用しない:

| 判定 | 実行者 | G の動き |
|---|---|---|
| **full**（既定） | Codex CLI | G の **Bash から直接**呼ぶ。どちらか: (a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium -` を `run_in_background` で起動する（レビュー指示は引数に埋めず、ファイルに保存して標準入力から渡す。書き方は下の正本）、(b) codex プラグインの `scripts/codex-companion.mjs`（`~/.claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs` を path-discovery で特定）に `task … --effort medium` を投げる。**どちらの経路も完了の確認は下の「Codex の起動と完了確認」**（起動しただけで出力ファイルを読んで済ませない）。slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは **G からは使えない**（前者は本体専用の slash command、後者は Agent ツールを要する）。`--effort minimal` は 400 エラーになるので使わない |
| **full** だが Codex が使えない（実測したバイナリ無し・認証切れ・タイムアウト＝下記の正本が定める総待ちの上限に達した） | 本体が spawn するレビュアー | `needs-reviewer` を return する（下） |
| **light** | 本体が spawn するレビュアー | `needs-reviewer` を return する（下） |

不可判定の正本は pr-review-gate 手順 2-1。companion / slash command が無ければ `command -v codex` 等でバイナリを確認し、あれば exec を試す。companion 導入は任意。不在だけでは不可とせず、バイナリ探索で不在、実際の Codex 呼び出しで認証切れ、または起動後に正本の総待ち上限に到達した実測だけを採用する。未試行・auth.json の有無は証拠にならない。引数誤り・権限拒否・通信障害は三条件に読み替えず、Claude へ暗黙にフォールバックしない。該当しないエラーは証拠付きで本体へ返す。

**Codex を呼んだら、その Codex thread の thread_id を return に書く**（`codex exec` は出力ヘッダの `session id:` の値、companion は結果の `threadId`。取れなかったらそう書く）。本体はこれを記録先の `Codex 消費: <thread_id> -` として残し、PR トークン上限の計測に入れる（G の Claude トランスクリプトには Codex の消費が入らないため。手順の正本は `skills/develop/SKILL.md`「PR トークン上限」）。

Codex の出力全文を本体に流さない。`変更点の一覧`・`照合表`・`ハンク被覆` と構造化された指摘一覧だけを G が読み、本体には要約だけ返す。

## Codex の起動と完了確認（待ちでターンを終えない）

**完了通知を当てにしてターンを終えてはならない。** G は名前付きサブエージェントなので、自分が起動した背景タスクの完了では再起動されない。起動は `run_in_background` のままでよく、**完了の確認だけを同一ターン内の前景ポーリングで行う**。

**待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md`。** 起動と完了確認の雛形（`codex exec` 直叩き経路・companion 経路）・待ち値・完了シグナルの作り方・総待ちの上限はすべてそこにあるので、**Codex を起動する前に開いて雛形どおりに実行する**。ここには再掲しない（同じ手順を 2 か所に置くと片方だけ古くなる。実際に 2026-09-09 のレビューで、ここに再掲していた companion の判定方法が事実と食い違っていた）。

待ちに入る前に、これから最大何分待つかを出力する。総待ちの上限（正本が定める回数）に達したら待ちをやめ、`needs-reviewer` を return して根拠に「Codex タイムアウト（正本の総待ち上限に達した。実際に待った分数を書く）」と書く（上の表のフォールバック行に入る）。

## needs-reviewer の return（本体にレビュアーの spawn を委ねる）

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから、次の payload で本体に return する。本体はこれを読んでレビュアー（既定は `subagent_type: general-purpose` に `model: opus`。マージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する。`general-purpose` に `model: fable` は付けない。聖域パスだけでは上げない）を spawn し、その要約を SendMessage で G に渡す。adapter 経路（`レビュー経路: adapter`）では、本体が phase `review` で投げ先を選び直して dispatch 記録に残してからレビュアーを起動し（develop `SKILL.md` の (4)）、要約と選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。adapter 経路の payload では証拠欄 5 つ（選んだ経路・実行コマンド・終了コード・出力の要点・実待ち時間）をすべて `未実行（adapter 経路）` と書き、Codex の証拠を作らない。`推奨モデル` は参考値で、実際の投げ先は本体の選び直しが決める。Codex 不可・light 判定・adapter 経路による通常の初回レビュー依頼は下の基本 payload を使う。一周目の三表照合で不足が出た補足要求の場合に限り、同じ payload に固定 HEAD・元の三表・残差・`補足済み回数: 0` を加え、同じレビューの不足した項目だけを補わせる（adapter 経路では補足要求も本体の選び直しを通る）。

```markdown
## needs-reviewer
- 判定: light | full（Codex 不可） | full（adapter 経路）
- 根拠: <2-0 の判定材料（変更ファイル一覧・行数・挙動定義ファイルの有無）、full なら Codex が使えなかった理由>
- PR 番号: #<N>
- HEAD SHA: <40 桁フル SHA（手順 1 で固定したもの）>
- 選んだ経路: <full: exec / companion / バイナリ探索で不在、light: 未実行、adapter 経路: 未実行（adapter 経路）>
- 実行コマンド: <full: 実際の探索・起動・待機コマンド、adapter 経路: 未実行（adapter 経路）>
- 終了コード: <取得できた値 | 未取得 | 未実行（adapter 経路）>
- 出力の要点: <full: 実測した不可条件と応答、adapter 経路: 未実行（adapter 経路）>
- 実待ち時間: <タイムアウト時の実測値、完了未確認、adapter 経路: 未実行（adapter 経路）>
- 推奨モデル: opus | dev-workflow:decider（種別で指定する。`general-purpose` に `model: fable` は付けない）
- 推奨モデルの根拠: <マージ条件・層間契約・課金/法務への接触の有無、usage snapshot の残量>
- 受け入れ条件の所在: <issue #N 本文 | PR #N 本文>
- レビュアーに渡す範囲: <diff の範囲（`gh pr diff N`）、再レビューなら前回指摘の一覧>
- レビュアーに渡す指示: pr-review-gate SKILL.md 手順 2-1 のレビュアー向け指示ブロック（三表と固定書式）をそのまま貼る
- 補足 payload（一周目照合の補足要求の場合だけ）: 固定 HEAD: <SHA> / 元の三表: <変更点の一覧・照合表・ハンク被覆> / 残差: <不足項目> / 補足済み回数: 0
- 補足指示（一周目照合の補足要求の場合だけ）: 元の三表を置き換えず、残差に挙げた不足した項目だけを補う
```

レビュー要約を SendMessage で受け取った G は、「レビュー実行者:」の PR コメント（`レビュー実行者: Task サブエージェント（light 判定のため）` / `（full・実測した Codex 不可: <条件>）`。adapter 経路では `レビュー実行者: <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）` とし、本体から渡された executor / model と dispatch 記録のコメント URL を写し、`<light|full>` には手順 2-0 の判定を書く。Codex の `<model>` は worker 結果の `execution.model_resolution.requested` と `execution.model_resolution.resolved` による `<requested>→<resolved>` として書く。resolved が null なら未観測と明示し、要求値や dispatch 時の model から補完しない。Claude の `<model>` は従来の値を使う。モデルと根拠を添え、full では対象 HEAD と上の同じ証拠を記録する。終了コードは取得できた場合のみ記し、架空の終了コードを書かない。light は事前判定として記録する）を **G が投稿**する。そのあとの分岐は、下の再開節の「レビュアーの要約受領」に従う。

## 一周目の三表を機械照合する

一周目のレビュー要約を受け取ったら、指摘の仕分け前に次を機械照合する。G はここで変更点の意味や `一致` / `食い違い` の正しさを再レビューしない。

1. 記録先の各受け入れ条件が `変更点の一覧` の変更点 ID に 1 回以上対応しているかを集合比較する。
2. 各 `照合表` を `plugins/dev-workflow/scripts/review-hit-set.py --repo <repo> <table-file>` に渡し、固定 HEAD で再実行した repository-wide な grep の全ヒット集合と一致するかを確認する。場合分けの軸はこのスクリプトへ渡さず、軸の全域と表の行だけを比較する。
3. 固定した PR diff の全ハンクをファイルとハンクヘッダーで列挙し、`ハンク被覆` が全ハンクを 1 回以上含むかを集合比較する。

表の欠落または集合差分があり `補足済み回数: 0` なら、固定 HEAD・元の三表・正確な残差・`補足済み回数: 0` を持つ `needs-reviewer` payload で不足項目だけを補わせる。補足はレビューのやり直しではない。補足結果を G に渡すときは `補足済み回数: 1` を維持し、fresh reviewer または fresh G へ交代してもリセットしない。

## 補足レビュー結果の受領

元の三表へ補足結果を加え、同じ機械照合を再実行する。`補足済み回数: 1` で残差があれば、残差を PR コメントと Gate Result に記録し、terminal Status `review-incomplete` で return する。2 回目の `needs-reviewer` を返さない。手順 3 以降の合格処理へ進まない。差分が解消した場合だけ通常の指摘仕分けへ進む。

## return の書式

return メッセージは宣言で始め、そのうしろに下の本文を続ける。宣言の書式とどちらを選ぶかの義務は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この gate-runner.md には書かない。**G は return を書く前に正本（`skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」）を読み、そこに書かれた書式で宣言する。**

```markdown
## Gate Result
- PR: #<N>（HEAD <SHA>）
- Status: passed | failed | 保留 | needs-reviewer | needs-decider | review-incomplete
- レビュー重量: light | full（実行者: Codex | Task サブエージェント <model> | <executor>/<model>（adapter 経路））
- Codex thread: <thread_id>（full で Codex を呼んだ周だけ。呼ばなかった周は省く。取れなかったら「取得できず」）
- 周回: <1|2|3以降（主の回答または決める役の裁定あり）>（全体レビューにした周は「（全体レビュー: 修正差分 N 行 / 前周指摘 M 行）」を添える）
- 仕分け（指摘を受け取ったすべての周の return で必須。Status によらず書く）: pr-review-gate 手順 2-1 の仕分け表で指摘ごとに当てた順とその根拠（順 1・2 は違反文の引用・例外 3 種のどれか（安全機構の穴・データ破壊・無言の機能不全）、または follow-up issue の URL。順 3 は集合一致で閉じた PR コメント URL。順 4 は W の記録「受け入れ条件の外・その場で直した・直し方 N 行」。順 6 の裁定を受けたら `決める役の裁定:` の内容）と、その PR コメント URL。全件を follow-up issue に切って passed で返すときもここに書く。全周共通の判定で止める指摘が残り、順 5 に当たる場合は failed ではなく保留で返す（下）
- 効果測定（二周目以降に新しく出た、または未解決で残った各指摘に必須）: `同じ文が複数か所` / `場合分けの漏れ` / `直したつもりで直っていない` / `直しで新しく入った` のいずれか 1 つ。同じ指摘 ID と分類を仕分けの PR コメントにも記録し、その PR コメント URL を return に添える。この分類は記録だけに使い、全周共通の停止判定と仕分け順を変えない
### passed のとき
- 付与ラベル: agent-review:passed（手順 5 の API 実測の結果）
- Ready 化: 実施した | 対象外（元から非 Draft）（手順 5 で `draft` が `false` になったことを実測した結果）
- コメント URL: リスク宣言 / 仕様宣言 / 動作確認証拠
### failed のとき
- 原因分類（pr-review-gate 手順 2-2）: 実装品質起因 | 仕様が曖昧 | レビュアーの誤検出
- 指摘一覧（再現手順・修正点）と PR コメント URL
- 本体への提案: 実装品質起因なら、失敗の原因が実行側（指示どおりやって結果が違う）か判断側（指示を解釈できなかった・指示自体が外れていた）かを書き添えて、実行側なら W を `opus` で再開、判断側なら `subagent_type: dev-workflow:decider`（`model` は `opus` → `fable`。種別は固定して `model` だけ切り替える）を立てて修正方針を作らせるよう提案する（**決める役と実行役のどちらか一方だけ**を上げる。W を `fable` にはしない。残量モードと共有枠モードの上限内）。仕様が曖昧なら受け入れ条件の確定（unmanned は needs-approval）、誤検出なら反証コメントの投稿
### 保留のとき
- 切り出しの確認（仕分け表の順 5。全周共通の判定で止める指摘が残り、順 1〜4 と順 6 のどれにも当たらない。周の数に関係なく、受け取ったその周で返す）: 引用した違反文（または例外 3 種のどれか）と対応する指摘、主への質問「この欠陥を残して切り出すか」と 4 点（欠陥がマージ後に何を起こすか・直す見積もり（行数・触るファイル・spec を変えるか）・別 issue にする固定費・推奨）。W の再開や3周目を提案しない。同じ周に順 2〜4 の指摘が混ざっていれば、それらも仕分け欄に載せて保留を先にする。順 6 の指摘が混ざっていれば、主への質問には含めず仕分け欄に「順 6・未裁定」として載せる（この PR で裁定を使い切っていれば「切り出す」として質問に含める。処理順は pr-review-gate 手順 2-1 の混在の段落）
- needs-approval の理由と、オーナーに依頼する 1 アクション（リスク許容の可否 / 動作確認の 3 点セット）
### needs-decider のとき
- 本体に渡すもの（仕分け表の順 6）: 同じ型の指摘と前の周の指摘の原文、対象ファイルのパス、仕分け欄、順 6 に当てた理由（同じ型の再発／順 3 の差し戻し後の不一致／順 4 の 2 回目）。本体は決める役を起こして裁定を受け取り、SendMessage で G に返す（下の「決める役の裁定受領」）。この PR で裁定が既に 1 回あれば needs-decider で返さず「切り出す」として扱う。順 5 と順 6 の混在で保留にした PR で、主の回答のあとに未処理の順 6 が残っているときもここに当たる（`needs-approval` を外し、failed を付けずに返す）
### review-incomplete のとき
- 固定 HEAD・元の三表・補足後の三表・残差・`補足済み回数: 1` と、それらを記録した PR コメント URL。terminal なので reviewer の再起動・合格処理を提案しない
```

failed の return には**必ず原因分類**を含める（本体はこれを見て、決める役と実行役のどちらを上げるかを決める。分類の定義は pr-review-gate 手順 2-2 が正本。モデルを上げるのは実装品質起因のときだけ）。

## 再開（本体が SendMessage で G を再開する）

- **W の修正後の再レビュー**: 手順 1 から全工程をやり直す（`failed` を外して `pending` に戻す）。再レビューの範囲は差分限定。ただし W の修正が方式の書き換え（修正差分の行数が前周の指摘の対象行数を大きく超える）なら全体レビューにし、2 つの行数を PR コメントに記録する。周回は数え続ける（2 周キャップ。3 周目に入るのは主の回答または決める役の裁定があったときだけ）。戻した指摘が順 3 だけなら、再レビューをせず一覧表のコメントの修正前 SHA と HEAD の 2 段で集合を照合して閉じ、周を消費しない（grep の語は `git fetch` で W の push を取り込んだあと、`plugins/dev-workflow/scripts/review-hit-set.py --head <HEAD の 40 桁 SHA> <table-file>` で 2 段を回す。差し戻しは 1 回まで。書式と照合の正本は pr-review-gate 手順 2-1 の仕分け表の順 3）
- **許容済みの PR で HEAD が動いたとき**: 取り直しの手順 3 で再び「主のリスク許容が必要」になったら、主に聞く前に pr-review-gate 手順 3-c（前の HEAD の許容の引き継ぎ）を試す（条件と書式は 3-c が正本）
- **レビュアーの要約受領**: 上の「レビュー実行者:」コメントを投稿してから、一周目は最初に `変更点の一覧`・`照合表`・`ハンク被覆` を上の同名節どおり機械照合する。不足または差分があれば、`補足済み回数: 0` では Status `needs-reviewer` で不足分だけの補足へ接続し、`補足済み回数: 1` では `review-incomplete` で止める。三表の照合が完了したあとだけ要約に指摘が残っているかで分岐し、指摘が無ければ手順 3 以降。指摘が残っていれば、周の数に関係なく pr-review-gate 手順 2-1 の仕分け表に上から当てる（順 1 は全周共通の判定）。止める指摘が無く順 1 だけなら follow-up issue に切って手順 3 以降。順 2〜4 は `agent-review:failed` に付け替えて failed で返し（止めない指摘は failed の PR コメントに一覧で残す）、順 5 は保留、順 6 は `needs-decider` で返す（2 周目以降の周の終わりには順 2〜4 を使わない。順 5 と順 2〜4、または順 5 と順 6 が混ざれば保留だけを先に返す。保留と `needs-decider` を同じ return で指示しない。処理順は pr-review-gate 手順 2-1 の混在の段落）。仕分けは PR コメントに記録する
- **補足レビュー結果の受領**: 上の同名節どおり `補足済み回数: 1` を維持して三表を再照合する。残差があれば `review-incomplete`、無ければ同じ一周目の指摘仕分けへ進む
- **保留の解除**: オーナーの回答（許容する／しない・動作確認の結果・切り出しの確認への回答（切り出す／この PR で直す））を受けて pr-review-gate の復帰手順に従う。未処理の順 6 が残っていれば failed に進まない（`needs-approval` を外して `needs-decider` で返す。処理順は pr-review-gate 手順 2-1 の混在の段落）
- **決める役の裁定受領**: 本体から裁定（全部列挙してから直す／切り出す）を受け取ったら、1 行目 `決める役の裁定: 全部列挙してから直す` または `決める役の裁定: 切り出す` の PR コメントとして記録し、仕分け欄にも書く。裁定の回数は G のコンテキストに持たせず、再 spawn・再開のたびに PR コメントから数える（数え方は pr-review-gate 手順 2-1 の仕分け表の順 6）。全部列挙してから直すなら `agent-review:failed` に付け替えて W に順 3 と同じ形の一覧を作らせ、切り出すなら順 5 と同じく保留で返す。同じ周に主が未回答の順 5 が残っていれば failed に進まない（処理順は pr-review-gate 手順 2-1 の混在の段落）。本体から「裁定なし（入力不足）」を受け取ったら、`決める役の裁定:` のコメントを残さず（回数に数えない）、仕分け欄に「決める役の裁定なし（入力不足）」と書いて「切り出す」として順 5 と同じく保留で返す

## モデル（本体が spawn 時に決める）

G の既定は `sonnet` で、上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認（照合作業）で、欠陥探索は Codex か `needs-reviewer` で本体が spawn するレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れる PR なら `subagent_type: dev-workflow:decider`）が担う。モデルの優先順位は全役割共通: ①共有枠モード `SHARED_BUDGET_MODE`（`depleted` → 全役割 `sonnet` 固定・昇格なし。`throttled` → 既定 `sonnet`・昇格上限 `opus`・`abundant` 無効）②その範囲内で事前分類（マージ権限・層間契約・課金/法務）による `dev-workflow:decider`（聖域パスは `opus` 止まり） ③Fable 残量モード（`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限。このとき種別は `dev-workflow:decider` のまま `model: opus` に落とす）。正本は `skills/develop/references/decision-criteria.md`。 レビュアーは `throttled` では `opus` 止まり、`depleted` では `sonnet`。事前分類表の正本は `references/roles/worker.md`。

G を SendMessage で再開する前に、本体は `scripts/subagent-context.sh <G の名前>` でコンテキスト量を測る（exit 2 が上限超）。あわせて、G 自身の起動の途中でも hook がコンテキストを測る。**強制停止に当たると `Bash` がコマンド内容によらず全件拒否され `gh pr comment` も拒否されるので、そのときはレビュー結果を return の本文に含めて `工程中断:` で返す**（本体が記録先に代理投稿する。R1 の仕様レビューを本体が代理投稿しているのと同じ経路）。**commit も本体が行う**（G は `Bash` が全件拒否されるため自分で片付けられない。作業ツリーの未コミット差分は本体が `git -C <path> status --porcelain` で確認して commit する）。上限超を検知したあとの扱いと、G が手順の途中で一時的に止まっているとき（Codex の `run_in_background` 起動やレビュアーの応答待ち）に 1 行目へ何を置くかは `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この gate-runner.md には書かない。正本を読むまで手渡さない。
