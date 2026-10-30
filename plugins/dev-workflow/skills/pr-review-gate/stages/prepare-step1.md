# 手順 1. 前提を揃える — pr-review-gate

以下 `$R` = `<owner>/<repo>`、`$N` = PR 番号。ゲートの開始・`agent-review:failed` からの再レビュー・保留からの再開で読む。戻した指摘が順 3 だけの修正のあとは、照合と振り分けの G も読む。

## 前提と理由（この段で使うもの）

- **stale passed**: 開始時に残っている `agent-review:passed` は前回 HEAD の遺物（passed 後に積まれたコミットは未レビュー）。auto-merge workflow は「対象 HEAD: <現 HEAD>」コメントの照合で stale passed を機械的に無効化する（未レビュー HEAD はマージされない）が、**手順として開始時に外すことは変わらず必要** — passed が残っている間は人間からもボードからも「合格済み」に見え、再レビューで欠陥・保留に転んだ事実が隠れるため。

1. PR に `agent-review:pending` が付いていることを確認（無ければ付ける）。**`agent-review:failed` からの再レビューもここが起点** — 修正を push したら `failed` を外して `pending` に戻し（`gh api -X DELETE repos/$R/issues/$N/labels/agent-review:failed` → `-X POST ... -f 'labels[]=agent-review:pending'`）、手順1から全工程をやり直す（前回の合格部分を流用しない。ただし再レビューの範囲は収束ルール（`stages/convergence.md`）に従い**差分限定**。方式の書き換えの後は全体レビューにし、周回は数え続ける）。
   このとき **`needs-approval` の要否も判断する** — 保留理由が解消しているなら
   `gh api -X DELETE repos/$R/issues/$N/labels/needs-approval` で外し、
   まだ主の許容待ちが残っているなら**付けたまま**にして手順6を続行する。黙って持ち越さない。
2. **stale な `agent-review:passed` を必ず外す**（理由はこのファイルの「前提と理由」の stale passed）。外してからレビューを始める（合格なら手順5で付け直す）。
   passed を外したら、PR が Draft でなければ `gh pr ready --undo` で Draft に戻す（手順5の合格処理で Ready にした PR に commit が積まれた取り直しのあいだ、周回ごとに CI を走らせないため。次の合格で Ready に戻る）。
   passed が付いていなかったとき（初回のゲート・failed からの再レビュー・保留からの再開）は Draft に戻さない（人間が非 Draft で作った PR を、failed や保留のまま Draft に残さないため）:
   ```bash
   if gh api repos/$R/issues/$N --jq '.labels[].name' | grep -qx 'agent-review:passed'; then   # passed が付いていたら
     gh api -X DELETE repos/$R/issues/$N/labels/agent-review:passed                           # 外して
     if [ "$(gh api repos/$R/pulls/$N --jq .draft)" = false ]; then gh pr ready --undo $N --repo $R; fi   # 非 Draft なら Draft に戻す
   fi
   ```
3. 記録先の**受け入れ条件**を取得する。判定の唯一の根拠はこれ。記録先は PR 本文で最初に現れる `Closes #N` / `Fixes #N` / `Refs #N`（大文字小文字不問）が指す issue で、**issue 参照が無い PR（Draft PR を記録先にした依頼）では PR 本文そのもの**が受け入れ条件になる（develop スキルの W は受け入れ条件を PR 本文に書く）:
   ```bash
   ISSUE=$(gh api repos/$R/pulls/$N --jq '.body' | grep -oiE '(closes|fixes|refs) #[0-9]+' | head -1 | grep -oE '[0-9]+')
   if [ -n "$ISSUE" ]; then gh api repos/$R/issues/$ISSUE --jq '.body'; else gh api repos/$R/pulls/$N --jq '.body'; fi
   ```
4. `git fetch origin` → `origin/main` をブランチへマージ（rebase + force-push は禁止）。コンフリクトが実装判断を要する規模なら `agent-review:failed` にして終了。
5. **対象 HEAD を固定する**（main 追従の push を済ませた**後**に取る。マージすると HEAD が動くため）:
   ```bash
   HEAD_SHA=$(gh api repos/$R/pulls/$N --jq '.head.sha')
   ```
