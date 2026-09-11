# tasks — memory-index-refresh

## 1. 初回整理（手作業。PR より先）

- [x] 1.1 claude-harness プロジェクトのメモリの控えを取る（`memory.bak-2026-09-11`）
- [x] 1.2 #295 の分類一覧（削除 14・短縮 4・維持 9）を主の承認のうえ手で適用し、索引を書き直す
- [x] 1.3 適用前後の数字を #294 にコメントし、閾値の初期値を確定する（本文 1 件は 2,500）

## 2. 検知（#294）

- [x] 2.1 `plugins/dev-workflow/tests/memory-tripwire.bats` に、閾値以内で無出力・条件ごとに 1 行・同時超過で 1 行・fail-open・環境変数の上書き・worktree の解決・`session-tripwires.sh` への注入のテストを書く
- [x] 2.2 `plugins/dev-workflow/scripts/memory-tripwire.sh` を実装し、`session-tripwires.sh` から呼んで出力を additionalContext の先頭に足す
- [x] 2.3 実メモリ（整理後で無出力・整理前の控えで 1 行）と所要時間（1 回 100ms 未満）を確かめる

## 3. 修復（#295）

- [x] 3.1 `plugins/dev-workflow/skills/memory-refresh/SKILL.md` と `commands/memory-refresh.md` を書き、初回整理の一覧を例として載せる
- [x] 3.2 `plugins/dev-workflow/tests/memory-refresh-skill.bats` で登録と手順の要素を固定する
- [x] 3.3 description 追加後も `tests/injection-budget.bats` の予算内に収まることを確かめる

## 4. 仕上げ

- [x] 4.1 `plugin.json` を 2.11.0 に上げてスキルとコマンドを登録し、`marketplace.json` と `CHANGELOG.md` を揃える
- [x] 4.2 リポジトリ全体のテスト（`bash scripts/test.sh`）を実行し、`not ok` を確認する（main でも落ちる statusline の 2 本以外は通る）
- [ ] 4.3 仕様レビューの APPROVE を得て `openspec archive` まで済ませる
