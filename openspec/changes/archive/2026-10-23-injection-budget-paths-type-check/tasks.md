## 1. テスト

- [x] 1.1 行末コメント付きの glob がコメントを除いて検査されるテストを足す
- [x] 1.2 `paths: null` が glob 0 件の違反になり、常時注入の合計に残るテストを足す
- [x] 1.3 output-styles が `paths:` を持っていても全文を計上されるテストを足す

## 2. 実装

- [x] 2.1 `frontmatter_paths_globs` に行末コメントの除去とリストでない値の扱いを足す
- [x] 2.2 `has_valid_paths` を足し、`list_always_on_md` と `list_path_scoped_md` から使う
- [x] 2.3 `breakdown` の output-styles の行を `list_synced_md` に替え、`path_scoped_notes` の既定を rules だけにする

## 3. 仕様と記録

- [x] 3.1 `openspec/specs/always-on-injection-scope` の要件に除外の条件・守備範囲・シナリオを足す
- [x] 3.2 `plugins/dev-workflow/changes/293.md` に変更の記録を書く
