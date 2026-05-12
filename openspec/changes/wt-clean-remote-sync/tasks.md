## 1. commands/wt-clean.md 更新

- [x] 1.1 「オプション」セクションに `--no-sync` の説明を追加（デフォルト=同期 ON、`--no-sync` で同期スキップ）
- [x] 1.2 「実行フロー」の先頭に Step 0「Remote 同期」を新設
  - `git remote get-url origin` で origin の存在確認
  - `git fetch origin`
  - `<main>` 検出（既存ロジック流用）
  - `git rev-list --left-right --count <main>...origin/<main>` で進行差を測定
  - 進んでいれば `git pull --ff-only origin <main>`、それ以外は up-to-date とログ
  - 失敗時はエラー中断、後続 Step に進まない
- [x] 1.3 既存の Step 番号を 1→2、2→3 … と繰り上げる（または「Step 0 を実行後、Step 1 へ進む」と1行追記する形でも可。実装時に判断）
- [x] 1.4 Step 7b の「実行してはならない操作」の `git pull` / `git fetch` を「Step 7b 内（worktree 内）で実行してはならない」と限定する文言に修正
- [x] 1.5 Step 8 完了レポートの先頭に「Remote 同期: ✅ pulled N commits / -- already up-to-date / -- skipped (--no-sync) / -- skipped (no origin remote)」のいずれかを 1 行表示する記述を追加

## 2. skills/wt-clean/SKILL.md 更新

- [x] 2.1 commands/wt-clean.md と同一の変更を反映（内容同期）
- [x] 2.2 frontmatter `version` を 1.1.0 → 1.2.0 に bump
- [x] 2.3 frontmatter `description` に「PR マージ後の片付けにも対応（remote 同期込み）」のニュアンスを追記
- [x] 2.4 トリガーフレーズ追加検討: 「PR マージ後の整理」「プルリク後の片付け」を description に含める

## 3. プラグインメタデータ更新

- [x] 3.1 `plugins/worktree/.claude-plugin/plugin.json` のバージョンを 1.4.0 系から bump（キャッシュ無効化）
- [x] 3.2 `.claude-plugin/marketplace.json` の worktree プラグインバージョンを同期

## 4. backlog 更新

- [x] 4.1 `openspec/backlog.md` に「`longrun-pr-merge-sync` skill 候補 — キャンセル」セクションを追記（wt-clean-remote-sync で統合済みのため作成しない旨と日付）

## 5. ドキュメント整合性

- [x] 5.1 commands 版と skills 版の差分が意図通りか diff で確認
- [x] 5.2 Step 7b の禁則記述が Step 0 と矛盾しないか確認
- [x] 5.3 完了レポートの例文が現実的な値になっているか確認

## 6. 動作確認（仕様記述レビュー + 実機確認のガイド）

※ 本 Change はドキュメント変更のため、各項目は SKILL.md / wt-clean.md で該当仕様が記述されていることを確認する。実機動作は次回 `wt-clean` 実行時にユーザーが確認する。

- [x] 6.1 デフォルト挙動: `wt-clean` で Step 0 が走り、ローカル `<main>` が origin/`<main>` に追従することを確認（Step 0 記述）
- [x] 6.2 `--no-sync` 指定時に Step 0 がスキップされることを確認（Step 0 冒頭の分岐記述）
- [x] 6.3 `--keep` 単独指定時もデフォルトで同期されることを確認（Step 0 → Step 1 → … → Step 7b の流れ）
- [x] 6.4 `--keep --no-sync` 併用が許可されることを確認（オプションセクション + Step 0 の opt-out 記述）
- [x] 6.5 `git pull --ff-only` 失敗時に wt-clean が中断し、後続 Step が走らないことを確認（Step 0 のエラー処理記述）
- [x] 6.6 `origin` remote が存在しないケースで Step 0 がスキップされエラーにならないことを確認（Step 0 冒頭の `git remote get-url origin` 分岐）
- [x] 6.7 完了レポート先頭に Remote 同期結果が 1 行表示されることを確認（Step 8 記述）
- [x] 6.8 PR マージ済み feature ブランチが、Step 0 同期後の Step 1 診断で 🟢 Safe に分類されることを確認（既存の `git branch --merged <main>` ロジック流用）

## 7. コミット & 反映

- [ ] 7.1 変更を commit（Conventional Commits 準拠）
- [ ] 7.2 push 後、プラグイン再インストール or `/reload-plugins` で反映確認（ユーザー実施）
