## Context

`owner-reply-check.sh` の `owner_text()` は、会話ログ（`~/.claude/projects/*/<セッション ID>.jsonl`）の各行を 7 条件で絞り、主の発言の本文だけを返す。PR #748 の 2 周目レビューで、会話の圧縮後にモデルが書いた要約の行がこの 7 条件を通りうると分かった。直近 14 日の実ログで `isCompactSummary: true` の行を見ると、いずれも `type: "user"`・`isMeta` なし・`origin` なし・`isVisibleInTranscriptOnly: true` だった。本文は要約 3 件のうち 2 件が `This session is being continued from a previous conversation` で始まり、1 件が `<artifact-content-authored-by-others/>` で始まる。

現状の緩和として、ゲート実行者は同じ timestamp の `MATCH:` の全文を読むので要約文は区別できる。ただし要約は過去の発言の言い換えで「許容する」という語が入りうるため、スクリプトの段で落としておく。

## Goals / Non-Goals

**Goals:**
- `isCompactSummary` が true の行を主の発言として数えない
- 回帰テストで、本文の書き出しに関係なく要約の行が落ちることを固定する

**Non-Goals:**
- 会話ログの未知の差し込みの形を網羅すること（spec の守備範囲④のまま）
- 呼び出し側（pr-review-gate の手順 5・3-c）の手順や出力形式を変えること

## Decisions

**判定は `isCompactSummary` の属性で行い、本文の接頭辞を見ない。**
- 採らなかった案 1: 本文が `This session is being continued` で始まる行を除く（既存の条件⑥⑦と同じ接頭辞方式）。実ログで別の書き出しの要約が 1 件あり、接頭辞では漏れる。また主が同じ文を貼り付けた発言まで落とす
- 採らなかった案 2: `isVisibleInTranscriptOnly: true` の行を除く。今回見た範囲では要約の行にしか付いていないが、属性の意味（画面の記録にだけ出す）は要約に限らず、何が付くかを確かめていない。除く範囲を確かめた形に絞るため採らない
- 比べ方は既存の `isMeta` と同じく `is True`（値が true のときだけ除く）。`false` やキーなしは通す。`isMeta` の条件と並べて書く

## Risks / Trade-offs

- [Claude Code が要約の行の属性名を変えると、また通りうる] → spec の守備範囲③④のとおり、形式の変化は bats の入力を実物から取り直して追う。ゲート実行者の全文確認が残る
