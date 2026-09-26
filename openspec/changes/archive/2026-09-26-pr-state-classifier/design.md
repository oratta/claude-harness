## Context

出発点は genetta-inc/flatmate の main の `scripts/pending-mirror.sh` の `PW_JQ_LIB`（1139〜1171 行）と、そのテスト `scripts/test-pending-pr-merge-wait.sh` の (K)(N)。

- `verdict`: チェック 1 件の結論。`conclusion` が空なら `state` / `status` を見て、`SUCCESS` / `NEUTRAL` / `SKIPPED` は `ok`、`PENDING` / `EXPECTED` / `QUEUED` / `IN_PROGRESS` / `WAITING` / `REQUESTED` と空は `pending`、それ以外（知らない値を含む）は `fail`
- `observe`: `mergeable == CONFLICTING` なら `conflict`、落ちたチェックがあれば `ci-fail`、`MERGEABLE` で全チェック `ok` なら `ready`、それ以外は `wait`。チェック名は `name` か `context`（タブ・改行・カンマを空白に置き換え）、run ID は `detailsUrl` / `targetUrl` の `/actions/runs/<id>/` から取る
- `decide($prev; $obs)`: 状態は `{state, head, reran_head, fixes, raised}`。`wait` と `ready` を先に返し、前回と同じ状態・同じ HEAD なら何もしない、上げ済みなら何もしない、`ci-fail` で run があり `reran_head` が今の HEAD でなければ再実行（次の状態名は `wait`）、修正回数が 2 以上なら上げる、それ以外は修正依頼
- 住人側（pr-watch）は、状態ファイルの読み書き・依頼の列・あなた待ちへの項目の追加・`gh run rerun`・住人の `done pushed|failed`（`failed` は `state` と `head` を消して修正回数は残す）を持つ。これらは移さない

GitHub Actions のジョブの annotation は `gh pr view` の `statusCheckRollup` には載らず、`GET /repos/{owner}/{repo}/check-runs/{check_run_id}/annotations` で取る。`statusCheckRollup` の CheckRun の `detailsUrl` は `https://github.com/<o>/<r>/actions/runs/<run>/job/<job>` の形で、Actions ではジョブ ID とチェックラン ID が同じ値になる（tasks 1.1 で確かめた: oratta/claude-harness の job 107940719281 と genetta-inc/flatmate の job 107971805803 で、`actions/runs/<run>/jobs` の `id`・`check_run_url` の末尾・`check-runs/<id>` の `id` と `details_url` の `/job/<id>` が一致し、`check-runs/<id>/annotations` が取れた）。

## Goals / Non-Goals

**Goals:**

- flatmate の分類と判断を、住人の状態・列・あなた待ちに依存しないスクリプトとして harness に置き、セッションと住人が同じ判断を呼べる
- 本当の失敗は再実行を挟まずに直しに回し、実行マシンの通信切れと PR に関わらない失敗だけを同じ HEAD で 1 回やり直す
- `UNKNOWN` を挟んだ再観測で修正回数が増えない（flatmate#899）

**Non-Goals:**

- 状態の保存場所・依頼の列・あなた待ち・`gh run rerun` の実行・住人の `done`。呼び出し側が持つ
- 「落ちたテストが PR の変更ファイルに関わるか」の判定そのもの。呼び出し側が決めてチェック名で渡す（テストとファイルの対応はリポジトリごとに違い、判定には LLM や差分の読みが要るため）
- セッションへの配線（#522 / #523）と flatmate の置き換え（genetta-inc/flatmate#976）
- 修正回数やり直し回数の上限を設定で変えること。上限は受け入れ条件どおりの固定値（やり直しは HEAD ごとに 1 回、直すは PR ごとに 2 回）

## Decisions

### 判断はネットワークに出ない 2 段（observe / decide）に分け、annotation の取得だけを別サブコマンドにする

`observe` と `decide` は標準入力と引数だけで決まり、`gh` を呼ばない。annotation の取得は `annotations <owner/repo>` に分け、`observe --hints <file>` で結果を渡す。呼び出しは次の形になる:

```bash
view="$(gh pr view "$n" --repo "$repo" --json mergeable,statusCheckRollup,headRefOid)"
printf '%s' "$view" | pr-state.sh annotations "$repo" > "$hints"
printf '%s' "$view" | pr-state.sh observe --hints "$hints" [--unrelated <check名>]... \
  | pr-state.sh decide "$prev"      # → {"act":..., "next":{...}, "obs":{...}}
```

比べた案:

- **`observe` の中で annotation も取る**: 呼び出しは 1 回で済むが、分類のテストに毎回 `gh` の偽物が要り、「入力が同じなら結果が同じ」が崩れる。住人は 1 回の走査で多数の PR を見るので、annotation を取る・取らないを呼び出し側が選べるほうがよい（落ちたチェックが無い PR では取る必要がない）。採らない
- **annotation の取得をスクリプトに持たず、呼び出し側に任せる**: annotation の URL の組み立てと通信切れの文言の照合を、セッションと住人の 2 か所に書くことになる。共有するために移すという目的に反する。採らない

### annotation の手がかりはジョブ ID を鍵にする

`annotations` の出力と `observe --hints` の入力は `{"annotations_by_job": {"<job>": [...]}}` とし、チェック名では引かない。チェック名はワークフローをまたいで重なることがあり（別ワークフローの同名ジョブ `test` など）、名前を鍵にすると片方の通信切れがもう片方の本当の失敗まで `runner-lost` にする。名前のまま同名の配列をつなぐ案は、この取り違えを守備範囲外として受け入れることになるので採らない。ジョブ ID を持たない失敗は通信切れと判定できないが、その失敗は Actions のジョブではないので annotation もやり直しの対象も無く、損失は無い。

