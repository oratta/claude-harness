## 1. commands/wt-clean.md 更新

- [x] 1.1 コマンド冒頭に `--keep` オプションの受付仕様を追記（デフォルト=削除、`--keep` 指定で再利用モード）
- [x] 1.2 Step 3 のレポート表示でモード（削除/再利用）を明示する
- [x] 1.3 Step 7 を「削除モード」と「再利用モード」で分岐する記述に変更
- [x] 1.4 再利用モードの処理ブロックを追加（main競合チェック → `git checkout main` → `git branch -d`）
- [x] 1.5 Step 6 FAIL 時は `--keep` でも保留する旨を明記
- [x] 1.6 Step 8 完了レポートに再利用可能化セクション（パス・次作業コマンド・依存再インストール注意）を追加
- [x] 1.7 🟡/🔴 は `--keep` 指定時も従来動作である旨を明記

## 2. skills/wt-clean/SKILL.md 更新

- [x] 2.1 commands/wt-clean.md と同一の変更を反映（内容同期）
- [x] 2.2 frontmatter の description に「`--keep` で再利用可能化」を追記検討
- [x] 2.3 version を 1.0.0 → 1.1.0 に bump

## 3. プラグインメタデータ更新

- [x] 3.1 plugins/worktree/.claude-plugin/plugin.json のバージョンを bump（キャッシュ無効化）

## 4. ドキュメント整合性

- [x] 4.1 commands版とskills版の差分が意図通りか diff で確認
- [x] 4.2 完了レポートの例文が現実的な値になっているか確認

## 5. 動作確認（仕様記述レビュー + 実機確認のガイド）

※ 本Changeはドキュメント変更のため、各項目はSKILL.md / wt-clean.md で該当仕様が記述されていることを確認する。実機動作は次回 `wt-clean` 実行時にユーザーが確認する。

- [x] 5.1 既存挙動: `wt-clean` オプションなしで従来通り全削除されることを確認（Step 7a に従来処理が保持されている）
- [x] 5.2 `--keep` で 🟢 Safe のみ再利用可能化、🟡 は従来削除、🔴 はスキップを確認（Step 7 分岐説明 + Step 7b 冒頭記述）
- [x] 5.3 再利用化後のworktreeで `git status` が main 上のクリーン状態になっていることを確認（Step 7b の `git checkout $MAIN_BRANCH` で保証。実機検証はユーザー）
- [x] 5.4 元ブランチが `git branch` 出力から消えていることを確認（Step 7b の `git branch -d` で保証。実機検証はユーザー）
- [x] 5.5 `node_modules` / `.env` / untracked ファイルが保持されていることを確認（Step 7b の「実行してはならない操作」で reset/clean を明示禁止）
- [x] 5.6 main 重複チェックアウト競合時に警告が出て該当worktreeが除外されることを確認（Step 7b の OTHER_CHECKOUT 検査ロジック）
- [x] 5.7 🟢 Safe が 0 件のときも `--keep` でエラーにならず正常終了することを確認（Step 7b 末尾の「🟢 Safe が 0 件の場合」記述）
- [x] 5.8 Step 6 サニティチェック FAIL 時、`--keep` でも該当worktreeが保留されることを確認（Step 6c 注記に「削除も再利用化も保留」明記）

## 6. コミット & 反映

- [ ] 6.1 変更を commit（Conventional Commits 準拠）
- [ ] 6.2 push 後、プラグイン再インストール or `/reload-plugins` で反映確認
