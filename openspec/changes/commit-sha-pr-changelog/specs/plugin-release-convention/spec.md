## ADDED Requirements

### Requirement: プラグインを変更しても版を上げない

このリポジトリのプラグインを変更する PR は、`plugin.json` と `.claude-plugin/marketplace.json` に `version` を書いてはならない（MUST NOT）。版は Claude Code がマーケットプレイス clone の HEAD の commit SHA から決める。版上げを求める記述を規約・文書に残してはならない（MUST NOT）。対象は `rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md`・`.github/workflows/ci.yml` のコメント・`README.md` の plugin.json の例で、これらは「版を上げない」「変更の記録は `plugins/<name>/changes/` に書く」を示さなければならない（MUST）。`docs/worktree-recovery.md` は、版が同じ間は利用者のキャッシュが更新されないこと、`version` を書かなければ commit SHA が版になり push ごとに更新が届くことを、実際の挙動どおりに書かなければならない（MUST）。

#### Scenario: 規約文書に版上げの指示が無い

- **WHEN** `rules/plugin-editing.md`・`CLAUDE.md`・`AGENTS.md`・`docs/worktree-recovery.md` を読む
- **THEN** `plugin.json` のバージョンを上げる・bump する指示が無く、`plugins/<name>/changes/` に変更を記録する指示がある

#### Scenario: キャッシュの挙動の記述が実挙動と合う

- **WHEN** `docs/worktree-recovery.md` の冒頭の cache の説明とマージ後の反映の節を読む
- **THEN** 「バージョンを上げなくても HEAD に追随する」という記述が無く、commit SHA が版になって更新が届くことが書かれている

#### Scenario: README の plugin.json の例に version が無い

- **WHEN** `README.md` の plugin.json の例を読む
- **THEN** `"version"` キーが含まれていない

### Requirement: 変更の記録は PR ごとの別ファイルに書く

プラグインの変更の記録は `plugins/<name>/changes/<番号>.md` に 1 PR 1 ファイルで書かなければならない（MUST）。`<番号>` は記録先が issue ならその issue 番号、Draft PR が記録先ならその PR 番号とする（GitHub では issue と PR が同じ番号空間を共有するので、別の PR と同じ名前にならない）。1 つの PR が複数のプラグインを変えたときは、プラグインごとに同じ番号のファイルを置く。ファイル名は `^[0-9]+\.md$` に一致し、1 行目は `# ` で始まる見出しでなければならない（MUST）。記録を書く対象は、これまで `CHANGELOG.md` を持っていたプラグイン（dev-workflow・product-handover）と、利用者に移行作業を求める変更をしたプラグインとする。`changes/<issue 番号>.md` が main に既にあるとき（同じ issue に 2 本目の PR を出したとき）は、issue 番号ではなくその PR の番号を使わなければならない（MUST。既存の記録を書き換えず、別ファイルにする）。

守備範囲: 形の検査が見る入力の出どころは、全 `plugins/*/changes/` 配下のファイルである。拾う誤りは、ファイル名が `^[0-9]+\.md$` に一致しないことと、1 行目が `# ` で始まらないことの 2 つだけである。通すことを許す入力は、記録を書かなかった PR（書き忘れは規約だけで扱い CI で落とさない）、ファイル名の番号が実在する issue / PR を指しているか、本文の中身が妥当かで、これらは検査しない。形の検査以外の経路（たとえば記録を `changes/` 以外に書く、同じ番号のファイルを上書きする）の穴は別途判断し、ここで塞ぎ切ることをこの要件の完了条件にしない。

#### Scenario: 変更記録のファイル名と見出しの形

- **WHEN** 全 `plugins/*/changes/` 配下のファイルを列挙する
- **THEN** 全ファイル名が `^[0-9]+\.md$` に一致し、各ファイルの 1 行目が `# ` で始まる

#### Scenario: この移行自体の記録がある

- **WHEN** `plugins/dev-workflow/changes/447.md` と `plugins/product-handover/changes/447.md` を読む
- **THEN** 両方が存在し、版番号の撤去と変更記録の方式の移行が書かれている

### Requirement: 過去の CHANGELOG.md は凍結する

既存の `plugins/dev-workflow/CHANGELOG.md` と `plugins/product-handover/CHANGELOG.md` は過去分として残し、タイトル行の直後に `changes/` の方式へ移行した旨を 1 行書かなければならない（MUST）。以後これらに項目を足してはならない（MUST NOT）。追記の有無は `origin/main` を要さず常に走る決定論的なテストで検査しなければならない（MUST）: 移行の 1 行の後に現れる最初の `## ` 見出しが、移行時点の最新の項目の見出しと一致すること。新しい項目が他のプラグインに `CHANGELOG.md` として作られてもならない（MUST NOT）。

守備範囲: 凍結の検査が見る入力の出どころは、凍結した 2 つのファイル（`plugins/dev-workflow/CHANGELOG.md`・`plugins/product-handover/CHANGELOG.md`）と `plugins/*/CHANGELOG.md` の一覧である。拾う誤りは、移行の 1 行と移行時点の最新項目の見出しの間への新しい `## ` 見出しの挿入、移行の 1 行の欠落、3 つ目の `plugins/*/CHANGELOG.md` の新設の 3 つである。通すことを許す入力は、既存項目の本文の訂正、最新項目より下への項目の挿入、`## ` 以外の見出し（`### ` など）の追加で、これらは検査しない。この検査以外の経路（たとえば `plugins/` の外に変更履歴のファイルを作る）の穴は別途判断し、ここで塞ぎ切ることをこの要件の完了条件にしない。

#### Scenario: 凍結した CHANGELOG の先頭に新しい項目が足されたのを検出する

- **WHEN** `plugins/dev-workflow/CHANGELOG.md` の移行の 1 行と `## 2.13.39` の見出しの間に新しい `## ` 見出しが足される
- **THEN** テストは足された見出しを出力して fail する

#### Scenario: 移行の 1 行がある

- **WHEN** 凍結した 2 つの `CHANGELOG.md` のタイトル行の次の非空行を読む
- **THEN** `changes/` を含む移行の 1 行である

#### Scenario: 新しい CHANGELOG.md を作らない

- **WHEN** `plugins/*/CHANGELOG.md` を列挙する
- **THEN** dev-workflow と product-handover の 2 件だけである
