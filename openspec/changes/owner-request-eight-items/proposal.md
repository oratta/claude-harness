# Proposal

## Why

主に頼みごとをするときの書き方の正本（`output-styles/readable.md` の節 3）は、質問の中に「OK すると何が起きるか」を埋め込み、Yes か No で答える依頼を前提にしている。一つ上の目的・緊急度・答えを待って止まっている作業の欄が無く、どこで出しても同じ長さになる。2026-11-18 にオーナーと決めた 8 項目・4 つのまとまり・使う場所ごとの表（https://github.com/oratta/claude-harness/issues/1671 、出どころ https://github.com/genetta-inc/flatmate/issues/2156 ）を正本にしないと、依頼の画面の側と二重管理になる。

## What Changes

- **BREAKING** `output-styles/readable.md` の節 3 を、6 段の順（質問 → 主に聞く理由 → 困りごと → 推奨と根拠 → リスク → 答え方）から、8 項目を 4 つのまとまりで定義する形に書き直す。題名（依頼の形。質問にしない）・アクション（どこで何をするか。リンク付き）／目的・詳細・論点・推奨と根拠・リスク／緊急度・ブロック／アクションに付けるリンク
- 使う場所ごとに、使うまとまりと長さを表で決める（対話のセッション・チャットで 1 件ずつ出す依頼・チャットで何件かまとめて出す一覧・依頼を並べる画面の行と詳細）。書けない項目は「—」、短い場所には全部の項目が読める場所へのリンクを付ける
- **BREAKING** 1 行目の書き分けを「求める発言は 1 行目を質問、最後の行を答え方」から「求める発言は 1 行目を題名、2 行目をアクション」に変える。`主がすること: なし` と主の質問への答えの扱いは残す
- 主に聞く理由の 3 つと論点の定義は残し、聞くかどうかの判定として 8 項目の前に置き、判定の結果を論点の項目に書く。論点なしの依頼は 4 行（題名・アクション・論点・推奨と根拠）に収める
- 質問に「OK すると何が起きるか」を埋め込む書き方と「いま困っていること」の段を無くす（目的とブロックが受け持つ）
- 例 3 つを新しい形に書き直す
- `rules/communication-style.md` の 3 番目を、正本と食い違わない要点に書き直す
- 参照先のうち旧い順を写している `plugins/dev-workflow/skills/pr-review-gate/declarations.md`（主への依頼文の 3〜4 行の説明）と `stages/pass.md`（「型の『答え方』に入れる」）を新しい項目名に合わせる
- `tests/owner-question-style.bats` を新しい決まりに合わせる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `owner-question-style`: 正本の節の中身（8 項目・まとまり・使う場所の表）、1 行目の書き分け、短い版の要点、論点の書き場所、1 行目と作文の決まり、論点なしの依頼の行数

## Impact

- `output-styles/readable.md`・`rules/communication-style.md`（常時注入の固定分。`tests/injection-budget.txt` の予算は動かさず、今の合計 42298 バイト以下に収める）
- `plugins/dev-workflow/skills/pr-review-gate/declarations.md`・`plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`
- `tests/owner-question-style.bats`
- 後続の change: 親と channel の発言の 1 行目（`owner-message-title-first-line`、dev-workflow-develop）と、番号検査の hook の見分け方（`owner-number-check-title-form`）。同じ PR に順に積む
- 開いている Draft PR https://github.com/oratta/claude-harness/pull/1655 が節 3 の主に聞く理由と同じ spec を書き換えている。先にマージされた側に合わせて書き直す
