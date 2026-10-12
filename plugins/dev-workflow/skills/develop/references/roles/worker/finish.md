# W（作業者）の指示書 — 仕上げ（`段: finish`）

(3b) で読む。全段で要る規則は `worker/common.md`。

## (3b) archive＋PR＋仕様宣言

(3a) の return を本体が受け取り、コンテキスト量を測ってから再開（または手渡し）されて入る節。実装内容には手を入れず、事務手続きだけを行う。

1. `openspec archive <change-name> --yes`（仕様化した場合。完了した change をアーカイブし、archive 済みの状態を PR に含める）。`--yes` は未完了タスクの確認も飛ばすので、実行の前に `tasks.md` に `- [ ]` が残っていれば archive せず、残りの項目を本体に返す。実行の後に `openspec/changes/archive/` へ移り、元の `openspec/changes/<change-name>/` が無いことを確かめ、移っていなければ出力を添えて本体に返す
2. 本体から V の `画面確認結果: 合格` が渡されたら開いた URL・見た要素・観測値を動作確認証拠の入力にする。`画面確認結果: 実行不能` なら理由を引き継ぎ、画面確認の証拠は書かない。
3. PR を **Draft のまま**用意する: 記録先が Draft PR ならそのまま使う。issue が記録先なら `gh pr create --draft` で作成する（本文に `Closes #<issue>`。unmanned では `plugins/dev-workflow/references/pr-body-format.md` の型に従い `agent-review:pending` を付ける — 憲法 Step 3 の 5〜6 に相当）。W は Draft を外さない（Ready 化は G が pr-review-gate 手順 5 で `agent-review:passed` の直前に行う。CI を Draft で止めるリポで、レビューと修正の周回ごとに CI を走らせないため）
4. **仕様宣言**を PR コメントに書く（書式・`対象 HEAD:` 規約の正本は `skills/pr-review-gate/declarations.md`（pr-review-gate 手順 3・3-b）。(3b) ではこのファイルだけを読む。`仕様: 更新した`＋archive 済み・`仕様レビュー: APPROVE`、または `仕様: 変更なし`＋理由）
5. return（1 行目は `工程完了: archive＋PR＋仕様宣言`）: **PR #N（HEAD SHA）と仕様宣言のコメント URL**、(3a) から引き継いだテストコマンドと exit code、埋めた決定の列挙、昇格トリップワイヤーの発火有無
