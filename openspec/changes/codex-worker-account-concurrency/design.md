## Context

`plugins/dev-workflow/scripts/codex-worker.py` は、Codex へ委譲した仕事を親プロセスから切り離して実行する台帳付きの worker である。排他は 2 箇所にある。

ひとつは台帳の中で、`submit` が `SELECT 1 FROM jobs WHERE acked=0 AND (cwd=? OR account=?)` を引き、1 件でも当たれば `cwd_or_account_locked` で拒否する（`codex-worker.py:405` 付近）。もうひとつは state-dir をまたぐグローバル予約 `reserve_global`（97 行〜）で、`~/.local/state/claude-harness-codex/ownership.sqlite` の `owners` テーブルに `account:<hash>` と `cwd:<hash>` の 2 キーを入れ、先行ジョブが TERMINAL かつ受領済みでなければ `global_account_or_cwd_locked` で拒否する。アカウント側を緩めるには、この 2 箇所の両方を変える必要がある。

アカウント側を 1 件に絞っている理由は残枠の確認にある。`quota_available`（169 行〜）が `usedPercent < 100` を要求し、`worker()` がターン開始の直前に `account/rateLimits/read` の結果をこれに渡す（297 行付近）。同じアカウントで 2 本同時に走ると、後から始まる方が読む使用率に先行ジョブの消費が入っていない。

認証プロファイルの奪い合いは理由ではない。ジョブごとに専用の `runtimes/<ジョブID>/` を作り、そこから共有の `auth.json` へシンボリックリンクを張るので、認証ファイルは書き換わらない。

## Goals / Non-Goals

**Goals:**
- 同じアカウントで、別々の作業ディレクトリの仕事を設定した上限まで同時に実行できる。
- 残枠の判定が、同時に走っている本数を見込んでも上限を超えないものになる。
- 受領されないまま終わったジョブがスロットを握り続けたとき、それを外す手段がある。
- サーバー側が同時実行を拒否したときに、理由を残して止まる。

**Non-Goals:**
- 複数アカウントの登録・巡回・配分（親エピックの別の子）。
- 作業ディレクトリ単位の排他の変更。
- 実行中のジョブへの追加指示（`send` / steer）や、unknown からの自動復旧。
- 別ホスト・別 OS ユーザー・別 HOME をまたぐ排他（従来どおり対象外）。

## Decisions

### 上限と余裕の幅は、register 時にアカウントの属性として台帳へ入れる

`accounts` テーブルに `max_concurrent` と `quota_margin_pct` の 2 列を足し、`register` の任意引数 `--max-concurrent`（既定 3）・`--quota-margin-pct`（既定 5）で決める。既存の行は `ALTER TABLE ... ADD COLUMN ... DEFAULT` で既定値を得る。

`submit` の引数や環境変数にしなかったのは、同じアカウントに違う上限が混ざると判定が呼び出し側の裁量になるためである。環境変数は、worker が子プロセスへ渡す変数を allowlist で絞っている（`clean_env`）設計と噛み合わず、submit する側のシェルごとに値が変わる。上限は「そのアカウントで何本流してよいか」というアカウントの性質なので、アカウントの登録情報と同じ場所に置く。

### グローバル予約は、アカウントキーを 1 行からスロット N 行に変える

`ownership.sqlite` に `account_slots(account_key TEXT, slot INTEGER, ledger TEXT, job TEXT, PRIMARY KEY(account_key, slot))` を足す。作業ディレクトリ側は今までどおり `owners` の 1 行のままにする。

`owners` の主キーは `key` 単独なので、`ALTER TABLE` ではスロットを持てない。既存の `owners` を作り直すと、いま走っているジョブのロックが消える。そこで作業ディレクトリ側は触らず、アカウント側だけ新しいテーブルへ移す。移行は予約の `BEGIN IMMEDIATE` の中で行い、`owners` に `account:<hash>` の行が残っていれば `account_slots` のスロット 0 へ写して `owners` から消す。

確保は、スロット 0 から N-1 を順に見て、空いているか先行ジョブが TERMINAL かつ受領済みの最初のスロットを取る。全部埋まっていれば `account_slots_exhausted` で拒否する。台帳の中の `submit` の判定も、`cwd=?` だけの拒否（`cwd_locked`）に変え、アカウント側は `reserve_global` の結果に委ねる。

