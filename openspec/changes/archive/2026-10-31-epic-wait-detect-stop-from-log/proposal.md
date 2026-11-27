# Proposal

## Why

エピックの子が停止の記録も止まった印（`mark stopped`）も残さずに主へ質問して止まると、親の `wait` はその子を見つけられない。oratta/mac-mini-migration#33 では子 4 件のうち 2 件がこの形で止まり、親は気づかなかった。子の手順を守らせる形では防げないため、2026-10-26 に主が、止まりに気づくのは親が子の会話ログで行うと決めた（#1382）。

## What Changes

この change は #1382 の 2 本の change の 1 本目で、受け入れ条件の 1 件目（記録も印も無い子を親の `wait` が返す）を満たす。

- `epic-dispatch.sh wait` が、LLM を使わずに子の会話ログ（サブエージェントを除く）を読み、ターンが終わっていて最後が子の発言で、以後に動きが無い子を止まった子として返す。背景のタスクが実行中の子は長い待ち時間のあとで返す
- 親の判断モデル（`stop-judge.sh`）の入力を、停止の記録から子の最後の発言に置き換える。判断の結果に `問いではない`（親を起こさず待ちを続ける）を足す
- 止まりの見分けに使う識別子を、停止の記録の URL から最後の子の発言の uuid に替える。`親の判断:` の照合・手順 8・`keepalive`・主の返事待ちの判定が対象になる。**BREAKING**: `親の判断:` の書式が変わる。更新前の行は一致せず「判断なし」に倒れる
- 判断の材料に読むリスク許容の記録を、最後の入力より後のものに限る
- `child-log` の読み取りを部品に分け、`wait`・`pending-owner`・`child-log` で共有する。親が全文を読む `child-log --last <N>` を足す
- `stop` 欄を親の `wait` も書く（再開の検知を親が持つ）。子の `mark stopped` / `mark resumed` は残す
- 親が問いでないと判断した止まりを `resumed` に戻すサブコマンド `dismiss <N>` を足す

範囲外は次のとおりで、2 本目の change `epic-child-stop-drop-mark` で扱う。

- 子の `mark` の義務をなくすこと、`references/epic-child-stop.md` の書き換え
- `子の停止: 主の返事待ち` の記録を残す場面を PR のリスク許容だけに絞ること
- マージ待ち・PR トークン上限・CI の止まりの読み替え

`stages/pass.md` の「親経由で受領」「親経由で受領（委任）」と `owner-reply-check.sh --relayed` / `--delegated` は変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: `wait` が止まった子を返す条件、入力待ちからの推定を禁じる要件、`stop-judge.sh` の入力と出力、`親の判断:` の識別子、`pending-owner`、`child-log`、`keepalive` の基点を変える
- `dev-workflow-epic-state`: 子の記録に任意項目を足し、親の見張りが読む情報源に会話ログを足し、`stop` の書き手に `dismiss` を足す

## Impact

- `plugins/dev-workflow/scripts/`: `epic-dispatch.sh`（`wait`・`pending-owner`・`child-log`・`dismiss`・`keepalive`・`resolve_stopped`）、`stop-judge.sh`、`epic-state.sh`、新規 `child-log-read.py`
- `plugins/dev-workflow/skills/develop/references/`: `epic.md`（手順 2・5・7・8）、`parent-pass-criteria.md`、`reply-after-idle.md`
- `plugins/dev-workflow/tests/`: 記録と印の無い子を用意するリハーサルの追加と、`親の判断:` の書式を前提にした既存テストの更新
- 費用: 親の判断モデルの呼び出しが増える。見積もりは `design.md`
