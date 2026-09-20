## 1. 設定をアカウントの属性として持つ

- [ ] 1.1 `register --max-concurrent`（既定 3）と `--quota-margin-pct`（既定 5）を受け取り、値の範囲（上限は 1 以上の整数、見込み消費率は 0 以上 100 以下）を検証して拒否するテストを書く（Red）
- [ ] 1.2 同じアカウント名へ再登録したとき、オプションを省略すると既定値で上書きされることを確かめるテストを書く
- [ ] 1.3 `accounts` テーブルへ `max_concurrent` / `quota_margin_pct` を `ADD COLUMN ... DEFAULT` で足し、`register` が値を書き込むようにする（Green）

## 2. グローバル予約をスロット化する

- [ ] 2.1 テスト用の作業ディレクトリをもう 1 本用意する（`setUp` の worktree を 2 本にする）。偽サーバー（`FAKE`）は `fixture.json` と `calls.jsonl` を認証元ディレクトリで共有しており、同時 2 件では両ジョブが同じ設定を読むので、ジョブごとに設定を分けたい場合はジョブ ID で分ける
- [ ] 2.2 上限 2 のアカウントへ、作業ディレクトリの異なる依頼を 2 件投入すると両方受理され、3 件目が `account_slots_exhausted` で拒否されるテストを書く（Red）
- [ ] 2.3 既存テスト `test_disconnect_unknown_keeps_lock`（`plugins/dev-workflow/tests/test_codex_worker.py:129`）の assert を `cwd_or_account_locked` から `cwd_locked` へ、`test_other_ledger_cannot_bypass_ownership`（同 `:151`）を `global_account_or_cwd_locked` から `global_cwd_locked` へ直す
- [ ] 2.4 スロットの状態を判定する読み取り専用のヘルパを作る。行が無い／参照先ジョブが TERMINAL かつ受領済み → 空き。queued・running・unknown・TERMINAL かつ未受領・参照先台帳が読めない → 占有中。`reserve_global` と 3 章の占有本数の数え上げの両方がこれを使う
- [ ] 2.5 `ownership.sqlite` に `account_slots(account_key, slot, ledger, job)`（主キーは `(account_key, slot)`）を作り、`reserve_global` がスロット 0 から順に最初の空きを取るようにする。全部が占有中なら `account_slots_exhausted`
- [ ] 2.6 参照先の台帳ファイルが無いスロットを「占有中」として飛ばし、他に空きがあれば投入が通ることを確かめるテストを書く（現行の `global_owner_unknown` で投入全体を落とさない。`codex-worker.py:111` の変更点）。投入は**別の作業ディレクトリ**から行う。作業ディレクトリ側の `owners` 行は従来どおりで、その参照先の台帳が無ければ `global_owner_unknown` のまま落ちる（この change が扱うのはアカウント側のスロットだけ）
- [ ] 2.7 `reserve_global` の `BEGIN IMMEDIATE` の中で、`owners` に残っている `account:<hash>` の行をスロット 0 へ写して `owners` から消す移行を入れる。作業ディレクトリ側の `owners` の扱いは変えない
- [ ] 2.8 移行前の `owners` にアカウント行がある状態から投入して、ロックが引き継がれる（先行ジョブが未受領なら拒否される）ことを確かめるテストを書く
- [ ] 2.9 台帳内の `submit` の判定を `SELECT 1 FROM jobs WHERE acked=0 AND cwd=?` に変え、拒否理由を `cwd_locked` にする。台帳をまたぐ作業ディレクトリの重複は `global_cwd_locked` にする。アカウント側の判定は `reserve_global` に任せる

## 3. 残枠に余裕の幅を持たせる

- [ ] 3.1 使用率と「見込み消費率 × 占有スロット数」の合計が 100% を超えるとき `quota_headroom_insufficient` で止まり、超えないとき開始するテストを書く（Red）
- [ ] 3.2 上限まで走らせたジョブをすべて完了・受領したあとの 1 件が、占有スロット数 1 として判定されて開始できることを確かめるテストを書く（スロット行が残っていても数に入れない）
- [ ] 3.3 `quota_available` の判定順を、(1) `usedPercent >= 100` なら `quota_exhausted`、(2) 100% 未満のときだけ `usedPercent + quota_margin_pct * inflight <= 100` を要求して不足なら `quota_headroom_insufficient`、にする。primary / secondary の両方の窓に同じ判定を掛ける。既存テスト `test_exhausted_quota_never_starts_turn` と `test_unknown_quota_is_not_permission` の振る舞いは変えない
- [ ] 3.4 `worker()` が 2.4 のヘルパで自分を含む占有スロット数を数え、`account/rateLimits/read` の結果とあわせて `quota_available` に渡すようにする。旧版で投入されたジョブは `account_slots` に行が無く 0 と数えられうるので `max(count, 1)` にする

