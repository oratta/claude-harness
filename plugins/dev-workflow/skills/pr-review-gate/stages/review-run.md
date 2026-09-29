# レビューの起動 — pr-review-gate

以下 `$R` = `<owner>/<repo>`、`$N` = PR 番号。段の一覧と手順番号の対応表は索引 `SKILL.md`（pr-review-gate の直下）にある。

このファイルが番号で指す他の段の手順は次のファイルにある（パスは pr-review-gate の直下から）: `stages/prepare.md`（手順 1・2・2-0）、`stages/reviewer-brief.md`（2-1 のレビュアー向け指示）、`stages/triage.md`（2-1 の止める判定と仕分け・2-2）、`declarations.md`（手順 3・3-b）、`stages/pass.md`（手順 4・5）。

## 入口

`stages/prepare.md` の 2-0 でレビュー重量を判定したあと、レビューを自分で起動する側が読む（develop 以外でゲートを回す本体、`レビュー経路: 従来` の G）。develop の G（`レビュー経路: adapter`）はこの段を読まない（レビュアーは本体が起こす）。

## 手順

#### 2-1. レビューの実行（レビュー実行者）

以下は**従来モード**の優先順。新 Codex モードは App Server 固定で、以下の exec / Claude fallback は適用しない。

| 順位 | 手段 | 使い方 | 使う条件 |
|---|---|---|---|
| **既定** | Codex CLI | `codex exec -c approval_policy=never -c model_reasoning_effort=medium -` 直叩き、または companion 経由（`/codex:adversarial-review --background --base origin/main` / `codex:codex-rescue` サブエージェント） | **full** と判定したとき（full ではまずここから試す） |
| フォールバック | Task サブエージェント | Agent ツール（`general-purpose`）に受け入れ条件＋diff 範囲＋`stages/reviewer-brief.md` のレビュアー向け指示ブロックを渡す。差分が 600 行を超えた一周目は `stages/prepare.md` 2-0 の区画ごとに起こす | ① **light** と判定したとき（最初からこれ）② full だが Codex CLI が使えないとき（実測したバイナリ無し・認証切れ・タイムアウト） |

Codex CLI は区画に分けず差分全体を渡す。150,000 トークンの上限は Claude のサブエージェントの hook の上限で Codex には掛からず、三表が欠けた場合は G の機械照合が fail-closed で止める。

Codex を full の既定にする理由: **実装者と別モデル系列で読ませたほうがレビューの独立性が上がる**（同一モデルは同じ盲点を共有する）。加えて**レビューで Claude の 5h/7d 枠を消費しない**ので、枠を実装サイクルに残せる。

**2-0 の事前判定と、この障害時フォールバックは役割が違う** — 前者はレビュー開始前に**変更内容**から重量を決める設計上の選択、後者は full と判定した後に **Codex の可用性**が理由で発生する迂回路。どちらの経路で Task サブエージェントになったかを PR コメントで書き分ける（`レビュー実行者: Task サブエージェント（light 判定のため）` / `レビュー実行者: Task サブエージェント（full・実測した Codex 不可: <条件>）`）。develop の adapter 経路（G が `needs-reviewer` を返し、本体が phase `review` で投げ先を選び直した場合）では `レビュー実行者: <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）` と書く（手順は develop の `references/roles/gate-runner.md`「レビュー経路の判別」）。executor が codex なら、worker 結果の `execution.model_resolution.requested` と `execution.model_resolution.resolved` を使って `<model>` を `<requested>→<resolved>` と書く。resolved が null なら未観測と明示し、要求値や dispatch 時の model で補完しない。executor が claude なら従来の model 値を使う。**どちらの経路でも手順3のリスク宣言・手順4の動作確認・fail-closed の判定順序は一切変わらない** — 変わるのはレビューを実行する主体だけで、免除される工程は無い。

**従来モードの不可判定**: companion / slash command が無ければ、`command -v codex` 等でバイナリを確認し、あれば exec を試す。companion 導入は任意で、不在だけでは Codex 不可にしない。不可と判定できるのは次の実測だけ:

