# experience-to-skill-jsonl-distillation Specification

## Purpose
TBD - created by archiving change experience-to-skill-jsonl-refocus. Update Purpose after archive.
## Requirements
### Requirement: Skill MUST auto-trigger only on skill-creation request phrases

新スキル `experience-to-skill` SHALL be activated by Claude **only when** the user message contains explicit skill-creation request phrases such as "スキル化して", "スキルにして", "スキルを作って", "過去の作業からスキルを作って", "この作業 スキル化したい". The skill description MUST NOT mention generic completion phrases (e.g., "完了", "done", "commit して", "archive") that would cause unrelated activations.

#### Scenario: User explicitly requests skill distillation

- **WHEN** the user sends a message such as "先週やった動画生成の作業をスキル化して"
- **THEN** Claude activates the `experience-to-skill` skill and initiates the jsonl distillation workflow

#### Scenario: User signals plain work completion

- **WHEN** the user sends a message such as "完了です" or "commit して" without any skill-creation phrase
- **THEN** the `experience-to-skill` skill MUST NOT auto-trigger

#### Scenario: Archive command completes

- **WHEN** `longrun:archive` or `openspec:archive` completes its workflow
- **THEN** the `experience-to-skill` skill MUST NOT be invoked (the new skill does not gate or augment archive flows)

### Requirement: Plugin MUST expose exactly one slash command e2s-distill

`plugins/experience-to-skill/.claude-plugin/plugin.json` の `commands` 配列 SHALL contain only `./commands/e2s-distill.md`. 旧コマンド (`e2s-commit`, `e2s-ok`, `e2s-rewind`, `e2s-status`, `e2s-reflect`) MUST be entirely removed from plugin.json references.

#### Scenario: plugin.json lists only e2s-distill

- **WHEN** `cat plugins/experience-to-skill/.claude-plugin/plugin.json | jq '.commands'` を実行する
- **THEN** 出力は `["./commands/e2s-distill.md"]` の 1 要素配列であり、旧コマンドファイルは含まれない

#### Scenario: Old command files do not exist

- **WHEN** `find plugins/experience-to-skill/commands -name 'e2s-commit.md' -o -name 'e2s-ok.md' -o -name 'e2s-rewind.md' -o -name 'e2s-status.md' -o -name 'e2s-reflect.md'` を実行する
- **THEN** ヒットが 0 件である

### Requirement: jsonl-finder script MUST normalize cwd to encoded directory name

`plugins/experience-to-skill/scripts/jsonl-finder.sh` SHALL provide a function `e2s_encode_cwd <absolute-path>` that maps an absolute path to the `~/.claude/projects/` directory naming convention by replacing each `/` and `.` with `-`. Consecutive hyphens MUST be preserved as-is (no collapsing).

#### Scenario: Standard cwd is encoded

- **WHEN** `e2s_encode_cwd /Users/oratta/foo/bar` が呼ばれる
- **THEN** 戻り値は `-Users-oratta-foo-bar`

#### Scenario: Cwd contains a dotted directory

- **WHEN** `e2s_encode_cwd /Users/oratta/.claude-mem` が呼ばれる
- **THEN** 戻り値は `-Users-oratta--claude-mem`（`.claude-mem` のドットが `-` になり連続ハイフン化）

#### Scenario: Worktree-style cwd is encoded

- **WHEN** `e2s_encode_cwd /Users/oratta/.superset/worktrees/abc/foo-bar` が呼ばれる
- **THEN** 戻り値は `-Users-oratta--superset-worktrees-abc-foo-bar`

### Requirement: jsonl-finder script MUST provide reverse-lookup fallback

`jsonl-finder.sh` SHALL provide a function `e2s_resolve_jsonl_dir <absolute-cwd>` that returns the matching `~/.claude/projects/<encoded>/` directory. If the primary encoding does not exist, the function MUST fall back to a prefix-match search across `~/.claude/projects/` entries and return the longest-prefix match with priority.

#### Scenario: Primary encoded directory exists

- **WHEN** `e2s_resolve_jsonl_dir /Users/oratta` が呼ばれ、`~/.claude/projects/-Users-oratta` ディレクトリが存在する
- **THEN** 戻り値は `~/.claude/projects/-Users-oratta`

#### Scenario: Primary encoded directory does not exist, prefix candidates exist

