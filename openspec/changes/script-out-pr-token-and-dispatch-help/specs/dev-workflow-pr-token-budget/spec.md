## ADDED Requirements

### Requirement: 計測は 1 コマンドのラッパーで呼ぶ
`plugins/dev-workflow/scripts/pr-token-measure.sh --repo <owner>/<repo> [--cap <tokens>] [--codex-home <dir>]... <記録先番号>...` を持たなければならない（MUST）。`codex-records.sh` を呼び、exit 0 のときだけ `pr-token-budget.sh <番号>... --codex-records <file>` を呼ぶ。`--codex-home` には渡されたものに加えて `${CODEX_HOME:-$HOME/.codex}` を渡し、`--cap` は渡されたときだけ渡す。`pr-token-budget.sh` の stdout と exit code（0 / 2 / 1）をそのまま返す。
#### Scenario: 記録の取得と集計を 1 回の呼び出しでつなぐ
- **WHEN** `pr-token-measure.sh --repo o/r 288` を呼び、`codex-records.sh` が exit 0 で記録を書く
- **THEN** `pr-token-budget.sh 288 --codex-records <その記録>` が呼ばれ、その stdout と exit code がそのまま返る

#### Scenario: 上限超過は exit 2 のまま返す
- **WHEN** `pr-token-budget.sh` が exit 2 を返す
- **THEN** ラッパーも exit 2 で終わり、stdout は `pr-token-budget.sh` の 1 行 JSON と同じである

#### Scenario: 本体の環境の CODEX_HOME を渡す
- **WHEN** `--codex-home /x` を付けて呼ぶ
- **THEN** `pr-token-budget.sh` には `--codex-home /x` と `--codex-home ${CODEX_HOME:-$HOME/.codex}` の両方が渡る

### Requirement: 本体は計測のたびにラッパーを呼び、手順書に 2 つのスクリプトの連結を残さない
本体は計測のたびに `pr-token-measure.sh` を呼ばなければならず（MUST）、`skills/develop/references/pr-token-budget.md` に `codex-records.sh` と `pr-token-budget.sh` を直接つなぐ手順を残してはならない（MUST NOT）。この要件は、2 つのスクリプトを本体が順に呼ぶ旧い規定に優先する。2 つのスクリプト自体の出力語と終了コードは変えない。

#### Scenario: 手順書に直接の連結が無い
- **WHEN** `pr-token-budget.md` を読む
- **THEN** 計測の呼び方は `pr-token-measure.sh` の 1 コマンドで、`codex-records.sh` を呼ぶ bash は無い

### Requirement: ラッパーは取得に失敗したら集計を呼ばず exit 1 で終わる
`pr-token-measure.sh` は、`codex-records.sh` が exit 0 以外のときは `pr-token-budget.sh` を呼ばず、stdout を空にして stderr に理由を出し exit 1 で終わらなければならない（MUST）。`--repo` の欠落と、番号が 0 件か数字でない場合も exit 1 とする。一時ディレクトリは終わるときに消す。LLM を呼ばず、GitHub に書き込まない（MUST NOT）。

守備範囲: 拾いたい誤りは、取得に失敗したのに前回のファイルや空の記録で集計し、Codex 分が抜けた合計を上限以内と読み違えることと、2 つのスクリプトの exit code がラッパーで書き換わることである。一時ディレクトリの置き場の選び方と、`pr-token-budget.sh` の出力の整形（しない）は検査しない。

#### Scenario: 取得に失敗したら集計を呼ばない
- **WHEN** `codex-records.sh` が exit 1 で終わる
- **THEN** `pr-token-budget.sh` は呼ばれず、stdout は空で、stderr に理由が出て exit 1 である
