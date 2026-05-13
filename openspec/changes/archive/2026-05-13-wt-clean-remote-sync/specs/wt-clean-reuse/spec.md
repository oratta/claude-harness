## MODIFIED Requirements

### Requirement: 再利用化は最小操作で安全に行う

`--keep` モードの再利用化処理は、worktree 内で `main`（または `master`）ブランチへ `git checkout` し、元のブランチを `git branch -d` で削除するものとする（SHALL）。**worktree 内**での `git reset --hard` / `git clean` / `git pull` / `git fetch` などの破壊的操作は実行しないものとする（SHALL NOT）。untracked ファイル（`node_modules`, `.env`, 作業中ファイル等）は一切変更しない。

なお、本禁則は Step 7b（再利用化処理）**内**の worktree に対する制約であり、Step 0（Remote 同期）でメインリポにて実行する `git fetch origin` / `git pull --ff-only origin <main>` は本禁則の対象外である。Step 0 と Step 7b は実行コンテキスト（メインリポ vs 各 worktree）と目的（最新化 vs 再利用化）が異なる。

#### Scenario: 再利用化で tracked ファイルが main と一致する

- **WHEN** 再利用化処理が完了する
- **THEN** 対象 worktree の HEAD は `main`（または `master`）を指し、tracked ファイルは main と一致する

#### Scenario: untracked ファイルは保持される

- **WHEN** 再利用化処理を実行する
- **THEN** `node_modules`, `.env`, その他 untracked ファイルは全て保持される

#### Scenario: 元ブランチが削除される

- **WHEN** 再利用化処理が完了する
- **THEN** `git branch` の出力に元のマージ済みブランチが含まれない

#### Scenario: Step 7b 内では worktree に対して pull/fetch しない

- **WHEN** `--keep` モードで Step 7b の再利用化処理を実行する
- **THEN** `git -C <worktree> pull` や `git -C <worktree> fetch` は実行されない（Step 0 のメインリポでの fetch/pull とは区別される）
