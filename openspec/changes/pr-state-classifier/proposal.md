# PR の状態の分類と次の一手を決めるスクリプトを dev-workflow に置く

## Why

CI 待ちの PR が落ちても、待っているセッションは起こされず、オーナーが見に戻るまで止まる（エピック #512）。flatmate では住人向けの見張り（`scripts/pending-mirror.sh pr-watch`、flatmate #880）が PR を「コンフリクト / CI 失敗 / マージ可能 / 待ち」に分けて次の一手を決めているが、その判断部分（`PW_JQ_LIB` の `verdict` / `observe` / `decide`）は住人の状態ファイル・依頼の列・あなた待ちと同じファイルに埋まっていて、セッション側からは呼べない。判断部分は住人に依存しないので harness に移し、セッション（#522 / #523）と住人（flatmate #976）が同じ判断を呼べるようにする（#521）。

移すにあたって 2 点を直す。

- 今の `decide` は、Actions の run がある CI 失敗なら中身を問わず同じ HEAD で 1 回再実行する。出荷ファイルの禁止語のような本当の失敗でも 1 周分の CI 時間を待ってから直しに回り、逆に実行マシンの通信切れや PR と関係ない不安定なテストかどうかは見ていない（flatmate PR #891 で 3 回落ちたうち 2 回はやり直しで通る失敗だった）
- 状態が読めない回（`mergeable` が `UNKNOWN`）を挟むと、前回の状態名が `wait` で上書きされ、変わっていないコンフリクトが「新しく入った」扱いになって修正回数が 1 増える（genetta-inc/flatmate#899）

## What Changes

- `plugins/dev-workflow/scripts/pr-state.sh` を新設する。サブコマンドは 3 つ:
  - `observe [--hints <file>] [--unrelated <check名>]...`: 標準入力の `gh pr view --json mergeable,statusCheckRollup,headRefOid` の JSON を、状態（`conflict` / `ci-fail` / `ready` / `wait`）・HEAD・落ちたチェック名・Actions の run ID・落ちたチェックごとの原因（`runner-lost` / `unrelated` / `real`）・やり直しに当たるか（`retry`）に分類して 1 行の JSON で出す
  - `decide [<前回の状態の JSON>]`: 標準入力の観測と前回の状態から、次の一手（`none` 待つ / `ready` マージ可能 / `rerun` CI をやり直す / `fix` 直しに回す / `escalate` オーナーに上げる）と次の状態を 1 行の JSON で出す
  - `annotations <owner/repo>`: 標準入力の同じ `gh pr view` の JSON から落ちた Actions のジョブを拾い、`gh api` でジョブの annotation を取って `observe --hints` に渡す形の JSON を出す（ネットワークに出るのはこのサブコマンドだけ）
- やり直しの条件を変える: 落ちたチェックがすべて「実行マシンの通信切れ（annotation に `The self-hosted runner lost communication with the server`）」か「呼び出し側が PR の変更に関わらないと渡したチェック」で、かつ Actions の run がある場合だけ、同じ HEAD で 1 回やり直す。それ以外は直しに回す
- 修正回数は PR ごとに累計し、直す判定は 2 回まで、3 回目は `escalate`。やり直しの権利は HEAD ごとに数え直す
- `wait` の観測は、HEAD が前回と同じなら前回の状態をそのまま残す（flatmate#899 の修正）
- 状態の持ち方（どこに保存するか・依頼の列・あなた待ち）は呼び出し側に残し、スクリプトは前回の状態を引数で受けて次の状態を出力で返すだけにする。状態のキー（`state` / `head` / `reran_head` / `fixes` / `raised`）は flatmate の状態ファイルと同じにし、知らないキーはそのまま引き継ぐ

## Capabilities

### New Capabilities

- `dev-workflow-pr-state`: PR の状態の分類（`observe`）・次の一手の判定（`decide`）・annotation の取得（`annotations`）の入出力と判定規則

### Modified Capabilities

（なし。セッション側の配線は #522 / #523、住人側の置き換えは genetta-inc/flatmate#976 で行う）

## Impact

- `plugins/dev-workflow/scripts/pr-state.sh`（新設）
- `plugins/dev-workflow/tests/pr-state.bats`（新設。flatmate の `scripts/test-pending-pr-merge-wait.sh` の (K)(N) から分類・判断のケースを移し、やり直しの仕分けと flatmate#899 の再現ケースを足す）
- `plugins/dev-workflow/changes/521.md`（変更記録）
- flatmate の pr-watch の振る舞いは、#976 で置き換えたときに次の 2 点が変わる: やり直しの手がかりが無い CI 失敗は再実行せずに直しに回る／次の一手の名前が `queue` → `fix`、`stall` → `escalate` になる
