# G を起こす本体の手順 — develop

本体が G を起こすときに読む。G は読まない。G の動作・return は `gate-runner.md` が正本。

## 段ごとの起動と入力

本体は**段ごとに新しい G を起こす**。起動指示には `段: <段の名前>` の 1 行と `レビュー経路:` の 1 行を書き、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼り、下の表の「本体が渡すもの」を足す。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（`n` はその PR・その段で起こした回数）、description は `G: <段> for PR #N (#issue)` の形にし、先頭の `G:` を残す（`scripts/subagent-context-audit.sh --by-role` がこの接頭辞で G と判定する）。

| 段 | 本体が起こす時点 | 本体が渡すもの | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | W の修正内容の要約（再レビューのとき） | `needs-reviewer` / 保留 |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定を受け取ったとき、直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | レビュアーの要約・補足レビューの結果・決める役の裁定・直し方の判定と判定の記録の URL・W の修正内容の要約のうち、その時点のもの | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | 前の段の Gate Result ブロック（引き継ぎの判定のあとは加えて引き継ぎの判定と判定の記録の URL） | passed / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | 主の回答 | `次の段へ` / failed / needs-decider / 保留 |

G が `工程中断:` で返したら、本体は同じ段の新しい G を起こし、前任の return 全文と、前任の起動指示に書いた入力を渡す。起こしてよい条件は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」が正本で、ここには書かない。

**条件の答えを受け取ったとき（本体の作業。G を起こさない）**: 照合と振り分けの G が 1 行目 `条件の確認待ち` の PR コメントを残した指摘（止めない指摘の振り分け表の段 B で、G が条件を決められなかったもの。return の仕分け欄に質問文がある）について、主が条件を答えたら、答えを受け取ったセッション（develop では本体）が次を行う: 答えを 1 行にして、エピックの本文（エピックに属さない PR では記録先の本文）の節 `## 条件の答え` に足す（節が無ければ作る）、`条件の確認待ち` のコメントに答えを返信する、確認待ちの指摘を `stages/triage.md` の段 B の表から当て直す（段 A には戻さない。当て直しはサブエージェントに任せてよい）。PR がマージ済みでも行う。ラベル・周・宣言には触れず、Gate Result も作らない。足した行は、以後のレビュアーの依頼文に入れる（`stages/reviewer-brief.md` の入口）。

## モデル（本体が spawn 時に決める）

G の既定は `sonnet` で、上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認（照合作業）で、欠陥探索は Codex か `needs-reviewer` で本体が spawn するレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れる PR なら `subagent_type: dev-workflow:decider`）が担う。モデルの優先順位は全役割共通: ①共有枠モード `SHARED_BUDGET_MODE`（`depleted` → 全役割 `sonnet` 固定・昇格なし。`throttled` → 既定 `sonnet`・昇格上限 `opus`・`abundant` 無効）②その範囲内で事前分類（マージ権限・層間契約・課金/法務）による `dev-workflow:decider`（聖域パスは `opus` 止まり） ③Fable 残量モード（`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限。このとき種別は `dev-workflow:decider` のまま `model: opus` に落とす）。正本は `skills/develop/references/decision-criteria.md`。 レビュアーは `throttled` では `opus` 止まり、`depleted` では `sonnet`。事前分類表の正本は `references/pre-classification.md`。


## 強制停止した G の後片付け

G が `Bash` の全件拒否で止まったら、本体がレビュー結果を記録先に代理投稿する。commit も本体が行う。作業ツリーの未コミット差分は本体が `git -C <path> status --porcelain` で確認して commit する。上限超・一時待ち・手渡しの条件は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本。