- **WHEN** `e2s_resolve_jsonl_dir /nonexistent/path` が呼ばれ、対応ディレクトリが存在しない
- **THEN** 戻り値は空文字または exit code 非 0 で、エラーを示す

### Requirement: jsonl-finder script MUST apply four-stage scan order

`jsonl-finder.sh` の jsonl 列挙関数 SHALL apply filters in this exact order: (1) directory existence check, (2) mtime range filter, (3) file size upper bound filter (default 50MB, overridable via env `E2S_JSONL_MAX_SIZE`), (4) keyword grep. Each stage MUST short-circuit downstream stages when its output is empty.

#### Scenario: Directory missing short-circuits

- **WHEN** 指定 cwd に対応する jsonl ディレクトリが存在しない状態で `e2s_list_jsonl <cwd>` を呼ぶ
- **THEN** 関数は exit code 非 0 を返し、後続フィルタを実行しない

#### Scenario: Size filter excludes large files

- **WHEN** 50MB を超える jsonl ファイルがディレクトリに存在し、`E2S_JSONL_MAX_SIZE` の上書きがない状態で `e2s_list_jsonl` を呼ぶ
- **THEN** その jsonl は結果リストに含まれない

### Requirement: sanitize script MUST redact known secret patterns

`plugins/experience-to-skill/scripts/sanitize.sh` SHALL provide a function `e2s_sanitize` that reads text from stdin and writes to stdout, replacing matches of the following Layer 1 regex patterns with `[REDACTED:<kind>]`: AWS access key (`AKIA[0-9A-Z]{16}`), OpenAI API key (`sk-[a-zA-Z0-9]{20,}`), Anthropic API key (`sk-ant-[a-zA-Z0-9_\-]{20,}`), GitHub token (`ghp_[a-zA-Z0-9]{36}`), GitHub PAT (`github_pat_[a-zA-Z0-9_]{82}`), JWT (`eyJ[a-zA-Z0-9_=]+\.eyJ[a-zA-Z0-9_=]+\.[a-zA-Z0-9_.+/=\-]+`), PEM block start (`-----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----`), email address (`[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`).

#### Scenario: OpenAI API key is redacted

- **WHEN** stdin に `My key is sk-abcdefghijklmnopqrstuvwxyz1234` を渡して `e2s_sanitize` を呼ぶ
- **THEN** stdout は `My key is [REDACTED:openai_key]` を含む

#### Scenario: Anthropic API key is redacted

- **WHEN** stdin に `token: sk-ant-api03-abcdefghijklmnopqrstuvwxyz` を渡す
- **THEN** stdout は `[REDACTED:anthropic_key]` を含む

#### Scenario: Email address is redacted

- **WHEN** stdin に `Contact: foo@example.com` を渡す
- **THEN** stdout は `[REDACTED:email]` を含み、原文の `foo@example.com` を含まない

#### Scenario: Non-secret text is preserved

- **WHEN** stdin に `Hello world, this is a normal log line.` を渡す
- **THEN** stdout は入力と同一の内容を返す

### Requirement: New SKILL.md MUST document Layer 2 LLM semantic review

