## 1. Plugin Scaffolding

- [x] 1.1 Create directory structure `plugins/experience-to-skill/` with subdirectories: `.claude-plugin/`, `skills/experience-to-skill/`, `commands/`
- [x] 1.2 Create `plugins/experience-to-skill/.claude-plugin/plugin.json` with name, version (0.1.0), description, and command registrations for `e2s-commit`, `e2s-ok`, `e2s-rewind`, `e2s-reflect`, `e2s-distill`
- [x] 1.3 Register `experience-to-skill` plugin in `.claude-plugin/marketplace.json` with appropriate metadata (name, description, keywords)
- [x] 1.4 Bump marketplace version in `.claude-plugin/marketplace.json` to reflect the addition

## 2. Main Skill Implementation (`experience-to-skill` skill)

- [x] 2.1 Create `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` with YAML frontmatter: `name: experience-to-skill`, strong auto-trigger description listing Japanese completion phrases ("完了", "終わった", "動作確認して", "確認お願いします", "archive して", "commit して") and archive-command completion events
- [x] 2.2 Write Precondition step: use `git diff --cached --quiet && git diff --quiet` to detect empty state; exit silently if clean
- [x] 2.3 Write Step 1 (file attribution): instructions for LLM to enumerate files it edited in this session via its own Edit/Write/MultiEdit/Bash tool call history, NOT via external state file
- [x] 2.4 Write Step 2 (git status intersection): run `git status --porcelain`, intersect with session-edited file list, record the intersection as the staging set
- [x] 2.5 Write Step 3 (Layer 1 secret filter): explicit exclusion of files matching `.env*`, `*.key`, `*.pem`, `credentials.*`, `*_secret*`, `id_rsa*` patterns from staging set
- [x] 2.6 Write Step 4 (Layer 1 content regex): scan staged diff content for AWS keys (`AKIA[0-9A-Z]{16}`), OpenAI keys (`sk-[a-zA-Z0-9]{48}`), GitHub tokens (`ghp_[a-zA-Z0-9]{36}`), JWT patterns, PEM blocks; abort on match
- [x] 2.7 Write Step 5 (Layer 2 LLM review): instruct LLM to review full staged diff for any secret-looking content Layer 1 may have missed; abort on suspicion
- [x] 2.8 Write Step 6 (commit message generation): Conventional Commits subject with type from (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`), 50 char max, imperative mood; body with `Intent:`, `Result:`, `Prompted-by: <session-id>#turn-<N>`, trailing `🤖 via experience-to-skill`
- [x] 2.9 Write Step 7 (session-id acquisition): describe fallback chain for obtaining session-id: `$CLAUDE_SESSION_ID` env var → jsonl path inspection → UUID generation
- [x] 2.10 Write Step 8 (execute commit): `git add <specific files>` (never `-A` or `.`), then `git commit -m "..."`; report commit SHA to user
- [x] 2.11 Write Step 9 (archive trigger path): when invoked from `longrun:archive` or `openspec:archive`, propose verified tag creation after successful commit via `/e2s:ok`
- [x] 2.12 Write Guardrails section: explicit prohibition of `git push`, `git commit --amend`, `git reset --hard`, `git rebase`, `--no-verify`, `--no-gpg-sign` as auto-executions
- [x] 2.13 Document context-compaction fallback behavior in a Notes section

## 3. Slash Commands

- [x] 3.1 Create `plugins/experience-to-skill/commands/e2s-ok.md` implementing verified tag creation: validate HEAD points to a commit, ensure clean working tree, generate label proposal from session context, accept optional `$ARGUMENTS` label, check for collision and append `-N` suffix, execute `git tag verified/YYYYMMDD-HHMMSS-<label>` as lightweight tag, report tag name
- [x] 3.2 Create `plugins/experience-to-skill/commands/e2s-rewind.md` implementing safe rewind: support `--list` mode (read-only tag listing), default mode (pick from list), explicit target mode (`$ARGUMENTS` = target tag); always check uncommitted changes and require explicit confirmation; create `backup/YYYYMMDD-HHMMSS-before-rewind` lightweight tag before reset; abort if backup tag creation fails; execute `git reset --hard <target>`; report backup tag name
- [x] 3.3 Create `plugins/experience-to-skill/commands/e2s-reflect.md` implementing interval analysis: default range `<latest-verified>..HEAD`, explicit range via `$ARGUMENTS`, read-only git operations only (`git log`, `git show`, `git diff`), read session jsonl via Prompted-by trailers with graceful fallback on missing session, abstract all content (never display raw prompts), output numbered candidates with name/description/triggers/steps/rationale/source SHAs + session refs
- [x] 3.4 Create `plugins/experience-to-skill/commands/e2s-distill.md` implementing SKILL.md generation: accept candidate id from `$ARGUMENTS`, ask user for placement choice (project-local `<root>/.claude/skills/distilled/` vs user-global `~/.claude/skills/distilled/`), enforce name prefix `e2s-` or `distilled-` in YAML frontmatter, include `## Source` section with commit SHAs + session refs, handle existing target with overwrite/version-suffix/cancel prompt
- [x] 3.5 Create `plugins/experience-to-skill/commands/e2s-commit.md` as the explicit manual commit trigger that invokes the same workflow as auto-trigger (useful as fallback when auto-trigger is missed)
- [x] 3.6 (Optional) Create `plugins/experience-to-skill/commands/e2s-status.md` for diagnostic display of uncommitted diffs, session-edited files, latest verified tag, and any pending suggestions

## 4. Global Policy Rewrite

- [x] 4.1 Rewrite `~/.claude/rules/git-commit-policy.md`: remove the "明示承認なしのコミット絶対禁止" section entirely
- [x] 4.2 Add new "Auto-commit Policy" section: permit automatic commits at work-completion units; specify trigger conditions (completion phrases, archive-command finishes, explicit `/e2s:commit`)
- [x] 4.3 Add new "Still Prohibited" section retaining bans on auto-`git push`, auto-`git commit --amend`, auto-`git reset --hard`, auto-`git rebase` (especially `-i`), `--no-verify`, `--no-gpg-sign`, and force operations to main/master
- [x] 4.4 Add cross-reference pointing to the `experience-to-skill` plugin README for the full commit workflow

## 5. Documentation

- [x] 5.1 Create `plugins/experience-to-skill/README.md` with: Overview, Quick Start, Commit Message Format, Verified Tags, Skill Distillation, Security (secret filter layers), Multi-Session Behavior
- [x] 5.2 Add README section "Relationship to skill-creator" explicitly covering the three distinctions: skill-creator builds from scratch with design input, experience-to-skill distills from history, both coexist via `distilled/` subdirectory and `e2s-`/`distilled-` name prefixes
- [x] 5.3 Add README section on uninstallation: commands to run for removal, note that `git-commit-policy.md` is NOT auto-restored on uninstall and the user should manually revert if desired
- [x] 5.4 Add README section documenting session jsonl location: `~/.claude/projects/<project-hash>/*.jsonl`, how Prompted-by references resolve, and the graceful fallback when sessions are missing
- [x] 5.5 Add README "Limitations" section: Prompted-by pointer only meaningful in local/same-user context, jsonl retention policy recommendations, tag count growth warning

## 6. Validation and Testing

- [x] 6.1 Run `openspec validate experience-to-skill-plugin --strict` and fix any reported issues
- [ ] 6.2 Reload plugins (`/reload-plugins`) and confirm the `experience-to-skill` plugin appears, its skill shows in the available skills list, and all 5 slash commands appear under `/e2s-*`
- [ ] 6.3 Manual test: make a trivial file edit, say "確認お願いします" (or similar completion phrase), verify skill auto-triggers and produces a correctly formatted commit
- [ ] 6.4 Manual test: create a `.env.test` file with a fake secret, attempt commit, verify Layer 1 rejects with clear error message
- [ ] 6.5 Manual test: embed an `sk-` prefixed fake key in a source file, attempt commit, verify Layer 1 regex catches it
- [ ] 6.6 Manual test: run `/e2s-ok test-verify`, verify tag `verified/YYYYMMDD-HHMMSS-test-verify` is created as lightweight tag
- [ ] 6.7 Manual test: create additional commit, run `/e2s-rewind`, verify backup tag is created before reset and HEAD returns to verified point
- [ ] 6.8 Manual test: open parallel Claude session, edit different files in each, commit from each, verify no cross-contamination (each commit contains only its own files)
- [ ] 6.9 Manual test: run `/e2s-reflect` after some commits, verify candidates are produced with commit SHAs and session refs in source section
- [ ] 6.10 Manual test: run `/e2s-distill <id>`, verify SKILL.md is created at correct location with `e2s-` or `distilled-` name prefix and Source section

## 7. Marketplace Integration

- [ ] 7.1 Verify `.claude-plugin/marketplace.json` version bump is semver-appropriate (minor version for new plugin addition)
- [ ] 7.2 Commit all changes with Conventional Commits-compliant message (this plugin's own dogfooding: first commit should use the new format)
- [ ] 7.3 Push to the marketplace git repository (requires explicit user approval per plugin's own guardrails)
- [ ] 7.4 Post-push: run `/plugin install experience-to-skill@oratta-claude-harness` in a fresh session to verify end-to-end installation works
