## Why

`tests/injection-budget.bats` の常時注入の集計は、rules の frontmatter の `paths:` を YAML として読まず、行末コメント付きの glob（`- "**" # scope/rules`）をコメントごと glob として扱い、`paths: null` のようなリストでない値でも「path スコープあり」として常時注入の合計から外していた。さらに `paths:` による除外が output-styles にも掛かっていた。output-styles に `paths:` フィールドは無く、選択中の本文は毎回載るので、該当ファイルができると実態より過小計上する（issue #293。PR #292 の Codex レビューの non-blocking 指摘）。今は `paths:` を持つファイルが 0 本で実害は無いが、path スコープを採用した時点で集計が偽る。

## What Changes

- `frontmatter_paths_globs` が行末の YAML コメントを落として glob を読み、`paths: null` などリストでない値からは glob を 1 件も出さない（＝ glob 0 件の違反）
- 常時注入からの除外は、非空の glob リストとして読める `paths:` を持つファイルだけに限る（`has_valid_paths`）
- `paths:` による除外は rules だけに掛け、output-styles は `list_synced_md` で全文を計上する。除外の注記も既定では rules だけを見る
- 上の 3 点の回帰テストを足す
- `openspec/specs/always-on-injection-scope` の要件「path スコープは配布形での両方向の実機確認を経てから採用する」に、集計が `paths:` で除外してよい条件と守備範囲、シナリオ 3 つを足す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `always-on-injection-scope`: 集計が `paths:` を理由に除外してよいのは rules の非空の glob リストだけ、output-styles は全文を計上する、という規定と守備範囲を足す

## Impact

- `tests/injection-budget.bats`（`frontmatter_paths_globs`・`has_valid_paths`（新規）・`list_always_on_md`・`list_path_scoped_md`・`path_scoped_notes`・`breakdown`、テスト 3 本）
- `plugins/dev-workflow/changes/293.md`（新規）
- 予算ファイル `tests/injection-budget.txt` は変えない（現状 `paths:` を持つファイルが 0 本なので合計は変わらない）
