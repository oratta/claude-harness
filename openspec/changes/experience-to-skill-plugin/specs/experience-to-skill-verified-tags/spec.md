## ADDED Requirements

### Requirement: Verified tags MUST use a structured, timestamp-sortable naming convention

All verified tags created by the plugin SHALL use the format `verified/<YYYYMMDD-HHMMSS>-<kebab-case-label>` where the timestamp MUST use UTC or the local system time consistently across all tags, and the label MUST be 2-40 characters in kebab-case derived from the work unit being verified. Tags MUST be created as lightweight tags (not annotated) to keep history clean and push-lightweight.

#### Scenario: User confirms infrastructure setup phase completion

- **WHEN** the user approves the completed work after finishing an infra-setup phase and invokes `/e2s:ok`
- **THEN** the skill MUST create a lightweight tag with a name matching `verified/20260414-1530-infra-phase5-complete` format, where the label is LLM-generated from the session context and user-editable

#### Scenario: Two tags created in the same second

- **WHEN** tag creation attempts collide at the same second
- **THEN** the skill MUST detect the collision via `git tag --list` and append a `-N` suffix (where N is 2, 3, ...) to disambiguate

### Requirement: `/e2s:ok` command MUST offer verified tag creation with user confirmation of the label

The `/e2s:ok` slash command SHALL implement the verified tagging workflow. It MUST: (1) verify that HEAD points to a commit (not a detached or clean working tree without commits), (2) generate a kebab-case label proposal from recent session context, (3) show the user the proposed tag name and allow editing before creation, (4) create the tag on the current HEAD, (5) report the tag name on success.

#### Scenario: Standard verified tag creation

- **WHEN** the user runs `/e2s:ok` after confirming their work is done
- **THEN** the command MUST display a proposed tag name, accept user edits, and create the tag via `git tag <name>` on HEAD

#### Scenario: Working tree has uncommitted changes when /e2s:ok is invoked

- **WHEN** the user runs `/e2s:ok` while uncommitted changes exist in the working tree
- **THEN** the command MUST refuse to create the tag, report the unstaged/uncommitted files, and suggest running `/e2s:commit` first

#### Scenario: User supplies an explicit label

- **WHEN** the user runs `/e2s:ok infra-phase5-complete` with an explicit label argument
- **THEN** the command MUST use the supplied label directly without prompting for editing, but MUST still validate the kebab-case format

### Requirement: Auto-trigger tag proposal on archive command completion

When `longrun:archive` or `openspec:archive` completes successfully, the `experience-to-skill` skill SHALL automatically propose creating a verified tag. The proposal MUST present the tag name with a meaningful label derived from the archive operation (e.g., the change name for openspec), and MUST NOT execute `git tag` without user confirmation.

#### Scenario: openspec:archive completes successfully

- **WHEN** `openspec:archive <change-name>` completes without error
- **THEN** the skill MUST propose `verified/<timestamp>-<change-name>` as a tag name and ask the user for confirmation before creating it

#### Scenario: User declines the auto-proposed tag

- **WHEN** the skill proposes a verified tag after archive completion and the user declines or ignores
- **THEN** the skill MUST NOT create the tag and MUST exit without error; the user can still manually invoke `/e2s:ok` later

### Requirement: `/e2s:rewind` MUST create a backup tag before any destructive operation

The `/e2s:rewind` slash command SHALL NOT perform `git reset --hard` or equivalent destructive operation without first creating a backup lightweight tag named `backup/<YYYYMMDD-HHMMSS>-before-rewind` pointing at the current HEAD. The backup tag creation MUST succeed before the reset executes; if backup tag creation fails for any reason, the rewind MUST be aborted.

#### Scenario: Rewind to most recent verified tag

- **WHEN** the user runs `/e2s:rewind` without arguments
- **THEN** the command MUST list verified tags with HEAD relationship info, let the user pick, create `backup/<timestamp>-before-rewind` on current HEAD, then execute `git reset --hard <chosen-tag>`, then report the backup tag name for recovery

#### Scenario: Rewind to a specific verified tag

- **WHEN** the user runs `/e2s:rewind verified/20260414-1530-foo`
- **THEN** the command MUST create a backup tag, execute `git reset --hard verified/20260414-1530-foo`, and report the backup tag name

#### Scenario: Backup tag creation fails due to disk full or permission error

- **WHEN** `git tag backup/...` fails before reset executes
- **THEN** the rewind MUST abort immediately, the reset MUST NOT execute, and the error MUST be reported to the user with the backup tag that was attempted

#### Scenario: List verified tags only

- **WHEN** the user runs `/e2s:rewind --list`
- **THEN** the command MUST display existing verified tags sorted by timestamp with their commit subject and age, without performing any destructive operation

### Requirement: Rewind MUST check for uncommitted changes and warn before destroying them

Before executing `git reset --hard`, `/e2s:rewind` SHALL check for uncommitted changes in the working tree. If any exist, the command MUST warn the user, list the files that will be lost, and require explicit confirmation to proceed.

#### Scenario: Rewind attempted with uncommitted changes

- **WHEN** the user runs `/e2s:rewind verified/foo` while `git status` shows modified or untracked files
- **THEN** the command MUST list the affected files, warn that they will be lost, and require the user to type "yes" or equivalent explicit confirmation before executing reset

#### Scenario: User cancels after seeing uncommitted changes warning

- **WHEN** the user declines the confirmation prompt
- **THEN** the rewind MUST NOT execute, the backup tag MUST NOT be created, and the working tree MUST remain untouched

### Requirement: Tags MUST be repo-local and NOT auto-pushed

Verified and backup tags created by the plugin SHALL remain local until the user explicitly pushes them. The skill and slash commands MUST NOT execute `git push --tags`, `git push origin <tag>`, or any push operation. Documentation MUST inform the user that tags are local-only by default.

#### Scenario: User pushes manually after creating verified tags

- **WHEN** the user runs `git push --tags` manually
- **THEN** the tags are pushed normally using standard git behavior, but the plugin itself MUST NOT initiate this

#### Scenario: Plugin adds a new tag

- **WHEN** the plugin creates any verified/ or backup/ tag
- **THEN** the tag remains local only, with no push attempt made

### Requirement: Multi-session tag creation MUST NOT collide on the same commit

When multiple Claude sessions are active on the same repository, each may attempt to create verified tags. The tagging workflow SHALL detect existing tags pointing at HEAD or nearby commits and avoid duplicate-meaning tags. If a tag with the proposed name already exists, the skill MUST append a disambiguating suffix.

#### Scenario: Two sessions tag the same commit concurrently

- **WHEN** Session A and Session B both attempt to create a tag at the same second on the same HEAD
- **THEN** the second `git tag` to execute MUST detect the name collision, append `-2` to its proposed name, and retry; both tags MUST successfully exist without data loss

#### Scenario: Session finds HEAD already has a verified tag from another session

- **WHEN** a session attempts `/e2s:ok` on a commit that another session already tagged as verified
- **THEN** the skill MUST display the existing verified tag(s) on HEAD and ask the user whether to add another tag with a different label, or skip tag creation
