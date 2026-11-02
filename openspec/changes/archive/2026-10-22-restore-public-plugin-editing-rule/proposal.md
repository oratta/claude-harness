## Why

PR #1218（change `move-private-parts-to-private-repo`）は、#1128 の仕分けの表のとおり `rules/plugin-editing.md` をまるごと公開版から消して個人版 `oratta/claude-harness-oratta` に移した。主は「ルールが個人版に移って公開でなくなったのは逆。公開版はみんな入れる」と指摘し、直してからマージすると決めた（https://github.com/oratta/claude-harness/issues/1129#issuecomment-6336113363 ）。ルールの中身は 2 種類が混ざっていた。プラグインを入れた誰にでも当てはまる注意（インストール先を直接編集しない等）と、Harness 開発者だけに要る手順（開発用 clone の解決、`sync.sh`、変更の記録、Draft PR）である。

## What Changes

- 公開版に `rules/plugin-editing.md` を短くして戻す。書くのは全員に要る 5 点: インストール先（`~/.claude/plugins/marketplaces/...`）を直接編集しない／`~/.claude/commands/` `~/.claude/skills/` のローカルコピーを編集しない／`~/.claude/rules/*.md` は symlink なのでルールも部品を持つリポジトリ側で直す／部品は持つリポジトリの開発用 clone で直す（個人版の名前は書かない）／手動で削除せず `/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`
- 個人版のリポジトリのルールは、Harness 開発者向けの部分だけに削り、ファイル名を `rules/harness-dev.md` に変える（公開版と同名だと `~/.claude/rules/` で衝突する）。個人版の main に直接 push せず、feature ブランチと Draft PR で行う
- 仕分けの表に `rules/plugin-editing.md` を「公開版」で載せ、「個人版に移した部品」の表から外し、移した部分は表のあとの段落に書く
- 検査を直す（移した部品の検査から `rules/plugin-editing.md` を外し、公開版のルールの中身の検査を足す。版上げ検査と常時注入の目印は対象に戻す）
- 戻した分だけ常時注入が増えるので `tests/injection-budget.txt`（聖域）を動かす。PR 本文に理由を書く
- 参照を戻す: `CLAUDE.md`・`AGENTS.md`（聖域）・`docs/worktree-recovery.md`・`rules/README.md` の「個人版が入っていれば」を外す。記録 `plugins/dev-workflow/changes/1218.md` を直す
- **BREAKING** なし（公開版の利用者には、いったん消える予定だったルールが残るだけ）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `harness-public-private-split`: 移した部品の要件から `rules/plugin-editing.md` を外し、公開版のプラグイン編集ルールの中身と個人版のファイル名の要件を足す
- `always-on-injection-scope`: 常時注入に残す指示の列挙に、公開版のプラグイン編集ルールの「手動で削除しない」を載せる
- `plugin-release-convention`: 版上げ指示が無いことを確かめる対象に `rules/plugin-editing.md` を戻す

## Impact

- 公開版: `rules/plugin-editing.md`（新規に戻す）・`rules/README.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md`・`docs/public-private-split.md`・`tests/public-private-split.bats`・`tests/always-on-injection-scope.bats`・`tests/plugin-release-convention.bats`・`tests/injection-budget.txt`・`plugins/dev-workflow/changes/1218.md`
- 個人版: `rules/plugin-editing.md` → `rules/harness-dev.md`（改名して削る）、README の言及
- オーナーの環境: 既存の `~/.claude/rules/plugin-editing.md`（公開版を指す symlink）はそのまま使える。PR #1218 の本文にあった「個人版へ張り替える」手順は不要になる。開発する PC は `~/.claude/rules/harness-dev.md` を個人版の clone の `rules/harness-dev.md` への symlink にする
