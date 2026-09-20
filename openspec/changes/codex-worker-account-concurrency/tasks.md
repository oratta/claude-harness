## 1. 設定をアカウントの属性として持つ

- [ ] 1.1 `register --max-concurrent`（既定 3）と `--quota-margin-pct`（既定 5）を受け取り、値の範囲（上限は 1 以上の整数、見込み消費率は 0 以上 100 以下）を検証して拒否するテストを書く（Red）
- [ ] 1.2 `accounts` テーブルへ `max_concurrent` / `quota_margin_pct` を `ADD COLUMN ... DEFAULT` で足し、`register` が値を書き込むようにする（Green）

## 2. グローバル予約をスロット化する

- [ ] 2.1 上限 2 のアカウントへ、作業ディレクトリの異なる依頼を 2 件投入すると両方受理され、3 件目が `account_slots_exhausted` で拒否されるテストを書く（Red）
- [ ] 2.2 同じ作業ディレクトリへの 2 件目が拒否されること、別の state-dir からの同じ作業ディレクトリの投入も拒否されることを確かめるテストを書く（既存の `test_other_ledger_cannot_bypass_ownership` を新しい拒否理由に合わせる）
- [ ] 2.3 `ownership.sqlite` に `account_slots(account_key, slot, ledger, job)` を作り、`reserve_global` がスロット 0 から順に空き（未使用、または先行ジョブが TERMINAL かつ受領済み）を探して確保するようにする
- [ ] 2.4 `reserve_global` の `BEGIN IMMEDIATE` の中で、`owners` に残っている `account:<hash>` の行をスロット 0 へ写して `owners` から消す移行を入れる。作業ディレクトリ側の `owners` の扱いは変えない
- [ ] 2.5 台帳内の `submit` の判定を `SELECT 1 FROM jobs WHERE acked=0 AND cwd=?` に変え、拒否理由を `cwd_locked` にする。アカウント側の判定は `reserve_global` に任せる
- [ ] 2.6 移行前の `owners` にアカウント行がある状態から投入して、ロックが引き継がれる（先行ジョブが未受領なら拒否される）ことを確かめるテストを書く

## 3. 残枠に余裕の幅を持たせる

- [ ] 3.1 使用率と「見込み消費率 × 占有本数」の合計が 100% を超えるとき `quota_headroom_insufficient` で止まり、超えないとき開始するテストを書く（Red）
- [ ] 3.2 `quota_available` に占有本数と見込み消費率を渡し、`usedPercent + quota_margin_pct * inflight <= 100` を要求するようにする。`quota_exhausted` と `quota_unknown` の既存の振る舞いは変えない
- [ ] 3.3 `worker()` が `account_slots` から自分を含む占有本数を数え、`account/rateLimits/read` の結果とあわせて `quota_available` に渡すようにする

## 4. サーバー側の同時実行拒否を扱う

- [ ] 4.1 `thread/start` / `turn/start` が同時実行を理由に失敗したとき、`failed` と `server_rejected_concurrent_turn` で終わり、再試行も別アカウントへの振り替えもしないテストを書く（Red）
- [ ] 4.2 `worker()` にその分岐を実装する

## 5. 放置された占有を外す

- [ ] 5.1 `reap` が、参照先台帳の消失・TERMINAL かつ受領済み・TERMINAL かつ未受領で既定 86400 秒を超えたもの、の 3 つを解放し、unknown を解放しないテストを書く（Red）
- [ ] 5.2 `reap [--older-than <秒>] [--account <名前>]` を CLI に足し、解放した件数と理由を stdout の JSON に出す

## 6. 受け入れ条件の再現検証とドキュメント

- [ ] 6.1 同時 2 件の投入・作業ディレクトリ重複の拒否・残枠が上限に近いときの拒否、の 3 つが独立したテストとして揃っていることを確認する
- [ ] 6.2 `plugins/dev-workflow/scripts/CODEX-WORKER.md` に、上限と見込み消費率の設定、新しい拒否理由（`cwd_locked` / `account_slots_exhausted` / `quota_headroom_insufficient` / `server_rejected_concurrent_turn`）、`reap` の使い方、古い版との併用を避ける注意を書く
- [ ] 6.3 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow エントリを 2.13.7 にする
- [ ] 6.4 `scripts/test.sh` を全件実行し、exit code を記録する
