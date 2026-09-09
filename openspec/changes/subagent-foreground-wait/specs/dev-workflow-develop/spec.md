## MODIFIED Requirements

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。事前分類表の「1 周目」列は**実行役（W）の上限を `opus` とし、`fable` 行を持ってはならない**（MUST NOT。4 分類のいずれに当たっても W は `opus` 止まりで、聖域パスの `opus` は据え置き）。表には、読んで判断する役（R1・G が要求するレビュアー）が `fable` 相当の分類に当たるときは `subagent_type: dev-workflow:decider` で spawn し、`general-purpose` に `model: fable` を付けないことを明記しなければならない（MUST）。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担うことを書く（SHALL）。`worker.md` の return には「指示のどこまでやって、どこで何が起きたか」を含める義務を書かなければならない（MUST。決める役の入力契約になるため）。

`spec-reviewer.md` は 5 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合）と 2 周キャップを含む（MUST）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱いを含む（MUST）: Codex は Bash から `codex exec -c approval_policy=never -c model_reasoning_effort=medium` または `codex-companion.mjs` を直接呼ぶ（slash command `/codex:adversarial-review` と `codex:codex-rescue` サブエージェントは G からは使えない）。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアー（既定 `opus`。マージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。聖域パスだけでは上げない）を spawn してその要約を G に SendMessage で渡す。このため G も名前付きで spawn する（MUST）。`needs-reviewer` の return には light/full の判定と根拠・対象 PR 番号と HEAD SHA・レビュアーの推奨モデル（または `dev-workflow:decider` 指定）と根拠・受け入れ条件の所在を含め（MUST）、レビュー要約を受け取った G が「レビュー実行者:」の PR コメントを投稿して手順 3 以降を続ける（SHALL）。G の failed の return には pr-review-gate 手順 2-2 の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を含めなければならない（MUST。本体が決める役 / 実行役のどちらを上げるかを決めるため）。

`worker.md`・`spec-reviewer.md`・`gate-runner.md` の 3 つはいずれも、長時間処理の完了通知を待つためにターンを終えてはならない旨を明記しなければならない（MUST）。待ち方の詳細の正本は `plugins/dev-workflow/references/subagent-waiting.md` とし、各指示書はそこを参照する（SHALL）。`gate-runner.md` の Codex 起動手順は、起動を background に置いたまま完了確認を同一ターン内の前景ポーリングで行う形でなければならず（MUST）、「出力ファイルを読め」だけで待ち方を書かない記述を残してはならない（MUST NOT）。前景の待ち値は Bash の前景上限（600000 ms）未満でなければならない（MUST）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表（「1 周目」列がすべて `opus` で `fable` 行が無い）、レビュアーの fable は `dev-workflow:decider` 経由であること、return に「指示のどこまでやって、どこで何が起きたか」を書く義務が書かれている

#### Scenario: spec-reviewer.md に 5 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 5 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex は `codex exec` / `codex-companion.mjs` を Bash で呼ぶこと、Codex が使えないときは `needs-reviewer`（判定・HEAD SHA・推奨モデル・受け入れ条件の所在を含む）を return して本体にレビュアーの spawn を委ねること、failed の return に原因分類を含めることが書かれている、Codex の完了確認を同一ターン内の前景ポーリングで行い前景の待ち値が 600000 ms 未満であることが書かれている

#### Scenario: 3 つの指示書に待ちでターンを終えない禁止がある
- **WHEN** `references/roles/` 配下の `worker.md` / `spec-reviewer.md` / `gate-runner.md` をそれぞれ読む
- **THEN** どのファイルにも「完了通知を待つためにターンを終えない」旨の記述があり、待ち方の正本として `references/subagent-waiting.md` が参照されている