### やり直すのは「落ちたチェックがすべてやり直しに当たる」ときだけ。手がかりが無ければ直しに回す

落ちたチェックごとに原因を `runner-lost`（annotation の文言に `The self-hosted runner lost communication with the server` を含む）→ `unrelated`（`--unrelated` で渡された名前）→ `real` の順で決める。`retry` は、状態が `ci-fail` で、落ちたチェックが 1 件以上あり、すべてが `real` でなく、すべてに Actions の run ID があるときだけ真。1 件でも `real` があれば直しに回す（やり直しても本当の失敗は残るので、直しを遅らせるだけになる）。

比べた案:

- **手がかりが無い CI 失敗は flatmate と同じく 1 回やり直す**: 呼び出し側が annotation も変更ファイルも渡さなくても不安定なテストを拾える。代わりに本当の失敗でも CI 1 周分（flatmate PR #891 では数分〜十数分）待ってから直しに回り、self-hosted の実行マシンの時間も使う。#521 の本文が「次の場合はやり直すに仕分ける」と条件を限っているのに合わせ、採らない。呼び出し側が不安定なテストをやり直したいときは、そのチェックを `--unrelated` で渡せば同じ振る舞いになる
- **一部のチェックだけやり直す**: `gh run rerun --failed` は run 単位で、run の中の本当の失敗も一緒に走り直す。やり直しと直しを同時に走らせると、直しの push で HEAD が変わってやり直しの結果が捨てられる。採らない

### 修正回数は PR ごとの累計、やり直しの権利は HEAD ごと

受け入れ条件 2 の「HEAD が変われば数え直す」は、やり直しの権利（`reran_head`）に掛ける。修正回数（`fixes`）は PR ごとに累計し、呼び出し側が状態を消す（PR が閉じた）まで戻さない。直しは必ず新しい HEAD を push するので、修正回数まで HEAD ごとに数え直すと 3 回目に届かず、オーナーに上がらない（flatmate の Nd のケース: HEAD d1 → d2 → d3 で 3 回目が上がる）。

### `wait` の観測は、HEAD が同じなら前回の状態を上書きしない（flatmate#899）

`wait` のときの次の状態は、前回と HEAD が同じなら前回の状態そのもの、違えば前回の状態に `{state: "wait", head: <今の HEAD>}` を重ねたもの。これで `conflict` → `UNKNOWN` → `conflict`（同じ HEAD）は「同じ状態・同じ HEAD」になり、依頼も修正回数も増えない。HEAD が変わったあとの `wait` は従来どおり状態名を `wait` にするので、新しい HEAD でまた止まれば新しい止まりとして扱う。やり直しの直後に次の状態名を `wait` にする既存の動き（同じ HEAD でもう一度落ちたら「状態が変わった」とみなして直しに進める）はそのまま残る。

### 状態のキーは flatmate の状態ファイルと同じにし、一手の名前は住人に依存しない語にする

状態のキーは `state` / `head` / `reran_head` / `fixes` / `raised` をそのまま使い、`decide` は前回の状態の知らないキー（住人の `last_done` など）を消さずに引き継ぐ。flatmate#976 で置き換えたとき、既存の状態ファイルの修正回数と上げ済みの印がそのまま効く。一手の名前は `queue`（住人の依頼の列）・`stall`（あなた待ちの印 `auto: pr-stall`）が住人の仕組みの名前なので、`none` / `ready` / `rerun` / `fix` / `escalate` にする。前回の状態が無い・`null`・`{}` は初見として扱う。

### 実装は bash と jq

判定は flatmate の jq の定義をほぼそのまま使えるので、jq の定義を 1 つの文字列に置き、サブコマンドの薄いシェルで包む。セッション（Bash ツール）からも住人（シェルスクリプト）からも追加の実行環境なしで呼べる。依存は `jq`（全サブコマンド）と `gh`（`annotations` だけ）。

## Risks / Trade-offs

- [Actions のジョブ ID とチェックラン ID が一致しない場合がある] → tasks 1.1 で実物の PR の `detailsUrl` とチェックランの API を突き合わせて確かめる。一致しないと分かったら `annotations` は `gh api repos/{o}/{r}/actions/jobs/{job}` の `check_run_url` を経由する。どちらでも `observe` / `decide` の入出力は変わらない
- [GitHub が通信切れの annotation の文言を変える] → 文言は定数 1 か所に置く。文言が変わると通信切れが `real` になり、やり直さずに直しに回る（安全側。直す側が失敗を読めば実行マシンの不調と分かる）
- [`annotations` を呼ぶ環境に `gh` の認証や checks の読み取り権限が無い] → 下の `gh api` の失敗と同じ扱いになり、通信切れも直しに回る。スクリプト冒頭のコメントに要る権限を書く
- [`annotations` の `gh api` が失敗する] → そのジョブは annotation 無しとして扱い（`real` になり直しに回る）、標準エラーに警告を出して exit 0。1 件の失敗で判定全体を止めない
- [呼び出し側が PR に関わる失敗を `--unrelated` で渡す] → やり直しは HEAD ごとに 1 回なので、同じ HEAD でもう一度落ちれば直しに回る。損失は CI 1 周分に限られる
