## 1. 検査を先に書く（TDD: この時点では落ちることを確かめる）

- [ ] 1.1 `tests/marketplace-sync.bats` の S130 を「全 `plugins/*/.claude-plugin/plugin.json` に `version` が無い」、S131 を「`marketplace.json` の全 `plugins[]` エントリに `version` が無い」に置き換え、違反したプラグイン名と値を出力して fail させる。`origin/main` を参照しない。使われなくなった merge-base の解決関数を消す
- [ ] 1.2 同ファイルの S139 を、先頭と末尾のエントリの `description` を別ブランチで書き換えてマージする形に直す
- [ ] 1.3 `tests/plugin-release-convention.bats` を新規に作る: `plugins/*/changes/*` のファイル名が `^[0-9]+\.md$` で 1 行目が `# ` で始まる／凍結した 2 つの `CHANGELOG.md` のタイトル行の次の非空行が `changes/` を含む／その後の最初の `## ` 見出しが dev-workflow は `## 2.13.37 —`、product-handover は `## v0.1.0 —` で始まる／`plugins/*/CHANGELOG.md` がこの 2 件だけ／規約文書（`rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md`）に版上げの指示が無く `changes/` の指示がある／`README.md` の plugin.json の例に `"version"` が無い／`docs/worktree-recovery.md` に「バージョン据え置きでも中身は入る」旨の記述が無い
- [ ] 1.4 `plugins/dev-workflow/tests/prompt-tripwires-refresh.bats` を、`version` の無い `plugin.json` と `CLAUDE_PLUGIN_ROOT` の切り替えで (a)〜(g) を確かめる形に書き換え、旧方式の版番号が状態ファイルに残っているセッションで 1 回だけ再注入するケースを足す
- [ ] 1.5 `bats tests/marketplace-sync.bats tests/plugin-release-convention.bats plugins/dev-workflow/tests/prompt-tripwires-refresh.bats` が期待どおりに落ちることを確かめる

## 2. 版の撤去

- [ ] 2.1 全 13 本の `plugins/*/.claude-plugin/plugin.json` から `version` を消す（`jq 'del(.version)'` で、キーの順序と他のフィールドを変えない）
- [ ] 2.2 `.claude-plugin/marketplace.json` の全 `plugins[]` エントリから `version` を消す
- [ ] 2.3 `jq` で全件 `has("version") == false` を確かめる（受け入れ条件 1）

## 3. 実行時スクリプト

- [ ] 3.1 `plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh` の比較値を `plugin.json` の `version` から `CLAUDE_PLUGIN_ROOT` の値に変える。`version` を抜く処理を消し、冒頭のコメント（「なぜバージョン変化だけを見るのか」と契約）を新しい比較値に合わせて直す。状態ディレクトリの既定名（`.tripwire-versions`）は既存の状態を引き継ぐため変えない
- [ ] 3.2 `plugins/dev-workflow/templates/escalation-tripwires.md` の「plugin.json のバージョンが前回注入時から変わったとき」の説明を、プラグインの更新（`CLAUDE_PLUGIN_ROOT` の変化）に直す
- [ ] 3.3 `bats plugins/dev-workflow/tests/prompt-tripwires-refresh.bats` が通る（受け入れ条件 5）

## 4. 各プラグインの bats の版の検査を削る

- [ ] 4.1 `git grep -n -E "sort -V|\.version|\"version\"" -- 'plugins/*/tests/*' tests` で全件を確定し、plugin.json / marketplace.json の版を見ている検査を一覧にする（SKILL.md frontmatter の版を見る検査は対象外）
- [ ] 4.2 casting（`casting-consultation.bats` の版の下限。agents の登録の検査は残す）、dev-workflow（`develop-command.bats`・`model-escalation-policy.bats`・`pr-review-gate-skill.bats`・`pr-review-gate-spec-declaration.bats`・`push-guard-setup.bats`・`retirement.bats`・`spec-decision-and-review.bats`）、worktree（`orphan-proc-guard.bats`・`setup-script.bats`・`unattended-mode.bats` の plugin.json の版）から版の検査を削る。同じテストにある版以外の検査は残す
- [ ] 4.3 `plugins/product-handover/tests/plugin-structure.bats` の「版が semver 形式」を「`version` が無い」に変える
- [ ] 4.4 `plugins/infra/skills/infra-setup/SKILL.md` の frontmatter から `version` を消し、`plugins/infra/tests/infra-fixes.bats` の S29 を「SKILL.md に `version:` が無い」に変え、S31 を削る

## 5. 変更記録の方式

- [ ] 5.1 `plugins/dev-workflow/CHANGELOG.md` と `plugins/product-handover/CHANGELOG.md` のタイトル行の直後に、以後は `changes/<番号>.md` に書き、このファイルには追記しない旨の 1 行を足す
- [ ] 5.2 `plugins/dev-workflow/changes/447.md` と `plugins/product-handover/changes/447.md` に、この移行の記録（版番号の撤去と変更記録の方式の移行）を書く

## 6. 規約と文書

- [ ] 6.1 `rules/plugin-editing.md` の版上げの 1 行を、版は上げない（commit SHA が版になる）・変更の記録は `plugins/<name>/changes/<番号>.md` に書く、に置き換える（聖域。最小限の差分）
- [ ] 6.2 `CLAUDE.md` と `AGENTS.md` の「`plugin.json` の bump」を外す（聖域。最小限の差分）
- [ ] 6.3 `docs/worktree-recovery.md` のマージ後の反映と `plugin.json` の bump の節を、版は上げないこと・`version` が無ければ commit SHA が版になり push ごとに更新が届くこと・版が同じ間はキャッシュが更新されないことに書き換える
- [ ] 6.4 `.github/workflows/ci.yml` の「バージョン整合ガード（S131）について」のコメントを、S130・S131 が `version` の不在を常時走る決定論的検査として見ている旨に書き換える
- [ ] 6.5 `README.md` の plugin.json の例から `"version"` を消す
- [ ] 6.6 `git grep -n -iE "バージョンを上げ|版を上げ|bump|plugin\.json.*version"` を archive・`_longruns` を除いて再実行し、プラグインの版上げを求める記述が残っていないことを確かめる（依存パッケージの版上げなど無関係なものは除く）

## 7. 仕上げ

- [ ] 7.1 `tests/injection-budget.bats` が通ることを確かめる。予算を動かす必要が出たら値と理由を PR 本文に書く
- [ ] 7.2 `bash scripts/test.sh` 全件をフォアグラウンドで流して通す（受け入れ条件 6。`statusline-multi-account.bats` の単発失敗は単独再実行で判定する）
- [ ] 7.3 `openspec validate commit-sha-pr-changelog --strict` が通る
