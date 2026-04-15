## ADDED Requirements

### Requirement: Skill MUST be triggered by LLM autonomously upon work completion

The `experience-to-skill` skill SHALL be implemented as an auto-trigger skill in `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`. The skill description MUST cause Claude to activate it when any of the following conditions are detected: (1) user messages containing completion phrases such as "完了", "終わった", "動作確認して", "確認お願いします", "archive して", "commit して"; (2) successful completion of `longrun:archive` or `openspec:archive` commands; (3) explicit invocation via the `/e2s:commit` slash command. Stop hooks SHALL NOT be used for commit execution.

#### Scenario: User signals work completion in Japanese

- **WHEN** the user sends a message containing "確認お願いします" after Claude has edited files in the session
- **THEN** Claude MUST activate the `experience-to-skill` skill and execute the commit workflow defined in the subsequent requirements

#### Scenario: Archive command completes successfully

- **WHEN** `longrun:archive` or `openspec:archive` completes its primary workflow
- **THEN** the archive command MUST invoke the `experience-to-skill` skill before exiting, and the skill MUST gate archive completion on successful commit

#### Scenario: User invokes explicit fallback command

- **WHEN** the user executes `/e2s:commit` with uncommitted changes in the working tree
- **THEN** Claude MUST execute the same commit workflow as auto-triggered mode

### Requirement: Skill MUST stage only files edited by the current session

The skill SHALL determine which files to include in the commit by reviewing Claude's own session context (Edit/Write/MultiEdit/Bash tool call history within the current session), NOT by consulting an external state file. The skill MUST NOT create or read `memory/e2s/sessions/*` directories, `.git/e2s/*` directories, or any other external tracking file for edited-file lists. When the set of files Claude edited in the current session is computed, the skill MUST cross-reference it against `git status` output and stage only the intersection.

#### Scenario: Multiple sessions editing different files in parallel

- **WHEN** Session A has edited `file_x.ts` and Session B has edited `file_y.ts` in the same working tree, and Session A triggers commit first
- **THEN** Session A's commit MUST contain only `file_x.ts` and leave `file_y.ts` unstaged, allowing Session B to commit `file_y.ts` later independently

#### Scenario: File appears in git status but is not in session context

- **WHEN** `git status` shows a modified file that does NOT appear in Claude's session tool call history
- **THEN** the skill MUST exclude that file from `git add`, and MAY ask the user for clarification if the file is large or central to the work

#### Scenario: Session context is compacted

- **WHEN** the session has undergone context compaction and fine-grained Edit history is summarized
- **THEN** the skill MUST rely on the compaction summary for file attribution, inspect `git diff` contents to judge ownership when ambiguous, and ask the user when uncertain

### Requirement: Commit messages MUST use Conventional Commits subject with structured Intent/Result/Prompted-by body

Every commit produced by the skill SHALL follow this format:

```
<type>(<scope>): <imperative subject, max 50 characters>

Intent: <1-2 lines describing what the user wanted to accomplish>
Result: <1-3 lines describing what actually changed or how the problem was solved>
Prompted-by: <session-id>#turn-<N>

🤖 via experience-to-skill
```

The `<type>` value MUST be one of: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`. The subject line MUST use imperative mood ("add" not "added") and MUST NOT exceed 50 characters. The `Intent` and `Result` fields MUST be present in every commit. The `Prompted-by` field MUST contain only a session-id and turn number pointer, NEVER the raw prompt text.

#### Scenario: Standard feature implementation commit

- **WHEN** Claude has implemented a new feature across multiple files and triggers commit
- **THEN** the commit message MUST have subject like `feat(experience-to-skill): add verified tag auto-proposal`, body starting with `Intent:` and `Result:` lines, and a `Prompted-by:` trailer containing only `<session-id>#turn-<N>`

#### Scenario: Bug fix triggered by user feedback

- **WHEN** the user reports a bug and Claude fixes it in the same session
- **THEN** the commit type MUST be `fix`, the `Intent` MUST reference the user's reported problem, and `Result` MUST describe the fix

#### Scenario: Attempt to embed prompt text in Prompted-by

- **WHEN** the skill generates a commit message
- **THEN** the `Prompted-by` field MUST NOT contain any prompt body text, only the session-id and turn number

### Requirement: Skill MUST apply two-layer secret filtering before committing

The skill SHALL execute two independent secret-scanning passes before every commit:

