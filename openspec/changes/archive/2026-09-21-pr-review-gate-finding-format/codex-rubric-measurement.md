# codex exec のレビュールーブリック実測（tasks 1.1・1.2）

判定: **適用される（優先度の見出しだけ）**。書式を指定しない指示で指摘が出ると、各指摘は `**[P1] <見出し>** — [file:line](...)` の形の Markdown 箇条書きで返った。JSON の `priority` / `confidence_score` / `code_location` の欄は出力に現れなかった。仕様の場合分け（出力にルーブリックの優先度または確信度が現れたら適用される）に従い、SKILL.md 手順 2-1 に対応表を置く。

## 実行環境

- 日時: 2026-09-21（JST）
- `codex-cli 0.153.4`（`/Users/oratta/.volta/bin/codex`、node は PATH の先頭に `/opt/homebrew/bin` を置いて起動）
- model: gpt-6-astra、reasoning effort: medium、approval: never、sandbox: workspace-write
- 起動・待ちは `plugins/dev-workflow/references/subagent-waiting.md` の (a) の雛形どおり（mktemp -d の専用ディレクトリ・nonce 付き完了マーカー・前景ポーリング）

実行コマンド（2 回とも同じ）:

```
{ codex exec -c approval_policy=never -c model_reasoning_effort=medium - < "<dir>/prompt.txt" ; printf '\n__CODEX_DONE_<nonce>__ rc=%s\n' "$?" ; } >> "<dir>/review.log" 2>&1
```

## 1 回目: 既存コミット 1 つの範囲

- 指示: `Review the changes introduced by commit e9371ab in this repository (run `git show e9371ab` to see the diff). Report any problems you find.`
- 終了コード: 0
- 出力の要点: 「No actionable defects found in commit `e9371ab`.」と関連 bats 105 件の通過報告だけ。指摘が 0 件なので、ルーブリックが適用されるかはこの回では判定できない
- `\[P[0-3]\]|priority|confidence_score` の出現: 0 件

## 2 回目: 指摘が出る一時的な 1 行変更

- diff: `plugins/dev-workflow/scripts/subagent-context.sh` の `over = ctx > cap` を `over = ctx < cap` にした未コミットの変更（実測後に手で元に戻し、コミットしていない）
- 指示: `Review the uncommitted changes in this repository (run `git diff` to see them). Report any problems you find.`
- 終了コード: 0
- 出力の要点（最終回答の全文）:
  - `**[P1] Reversed comparison breaks context-cap enforcement** — [subagent-context.sh:122](.../plugins/dev-workflow/scripts/subagent-context.sh:122). Changing `ctx > cap` to `ctx < cap` flags under-limit agents as over capacity and lets over-limit agents pass. ... Restore `ctx > cap`.`
  - `Validation: bats plugins/dev-workflow/tests/subagent-context.bats — 8 failed, 7 passed. No files changed.`
- `\[P[0-3]\]|priority|confidence_score` の出現: `[P1]` が 2 行（最終回答とその再掲）。`priority` と `confidence_score` の字面は 0 件

## 固定書式への影響

優先度（`[P0]`〜`[P3]`）・場所（`file:line` のリンク）・何が起きるか・直し方に当たる内容は出るが、固定書式の「検証」（`confirmed` / `plausible`）と「根拠」（受け入れ条件・spec の引用、または例外 3 種）に当たる欄は無い。このため書式ブロックは Codex への指示文にも貼ったままにし、Codex が優先度付きの形で返したときの読み替えを SKILL.md の対応表に置く。実測中に `bats` を回したことを示す一文はあったが、指摘ごとの検証済みかどうかの表明は無いので、`[P*]` の優先度も確信度も `confirmed` の代わりにしない。
