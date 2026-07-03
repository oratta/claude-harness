# worktree-command-wrapper Specification (Delta)

## ADDED Requirements

### Requirement: wt-clean コマンドは SKILL.md を読み込んで実行する薄いラッパーである

`plugins/worktree/commands/wt-clean.md` は、診断分類表・実行フロー本文（Step 0/A/B/C）・squash マージ検出ロジックなどの手順本体を自身に持ってはならない (MUST NOT)。代わりに、対応する `${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行する薄いラッパーでなければならない (MUST)。`CLAUDE_PLUGIN_ROOT` が未設定の環境でも SKILL.md を特定できるフォールバック（marketplace / installed の探索）を含めること。

#### Scenario: wt-clean コマンドが SKILL.md を Read してインライン実行する

- **WHEN** ユーザーが `plugins/worktree/commands/wt-clean.md` を開く
- **THEN** `skills/wt-clean/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を含むパス）を Read tool で読み込み、その指示に従ってインライン実行する旨の指示が本文に含まれている

#### Scenario: コマンドに診断分類表の重複コピーが無い

- **WHEN** ユーザーが `plugins/worktree/commands/wt-clean.md` 内で診断分類表（`🟢 Safe` / `🟡 Recoverable` / `🔴 Active` の 3 行を持つ Markdown 表、またはその分類条件本文）を grep する
- **THEN** 分類表・分類条件の本文は 1 件も存在しない（分類の正は `skills/wt-clean/SKILL.md` 側にのみ存在する）

#### Scenario: コマンドに squash 検出ロジックの重複コピーが無い

- **WHEN** ユーザーが `plugins/worktree/commands/wt-clean.md` 内で squash 検出の手順本文（`検証A` / `検証B` / `検証C`、`git cherry`、`TREE_DIFF`、`SQUASHED` などの手順コード）を grep する
- **THEN** これらの手順本文は command に存在しない（squash 検出の正は `skills/wt-clean/SKILL.md` 側にのみ存在する）

### Requirement: wt-setup コマンドは SKILL.md を読み込んで実行する薄いラッパーである

