## Context

`review-hit-set.py --head` は、順 3 の補助表 `### 書き換えた該当しない行` と主表の扱い欄を検査する。現状はどちらの検査も `ContractError` を即座に raise し、`main()` を呼ぶ `try` の外側の `except (ContractError, OSError, RuntimeError, ValueError)` で捕まえて `contract: <message>` を stderr に 1 行出し、exit 1 で終わる。1 回の実行で見つかる違反は常に 1 件だけになる。

同じスクリプトはもう一つの出力経路も持つ：`main()` が正常終了する側では `missing:` `extra:` `unmatched:` `not-removed:` を `report` リストに積み、全部の検査が終わってから `for line in report: print(line)` でまとめて stdout に出し、`return int(bool(report))` で exit code を決める。この 2 系統目の書式（全件検査 → 蓄積 → まとめて出力）を、行単位の内容違反にもそのまま使う。

## Goals / Non-Goals

**Goals:**
- `parse_rewritten` と `main` の `--head` 検査ループで見つかる行単位の内容違反（扱い欄の値が2値のどちらでもない、補助表の行が扱い「該当しない」の行をちょうど 1 つ指さない、重複した補助表の行、書き換えていない補助表の行）を、最初の 1 件で止めず全件検査してから `report` にまとめて出す。
- 表の構造そのものが検査を続けられない種類のエラー（見出し欠落、列数不一致、必須フィールド欠落、SHA 形式不正、検索コマンド構文違反）は、従来どおり `ContractError` の即時 raise・exit 1 のまま変えない。

**Non-Goals:**
- 順 3 の運用手順（G が W に差し戻す回数の上限、仕分け表の順そのもの）は変えない。今回の変更はスクリプトが違反を検出する粒度だけを直す。
- `--head` を付けない呼び出し（一周目照合の経路）の出力・終了コードは変えない（既存 spec が明記する不変条件）。

## Decisions

### 1. 構造エラーと内容違反の境界

境界は「後続の行の検査を続けられるかどうか」で引く。表のヘッダーが見つからない、列数が期待と違う、必須フィールドが欠落している場合は、その時点で行の意味が確定しないため以降の検査ができない → 即時 raise を維持する。一方、扱い欄の値・補助表の対応先・重複・書き換え無しは、1 行が違反していても他の行の検査は独立して続けられる → 蓄積対象にする。

対象箇所（現状の行番号）:
- `parse_rewritten`（review-hit-set.py:144-166 付近）内、`raise ContractError(f"rewritten row is duplicated: ...")` と `raise ContractError(f"rewritten row must point at one not-applicable row: ...")` と `raise ContractError(f"rewritten row body is unchanged: ...")` の 3 箇所
- `main`（review-hit-set.py:297-302 付近）の `--head` 検査ループ、`raise ContractError(f"row-3 handling must be 直した or 該当しない: <理由>: ...")`

これ以外（`table_rows` のヘッダー欠落、`row_key` の path/line 不正、`field` の必須フィールド、`parse_command` の構文検査、`repository_root` の repo 検査）は変えない。

### 2. 蓄積した違反の出力形式

`report` に積む行は、既存の `missing:` / `extra:` / `unmatched:` / `not-removed:` と同じ「種別: 詳細」の形式に揃え、`contract: <理由>: <path>:<line>` とする（例: `contract: handling must be 直した or 該当しない: <理由>: foo.py:12`、`contract: rewritten row is duplicated: foo.py:12`）。理由は現行の `ContractError` のメッセージ文言をそのまま流用し、末尾に `<path>:<line>` を付ける形にする（メッセージ文言自体は変えない。プレフィックスと出力先だけを変える）。

出力先は他の report 項目と同じく stdout（`for line in report: print(line)`）。exit code も同じ `return int(bool(report))` に合流させる。従来の stderr 経路（`contract: <message>` を stderr に出して exit 1）は構造エラーだけに残る。

`parse_rewritten` は現状 `rows`（主表の内容）だけを受け取り違反があれば即 raise する関数なので、蓄積した違反を関数の戻り値だけで表現できるよう、戻り値を `(rewritten, violations)` のタプルに変える（呼び出し側の `main` で `report` に連結する）。`main` の `--head` 検査ループも同様に、ループ中で見つけた違反を `report` に `append` してから残りの行の検査を続ける。

### 3. 検査順序と重複違反

同じ行が複数の違反条件に同時に該当することは無い（扱い欄の値チェックは主表のループ、補助表の 3 条件は補助表のループで、対象が別）。したがって出力順は「主表の扱い欄チェック（行の登場順）→ 補助表の 3 条件チェック（行の登場順）」のまま、優先度付けは不要。

## Risks / Trade-offs

- [`report` の行数が増えることで、G が順 3 で「差分だけを見る」契約に影響しないか] → 影響しない。G は集合の一致だけを見る 2 段照合（一致すれば早期終了、不一致ならその差分を返す）を使っており、`review-hit-set.py` の `report` はスクリプト単体の出力であって G の照合ロジックには使われない。`review-hit-set.py` は主に W・G の手動確認や補助スクリプトとして使う。
- [既存の bats テストが `contract: <message>` を stderr かつ単一行として期待している場合、壊れる] → 対象の 4 違反（扱い欄の値・補助表の対応先・重複・書き換え無し）のテストケースは出力先と行数の期待を書き換える。構造エラー側のテストケースは変更不要（互換性維持）。

## Migration Plan

不要（ローカル CLI スクリプトの挙動変更であり、デプロイ・ロールバック手順は無い。既存の bats テストと `openspec/specs/dev-workflow-pr-review-gate/spec.md` の更新だけで完結する）。

## Open Questions

なし。
