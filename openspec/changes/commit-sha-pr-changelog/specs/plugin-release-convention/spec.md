## ADDED Requirements

### Requirement: プラグインを変更しても版を上げない

このリポジトリのプラグインを変更する PR は、`plugin.json` と `.claude-plugin/marketplace.json` に `version` を書いてはならない（MUST NOT）。版は Claude Code がマーケットプレイス clone の HEAD の commit SHA から決める。版上げを求める記述を規約・文書に残してはならない（MUST NOT）。対象は `rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md`・`.github/workflows/ci.yml` のコメント・`README.md` の plugin.json の例で、これらは「版を上げない」「変更の記録は `plugins/<name>/changes/` に書く」を示さなければならない（MUST）。`docs/worktree-recovery.md` は、版が同じ間は利用者のキャッシュが更新されないこと、`version` を書かなければ commit SHA が版になり push ごとに更新が届くことを、実際の挙動どおりに書かなければならない（MUST）。

#### Scenario: 規約文書に版上げの指示が無い

- **WHEN** `rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md` を読む
- **THEN** `plugin.json` のバージョンを上げる・bump する指示が無く、`plugins/<name>/changes/` に変更を記録する指示がある

#### Scenario: キャッシュの挙動の記述が実挙動と合う

- **WHEN** `docs/worktree-recovery.md` のマージ後の反映の節を読む
- **THEN** 「バージョンを上げなくても HEAD に追随する」という記述が無く、commit SHA が版になって更新が届くことが書かれている

#### Scenario: README の plugin.json の例に version が無い

- **WHEN** `README.md` の plugin.json の例を読む
- **THEN** `"version"` キーが含まれていない

### Requirement: 変更の記録は PR ごとの別ファイルに書く

プラグインの変更の記録は `plugins/<name>/changes/<番号>.md` に 1 PR 1 ファイルで書かなければならない（MUST）。`<番号>` は記録先が issue ならその issue 番号、Draft PR が記録先ならその PR 番号とする（GitHub では issue と PR が同じ番号空間を共有するので、別の PR と同じ名前にならない）。1 つの PR が複数のプラグインを変えたときは、プラグインごとに同じ番号のファイルを置く。ファイル名は `^[0-9]+\.md$` に一致し、1 行目は `# ` で始まる見出しでなければならない（MUST）。記録を書く対象は、これまで `CHANGELOG.md` を持っていたプラグイン（dev-workflow・product-handover）と、利用者に移行作業を求める変更をしたプラグインとする。

#### Scenario: 変更記録のファイル名と見出しの形

- **WHEN** 全 `plugins/*/changes/` 配下のファイルを列挙する
- **THEN** 全ファイル名が `^[0-9]+\.md$` に一致し、各ファイルの 1 行目が `# ` で始まる

#### Scenario: この移行自体の記録がある

- **WHEN** `plugins/dev-workflow/changes/447.md` と `plugins/product-handover/changes/447.md` を読む
- **THEN** 両方が存在し、版番号の撤去と変更記録の方式の移行が書かれている

### Requirement: 過去の CHANGELOG.md は凍結する

既存の `plugins/dev-workflow/CHANGELOG.md` と `plugins/product-handover/CHANGELOG.md` は過去分として残し、タイトル行の直後に `changes/` の方式へ移行した旨を 1 行書かなければならない（MUST）。以後これらに項目を足してはならない（MUST NOT）。追記の有無は `origin/main` を要さず常に走る決定論的なテストで検査しなければならない（MUST）: 移行の 1 行の後に現れる最初の `## ` 見出しが、移行時点の最新の項目の見出しと一致すること。新しい項目が他のプラグインに `CHANGELOG.md` として作られてもならない（MUST NOT）。

#### Scenario: 凍結した CHANGELOG の先頭に新しい項目が足されたのを検出する

- **WHEN** `plugins/dev-workflow/CHANGELOG.md` の移行の 1 行と `## 2.13.37` の見出しの間に新しい `## ` 見出しが足される
- **THEN** テストは足された見出しを出力して fail する

#### Scenario: 移行の 1 行がある

- **WHEN** 凍結した 2 つの `CHANGELOG.md` のタイトル行の次の非空行を読む
- **THEN** `changes/` を含む移行の 1 行である

#### Scenario: 新しい CHANGELOG.md を作らない

- **WHEN** `plugins/*/CHANGELOG.md` を列挙する
- **THEN** dev-workflow と product-handover の 2 件だけである