`plugins/worktree/commands/wt-setup.md` は、実行フロー本文（Step 1-6: スクリプト実行・`.worktreeinclude` 生成・依存インストール・Draft PR ブートストラップ・完了レポート・後続作業）を自身に持ってはならない (MUST NOT)。代わりに、対応する `${CLAUDE_PLUGIN_ROOT}/skills/wt-setup/SKILL.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行する薄いラッパーでなければならない (MUST)。`CLAUDE_PLUGIN_ROOT` 未設定時のフォールバックを含めること。

#### Scenario: wt-setup コマンドが SKILL.md を Read してインライン実行する

- **WHEN** ユーザーが `plugins/worktree/commands/wt-setup.md` を開く
- **THEN** `skills/wt-setup/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-setup/SKILL.md` を含むパス）を Read tool で読み込み、その指示に従ってインライン実行する旨の指示が本文に含まれている

#### Scenario: コマンドにセットアップ手順本文の重複コピーが無い

- **WHEN** ユーザーが `plugins/worktree/commands/wt-setup.md` 内でセットアップ手順本文（`wt-setup.sh` の呼び出しブロック、`.worktreeinclude` 生成の分類ルール本文、`gh pr create --draft` の Draft PR ブートストラップ手順など）を grep する
- **THEN** これらの手順本文は command に存在しない（Step 1-6 の正は `skills/wt-setup/SKILL.md` 側にのみ存在する）

### Requirement: ラッパーは command frontmatter を維持し引数を透過する

両 command の YAML frontmatter を維持しなければならない (MUST)。`wt-clean.md` は `allowed-tools` に `AskUserQuestion` を含む必要ツール一式（少なくとも `Read, Bash, AskUserQuestion`）を保持し、`wt-setup.md` は `allowed-tools` と `argument-hint` を保持すること。ラッパーは `$ARGUMENTS`（位置引数・`--keep` / `--no-sync` / `--with-pr` などのフラグ・後続作業指示）を SKILL.md の実行にそのまま受け渡さなければならない (MUST)。command が独自に引数の意味を再定義・上書きしてはならない (MUST NOT)。

#### Scenario: wt-clean の frontmatter が allowed-tools を維持する

- **WHEN** ユーザーが `plugins/worktree/commands/wt-clean.md` の frontmatter を読む
- **THEN** `allowed-tools` に `AskUserQuestion`・`Read`・`Bash` を含む（SKILL.md の診断フロー実行に必要なツールが欠落していない）

#### Scenario: wt-setup の frontmatter が allowed-tools と argument-hint を維持する

- **WHEN** ユーザーが `plugins/worktree/commands/wt-setup.md` の frontmatter を読む
- **THEN** `allowed-tools` が保持され、かつ `argument-hint`（`[--with-pr] ...` 相当）が存在する

#### Scenario: 引数が SKILL.md の実行に透過される

- **WHEN** ユーザーが `/wt-clean ~/wt/foo --no-sync` や `/wt-setup --with-pr ログイン画面のバグ修正` のように引数付きで起動する
- **THEN** ラッパーは `$ARGUMENTS` を SKILL.md の実行にそのまま渡す旨を明記しており、位置引数・フラグ・後続作業指示が SKILL.md 側のフローに欠落なく届く

### Requirement: 安全性クリティカルな禁則は SKILL.md に一本化され両経路で同一に到達する

squash マージ検出（検証 A: tracked source の実ツリー差分が空か、検証 B: `git cherry` の patch-equivalent 判定、検証 C: `gh pr` の当該ブランチ発 PR が MERGED か）と、「AskUserQuestion の回答到着後の別ターンで破壊操作を実行する絶対禁則（AskUserQuestion ツール呼び出しと削除 Bash を同一ターンの並列ツール呼び出しに含めてはならない）」は、`plugins/worktree/skills/wt-clean/SKILL.md` の 1 箇所にのみ存在しなければならない (MUST)。これらの安全性記述は本 change で一言一句失われてはならない (MUST NOT lose)。command 経由の起動と skill 経由の起動のどちらでも、同一の `skills/wt-clean/SKILL.md` 本文が実行され、診断フローが一致しなければならない (MUST)。

#### Scenario: squash 検出 A/B/C が SKILL.md に一言一句残っている

- **WHEN** ユーザーが `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- **THEN** 検証 A（tracked source の実ツリー差分が空）・検証 B（`git cherry`）・検証 C（`gh pr` MERGED）の 3 検証、「最も信頼できるのは検証 A（実ツリー差分）」「判断が割れたら実ツリー差分を優先」、および `SQUASHED` 非空を 🟢/🟡 として扱い `AHEAD_COUNT > 0` でも 🔴 にしない旨がすべて残っている

#### Scenario: AskUserQuestion 別ターン実行の絶対禁則が SKILL.md に残っている

- **WHEN** ユーザーが `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- **THEN** 「AskUserQuestion ツール呼び出しと、削除を実行する Bash 呼び出しを同一ターンの並列ツール呼び出しに含めてはならない」「回答を受け取った後の別のアシスタントターンで実行する」旨の絶対禁則（最重要）が残っている

#### Scenario: command 経由と skill 経由で同一の診断フローになる

- **WHEN** ユーザーが `/wt-clean` を command として起動した場合と、wt-clean skill を（skill として）起動した場合を比較する
- **THEN** command は独立した実行フロー定義を持たず SKILL.md を Read して実行するため、両経路とも `skills/wt-clean/SKILL.md` の同一手順（Step 0 同期 → Step A TARGETS 確定 → Step B squash 検出込み遅延診断 → Step C レポート）を実行し、診断フローが一致する（command 側に旧分類表など SKILL.md と異なる別フローが存在しない）
