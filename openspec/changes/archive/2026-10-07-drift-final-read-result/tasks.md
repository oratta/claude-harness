行番号は仕様づくりの時点（origin/main の f26fbecf）の値。前のタスクの編集でずれうるので、編集の前に該当範囲を読んで確かめる。

編集するファイルは合わせて 4 個（テスト 1、スクリプト 1（コメントのみ）、変更の記録 1、`openspec/specs` は archive で反映）。

## 1. テスト（固定）

- [x] 1.1 `drift.bats` に、最後のファイルの読み込み中に時計が上限を超えても読み終えた結果が使われることを見る 1 件を足す。bats の中で `python3` から `cost_ledger` を読み込み、`time.monotonic` を呼び出し回数で差し替える。`session_facts()` が呼ぶ順は、開始時刻の取得（1 回目）→ ファイルを開く前の確認（ファイル 1 つにつき 1 回）→ 5,000 行ごとの確認、なので、最初の 2 回（開始と、1 ファイルしか無い状態の開く前の確認）は 0 秒を返して開く前の確認では期限超過にしない。3 回目以降は 2 秒を返す（読み込み中に時計が進んだ状態）。対象は台帳または会話ログの 1 ファイルだけにして、`DRIFT_CHECK_EVERY_LINES` より短くする（行数ごとの確認が 1 度も働かず、3 回目の呼び出しも起きない）。予算 1 秒、公式 $10・自前 $6 のセッションで `price_drift()` を呼び、期待は `cut_off` が立たず `drifted` が 1。続けて同じ状態で `DRIFT_CHECK_EVERY_LINES` を 1 に差し替え、行数ごとの確認（3 回目の呼び出し）で初めて 2 秒を観測して `cut_off` が立つことも 1 件で見る（確認が働けば打ち切る側は変わっていないことの固定）。この 2 件は台帳の経路と会話ログの経路の両方で書く。アサーションには `|| return 1` を付ける。触る範囲: `plugins/cost-ledger/tests/drift.bats:314-360`（打ち切りのテスト群。この後ろに足す）、`plugins/cost-ledger/tests/drift.bats:19-58`（setup と行を作る関数。読むだけ）、`plugins/cost-ledger/scripts/cost_ledger.py:810-860`（`session_facts` の確認位置。読むだけ）

## 2. コメント

- [x] 2.1 `_drift_lines()` の docstring に、「読み終えた結果は上限を超えていても使う。確認を足さない理由は design.md」の趣旨を足す。処理は変えない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:788-794`、`plugins/cost-ledger/scripts/cost_ledger.py:806-808`（`session_facts` の docstring）

## 3. 確認と記録

- [x] 3.1 `bats plugins/cost-ledger/tests/drift.bats` が通ることを確かめる。触る範囲: なし（実行のみ）
- [x] 3.2 `plugins/cost-ledger/changes/701.md` を書く（決定と理由、LLM トークンを使わないこと、突き合わせ 1 回の所要時間の前後と `gh` の呼び出し回数の実測）。触る範囲: `plugins/cost-ledger/changes/701.md`（新規）
- [x] 3.3 エピック #272 の制約として、突き合わせ 1 回の所要時間の変更前後の実測値と `gh` の呼び出し回数（0 回のまま）を、PR 本文にも書く（変更の記録ファイルだけにしない）。変更前は `git archive origin/main` で取り出したスクリプトで測る。触る範囲: PR 本文（`gh api` の REST で作成・更新する）