**Layer 1 (deterministic regex-based):**
- Files matching `.env*`, `*.key`, `*.pem`, `credentials.*`, `*_secret*`, `id_rsa*` patterns MUST be excluded from `git add` unconditionally
- Regex patterns for common secret formats (AWS access keys `AKIA[0-9A-Z]{16}`, OpenAI keys `sk-[a-zA-Z0-9]{48}`, JWT tokens, PEM blocks, GitHub tokens `ghp_[a-zA-Z0-9]{36}`) MUST be applied to the staged diff content

**Layer 2 (LLM semantic check):**
- Before executing `git commit`, the LLM MUST review the full staged diff for anything resembling credentials, tokens, or PII that Layer 1 missed

If EITHER layer flags potential secrets, the commit MUST be aborted and the issue reported to the user with the specific file, line, and suspected value (partially redacted).

#### Scenario: .env file in staged changes

- **WHEN** `git status` shows a modified `.env.local` file within the session's edited files
- **THEN** Layer 1 MUST exclude `.env.local` from the commit and report the exclusion to the user

#### Scenario: Hardcoded API key detected by regex

- **WHEN** staged diff contains a line matching `sk-[a-zA-Z0-9]{48}`
- **THEN** Layer 1 MUST abort the commit, report the file and line number, and require user intervention before proceeding

#### Scenario: Custom internal token not matching standard patterns

- **WHEN** staged diff contains a custom-format token like `company_internal_token_abc123...` that Layer 1 does not catch
- **THEN** Layer 2 (LLM review) MUST flag it based on context (variable name, adjacent comments), abort the commit, and report to the user

### Requirement: Skill MUST NOT auto-execute destructive or remote-impacting git operations

The skill SHALL restrict itself to `git add <specific-files>` and `git commit` only. The following operations MUST be prohibited from auto-execution by the skill: `git push`, `git commit --amend`, `git reset --hard`, `git rebase`, `git checkout --`, `git clean -f`, `git tag --force`, `git branch -D`, any command using `--no-verify` or `--no-gpg-sign`. These operations MUST remain subject to explicit user approval.

#### Scenario: Skill would normally want to amend a previous commit

- **WHEN** a commit's secret filter succeeds but the user immediately points out that the Intent line is incorrect
- **THEN** the skill MUST NOT auto-execute `git commit --amend`; it MUST ask the user for explicit permission, or create a new follow-up commit

#### Scenario: User asks the skill to push

- **WHEN** the user says "push してください" after a commit
- **THEN** the skill MUST require explicit confirmation per standard git safety protocol, regardless of the context, because push is out of scope for this skill

### Requirement: Skill MUST gracefully skip when there is nothing to commit

The skill SHALL begin every commit workflow with a precondition check using `git diff --cached --quiet && git diff --quiet`. If no changes exist, the skill MUST exit silently without error, without creating empty commits.

#### Scenario: Auto-trigger fires after a pure Q&A turn with no file edits

- **WHEN** the user sends a completion-phrase message but no files were modified in the preceding turns
- **THEN** the skill MUST detect the clean state and exit without attempting to commit

#### Scenario: All changes are in excluded files

- **WHEN** the only modified files are `.env.local` and other secret-pattern-matching files that Layer 1 excludes
- **THEN** the skill MUST report the exclusion to the user and exit without committing

### Requirement: Global git-commit-policy.md MUST be rewritten to allow auto-commits

The plugin installation or implementation change SHALL rewrite `~/.claude/rules/git-commit-policy.md` to remove the existing "明示承認なしのコミット絶対禁止" (never commit without explicit approval) clause and replace it with a policy permitting automatic commits at work-completion units. The new policy MUST explicitly retain prohibitions on: automatic `git push`, `git commit --amend`, `git reset --hard`, `git rebase -i`, and use of `--no-verify`.

#### Scenario: Policy file is updated

- **WHEN** the implementation modifies `~/.claude/rules/git-commit-policy.md`
- **THEN** the new content MUST permit automatic commits at completion events while explicitly prohibiting push / amend / reset / rebase / --no-verify auto-execution

#### Scenario: User rolls back the plugin

- **WHEN** the user uninstalls the plugin via `/plugin uninstall experience-to-skill@oratta-claude-harness`
- **THEN** the user SHOULD manually restore the previous `git-commit-policy.md` or accept the new policy; the uninstall process is NOT required to auto-restore it, but the README MUST document the manual restoration path
