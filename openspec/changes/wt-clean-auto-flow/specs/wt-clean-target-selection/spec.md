## MODIFIED Requirements

### Requirement: TARGETS を Pass 1 で自動処理し、判断が必要な対象は Pass 2 でまとめて対話する

`wt-clean` は確定した TARGETS を `git worktree list` の順で 1 件ずつ、`i/N` 形式の進捗表示とともに遅延診断するものとする（SHALL）。診断結果に応じて 2 パスで処理する:

**Pass 1（ノンブロッキング自動処理）** — 走行中に AskUserQuestion でブロックしない（SHALL NOT）:
- 🟢 Safe（マージ済み & dirty なし & LLM なし）→ 診断根拠（マージ済み判定の根拠）を表示したうえで、追加確認なしに削除する（`--keep` 指定時は再利用化する）。Step A で TARGETS に含めたことを削除の承認とみなす
- 🟡 Recoverable で dirty なし（LLM のみ）→ LLM をメインリポへ退避し、退避先ファイルの実在を検証したうえで、追加確認なしに削除する。検証に失敗した場合は削除せず HELD として保留する
- 🔴 Active、または dirty のある 🟡 → その場では一切操作せず `DEFERRED` キューに積み、次の対象へ進む

**Pass 2（判断バッチ）** — Pass 1 完了後にのみ実行する:
- `DEFERRED` が空なら対話せず Step C へ進む
- 非空なら各対象の状況（未マージコミット一覧・dirty stat・LLM 有無）を提示し、AskUserQuestion でまとめて選択させる（1 対象 1 問、1 回最大 4 問。超過分は複数回に分け提示範囲を明示する）
- dirty の破棄・🔴 の破棄削除・🔴 のマージは、回答を受け取った後の別ターンでのみ実行する

#### Scenario: 🟢 Safe は確認なしで削除される

- **WHEN** Pass 1 で対象が 🟢 Safe と診断される
- **THEN** マージ済み判定の根拠が表示されたうえで、AskUserQuestion を挟まずに `git worktree remove` + ブランチ削除が実行される

#### Scenario: 🟡（LLM のみ）は退避検証後に確認なしで削除される

- **WHEN** Pass 1 で対象が dirty なしの 🟡 Recoverable（LLM あり）と診断される
- **THEN** LLM ファイルがメインリポへ退避され、退避先の実在検証が成功した後、AskUserQuestion を挟まずに削除される
- **AND** 退避検証が失敗した場合は削除されず HELD として保留される

#### Scenario: 🔴 / dirty は Pass 1 でブロックせず後回しにされる

- **GIVEN** TARGETS に 🟢 が 3 件、🔴 が 1 件含まれる
- **WHEN** Pass 1 が走る
- **THEN** 🔴 の対象では AskUserQuestion が発生せず DEFERRED に積まれ、後続の 🟢 の自動処理が先に完了する
- **AND** Pass 2 で初めて 🔴 の選択が提示される

#### Scenario: 判断が不要なら一度も走行中ブロックが発生しない

- **GIVEN** TARGETS の全件が 🟢 または 🟡（dirty なし）である
- **WHEN** wt-clean が Step B を実行する
- **THEN** Step A の対象確定以降、AskUserQuestion は一度も呼ばれず Step C の完了レポートまで到達する

### Requirement: 完了レポートに処理結果と残存件数を表示する

`wt-clean` は逐次処理の完了後、自動処理した対象・判断バッチで処理した対象・スキップした対象・保留した対象・残存 worktree 件数を含む完了レポートを表示するものとする（SHALL）。`wt-clean-remote-sync` 仕様に従い、レポート冒頭には Step 0 の同期結果を 1 行で含める。

#### Scenario: 自動処理と判断バッチ処理が区別表示される

- **WHEN** Pass 1 で 2 件が自動削除され、Pass 2 で 1 件がマージ→削除、1 件がスキップされる
- **THEN** レポートで自動処理分（🟢/🟡）と判断バッチ分（🔴 等）、スキップ、保留、残存 worktree 件数が区別して表示される