- バイナリ無し: `command -v codex` 等の探索コマンドが不在を示した。
- 認証切れ: 実際の Codex 呼び出しが認証切れの応答を返した。
- タイムアウト: 起動後、待ち方の正本が定める総待ちの上限に達した。単一回の待ち終了を総待ち上限として扱わない。

未試行、auth.json の有無、バージョン表示だけでは可否を確定しない。「サブスク切れ」との推測も認証切れの実測に代用しない。引数誤り・権限拒否・通信障害などを三条件に読み替えて Claude へ暗黙にフォールバックしない。該当しないエラーは証拠とともに本体へ返す。

従来モードの full は、成功時も不可時も次の証拠を PR コメントに残す。終了コードは取得できた場合だけ書く。タイムアウトで完了未確認なら実待ち時間を書き、架空の終了コードを書かない。light は事前判定の根拠を記録し、未実行の Codex 証拠を作らない。develop の adapter 経路では同じ雛形の証拠欄を `未実行（adapter 経路）` と書き、レビュー実行者行は adapter 経路の形にする。

```text
対象 HEAD: <40 桁フル SHA>
レビュー実行者: <Codex CLI | Task サブエージェント（full・実測した Codex 不可: 条件） | <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）>
選んだ経路: <exec | companion | バイナリ探索で不在 | 未実行（adapter 経路）>
実行コマンド: <実際の探索・起動・待機コマンド | 未実行（adapter 経路）>
終了コード: <取得値 | 未取得 | 未実行（adapter 経路）>
出力の要点: <完了結果 | 実測した不可条件と応答 | 未実行（adapter 経路）>
実待ち時間: <タイムアウト時の実測値、完了未確認 | 未実行（adapter 経路）>
```

**Task サブエージェントのモデルは明示指定する（Agent ツールの `model` パラメータ）**:

- **既定は `opus`。** モデル未指定のサブエージェントは親セッションのモデルを継承するため、親が Fable のセッションではフォールバックのたびに Fable レビューが自動発火し、週次枠を無言で消費する（主が避けたいと明言している消費）。レビューの価値の中心は「実装者と別の目」であり、モデルの最高性能ではない。
- **Fable に上げるときは `model` ではなく種別で上げる**: 次の両方を満たすときだけ `subagent_type: dev-workflow:decider` で spawn する（`general-purpose` に `model: fable` は付けない。`scripts/agent-model-guard.sh` が PreToolUse で拒否する）。①変更が壊れると影響の重い部分（マージ条件の判定・レート/使用量制御・エージェントの行動規約）に触れている ② active スロットの Fable 週次の実効値（`~/.claude/.usage-snapshot` の `fable_weekly_pct` をリセット時刻で読み替えた値。取得からの経過時間では捨てない）で、Fable 週次枠に余裕がある（`FABLE_BUDGET_MODE=exhausted` 相当なら種別はそのままに `model: opus` へ落とす）。判断根拠を PR コメントのレビュー実行者行に添える（例: `レビュー実行者: dev-workflow:decider（fable — マージ判定に接触・週次残 40%）`）。決める役は `Bash` を持たないので、レビュー結果の PR コメント投稿はゲートを回す側が代理で行う。

**Codex の呼び出し規約**（2026-08-07 の調査で確定。守らないと「原因不明のタイムアウト」になる）:

- **前景 1 回で起動から完了まで待ち切ろうとする呼び方を禁止する**（前景で待つこと自体の禁止ではない。完了の確認は下のとおり前景ポーリングで行う）。Claude Code の Bash は 1 回 **10 分**が上限で、Codex レビューはそれを超えることがある（上の「10 分でタイムアウト」の直接原因はこれ）。`/codex:adversarial-review` は必ず **`--background`** で起動する。
- **待ち方は読み手で変わる。** 待ち値・完了シグナル・繰り返し回数・総待ちの上限の正本は `plugins/dev-workflow/references/subagent-waiting.md` で、**ここには再掲しない**（2 か所に置くと片方だけ古くなる）:
  - **メインセッション（本体）**: 背景タスクの完了で再起動されるので、`--background` 起動 ＋ 完了通知での続行でよい。
  - **サブエージェント（G など）**: 再起動されないので、完了の確認を**同一ターン内の前景ポーリング**で行う。完了を待つ目的でターンを終えてはならない（サブエージェントは再起動されないので、ターンを終えるとオーナーが気づくまで止まったままになり、気づかれなければ何時間でも作業が進まない）。正本を開いて雛形どおりに実行する。
