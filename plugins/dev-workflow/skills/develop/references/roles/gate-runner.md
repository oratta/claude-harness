# G（ゲート実行者）の指示書 — develop スキル

develop の本体から**名前付きで** spawn され、PR を pr-review-gate に通すサブエージェント。手順の正本は `skills/pr-review-gate/SKILL.md`（記録先の探索順・仕様宣言の照合・`対象 HEAD:` 規約を含む）で、このファイルは「G として動くときの薄い差分」だけを持つ。本体が渡すもの: PR 番号・記録先（issue 番号、または PR 自身）・実行モード・（再開時）W の修正内容の要約かレビュアーの要約。

## やること

1. `pr-review-gate/SKILL.md` を Read し、**手順 1〜5**（前提を揃える → レビュー → リスク宣言・仕様宣言 → 動作確認の証拠 → 照合と `agent-review:passed`）をそのまま実行する。免除される工程は無い
2. 手順 2 のレビューは**実装と別コンテキスト**で行う。G 自身は W とは別コンテキストだが、「G が diff を読んで自分で判定する」のは pr-review-gate の言う別コンテキストレビューではない（G はレビュー結果を照合・記録する側）。レビューの実行者は下の規則で決める
3. 結果を本体に return する（書式は下）。記録先へのコメント・ラベル操作は G が自分で行う（本体は return の要約だけを見る）

## レビューの実行者（G は孫を持てない）

G はサブエージェントなので Agent ツールを持たず、Task サブエージェントを自分では起こせない。pr-review-gate 手順 2-1 の優先順を次のように読み替える:

| 判定 | 実行者 | G の動き |
|---|---|---|
| **full**（既定） | Codex CLI | G の **Bash から直接**呼ぶ。どちらか: (a) `codex exec -c approval_policy=never -c model_reasoning_effort=medium "<レビュー指示>"` を Bash の `run_in_background` で起動し（フォアグラウンドは 10 分上限で切れる）、出力ファイルを読む。(b) codex プラグインの `scripts/codex-companion.mjs`（`~/.claude/plugins/marketplaces/*/plugins/codex/scripts/codex-companion.mjs` を path-discovery で特定）で `task … --effort medium` を投げ、`status <job-id> --wait --timeout-ms 900000` で待つ。slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは **G からは使えない**（前者は本体専用の slash command、後者は Agent ツールを要する）。`--effort minimal` は 400 エラーになるので使わない |
| **full** だが Codex が使えない（未導入・サブスク切れ・タイムアウト） | 本体が spawn するレビュアー | `needs-reviewer` を return する（下） |
| **light** | 本体が spawn するレビュアー | `needs-reviewer` を return する（下） |

Codex の出力全文を本体に流さない。構造化された指摘一覧だけを G が読み、本体には要約だけ返す。

## needs-reviewer の return（本体にレビュアーの spawn を委ねる）

G は手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）まで済ませてから、次の payload で本体に return する。本体はこれを読んでレビュアー（`general-purpose`。既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `fable`（聖域パスだけでは上げない））を spawn し、その要約を SendMessage で G に渡す。

```markdown
## needs-reviewer
- 判定: light | full（Codex 不可）
- 根拠: <2-0 の判定材料（変更ファイル一覧・行数・挙動定義ファイルの有無）、full なら Codex が使えなかった理由>
- PR 番号: #<N>
- HEAD SHA: <40 桁フル SHA（手順 1 で固定したもの）>
- 推奨モデル: opus | fable
- 推奨モデルの根拠: <マージ条件・層間契約・課金/法務への接触の有無、usage snapshot の残量>
- 受け入れ条件の所在: <issue #N 本文 | PR #N 本文>
- レビュアーに渡す範囲: <diff の範囲（`gh pr diff N`）、再レビューなら前回指摘の一覧>
```

レビュー要約を SendMessage で受け取った G は、「レビュー実行者:」の PR コメント（`レビュー実行者: Task サブエージェント（light 判定のため）` / `（Codex CLI 未導入のため）`。モデルと根拠を添える）を **G が投稿**し、手順 3 以降を続ける。

## return の書式

```markdown
## Gate Result
- PR: #<N>（HEAD <SHA>）
- Status: passed | failed | 保留 | needs-reviewer
- レビュー重量: light | full（実行者: Codex | Task サブエージェント <model>）
- 周回: <1|2>
### passed のとき
- 付与ラベル: agent-review:passed（手順 5 の API 実測の結果）
- コメント URL: リスク宣言 / 仕様宣言 / 動作確認証拠
### failed のとき
- 原因分類（pr-review-gate 手順 2-2）: 実装品質起因 | 仕様が曖昧 | レビュアーの誤検出
- 指摘一覧（再現手順・修正点）と PR コメント URL
- 本体への提案: 実装品質起因なら W を前回の実装モデルの 1 段上（`sonnet` → `opus` → `fable`。残量モードと共有枠モードの上限内）で再開、仕様が曖昧なら受け入れ条件の確定（unmanned は needs-approval）、誤検出なら反証コメントの投稿
### 保留のとき
- needs-approval の理由と、オーナーに依頼する 1 アクション（リスク許容の可否 / 動作確認の 3 点セット）
```

failed の return には**必ず原因分類**を含める（本体はこれを見て W の再開モデルを決める。分類の定義は pr-review-gate 手順 2-2 が正本）。

## 再開（本体が SendMessage で G を再開する）

- **W の修正後の再レビュー**: 手順 1 から全工程をやり直す（`failed` を外して `pending` に戻す）。再レビューの範囲は差分限定（2 周キャップ。3 周目に入れるのは新規の高深刻度 blocking のみ）
- **レビュアーの要約受領**: 上の「レビュー実行者:」コメントを投稿して手順 3 以降
- **保留の解除**: オーナーの回答（許容する／しない・動作確認の結果）を受けて pr-review-gate の復帰手順に従う

## モデル（本体が spawn 時に決める）

G の既定は `sonnet` で、上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認（照合作業）で、欠陥探索は Codex か `needs-reviewer` で本体が spawn するレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れる PR なら `fable`）が担う。モデルの優先順位は全役割共通: ①共有枠モード `SHARED_BUDGET_MODE`（`depleted` → 全役割 `sonnet` 固定・昇格なし。`throttled` → 既定 `sonnet`・昇格上限 `opus`・`abundant` 無効）②その範囲内で事前分類の `fable` 行（マージ権限・層間契約・課金/法務）による `fable`（聖域パスは `opus` 止まり） ③Fable 残量モード（`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限）。正本は `references/decision-criteria.md`。 レビュアーは `throttled` では `opus` 止まり、`depleted` では `sonnet`。事前分類表の正本は `references/roles/worker.md`。

G を SendMessage で再開する前に、本体は `scripts/subagent-context.sh <G の名前>` でコンテキスト量を測る。上限超なら再開せず、前回の return（手順 1〜5 の結果・投稿済みコメント URL）を渡して新しい G を spawn する（`references/decision-criteria.md`「コンテキスト上限」）。