別の state-dir が別の上限を登録していても整合を取らない。上限が食い違えば大きい方を登録した側が多くスロットを取るが、後述の残枠判定が実際の占有スロット数を数えて効くので、上限超過は残枠側で止まる。ownership 側に上限を持たせて食い違いを拒否する案も考えたが、片方の state-dir で登録し直しただけで全部の投入が止まるため採らない。

### 残枠は「使用率 + 見込み消費率 × 同時本数」で判定する

`quota_available` が `usedPercent < 100` を要求しているのを、`usedPercent + quota_margin_pct * inflight <= 100` に変える。`inflight` は自分を含む、そのアカウントで現在占有されているスロット数で、`account_slots` を数えて得る。不足していれば `quota_headroom_insufficient` で止める（`quota_exhausted` とは別の理由にして、100% 到達と余裕不足を混同しない）。

既定の 3 本・5% では、使用率 85% を超えた時点で 3 本目が止まる。余裕の幅を「1 本あたりの見込み消費率」に置いたのは、ターン開始前には実際の消費量が分からないので、定数で見積もるしかないためである。開始前後の使用率の差分から実測する案は、ターンの長さと内容で大きく振れるうえ、先行ジョブの差分がまだ取れていない 1 本目に適用できない。

`quota_unknown`（窓が読めない・不正）の扱いは変えない。

### サーバー側が同時実行を拒否したら、理由を残して止まる

`thread/start` または `turn/start` が同時実行を理由に失敗したら、status を `failed`、`error_kind` を `server_rejected_concurrent_turn` にして終える。再試行しない。別アカウントへ振り替えない。スロットは他の TERMINAL なジョブと同じで、受領されるまで保持する（証拠を残したまま次を詰め込まないため）。

### 放置されたスロットは `reap` コマンドで外す

`codex-worker.py --state-dir <dir> reap [--older-than <秒>] [--account <名前>]` を追加する。各スロットについて参照先の台帳を読み、次のときだけ解放して、解放した件数と理由を stdout の JSON に載せる。

- 参照先の台帳ファイルが無くなっている（`ledger_missing`）。
- ジョブが TERMINAL かつ受領済み（`acked`）。
- ジョブが TERMINAL だが未受領で、最終更新から `--older-than`（既定 86400 秒）を超えている（`stale_unacked`）。

`unknown`（実行の終わりを観測できていない状態）のスロットは `reap` でも解放しない。これは「不明な実行を再投入しない」という既存の要件を維持するためで、解放したい場合は運用者が状況を確かめてから当該ジョブを `ack` する。

自動解放にしなかったのは、未受領のまま終わったジョブは結果が読まれていないことを意味し、時間だけを根拠に黙って捨てると結果の取りこぼしに気づけなくなるためである。明示コマンドにすれば、外した事実が実行ログに残る。

## Risks / Trade-offs

- 見込み消費率は定数の見積もりなので、実際の消費がそれを上回ると使用率が 100% に達しうる → 既定を 5% と保守的に置き、`register` で上げられるようにする。100% に達した場合の振る舞いは既存の `quota_exhausted` のままで、次のターン開始が止まる。
- 同じアカウントの 3 本が同時にサーバーへ投げるため、サーバー側の同時実行制限に当たる可能性が上がる → 当たったら `server_rejected_concurrent_turn` で止め、黙って直列に戻さない。運用者は `register --max-concurrent` を下げて調整する。
- `ownership.sqlite` にテーブルを足し、アカウント行を移す → 移行は予約の排他トランザクションの中で行い、作業ディレクトリ側の `owners` は触らない。古い版の `codex-worker.py` を同じ HOME で併用すると、新しい版が取ったスロットを古い版が見ないので排他が壊れる。併用しない。
- 未アーカイブの change `add-codex-worker` の delta に「同じ account/cwd は別台帳からも重複実行を拒否する（MUST）」が残っており、この change の要件と正面からぶつかる → 新しい capability の要件本文に、アカウント側の扱いをこちらが上書きすると明記する。どちらかがアーカイブされる時点で文面の突き合わせが要る（この change の範囲外）。

## Migration Plan

1. `accounts` に 2 列を足す（既定値付きの `ADD COLUMN` なので既存の登録は動き続ける）。
2. `ownership.sqlite` に `account_slots` を作り、予約のたびに `owners` のアカウント行をスロット 0 へ写して消す。
3. 上限の既定は 3。従来どおり 1 本で運用したい場合は `register --max-concurrent 1` で戻せる（ロールバック経路）。