- **`codex-companion.mjs status --wait` の `--timeout-ms` は必ず明示する。** 既定は **4 分**しかない。値は Bash 前景の上限（600000 ms）未満にする — 従来ここに書いていた上限超えの値は 1 回の呼び出しで完走せず、これが待ちの構造を壊す原因だった。既定値・1 回で終わらなかったときの繰り返し・総待ちの上限に達したときの分岐は正本に従う。上の表のフォールバック条件に挙げた「タイムアウト」は、その総待ちの上限に達したことを指す。
- **推論の深さを中に落とす。** `config.toml` の既定 `high` はレビューには過剰で、実行時間が 10 分を超える一因。`codex exec` 直叩きなら `-c model_reasoning_effort=medium`、`codex:codex-rescue` サブエージェント（companion の `task`）なら `--effort medium`。**`/codex:adversarial-review` に付けてはいけない** — review 系は `-c` も `--effort` も受け取らず、渡した文字列は黙って**レビューの focus text に混ざる**（`--base` / `--scope` / `--model` のみ有効）。
- **`--effort minimal` を使わない。** 無効値で **400 エラー**になることを実測済み。companion 側のバリデーションは通ってしまい API で落ちるので、失敗が呼び出し側から見えにくい。API の有効値は `none` / `low` / `medium` / `high` / `xhigh` / `max`（companion の `--effort` が受理する集合とはずれている。実務では `medium` を使う）。
- **`codex exec` を直叩きするときは `-c approval_policy=never` を必ず付ける。** config の「承認を求める」設定を継承すると、無人実行では誰も承認できずハングする穴がある（companion 経由なら既定で `never` なので不要）。
- **exec のレビュー指示はファイルに保存して標準入力から渡す。** 固定した HEAD・diff 範囲・受け入れ条件と`stages/reviewer-brief.md` のレビュアー向け指示ブロックを含め、起動・完了シグナル・結果の読み方は待ち方の正本に従う。
- **Codex の出力全文を本体セッションに流し込まない。** `変更点の一覧`・`照合表`・`ハンク被覆` と構造化された指摘一覧だけをサブエージェント側で読み、本体には要約だけ返す（レビュー出力は 1 ターンでコンテキストを食い潰す量になる）。

##### 各 PC の確認（従来モード・実測は別運用）

1. 各稼働 PC で `command -v codex` と `codex --version` を実行し、パス・バージョン・結果を記録する。companion の有無も調べるが、companion 導入は任意。バイナリ無しなら探索結果を記録する。
2. バイナリがあれば、固定した対象 HEAD・diff 範囲・受け入れ条件を用意し、上の呼び出し規約で実レビューを起動する。companion が無くても exec を試す。指示はファイルから標準入力へ渡す。
3. `plugins/dev-workflow/references/subagent-waiting.md` の完了確認と有限ポーリングに従い、実レビューの完了結果を確認する。バイナリ・auth.json の存在や version 表示だけでレビュー可能とは宣言しない。三条件以外のエラーはそのまま記録し、未確認として残す。
4. 以下を対象 issue に記録する。認証情報そのものは転載しない。未実測は未確認とし、文書化完了と実測完了を区別する。各 PC の結果が揃うまで対象 issue を完了扱いにせず、文書化 PR に自動 close 指定を付けない。

```text
PC 識別子: <識別できる名前>
日時: <タイムゾーン付き>
バイナリのパス・バージョン: <探索と version の出力>
companion 有無: <有 / 無>
対象 HEAD・diff 範囲: <40 桁フル SHA、base..HEAD>
経路・実行コマンド: <探索・起動・待機の実際のコマンド>
完了状態・結果: <取得できた終了コードと出力の要点、タイムアウトは実待ち時間と完了未確認>
可否 / 未確認: <レビュー完了を確認して可 / 三条件を実測して不可 / 未確認>
残課題: <未確認事項、次の対応>
```

## G として動くとき（develop）

この節は develop の G（`skills/develop/references/roles/gate-runner.md` の指示で動くゲート実行者）だけに関係する。develop 以外の読み手は読み飛ばしてよい。

