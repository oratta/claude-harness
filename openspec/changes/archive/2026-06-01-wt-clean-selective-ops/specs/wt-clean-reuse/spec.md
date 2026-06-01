## MODIFIED Requirements

### Requirement: wt-clean は --keep オプションを受け付ける

`wt-clean` コマンドおよびスキルは `--keep` オプションを受け付けるものとする（SHALL）。`wt-clean-target-selection` の逐次処理ループにおいて、オプション未指定時は選択された TARGETS のうち 🟢 Safe を削除し、`--keep` 指定時は 🟢 Safe を再利用化する。後方互換性のため、デフォルト動作（削除）は変更しない。`--keep` は引数（パス／ブランチ名指定）とも併用可能とする。

#### Scenario: オプション未指定時は 🟢 Safe を削除する
- **WHEN** ユーザーが `wt-clean` をオプションなしで実行し、逐次処理ループで 🟢 Safe と診断された TARGETS を処理する
- **THEN** その worktree は `git worktree remove` + `git branch -d` で削除される

#### Scenario: --keep 指定時は 🟢 Safe を再利用化する
- **WHEN** ユーザーが `wt-clean --keep` を実行し、逐次処理ループで 🟢 Safe と診断された TARGETS を処理する
- **THEN** worktree は削除されず、worktree 内のブランチが `main`（または `master`）に切り替えられ、元ブランチが削除される

#### Scenario: --keep が引数指定と併用できる
- **WHEN** ユーザーが `wt-clean --keep ~/wt/foo` を実行する
- **THEN** `foo` のみが TARGETS になり、それが 🟢 Safe なら再利用化される

### Requirement: サニティチェック FAIL 時は再利用化も保留する

`wt-clean-merge-active` の都度サニティチェック（マージ実行直後）で FAIL した worktree は、`--keep` 指定時も再利用化せず保留するものとする（SHALL）。マージを伴わない純粋な 🟢 Safe 再利用化（既に main にマージ済みのため `wt-clean` 自身はマージを実行しない）および 🟡 削除では、サニティチェックは実行されない。

#### Scenario: マージ後サニティ FAIL 時は再利用化しない
- **WHEN** `--keep` モードで 🔴 をマージし、その直後の都度サニティチェックが FAIL する
- **THEN** 該当 worktree は削除も再利用化もされず保留される（なお `wt-clean-merge-active` により、マージを伴う処理は --keep 指定でも通常削除側に流れるため、保留対象はマージ済み worktree となる）

#### Scenario: マージを伴わない 🟢 再利用化ではサニティチェックが走らない
- **WHEN** `--keep` モードで、既に main にマージ済みの 🟢 Safe を再利用化する
- **THEN** `wt-clean` 自身はマージを実行しないため、その worktree についてサニティチェックは行われず、再利用化が実行される
