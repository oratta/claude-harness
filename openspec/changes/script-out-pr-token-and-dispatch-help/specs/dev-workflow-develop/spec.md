## ADDED Requirements

### Requirement: epic-dispatch.sh は --help で出力語の意味を出す
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、第 1 引数が `--help` か `-h` のとき、stdout にサブコマンドの書式と出力語の意味を出して exit 0 で終わらなければならない（MUST）。出力語は `launch`・`reply`・`reap`・`wait` などが返すもの（`launched`・`skipped`・`failed`・`deferred`・`reaped`・`gone`・`kept <理由>` など）で、終了コード・`child-log` の列・`max-parallel` の既定値の決め方・子の起動コマンドの組み立て（`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL` と既定）も出す。`gh`・`orca`・`git` を呼ばず、状態の記録を読み書きしない（MUST NOT）。既存の使い方（stderr・exit 1）と各サブコマンドの出力語・終了コードは変えない（MUST NOT）。

#### Scenario: --help は出力語の意味を出して exit 0 で終わる
- **WHEN** `epic-dispatch.sh --help` を呼ぶ
- **THEN** stdout に `launched`・`deferred`・`reaped`・`gone`・`kept` の各語と意味が出て、exit 0 で、`gh`・`orca`・`git` は呼ばれない

#### Scenario: 既存の使い方は変わらない
- **WHEN** 知らないサブコマンドか引数なしで呼ぶ
- **THEN** stderr に使い方が出て exit 1 で、stdout は空である

### Requirement: epic-loop.md は出力語の説明を持たず分類表だけを持つ
`skills/develop/references/epic-loop.md` は、`epic-dispatch.sh` の出力語の意味の説明を持たず、`--help` を参照したうえで、出力語ごとに「止まって主に報告する／進む」の分類を表で示さなければならない（MUST）。

守備範囲: 拾いたい誤りは、`--help` の出力語の一覧が実装と食い違うこと（スクリプトが出す語と `--help` の語を突き合わせて検査する）である。説明文の言い回しと、分類表の各行の妥当性は機械では検査せず、レビューで見る。

#### Scenario: 実装が出す語は --help に載る
- **WHEN** `epic-dispatch.sh` が出す出力語の一覧と `--help` の出力を突き合わせる
- **THEN** 一覧のすべての語が `--help` に現れる
