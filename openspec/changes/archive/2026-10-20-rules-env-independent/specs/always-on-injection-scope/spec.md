## MODIFIED Requirements

### Requirement: 縮約は削除ではなく移設で、移設先を任意の cwd から辿れる形にする

常時注入から削った記述は、削除してはならない（MUST NOT）。移設先のファイルに同じ内容を残さなければならない（MUST）。

`rules/*.md` は symlink で**全プロジェクト**のセッションに載るため、移設先は harness のリポジトリを cwd に持たないセッションからも解決できる形で書かなければならない（MUST）。リポジトリ相対パス（`plugins/casting/skills/casting/SKILL.md`・`docs/worktree-recovery.md` 等）で書いてはならない（MUST NOT）。他プロジェクトで作業中にそのルールが発火したとき、そのパスは Read できず、移設した内容に誰も届かなくなる。

解決できる形とは次の 3 つをいう。

- skill へ移す場合: **スキル名**で書く（`casting:casting`・`dev-workflow:pr-review-gate`）。スキルはどの cwd からでも起動できる
- `references/` / `docs/` へ移す場合: **`~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`** の形で書く
- 全文の正本が Output Style の場合: **`~/.claude/output-styles/<name>.md`**（Output Style `<name>`）の形で書く。`scripts/sync.sh` が Output Style をこのパスに symlink するので、どの cwd からでも解決でき、marketplace の clone の場所（オーナーの環境の固有名）を本文に書かずに済む。配る候補の規則（`harness-public-private-split` の「配る候補の規則は環境固有の記述を持たず…」の 6 ファイル）は、この形で書かなければならない（MUST）

加えて `rules/README.md` のファイル一覧表に、ルールごとの移設先を書かなければならない（MUST）。`rules/README.md` は集計対象外（`list_synced_md` が除外する）なので、ここに書いても常時注入の合計は増えない。

#### Scenario: 縮約したルールから移設先を辿れる

- **WHEN** 縮約した各ルールの本文を読む
- **THEN** 詳細の移設先がスキル名か `~/.claude/plugins/marketplaces/oratta-claude-harness/` から始まる絶対パス（Output Style が正本のルールは `~/.claude/output-styles/<name>.md`）で書かれており、その解決先（該当スキル、または展開後のファイル）が実在する

#### Scenario: Output Style が正本のルールは cwd に依らない参照で示す

- **WHEN** `rules/communication-style.md` の全文の正本を示す文を読む
- **THEN** `~/.claude/output-styles/readable.md` と Output Style `readable` の名で書かれ、`marketplaces/` を含まず、`rules/README.md` の同じルールの行に marketplace の clone のパスでの場所が書かれている

#### Scenario: 移設先にリポジトリ相対パスが残っていない

- **WHEN** 縮約した各ルールの本文から、移設先として示されたパスを集める
- **THEN** `plugins/`・`docs/`・`scripts/` 等で始まるリポジトリ相対パスが 1 つも含まれていない

#### Scenario: README の一覧表が移設先を持つ

- **WHEN** `rules/README.md` のファイル一覧表を読む
- **THEN** 縮約した各ルールの行に、同じ解決できる形の移設先が書かれている
