行番号は仕様づくりの時点（origin/main の f26fbecf）の値。前のタスクの編集でずれうるので、編集の前に該当範囲を読んで確かめる。

編集するファイルは合わせて 4 個（テスト 1、スクリプト 1（コメントのみ）、変更の記録 1、`openspec/specs` は archive で反映）。

## 1. テスト（固定）

- [ ] 1.1 `drift.bats` に、最後のファイルの読み込み中に時計が上限を超えても読み終えた結果が使われることを見る 1 件を足す。bats の中で `python3` から `cost_ledger` を読み込み、`time.monotonic` を差し替えて 0 秒始まり・2 秒進みにし（読み直しの開始時の呼び出しは 0、その後は 2 を返す）、`DRIFT_CHECK_EVERY_LINES` より短い 1 ファイルで `price_drift()` を呼ぶ。予算 1 秒、公式 $10・自前 $6 のセッション。期待は `cut_off` が立たず `drifted` が 1。同じ状態で、行数ごとの確認が働く長さ（`DRIFT_CHECK_EVERY_LINES` を 1 に差し替える）なら `cut_off` が立つことも 1 件で見る（確認が働けば打ち切る側は変わっていないことの固定）。台帳から読む経路でも 1 件。アサーションには `|| return 1` を付ける。触る範囲: `plugins/cost-ledger/tests/drift.bats:314-360`（打ち切りのテスト群。この後ろに足す）、`plugins/cost-ledger/tests/drift.bats:19-58`（setup と行を作る関数。読むだけ）

## 2. コメント

- [ ] 2.1 `_drift_lines()` の docstring に、「読み終えた結果は上限を超えていても使う。確認を足さない理由は design.md」の趣旨を足す。処理は変えない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:788-794`、`plugins/cost-ledger/scripts/cost_ledger.py:806-808`（`session_facts` の docstring）

## 3. 確認と記録

- [ ] 3.1 `bats plugins/cost-ledger/tests/drift.bats` が通ることを確かめる。触る範囲: なし（実行のみ）
- [ ] 3.2 `plugins/cost-ledger/changes/701.md` を書く（決定と理由、LLM トークンを使わないこと、突き合わせ 1 回の所要時間の前後と `gh` の呼び出し回数の実測）。触る範囲: `plugins/cost-ledger/changes/701.md`（新規）