新 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` SHALL include a section that instructs the LLM to perform a second-pass semantic review on extracted text before writing SKILL.md, identifying custom-format tokens, PII (names, addresses, phone numbers in context), URL-embedded credentials, and TODO/FIXME placeholder secrets. The section MUST instruct the LLM to abstract or remove suspicious content and, when uncertain, to ask the user.

#### Scenario: SKILL.md mentions Layer 2 review

- **WHEN** `grep -F "Layer 2" plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` を実行する
- **THEN** ヒット行が 1 件以上ある

### Requirement: e2s-distill command MUST be a single conversational entry point

`plugins/experience-to-skill/commands/e2s-distill.md` SHALL be the single entry point that orchestrates the full distillation flow: (a) resolve jsonl directory, (b) list/filter candidates, (c) ask user to narrow down, (d) read selected jsonl turns, (e) extract success patterns, (f) sanitize, (g) propose SKILL.md name with `e2s-` or `distilled-` prefix, (h) ask placement (project-local vs user-global), (i) write SKILL.md. The command MUST NOT depend on `/tmp/e2s/reflect-candidates.json` or any prior `/e2s:reflect` invocation.

#### Scenario: Command file exists and uses skill chaining

- **WHEN** `ls plugins/experience-to-skill/commands/e2s-distill.md` を実行する
- **THEN** ファイルが存在する

#### Scenario: Command does not reference removed reflect candidates file

- **WHEN** `grep "reflect-candidates" plugins/experience-to-skill/commands/e2s-distill.md` を実行する
- **THEN** ヒット 0 件

### Requirement: Generated SKILL.md MUST use e2s- or distilled- prefix

`/e2s:distill` で生成される SKILL.md の frontmatter `name:` フィールド SHALL start with either `e2s-` or `distilled-` prefix. The command file MUST document this naming rule.

#### Scenario: Command file documents the prefix rule

- **WHEN** `grep -E "(e2s-|distilled-)" plugins/experience-to-skill/commands/e2s-distill.md` を実行する
- **THEN** ヒットが 1 件以上ある（規約に関する記述）

### Requirement: Plugin MUST NOT contain old e2s command files or skill

`plugins/experience-to-skill/commands/` SHALL NOT contain any of the old command files (`e2s-commit.md`, `e2s-ok.md`, `e2s-rewind.md`, `e2s-status.md`, `e2s-reflect.md`). The old auto-commit-style SKILL.md MUST be replaced by the new jsonl-distillation SKILL.md.

#### Scenario: No old command files remain

- **WHEN** `find plugins/experience-to-skill -name 'e2s-commit.md' -o -name 'e2s-ok.md' -o -name 'e2s-rewind.md' -o -name 'e2s-status.md' -o -name 'e2s-reflect.md'` を実行する
- **THEN** ヒットが 0 件である

#### Scenario: No old commands referenced in repository

- **WHEN** `grep -rE '/e2s:(commit|ok|rewind|status|reflect)\\b' .` を実行（除外: `.git/`, `_longruns/`, `openspec/changes/experience-to-skill-plugin/`, `decisions.md` の許可リスト記載分）
- **THEN** ヒットが 0 件である

### Requirement: Bats tests MUST cover shell helper functions

`plugins/experience-to-skill/tests/jsonl-finder.bats` および `plugins/experience-to-skill/tests/sanitize.bats` SHALL exist and SHALL contain unit tests for the normalization and sanitization functions defined above. All tests MUST PASS when `bats plugins/experience-to-skill/tests/*.bats` is executed.

#### Scenario: Bats test files exist

- **WHEN** `ls plugins/experience-to-skill/tests/jsonl-finder.bats plugins/experience-to-skill/tests/sanitize.bats` を実行する
- **THEN** 両ファイルが存在する

#### Scenario: Bats tests pass

- **WHEN** `bats plugins/experience-to-skill/tests/*.bats` を実行する
- **THEN** exit code が 0 であり、全テストが PASS する

### Requirement: Test fixture jsonl MUST be sanitized

`plugins/experience-to-skill/tests/fixtures/sample-session.jsonl` SHALL exist with at least one conversational turn, and MUST NOT contain any PII or secret. The fixture MUST be re-usable for manual E2E verification.

#### Scenario: Fixture file exists

- **WHEN** `ls plugins/experience-to-skill/tests/fixtures/sample-session.jsonl` を実行する
- **THEN** ファイルが存在する

#### Scenario: Fixture does not contain known secrets

- **WHEN** fixture を `scripts/sanitize.sh` に通す
- **THEN** 入力と出力が同一である（既にサニタイズ済み）

### Requirement: plugin.json and marketplace.json versions MUST be bumped consistently

`plugins/experience-to-skill/.claude-plugin/plugin.json` の `version` SHALL be bumped from `0.1.0` to at least `0.2.0` (minor bump), and `.claude-plugin/marketplace.json` の `experience-to-skill` エントリの `version` MUST be synchronized to the same value.

#### Scenario: plugin.json version bumped

- **WHEN** `jq -r '.version' plugins/experience-to-skill/.claude-plugin/plugin.json` を実行する
- **THEN** 戻り値が `0.2.0` 以上（最低 minor bump）

#### Scenario: marketplace.json version synced

- **WHEN** `jq -r '.plugins[] | select(.name == "experience-to-skill") | .version' .claude-plugin/marketplace.json` を実行する
- **THEN** plugin.json と同じ値を返す

