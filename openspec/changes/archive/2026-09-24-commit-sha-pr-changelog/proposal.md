## Why

今の規約は PR ごとに `plugins/<name>/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の `version` を上げ、`CHANGELOG.md` の先頭に項目を足すよう求めている。並行する PR が全部同じ行を書き換えるので、1 本マージされるたびに残りが衝突する（PR #438 は 1 日で 3 回衝突し、#428 と #438 は同じ `2.13.37` を選んで版が重複しかけた）。Claude Code は git ソースのマーケットプレイスで `version` が無ければ commit SHA を版にして push ごとに更新を届けるので、版を人が管理する理由は無い（issue #447）。

## What Changes

- **BREAKING**（配布の版の付け方）: 全プラグインの `plugin.json` と `marketplace.json` の `plugins[]` エントリから `version` を消す。以後の版は Claude Code がマーケットプレイス clone の HEAD の commit SHA（先頭 12 桁）から決める。片方でも残るとその値が版として固定され更新が止まるので、両方から消す
- `tests/marketplace-sync.bats` の S130（marketplace と plugin.json の版の一致）と S131（merge-base より版が上がっている）を、`version` が無いことを確かめる検査に置き換える。S132 と同じく `origin/main` を要さず CI で常に走る決定論的な検査にし、版を上げる古い PR が後からマージされて `version` が復活するのを CI で落とす。S139 は版ではなく別のフィールドを書き換える 2 ブランチで同じ性質を確かめる形に直す
- 版の下限（`sort -V` など）や marketplace との版一致を検査している各プラグインの bats から、版の検査部分を削る（版以外の検査は残す）
- `plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh` は `plugin.json` の `version` の代わりに `CLAUDE_PLUGIN_ROOT`（キャッシュの版名＝SHA を含むパス）の変化でプラグインの更新を検知する。`version` が無い `plugin.json` で黙って止まる現状を直す
- CHANGELOG を PR ごとの別ファイル `plugins/<name>/changes/<番号>.md` に書く方式に変える。既存の `CHANGELOG.md` は過去分として残し、先頭に移行を 1 行書いて以後は追記しない。追記されていないことを決定論的なテストで固定する
- 版上げを求めている規約・文書（`rules/plugin-editing.md`、`CLAUDE.md`、`AGENTS.md`、`docs/worktree-recovery.md`、`.github/workflows/ci.yml` のコメント、`README.md` の plugin.json の例、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/infra/skills/infra-setup/SKILL.md` の plugin 版の写し）を新しい方式に書き換える

## Capabilities

### New Capabilities

- `plugin-release-convention`: プラグインを変更したときの規約。版を上げないこと、変更の記録を PR ごとの別ファイルに書くこと、過去の `CHANGELOG.md` を凍結することと、それらを固定するテスト

### Modified Capabilities

- `marketplace-plugin-sync`: 「全エントリの version が plugin.json と一致」と「変更したプラグインは merge-base より version が上がっている」を、「plugin.json と plugins[] は version を持たない」に置き換える。無関係な PR が衝突しないことの検査を版以外のフィールドで行う形に直す
- `marketplace-final-sync`: 過去の run での版上げ要件を外し、marketplace.json と plugin.json の一致を description だけにする
- `loops-longrun-retirement`: 過去の change での版上げ要件を外す
- `infra-doc-integrity`: infra-setup の SKILL.md に plugin の版を写す要件を「写さない」に変え、infra の版上げ要件を外す
- `experience-to-skill-jsonl-distillation`: 過去の change での版上げ要件を外す
- `global-push-guard`: 過去の change での版上げ要件を外す
- `discord-plugin-retirement`: 他エントリの「version を変えない」制約と、版上げ検査への言及を外す
- `dev-workflow-escalation-tripwires`: セッション途中のプラグイン更新を `version` ではなく `CLAUDE_PLUGIN_ROOT` の変化で検知して再注入する要件を足す

## Impact

- 配布: 全 13 プラグインの `plugin.json`、`.claude-plugin/marketplace.json`。マージ後、利用者のキャッシュは 1 回だけ semver 名から SHA 名のディレクトリに移り、以後はマージごとに更新が届く
- 実行時コード: `plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh`（とその bats）
- テスト: `tests/marketplace-sync.bats`、版を検査している各プラグインの bats（casting・dev-workflow・worktree・infra・product-handover）、新規の規約テスト
- 文書・規約: `rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`（聖域。PR は `human-merge`）、`docs/worktree-recovery.md`、`.github/workflows/ci.yml`、`README.md`、`plugins/dev-workflow/CHANGELOG.md`、`plugins/product-handover/CHANGELOG.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/infra/skills/infra-setup/SKILL.md`
- 並行作業: 版を上げている開いた PR と稼働中の worktree は、main を取り込むと `version` 行と `CHANGELOG.md` 先頭で衝突し、取り込まずにマージしようとすると新しい検査で CI が落ちる（周知はマージ後に本体が行う）
