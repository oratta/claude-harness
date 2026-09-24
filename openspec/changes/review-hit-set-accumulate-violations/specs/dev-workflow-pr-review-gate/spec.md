## MODIFIED Requirements

### Requirement: 共通照合スクリプトが順 3 の 2 段目を機械照合する

`plugins/dev-workflow/scripts/review-hit-set.py` は、`--head <rev>` を付けて呼ばれたときに限り、第 1 段（修正前 SHA での全ヒット集合と主表の一致）に続けて、SKILL.md の順 3 の 2 段目（HEAD の残存ヒットと「該当しない」行の `(ファイル, 本文)` の件数照合、補助表による本文の差し替え、扱いが混在する組の削除行の検査）を行わなければならない（MUST）。差分があれば、対応しない HEAD のヒットを `unmatched: <ファイル>:<HEAD の行>`、削除行が足りない「直した」の行を `not-removed: <ファイル>:<修正前の行>` の形で出力して exit 1 を返し、どちらの段も一致すれば exit 0 を返す（MUST）。

守備範囲（入力・拾いたい誤り・通ることを許す入力・範囲外）は「一覧の一致で閉じる（順 3）」の要件と同じとし、本要件はそれを機械化するだけで、守備範囲を広げも狭めもしない。

`--head` 付きの呼び出しでは、次の行を契約違反として扱わなければならない（MUST）: 主表の扱いの欄が `直した` / `該当しない: <理由>` のどちらかちょうどでない行、主表で扱いが「該当しない」の行をちょうど 1 つ指さない補助表の行、同じ `(ファイル, 行（修正前 SHA）)` を指す 2 つ目以降の補助表の行、修正後の本文が指す主表の行の本文と等しい補助表の行。これら 4 種類は**表の全行を検査し終えてから**まとめて報告しなければならず（MUST）、最初の 1 件を見つけた時点で検査を止めてはならない（MUST NOT）。各違反は `contract: <理由>: <ファイル>:<行（修正前 SHA）>` の形式で、他の差分出力（`unmatched:` / `not-removed:`）と同じ標準出力・同じ `report` の並びに加え、いずれかが 1 件でもあれば exit 1 を返す（MUST）。

これに対し、表の構造そのものが以降の行の検査を続けられなくする違反（見出し行の欠落、列数が期待と異なる、必須フィールドの欠落、修正前 SHA の形式不正、`--head` の SHA 形式不正、検索コマンドの構文違反）は、見つけた時点で即座に処理を止め、標準エラー出力に `contract: <message>` を 1 行出して exit 1 を返す（MUST。既存の中断的エラー経路を維持する）。行単位の内容違反（本要件が列挙する 4 種類）と表の構造エラーを区別せず同じ経路で扱ってはならない（MUST NOT）。

`--head` を付けない呼び出しは、補助表を読まず、現行の第 1 段だけの出力と終了コードを変えてはならない（MUST NOT。一周目の `照合表` の経路を変えないため）。

G が `--head` に渡すのは、W の push を `git fetch` で取り込んだあとの HEAD の 40 桁フル SHA とし、`skills/develop/references/roles/gate-runner.md` の順 3 の照合の記述は、2 段目を `review-hit-set.py --head <HEAD の 40 桁 SHA>` で回すことを、規則の正本である SKILL.md の順 3 への参照とあわせて書かなければならない（MUST）。

#### Scenario: 補助表ありの書き換えが一致する

- **WHEN** 修正前 SHA で「該当しない」行の本文を HEAD で書き換え、主表に修正前の本文、補助表に修正後の本文を載せた一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは exit 0 を返す

#### Scenario: 補助表なしの書き換えが不一致になる

- **WHEN** 同じ書き換えについて補助表の無い一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは書き換え後の行を `unmatched:` として出力し exit 1 を返す

#### Scenario: 混在する組の直し忘れを検出する

- **WHEN** 同じファイル・同じ本文の組に「直した」と「該当しない」が 1 件ずつあり、「該当しない」側だけを書き換えて補助表に載せ、「直した」側を変更していない一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは「直した」の行を `not-removed:` として出力し exit 1 を返す

#### Scenario: 補助表が直した行を指す

- **WHEN** 補助表の行が主表で扱いが「直した」の行を指す一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは `contract: rewritten row must point at one not-applicable row: <ファイル>:<行>` を report に積んで exit 1 を返す

#### Scenario: 補助表の行が重複する

- **WHEN** 補助表に同じ `(ファイル, 行（修正前 SHA）)` を指す行が 2 つある一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは `contract: rewritten row is duplicated: <ファイル>:<行>` を report に積んで exit 1 を返す

#### Scenario: 書き換えていない行が補助表に載っている

- **WHEN** 補助表の修正後の本文が、指す主表の行の本文と等しい一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは `contract: rewritten row body is unchanged: <ファイル>:<行>` を report に積んで exit 1 を返す

#### Scenario: 扱い欄の値が2値のどちらでもない

- **WHEN** 主表の扱いの欄が `直した` でも `該当しない: <理由>` でもない値を持つ行を含む一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは `contract: row-3 handling must be 直した or 該当しない: <理由>: <ファイル>:<行>` を report に積んで exit 1 を返す

#### Scenario: 補助表に複数種類の違反が同時にある

- **WHEN** 補助表に「扱いが直したの行を指す行」と「重複した行」の 2 種類の違反を同時に含む一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトは両方の違反を `contract: ...` として report にまとめて出力し、最初の違反を見つけた時点で検査を止めない

#### Scenario: 表の構造エラーは引き続き即時停止する

- **WHEN** 主表の見出し行が欠落した一覧、または列数が期待と異なる行を含む一覧を `--head <HEAD>` 付きで照合する
- **THEN** スクリプトはその時点で処理を止め、標準エラー出力に `contract: <message>` を 1 行出して exit 1 を返す

#### Scenario: gate-runner.md が 2 段目のスクリプト実行を参照する

- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の順 3 の照合の記述を読む
- **THEN** `review-hit-set.py` を `--head` と fetch 後の HEAD の 40 桁 SHA 付きで実行することと、規則の正本が pr-review-gate の SKILL.md の順 3 であることが書かれている

#### Scenario: --head 無しの既存経路は変わらない

- **WHEN** 補助表を含む一覧を `--head` 無しで照合し、修正前 SHA のヒット集合が主表と一致する
- **THEN** スクリプトは補助表を無視して exit 0 を返す
