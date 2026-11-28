# Codex develop の例外依頼

一時書き込みレビュー・V・引き継ぎ判定・論点なし確認を処理するときに読む。

- 一時書き込みが必要な関連テスト（bats、`mktemp`、`TMPDIR` / `BATS_TMPDIR`、pytest 等）の再実行レビューは、呼び出し側が分類し、開始時と同じ実行先指定・account-home・coordinator を付けて `request --phase review --request-kind temp-write-review` を通す。読み取り専用レビュアーが再実行できなかった場合も同じ request を通す。起動許可なら返った model で Claude のレビュアー（`dev-workflow:reviewer`）を同じ固定 HEAD で起こし、書き込める同一パスを `TMPDIR` / `BATS_TMPDIR` に渡して取り直す（補足済み回数を増やさず、`review-incomplete` で止めない）。起動不可なら Claude も代替の Codex 役も起こさず、レビュー未完了と理由を記録して一時書き込みレビュー待ちで保留する。主の再実行証拠による復帰は下の同名節に従う。CI/W の結果で代用せず、read-only role に writableRoots を追加しない。
- 4 例外は通常の依頼（`--request-kind normal`）と区別し、V は `--phase implement --request-kind visual-check`、引き継ぎ判定と論点なし確認は `--phase decider --request-kind carryover-judge` / `--request-kind no-point-check` を使う。開始時の指定を保持して request を通し、`status: blocked` / `launchable: false`（exit 2）なら起動しない。codex-standard 等の Claude を使わない構成では 4 例外を非起動とし、通常の書き込み不要レビューは独立した Codex 読み取り役で継続する。dispatch 記録には phase・request_kind・role・非起動の理由（error）・selection を残し、構成があれば execution_config とその hash も残す。未実行を合格にしない。

## 主の再実行証拠による復帰

この節は Claude を使わない構成での一時書き込みレビュー待ちだけに適用する。主の結果だけで合格にしない。一時書き込みテストの自己再実行のみを限定例外とし、Claude を使える場合の reviewer 自身の再実行・Claude 取り直しと、一時書き込み不要の関連テスト・lint の自己再実行義務は維持する。同一固定 HEAD・read-only 権限を保ち、writableRoots は追加しない。

1. 本体は主に固定 HEAD・関連テストの正確なコマンド/範囲・環境/一時領域・期待結果を示して独立再実行を依頼する。CI/W の結果では代用しない。
2. 証拠には対象 HEAD・正確なコマンド/範囲・環境/一時領域・実施日時・出力・終了コード・回答の出典が必要。本体は照合して PR に記録し、証拠 URL を残す。回答の出典は回答リンク、会話ならセッション ID・日時・原文、親経由なら既存の hold-resume の復帰手順の出典情報とする。必須記録が不足する間は保留を続け、既存結果への補足のみを求める。同じ実行の再依頼はしない。主の結果が失敗なら証拠を記録して既存の修正サイクルへ戻し、成功や独立レビュー完了とは扱わない。
3. 同じ HEAD・同じ範囲の有効な証拠があれば再依頼しない。既存の証拠 URL を次の reviewer / G に渡す。HEAD または対象範囲が変わったときだけ新しい対象での再実行を求める。
4. 成功結果と必須記録が揃ったら、W と別 thread の通常の read-only Codex reviewer に固定 HEAD と証拠 URL を渡す。この起動は `request --phase review --request-kind normal` を通し、残るコード/三表レビュー・可能な再実行・主の結果評価を完了させる。独立レビュー完了結果と証拠 URL が揃うまで保留し、主の結果だけで一般の動作確認代行の手順 5 に直行しない。本体は独立レビュー完了結果と証拠 URL を fresh G に渡し、G は既存の合格条件を再確認する。
