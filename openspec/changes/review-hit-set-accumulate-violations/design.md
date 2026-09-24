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

これ以外（例: `table_rows` のヘッダー欠落、`row_key` の path/line 不正（補助表の行にも及ぶ）、`decode_cell` のバッククォート囲み・escape 違反、`field` の必須フィールド、`parse_command` の構文検査、`repository_root` の repo 検査、`git grep` 実行時の失敗）は、蓄積対象の 4 種類（扱い欄の値・補助表の対応先・重複・書き換え無し）のどれにも該当しない行単位の違反も含め、すべて従来どおり `ContractError` の即時 raise を維持する。「後続の行の検査を続けられるかどうか」という境界の基準に照らすと、これらは行の意味そのものが確定しない（path/line が数値でない、本文の escape が壊れている等）か、個々の行の話ではなく実行全体の前提（repo・検索コマンド・git grep の実行）に関わるため、蓄積して継続する対象にならない。

### 2. 契約違反行を後続の照合に混ぜない（BLOCKER 対応）

蓄積に変えても、違反した行をそのまま `rewritten` マップや `second_stage` の集合計算に混ぜると、二次的な誤った差分が生まれる。たとえば扱い欄が不正な行は、`second_stage` の `groups` で `handling != FIXED` として「該当しない」側に数えられる一方、`NOT_APPLICABLE_RE` に一致しないため `allowed` には入らない。その結果、対応するはずの HEAD ヒットが実際には無い `unmatched:` として誤検出される。補助表の 3 条件（対応先が「該当しない」行を指さない・重複・書き換え無し）についても同様に、違反した行の指す先や書き換え後の本文をそのまま使うと、`second_stage` の計算が壊れる。

決定（R1 の修正案どおり）:
- `parse_rewritten` は、契約違反した補助表の行を `rewritten` マップの値として採用しない。ただし重複（同じ `(path, line)` を指す 2 件目以降の補助表行）は、最初に見つかった行の値だけを `rewritten` の候補として保持し、2 件目以降を「重複」の違反として記録する（「対応先が該当しない行を指さない」「書き換え無し」の 2 条件に違反した行は、そのキー自体を `rewritten` に入れない）。
- **`--head` 検査ループの扱い欄チェックまたは `parse_rewritten` のどちらかで違反が 1 件でもあれば、`second_stage` を呼ばない。** その場合の出力は第 1 段（`missing:` / `extra:`）と、蓄積した `contract:` 行だけにする。違反が 0 件のときだけ、従来どおり `second_stage` を実行して `unmatched:` / `not-removed:` を追加する。

この決定により、W は 1 回の実行で「表の書式・内容の契約違反」と「HEAD との差分」を混同せずに受け取る。契約違反がある間は差分（`unmatched:` / `not-removed:`）を計算しても意味が無い（前提の表が信頼できないため）ので、違反を直してから改めて差分を見る、という 2 段階の運用と自然に対応する。

### 3. 蓄積した違反の出力形式

`report` に積む行は、既存の `missing:` / `extra:` / `unmatched:` / `not-removed:` と同じ「種別: 詳細」の形式に揃え、`contract: <理由>: <path>:<line>` とする（例: `contract: row-3 handling must be 直した or 該当しない: <理由>: foo.py:12`、`contract: rewritten row is duplicated: foo.py:12`）。理由の部分は現行の `ContractError` のメッセージ文言をそのまま流用する。現行のメッセージ文言はすでに末尾が `: <path>:<line>` の形（f-string の埋め込み）になっているため、新たに `<path>:<line>` を付け足す必要はない——文言をそのまま `contract: ` プレフィックス付きで report に積むだけでよい（二重にしない）。

出力先は他の report 項目と同じく stdout（`for line in report: print(line)`）。exit code も同じ `return int(bool(report))` に合流させる。従来の stderr 経路（`contract: <message>` を stderr に出して exit 1）は構造エラーだけに残る。

`parse_rewritten` は現状 `rows`（主表の内容）だけを受け取り違反があれば即 raise する関数なので、蓄積した違反を関数の戻り値だけで表現できるよう、戻り値を `(rewritten, violations)` のタプルに変える（呼び出し側の `main` で `report` に連結する）。`main` の `--head` 検査ループも同様に、ループ中で見つけた違反を `report` に `append` してから残りの行の検査を続ける。

### 4. 検査順序と重複違反

同じ行が複数の違反条件に同時に該当することは無い（扱い欄の値チェックは主表のループ、補助表の 3 条件は補助表のループで、対象が別）。したがって出力順は「主表の扱い欄チェック（行の登場順）→ 補助表の 3 条件チェック（行の登場順）」のまま、優先度付けは不要。決定 2 により、違反が 1 件でもあれば出力はこの順の `contract:` 行と第 1 段の差分だけになり、`second_stage` 由来の行（`unmatched:` / `not-removed:`）は混ざらない。

## Risks / Trade-offs

- [`report` の行数が増えることで、G が順 3で「差分だけを見る」契約に影響しないか] → 影響しない。G は `gate-runner.md`（再開節「W の修正後の再レビュー」）と pr-review-gate `SKILL.md` 手順 2-1（223 行付近の 2 段照合の規定）で `review-hit-set.py --head` を実行し、その exit code と出力の差分行をそのまま W への差分として使う（集合の一致だけを見る）。今回の変更は差分行の種類（`missing:` / `extra:` / `unmatched:` / `not-removed:` に加え新設の `contract:`）を増やすだけで、G の照合ロジック自体は変えない。決定 2 の対応により、契約違反があるときに偽の `unmatched:` / `not-removed:` が混ざらないため、G が受け取る差分はむしろ正確になる。
- [既存の bats テストが `contract: <message>` を stderr かつ単一行として期待している場合、壊れる] → 対象の 4 違反（扱い欄の値・補助表の対応先・重複・書き換え無し）のテストケースは出力先と行数の期待を書き換える。構造エラー側のテストケースは変更不要（互換性維持）。

## Migration Plan

不要（ローカル CLI スクリプトの挙動変更であり、デプロイ・ロールバック手順は無い。既存の bats テストと `openspec/specs/dev-workflow-pr-review-gate/spec.md` の更新だけで完結する）。

## Open Questions

なし。
