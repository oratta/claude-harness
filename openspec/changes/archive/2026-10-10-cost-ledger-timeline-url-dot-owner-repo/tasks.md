## 1. 実装とテスト

- [x] 1.1 位置引数の URL から取り出した owner / repo に `valid_parts()` を掛け、通らなければ対象にしない。触る範囲: plugins/cost-ledger/scripts/gate_report.py:503-505（`trigger_targets()` の、位置引数の URL を対象にする分岐。行番号はこの change を作った時点の main）
- [x] 1.2 URL の経路のテストを 1 本足す（owner 側と repo 側・`.` と `..`・`-R` や `GH_REPO` との併記・正当な名前の対照）。触る範囲: plugins/cost-ledger/tests/gate-report.bats:708（`gh api` の endpoint の `.` / `..` のテストの直後に足す。行番号は同上）

## 2. spec

- [x] 2.1 「対象の解決」の、owner / repo が `.` か `..` の対象を飛ばす文に、位置引数の URL と、併記した `-R` / `GH_REPO` に落ちないことを足す。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:89（要件「対象の解決」の本文。行番号は同上）
- [x] 2.2 同じ要件の守備範囲の、位置引数の URL を見ないとしていた項目を、4 つの経路のどれでも見ない形（`a/...`・`a/b..`）の項目に差し替え、「許可の一覧」に `cost-ledger-write-allowlist` を添える。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:97（同じ要件の「守備範囲:」の段落。行番号は同上）
- [x] 2.3 Scenario を 2 つ足す。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:143（同じ要件の Scenario「owner / repo が `.` か `..` の対象は飛ばす」の直後に足す。行番号は同上）

## 3. 確認

- [x] 3.1 直す前後の `find_triggers()` の結果を同じ入力で比べ、変わるのが「URL の owner / repo が `.` か `..` のとき対象なしになる」だけであること
- [x] 3.2 足したテストが、拒否を外した複製・owner だけ／repo だけ拒否する複製で落ちること
- [x] 3.3 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通ること
