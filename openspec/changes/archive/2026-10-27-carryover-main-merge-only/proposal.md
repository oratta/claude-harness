# Proposal

## Why

主が一度許容した PR は、main を取り込んで HEAD が動いただけでも、衝突を解いたファイルがリスクの根拠ファイルや許可リストの外のファイルに当たると、引き継ぎにいくつも条件が付き（PR 全体を見た取り直しのレビュー・終了コード 4 の判定役・宣言本文の一致）、どれかが欠けると主に聞き直す（issue #1329。実例は PR #1313）。並列で作業している兄弟の PR が先に入ると「許容する → main が進む → また聞かれる」のループになる。主の判断（2026-10-25）は「許容したのはソースの編集ではなくどう変わるかで、衝突しないように main を取り込むこと自体を条件にするのは意味がない」であり、main の取り込みだけで HEAD が動いたなら条件を付けずに引き継ぐ。

## What Changes

- `risk-carryover-check.sh`: 前 HEAD から新しい HEAD までに積まれた commit が main を取り込む merge commit だけ（`PR_COMMITS=0`）で、履歴の判定（前 HEAD が祖先・merge commit が 2 親で第 2 親が base の祖先・第 1 親が PR の履歴の中）に `NG:` が無ければ、衝突解消のファイルが許可リストの外でも、根拠ファイルの差分がどうであっても、`CARRYOVER=yes` で終了コード 0 を返す。このとき根拠ファイルの PR 自身の差分の比較（`EVIDENCE_*` の分類と、そのためのバイナリ・merge-base の `NG:`）は行わない。`RESOLVED_FILES=` と `RESOLVED_OUTSIDE_ALLOWLIST=` の行は記録のために今どおり出す
- `PR_COMMITS` が 1 以上のときの判定（終了コード 1・4・3・0 とその優先順、判定役、PR 全体を見た取り直しのレビュー）は変えない
- `skills/pr-review-gate/stages/hold.md` 手順 3-c: スクリプトが終了コード 0 と `PR_COMMITS=0` を返したときは、取り直しのレビューの範囲（差分限定でよい）・判定役・条件 4（新しい HEAD で組み立てた宣言本文が前と同一）によらず引き継ぐと書く。引き継いだ宣言の本文は前の宣言の本文のままにする。条件 2（根拠ファイルの行）と条件 3（元の回答の真正性の確かめ直し）は残す
- `skills/pr-review-gate/stages/pass.md`: 合格条件と develop での合格処理の読み方が、この引き継ぎ（`PR_COMMITS=0` の終了コード 0）でも今の 4 行の追記で通ることを確かめ、要るなら文言を合わせる
- **BREAKING**（判定の結果が変わる）: main の取り込みだけの場合、これまで終了コード 3（許可リスト外の衝突解消）・4（衝突解消が根拠ファイルの PR の変更を変えた）・1（バイナリの根拠ファイル・merge-base が 1 つに決まらない）になっていた入力が終了コード 0 になる。また、同じ場合に以前は出ていた `EVIDENCE_MAIN_ONLY=` の行が出なくなり、`EVIDENCE_DIFF_LINES=0` になる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「前の HEAD の許容を新しい HEAD に引き継いでよい条件」（main の取り込みだけなら条件①の取り直しのレビュー・判定役・条件④を外す。守備範囲の書き直し）、要件「risk-carryover-check.sh が差分の範囲と根拠ファイルの PR 自身の差分を判定する」（`PR_COMMITS=0` の終了コード 0 と、その場合に根拠ファイルの比較をしないこと）、要件「引き継いだ宣言の書式と合格条件」（引き継ぎの根拠の行の根拠ファイルの欄に「PR_COMMITS=0 のとき: 比べず（PR 自身の commit 0 件）」の選択肢を足す）、要件「終了コード 4 は作業の文脈を持たない判定役に比べさせる」（場面「main の取り込みだけなら判定役を起こさない」の中身を `PR_COMMITS=0` の場合に直し、PR 自身の commit がある場合の場面を足す）

## Impact

- `plugins/dev-workflow/scripts/risk-carryover-check.sh`
- `plugins/dev-workflow/tests/risk-carryover-check.bats`（`PR_COMMITS=0` で終了コード 3・4 を期待している既存のテストは、PR 自身の commit を積んだ形に直すか、終了コード 0 の期待に直す）
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（3-c）
- `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（要るときだけ）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（3-c の文言を見るテストが新しい文で通るか）
- `plugins/dev-workflow/changes/1329.md`（新規）
- 終了コード 4 の判定役・判定の記録・引き継いだ宣言の 4 行の書式・`needs-carryover-judge` の return は変えない
