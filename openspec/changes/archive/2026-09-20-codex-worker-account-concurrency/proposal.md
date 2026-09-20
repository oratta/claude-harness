## Why

Codex へ委譲した開発が 1 アカウントにつき同時 1 件しか走らない。`codex-worker.py` の submit が、未受領（ack されていない）ジョブの中に同じ作業ディレクトリか同じアカウントのものが 1 件でもあれば拒否するため、アカウントを 1 つしか持たない通常の状態では委譲がすべて直列になる。アカウント側を 1 件に絞っている理由は認証ファイルの奪い合いではなく残枠の確認にあり（ターン開始直前に読む使用率に、同時に走っている別ジョブの消費が入らない）、この 1 点を解けば並列に流せる。

## What Changes

- アカウント単位の排他を「1 件」から「設定で決まる上限 N 件」に変える（既定 N = 3）。**BREAKING**: 拒否理由の名前が変わる。台帳の中の `cwd_or_account_locked` は作業ディレクトリ側の `cwd_locked` だけになり、アカウント側は `account_slots_exhausted` になる。台帳をまたぐ `global_account_or_cwd_locked` は作業ディレクトリ側の `global_cwd_locked` だけになる。
- 作業ディレクトリ単位の排他は変えない（同じ作業ディレクトリへの 2 件目は今までどおり拒否する）。
- 台帳（state-dir）をまたぐグローバル予約 `reserve_global` を、アカウントキー 1 行の占有からスロット N 個の占有に変える。作業ディレクトリキーは 1 行のまま。
- 残枠の判定に余裕の幅を持たせる。使用率が 100% 未満であることだけを見るのをやめ、同時に占有されている本数 × 1 本あたりの見込み消費率を足しても 100% を超えないことを要求する（見込み消費率の既定は 5%）。
- サーバーがスレッドまたはターンの開始を**エラー応答で**拒んだ場合は、理由を台帳に残して `failed` で停止する。**BREAKING**: 現行はターン開始の失敗をすべて `unknown` にしている。切断・タイムアウト（受理されたか分からない場合）は従来どおり `unknown` のままにする。
- 受領されないまま終わったジョブが握り続けているアカウント側のスロットを外すコマンド `reap` を追加する。作業ディレクトリ側のロックは従来どおり `ack` で空く。

## Capabilities

### New Capabilities
- `codex-worker-concurrency`: 1 アカウントで同時に実行できる Codex ジョブの本数、そのスロットの確保と解放、残枠判定の余裕の幅を決める。

### Modified Capabilities
（なし。アカウントと作業ディレクトリの排他を規定している要件「アカウントと作業ディレクトリを排他的に所有する」は、まだ `openspec/specs/` に取り込まれておらず、未アーカイブの change `add-codex-worker` の delta の中にある。そのため差分ではなく新しい capability として書き、アカウント側の扱いをこちらが上書きすることを spec の本文に明記する。)

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`: `submit` の拒否条件、`reserve_global`、`quota_available`、`worker()` の残枠呼び出し、CLI のサブコマンドとオプション。
- `plugins/dev-workflow/tests/test_codex_worker.py`: 同時 2 件の投入・作業ディレクトリ重複の拒否・残枠が上限に近いときの拒否の 3 つを再現検証する。
- `plugins/dev-workflow/scripts/CODEX-WORKER.md`: 新しい設定・拒否理由・`reap` の手順。
- `~/.local/state/claude-harness-codex/ownership.sqlite`: アカウント側のスロットを持つテーブルを追加し、既存のアカウント行を初回に移す。
- 未アーカイブの change `add-codex-worker` の delta にアカウント側の排他を 1 件と読める MUST が残るので、この change をアーカイブする時点で文面を突き合わせる（tasks.md の 7 章）。
