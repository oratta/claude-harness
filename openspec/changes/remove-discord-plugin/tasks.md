## 1. テストを先に書く（Red）

- [ ] 1.1 `tests/discord-plugin-retirement.bats` を作り、spec `discord-plugin-retirement` の各 Scenario を検査する: `plugins/discord` の不在（`git ls-files` 0 件）・marketplace の `plugins[]` と全 `bundles[].plugins[]` に discord が無い・`ci.yml` に `discord` / `setup-bun` が 0 件で issue #138 の SHA 固定方針コメントが残る・`openspec/specs/discord-reaction-delivery` の不在・3 文字列の掃除（許容場所 (a)〜(d) を除いて 0 件。許容はパスの列挙で書く）・README に discord の行が無く切り替え手順の 4 文字列がある。テスト名は ASCII のみ
- [ ] 1.2 `bats tests/discord-plugin-retirement.bats` が撤去前の状態で落ちることを確認する

## 2. 撤去（Green）

- [ ] 2.1 `git rm -r plugins/discord`
- [ ] 2.2 `.claude-plugin/marketplace.json` の `plugins[]` から `discord` のエントリだけを外す（他エントリの差分が出ないことを `git diff` で確認）
- [ ] 2.3 `.github/workflows/ci.yml` から bun 導入のステップとその説明コメントを消し、冒頭の SHA 固定方針コメントから `oven-sh/setup-bun` の例示を外す（方針の文と issue #138 は残す）
- [ ] 2.4 ルート `README.md` のプラグイン一覧から `discord` 行を消し、「解散済みプラグイン」節に移設の記録（genetta-inc/flatmate#851 へのリンク）と切り替え手順（`claude plugin uninstall discord@oratta-claude-harness`・`enabledPlugins` の `discord@flatmate` への置き換え・住人の `CHANNEL_PLUGINS` を `plugin:discord@flatmate` に）を書く
- [ ] 2.5 ここまでを commit する（spec の削除はまだ行わない）

## 3. 検証

- [ ] 3.1 `bats tests/discord-plugin-retirement.bats`（spec 不在の検査を除き pass）・`bats tests/marketplace-sync.bats`・`bats tests/injection-budget.bats` が pass する。注入量の実測が 38,749 バイト前後で予算 40,260 を動かさずに通ることを確認する
- [ ] 3.2 issue #314 の受け入れ条件のコマンドを実行する: `git ls-files plugins/discord | wc -l` が 0、`jq -e '[.plugins[].name] | index("discord") == null' .claude-plugin/marketplace.json` が exit 0、`grep -n -i discord .github/workflows/ci.yml` が 0 件
- [ ] 3.3 `scripts/test.sh` をフォアグラウンドで全件実行し exit 0 を確認する

## 4. main spec の直接削除と archive

- [ ] 4.1 archive の直前に `git rm -r openspec/specs/discord-reaction-delivery` を行い、移設先 genetta-inc/flatmate#861 を commit メッセージに書いて commit する（全要件 REMOVED の delta は archive が `Spec must have at least one requirement` で中断するため、delta では表現しない）
- [ ] 4.2 `bats tests/discord-plugin-retirement.bats` と `bats tests/openspec-specs-format.bats` が全件 pass する
- [ ] 4.3 `openspec archive remove-discord-plugin -y` で archive し、`openspec/specs/discord-plugin-retirement/spec.md` ができることを確認する。archive 後に `scripts/test.sh` を再実行して exit 0 を確認する
