## Why

`plugins/casting/tests/casting-structure.bats` は、`casting-check.sh` が報告する検出カテゴリ数を実装から機械的に取るために `report` 呼び出しを grep で数えている。落としていたのは行頭コメント行だけで、シェルの構文は見ていないため、次の「コードではない `report`」も呼び出しとして数えていた（oratta/claude-harness#163）:

- ヒアドキュメント本文（`<<'EOF' … report "x" … EOF`）
- 行末コメント（`some_cmd  # report "x" と書き換える`）
- 文字列リテラルの中（`echo 'usage: report "x" msg'`）

ずれる向きは偽陽性だけで、リテラル一致は `count_report_calls` と `count_literal_report_calls` を同じだけ増やすため、非リテラル呼び出しを相殺して検査をすり抜けさせる経路にはならない。実害は「テストが理由なく赤くなる」ことで、`report` の語を含む使い方出力やエラーメッセージを `casting-check.sh` に足した瞬間、数え方と無関係な2つのテスト（「documented five」「N項目」の突き合わせ）が落ちて原因が分かりにくくなる。issue #163 の triage で 3 形とも現行 main（`7b81280`）で再現済み。

## What Changes

- **数え方の本体を `plugins/casting/tests/lib/report-calls.py` に切り出す**: シェルの引用・コメント・ヒアドキュメントだけを見る軽量スキャナで、コード領域にある `report` 呼び出しを「`<行番号> literal <カテゴリ>` / `<行番号> nonliteral <抜粋>`」の1行1件で列挙する。完全なシェルパーサではなく（`$(…)` の中身は素通し）、判定に迷う形はすべて多めに数える側（偽陽性）へ倒す
- **`casting-structure.bats` のカウンタをスキャナ経由に付け替える**: `check_script_body` を廃し、`report_calls` / `literal_report_categories` を土台に `detection_categories`・`count_report_calls`・`count_literal_report_calls` を組み直す。呼び出しの判定規則（直前は行頭か `[;&|(){}` か空白／直後は空白＋非空白）は grep 時代のまま引き継ぐので、`report()` の定義行を拾わないことと、行継続（`report \`）が nonliteral として検査に出ることは変わらない
- **偽陽性 3 形の退行テストを追加する**: 合成スクリプトで 3 形が 1 件も足さないことと、同じスクリプトに本物の呼び出しを 1 件足すとカテゴリ数が 1 になること（＝カウンタを緩めて数え落とし側へ逃げていないこと）を続けて assert する
- **`casting-check.sh` は変更しない**: 制約を受け入れて「`report` を含むヒアドキュメントを書かない」と注意書きを置く案（issue の二択のもう片方）は採らない。書いてよい/いけない記述をスクリプト側に覚えさせる規約が増えるうえ、違反しても落ちるのは無関係なテストのままで、原因の分かりにくさが解消しないため

## Capabilities

### Modified Capabilities

- `casting-project-files`: 「検出項目数の表記と実装の一致」に、数え上げの対象をコード領域の `report` 呼び出しに限る要件と、偽陽性側へ倒す（数え落とし側へ倒さない）方向の要件を追加する

## Impact

- `plugins/casting/tests/lib/report-calls.py` — 新設（数え方の本体）
- `plugins/casting/tests/casting-structure.bats` — カウンタの付け替え・退行テスト 1 件追加（24 → 25 tests）
- `openspec/specs/casting-project-files/spec.md` — 「検出項目数の表記と実装の一致」に要件と Scenario を追加
- `plugins/casting/scripts/casting-check.sh`・README・SKILL.md・plugin.json・marketplace.json は変更しない（検出カテゴリは 5 件のまま・「N項目」表記も動かない）