### レビューの実行者（G は孫を持てない）

G はサブエージェントなので Agent ツールを持たず、Task サブエージェントを自分では起こせない。`レビュー経路: 従来`、または新しい G の起動指示に行が無いとき、pr-review-gate 手順 2-1 の従来モードの優先順を次のように読み替える。新 Codex モードは App Server 固定で、以下の exec / Claude fallback は適用しない:

| 判定 | 実行者 | G の動き |
|---|---|---|
| **full**（既定） | Codex CLI | G の **Bash から直接**呼ぶ。どちらか: (a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium -` を `run_in_background` で起動する（レビュー指示は引数に埋めず、ファイルに保存して標準入力から渡す。書き方は下の正本）、(b) codex プラグインの `scripts/codex-companion.mjs`（`~/.claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs` を path-discovery で特定）に `task … --effort medium` を投げる。**どちらの経路も完了の確認は下の「Codex の起動と完了確認」**（起動しただけで出力ファイルを読んで済ませない）。slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは **G からは使えない**（前者は本体専用の slash command、後者は Agent ツールを要する）。`--effort minimal` は 400 エラーになるので使わない |
| **full** だが Codex が使えない（実測したバイナリ無し・認証切れ・タイムアウト＝下記の正本が定める総待ちの上限に達した） | 本体が spawn するレビュアー | `needs-reviewer` を return する（書式は `stages/prepare.md` の「G として動くとき（develop）」節） |
| **light** | 本体が spawn するレビュアー | `needs-reviewer` を return する（書式は `stages/prepare.md` の「G として動くとき（develop）」節） |

不可判定の正本は pr-review-gate 手順 2-1。companion / slash command が無ければ `command -v codex` 等でバイナリを確認し、あれば exec を試す。companion 導入は任意。不在だけでは不可とせず、バイナリ探索で不在、実際の Codex 呼び出しで認証切れ、または起動後に正本の総待ち上限に到達した実測だけを採用する。未試行・auth.json の有無は証拠にならない。引数誤り・権限拒否・通信障害は三条件に読み替えず、Claude へ暗黙にフォールバックしない。該当しないエラーは証拠付きで本体へ返す。

**Codex を呼んだら、その Codex thread の thread_id を return に書く**（`codex exec` は出力ヘッダの `session id:` の値、companion は結果の `threadId`。取れなかったらそう書く）。本体はこれを記録先の `Codex 消費: <thread_id> -` として残し、PR トークン上限の計測に入れる（G の Claude トランスクリプトには Codex の消費が入らないため。手順の正本は `skills/develop/SKILL.md`「PR トークン上限」）。

Codex の出力全文を本体に流さない。`変更点の一覧`・`照合表`・`ハンク被覆` と構造化された指摘一覧だけを G が読み、本体には要約だけ返す。

### Codex の起動と完了確認（待ちでターンを終えない）

**完了通知を当てにしてターンを終えてはならない。** G は名前付きサブエージェントなので、自分が起動した背景タスクの完了では再起動されない。起動は `run_in_background` のままでよく、**完了の確認だけを同一ターン内の前景ポーリングで行う**。

**待ち方の正本は `plugins/dev-workflow/references/subagent-waiting.md`。** 起動と完了確認の雛形（`codex exec` 直叩き経路・companion 経路）・待ち値・完了シグナルの作り方・総待ちの上限はすべてそこにあるので、**Codex を起動する前に開いて雛形どおりに実行する**。ここには再掲しない（同じ手順を 2 か所に置くと片方だけ古くなる。古いほうの手順に従うと、事実と違う判定でゲートを通すことになる）。

待ちに入る前に、これから最大何分待つかを出力する。総待ちの上限（正本が定める回数）に達したら待ちをやめ、`needs-reviewer` を return して根拠に「Codex タイムアウト（正本の総待ち上限に達した。実際に待った分数を書く）」と書く（上の表のフォールバック行に入る）。

## 出口

- レビュアーには `stages/reviewer-brief.md` のレビュアー向け指示ブロックを渡す。
- レビュー結果を受け取ったら、指摘が残っていれば `stages/triage.md`、残っていなければ `declarations.md`（手順 3・3-b）へ進む。