## 4. サーバー側の拒否をエラー応答と切断で分ける

- [ ] 4.1 `thread/start` / `turn/start` に対してサーバーがエラー応答（id 付き）を返したとき、`failed` になり `error_kind` にそのエラーコードが含まれるテストを書く（Red）
- [ ] 4.2 応答が得られないまま切断した場合が従来どおり `unknown` のままであることを確かめるテストを書く。既存の `test_disconnect_unknown_keeps_lock` の偽サーバーは `turn/start` に応答してから終了するので、spec の Scenario「ターン開始の要求後に切断する」（応答なし）を直接なぞる fixture（例 `disconnect_before_reply`）を 1 本足し、そちらでも `unknown` になることを確かめる
- [ ] 4.3 `Rpc.request` がエラー応答のときだけ `Rejected` の下位クラス（例 `ServerRejected`）をエラーコード付きで投げるようにする（`codex-worker.py:231-232`）
- [ ] 4.4 `worker()` の例外処理（`:369`、`turn_submitted` による分岐）を直す。`turn/start` が正常応答を返した時点で立てるフラグ（例 `turn_accepted`）を追加し、except 節では `ServerRejected` **かつ `turn_accepted` が偽**のときだけ `failed` + `server_rejected_start_<コード>` にする。`turn_accepted` が真のあとの `ServerRejected`（受理済みターンに対する `turn/interrupt` や `thread/read` のエラー応答）は従来どおり `unknown`。それ以外の例外も従来どおり
- [ ] 4.5 同時実行を理由とするエラー応答の判別規則が確認できた場合だけ、`server_rejected_concurrent_turn` に置き換える分岐と、その一致条件を `CODEX-WORKER.md` に書く。確認できなければ規則は入れず、全件をエラーコード付きで残す旨だけ書く

## 5. 放置されたアカウント側の占有を外す

- [ ] 5.1 `reap` が、TERMINAL かつ受領済み・TERMINAL かつ未受領で既定 86400 秒を超えたもの、の 2 つだけを解放し、`unknown` と参照先台帳の無いものを解放しないテストを書く（Red）
- [ ] 5.2 `reap` のあとでも同じ作業ディレクトリへの再投入が `cwd_locked` で拒否される（作業ディレクトリ側のロックを外さない）ことを確かめるテストを書く
- [ ] 5.3 `reap [--older-than <秒>] [--account <名前>]` を CLI に足す。出力 JSON に、解放したスロットとその理由（`acked` / `stale_unacked`）だけでなく、解放しなかったスロットとその理由（`unknown` / `ledger_missing` / `not_stale`）も載せる

## 6. 受け入れ条件の再現検証とドキュメント

- [ ] 6.1 同時 2 件の投入・作業ディレクトリ重複の拒否・残枠が上限に近いときの拒否、の 3 つが独立したテストとして揃っていることを確認する
- [ ] 6.2 `plugins/dev-workflow/scripts/CODEX-WORKER.md` に次を書く。上限と見込み消費率の設定と、省略時は既定値で上書きされること・未受領ジョブがあると `register` が拒否されるので上限の変更は全件 `ack` の後にしかできないこと。新しい拒否理由（`cwd_locked` / `global_cwd_locked` / `account_slots_exhausted` / `quota_headroom_insufficient` / `server_rejected_start_<コード>`、判別できた場合の `server_rejected_concurrent_turn`）。`reap` の使い方と、外れるのはアカウント側のスロットだけで作業ディレクトリは `ack` で空くこと。古い版との併用を避ける注意
- [ ] 6.3 `CODEX-WORKER.md` の「参照先喪失はunknownとして拒否する」の一文を、アカウント側と作業ディレクトリ側の両方を書く形に直す。アカウント側のスロットは占有中として飛ばし（投入全体は止めない）`reap` でも解放しない。作業ディレクトリ側は従来どおり拒否する
- [ ] 6.4 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow エントリを 2.13.7 にする
- [ ] 6.5 `scripts/test.sh` を全件実行し、exit code を記録する

## 7. アーカイブ前の文面の突き合わせ

- [ ] 7.1 この change をアーカイブする直前に `openspec/specs/codex-worker/spec.md` の有無を確認する。存在していれば、要件「アカウントと作業ディレクトリを排他的に所有する」からアカウント側の排他を外す MODIFIED delta をこの change に足してからアーカイブする。存在していなければ、未アーカイブの change `add-codex-worker` の担当への申し送りを issue #326 にコメントする
