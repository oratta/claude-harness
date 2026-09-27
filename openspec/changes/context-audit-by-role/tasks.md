## 1. テスト（bats fixture）を先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/subagent-context-audit.bats` に `--by-role` 用の fixture（`agent-*.jsonl` + 隣の `agent-*.meta.json`）を追加する。`agentType: dev-workflow:decider` の件、`description` 先頭トークンが `W` / `R1` / `G` / `Reviewer` の件、どちらにも当たらない件（`unknown` 行き）を最低 1 件ずつ用意する
- [x] 1.2 「`--by-role` を付けない既定呼び出しは出力が変わらない」ケースを追加する（既存の合格しているテストと同じ fixture を使い、`by_role` キーが出力に含まれないことを確認する）
- [x] 1.3 「`agentType` が `description` の見た目より優先される」ケース（`agentType: dev-workflow:decider` かつ `description` が `R1:` で始まる fixture）を追加する
- [x] 1.4 「担当別の `count` の合計が全体の `count` と一致する」ケースを追加する（`unknown` を含む混在 fixture）
- [x] 1.5 `docs_median` 用のケース（個体 A に対象ホップ 2 つ、`usage` 差分がそれぞれ 3000 と 2000（指示書 `Read` のホップと `Skill` 呼び出しのホップを 1 つずつ）、個体 B に対象ホップ 0 の fixture を用意し、個体ごとに合計してから担当内で中央値を取る 2 段階集約により `docs_median` が 2500（個体 A の合計 5000 と個体 B の合計 0 の中央値）になることを確認する。指示書パスは `plugins/cache/oratta-claude-harness/.../*.md` への `Read` とする）
- [x] 1.6 `reread_pct` の基本ケース（同一 `#N`（例 `#552`）を持つ `W` を 2 体、`timestamp` 順に fixture 化し、先行が `fileA.md` と `fileB.md` を読み、後続が `fileA.md` だけ読み直す構成で `50.0` になることを確認する）を追加する。あわせて、先行・後続の `file_path` のディレクトリ部分が異なっていても末尾のファイル名（ベースネーム）が一致すれば読み直しとして数えるケース（worktree パスの違いを模した fixture）を追加する
- [x] 1.7 `reread_pct` の母数除外・グループ化ケース: 「グループ最初の `W` は母数から除かれる」「`description` に `#N` が無い `W` は対象から除かれる」「`description` に `#N` が複数出現する場合（例 `W: gate for PR #400 (#288)`）は最も左の `#400` がグループ化に使われる」の 3 ケースを追加する
- [x] 1.8 `python3` が無い環境で `--by-role` を実行した場合、既存の fail-open 応答（`count: 0` の固定文字列）のまま `by_role` キーが出ないケースと、`python3` はあるが対象トランスクリプトが 0 件の場合に `by_role` の 6 キー全部が `count: 0` / `first_median: null` / `docs_median: null` / `last_median: null` / `over_cap_pct: 0.0` で埋まるケースを追加する
- [x] 1.9 「既定・`--by-role` でキャッシュファイルが衝突しない」ケース（`--cache` を省略した状態で両方を実行し、既定パスと `.by-role` サフィックス付きパスが別ファイルになることを確認する）を追加する
- [x] 1.10 上記全ケースを実行し、実装前は失敗する（Red）ことを確認する

## 2. 実装（Green）

- [x] 2.1 `plugins/dev-workflow/scripts/subagent-context-audit.sh` に `--by-role` 引数を追加する
- [x] 2.2 担当分類ロジック（`agentType` 優先 → `description` 先頭コロン区切りトークン → `unknown`）を実装する
- [x] 2.3 `--by-role` 指定時のみトランスクリプト全文を前方から走査するパスを実装する（既定呼び出しの走査経路には触れない）
- [x] 2.4 `docs_median` の算出（指示書 `Read` / `Skill` の `tool_use` を含むホップの `usage` 差分を、個体ごとに合計してから担当内で中央値を取る 2 段階集約。複数 `tool_use` 混在時はホップ全体を docs 側に丸める近似）を実装する
- [x] 2.5 `reread_pct` の算出（`#N` によるグループ化、先行の `Read` `file_path` 和集合に対する後続の読み直し割合、グループ最初と `#N` 不明個体の母数除外）を実装する
- [x] 2.6 `by_role` キーの組み立て（担当ごとの `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct`、`W` のみ `reread_pct`）を実装する
- [x] 2.7 `--cache` 省略時、`--by-role` 指定時だけ既定パスに `.by-role` サフィックスを足すロジックを実装する（`--cache` 明示時はそのまま使う）
- [x] 2.8 `plugins/dev-workflow/tests/subagent-context-audit.bats` を実行し、1. の全ケースと既存ケースが通ることを確認する（Green）

## 3. ドキュメント

- [x] 3.1 `plugins/dev-workflow/docs/usage-audit.md` に `--by-role` の節を追記する（実行コマンド例・`by_role` 配下の出力キーの意味・分類規則・`reread_pct` の母数の注意）
- [x] 3.2 `subagent-context-audit.sh` 冒頭のコメント（使い方・出力例）に `--by-role` を追記する

## 4. 実機確認

- [ ] 4.1 実機の `~/.claude/projects` に対して `subagent-context-audit.sh --by-role --refresh` を実行し、exit 0 で `by_role` が出ることを確認する
- [ ] 4.2 `--by-role` を付けない同一実行が、この change の前後で出力が変わらないことを確認する（差分比較）

## 5. エピック #511 への基準値コメント

- [ ] 5.1 4.1 で得た実データの `by_role` 内訳（担当別 `first_median` / `last_median` / `over_cap_pct`）を、施策前の基準値として https://github.com/oratta/claude-harness/issues/511 にコメントする（この change のタスクであり恒久仕様ではない旨を明記する）

## 6. 変更の記録

- [ ] 6.1 `plugins/dev-workflow/changes/552.md` を作成する（`plugins/dev-workflow/changes/522.md` 等の既存形式に合わせ、変更の要点・理由・影響ファイルを書く）

## 7. 検証

- [ ] 7.1 `openspec validate context-audit-by-role --strict` を実行し、exit 0 を確認する
- [ ] 7.2 `./scripts/test.sh` を実行し、exit 0 を確認する（issue #552 受け入れ条件 4）
- [ ] 7.3 `./scripts/lint.sh` を実行し、exit 0 を確認する（issue #552 受け入れ条件 4）
- [ ] 7.4 本 tasks.md のチェックボックスが全部 `[x]` になっていることを確認する
