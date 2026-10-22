## MODIFIED Requirements

### Requirement: プラグインを変更しても版を上げない

このリポジトリのプラグインを変更する PR は、`plugin.json` と `.claude-plugin/marketplace.json` に `version` を書いてはならない（MUST NOT）。版は Claude Code がマーケットプレイス clone の HEAD の commit SHA から決める。版上げを求める記述を規約・文書に残してはならない（MUST NOT）。対象は `CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md`・`.github/workflows/ci.yml` のコメント・`README.md` の plugin.json の例で、これらは「版を上げない」「変更の記録は `plugins/<name>/changes/` に書く」を示さなければならない（MUST）。プラグイン編集ルール `rules/plugin-editing.md` は #1129 で個人版のリポジトリ `oratta/claude-harness-oratta` に移したので、この対象に含めない。`docs/worktree-recovery.md` は、版が同じ間は利用者のキャッシュが更新されないこと、`version` を書かなければ commit SHA が版になり push ごとに更新が届くことを、実際の挙動どおりに書かなければならない（MUST）。

#### Scenario: 規約文書に版上げの指示が無い

- **WHEN** `CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md` を読む
- **THEN** `plugin.json` のバージョンを上げる・bump する指示が無く、`plugins/<name>/changes/` に変更を記録する指示がある

#### Scenario: キャッシュの挙動の記述が実挙動と合う

- **WHEN** `docs/worktree-recovery.md` の冒頭の cache の説明とマージ後の反映の節を読む
- **THEN** 「バージョンを上げなくても HEAD に追随する」という記述が無く、commit SHA が版になって更新が届くことが書かれている

#### Scenario: README の plugin.json の例に version が無い

- **WHEN** `README.md` の plugin.json の例を読む
- **THEN** `"version"` キーが含まれていない
