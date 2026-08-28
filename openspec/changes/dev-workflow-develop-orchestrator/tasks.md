## 1. テスト先行（develop の構造に対する文書アサーション）

- [ ] 1.1 `plugins/dev-workflow/tests/develop-skill.bats` を新設する: 「いつ使うか」・本体の禁止事項（Edit でコードを書かない／レビュー代行しない）・入口 0（issue 任意・Draft PR 早期・受け入れ条件は PR 本文）・1 ループ（W→R1→W→G の順序、R1/G の 2 周キャップ、failed → W 再開）・モデル節（W/R1/G 既定 opus、fable 条件、reserve/exhausted）・エピック 4 節・実行戦略 3 分岐と決定論的シグナルの不在・`skills/github-issue` の不在・description の発火語
- [ ] 1.2 `tests/develop-roles.bats` を新設する: `references/roles/worker.md`（仕様化判断の記録書式・`gh` 投稿・記録前に進まない・事前分類 4 分類・`model: fable`・AGENT_MODEL・reserve/exhausted・openspec CLI 縮退経路のレビュー）、`spec-reviewer.md`（5 観点・読み取り専用・grep 先行・2 周キャップ・needs-approval・AskUserQuestion・unmanned サイクル終了・結果書式・最新 1 件・Closes/Fixes/Refs・PR コメントへの縮退・model 明示・既定 opus）、`gate-runner.md`（pr-review-gate 参照・手順 1〜5・`needs-reviewer`・Codex は Bash 経由）
- [ ] 1.3 `tests/work-issue-command.bats` と `tests/issue-draft-sections.bats` を `tests/develop-command.bats` に統合する: `commands/develop.md` の 5 分岐（②④⑤の既定が入口 0）・issueify の path-discovery・fail-soft の最小ドラフト 2 節・承認ゲート・着手 1 件選択・`commands/work-issue.md` がエイリアスで本文を持たないこと
- [ ] 1.4 `tests/model-escalation-policy.bats` を移行する: 事前分類の正本を `references/roles/worker.md` に、pr-review-gate 側の参照文言を `develop スキルの references/roles/worker.md が正本` に、バージョン下限を 2.0.0 に更新
- [ ] 1.5 `tests/spec-decision-and-review.bats` を移行する: Step B / Step D の切り出しを worker.md / SKILL.md の 1 ループ / spec-reviewer.md に付け替え、`references/spec-review.md` の参照を `references/roles/spec-reviewer.md` に変更
- [ ] 1.6 loops 側の退行ガードを `plugins/loops/tests/dev-agent-tripwires.bats` に追加する: テンプレートとレシピに `github-issue` が現れず `develop` が委譲先であること
- [ ] 1.7 この時点で `scripts/test.sh dev-workflow loops` を実行し、新規テストが Red であることを確認する

## 2. develop スキルの新設

- [ ] 2.1 `skills/develop/SKILL.md` を書く（frontmatter: name / description（発火語込み）/ version 1.0.0。本文: いつ使うか・本体の役割・入口 0・1 ループ・モデル・エピックの扱い・実行モード表（interactive / unmanned）・longrun:plan を呼ばない理由）
- [ ] 2.2 `skills/develop/references/roles/worker.md` を書く（旧 Step A〜D 本文を移し、記録先を「issue または Draft PR」に一般化。実行戦略 3 分岐を削除し、「重要実装の事前分類」表を正本として置く。Draft PR を記録先にする場合の最初の commit → `gh pr create --draft` の手順を含む）
- [ ] 2.3 `skills/develop/references/roles/spec-reviewer.md` を書く（旧 `references/spec-review.md` を移し、記録先の一般化・PR→issue 解決規則に「無ければ PR 自身のコメント」を追記・結果コメントの投稿手順を含む）
- [ ] 2.4 `skills/develop/references/roles/gate-runner.md` を書く（pr-review-gate を Read して手順 1〜5 を実行、`needs-reviewer` の return 規約、return の書式 passed / failed / 保留）
- [ ] 2.5 `skills/develop/references/decision-criteria.md` を書く（旧 decision-criteria.md から 4 象限・実行戦略の判定表・決定論的シグナル・self-contained 節を削除し、Step B / Step C / 残量モード / 自動導出 / 判定に使わない材料を残す）
- [ ] 2.6 `commands/develop.md` を書き、`commands/work-issue.md` をエイリアスに置き換える
- [ ] 2.7 `skills/github-issue/` を削除する

## 3. 参照の付け替え

- [ ] 3.1 `skills/pr-review-gate/SKILL.md` の `github-issue` 参照 2 箇所（仕様宣言の前提・事前分類の正本）を `develop スキルの references/roles/worker.md` に付け替え、frontmatter version を上げる
- [ ] 3.2 `templates/escalation-tripwires.md` のトリップワイヤー 1 の乗り換え先を「本体に return して分割（エピック化）、または /lr:e 系」に直す
- [ ] 3.3 `plugins/dev-workflow/README.md`・ルート `README.md` の dev-workflow 節を develop に書き換える
- [ ] 3.4 `plugins/dev-workflow/.claude-plugin/plugin.json` の skills / commands / description / version（2.0.0）を更新し、`.claude-plugin/marketplace.json` の dev-workflow と loops のバージョンを揃える
- [ ] 3.5 `plugins/loops/templates/agent-loop-template.md`・`recipes/loop-dev-agent.md`・`.claude-plugin/plugin.json` の `github-issue` を `develop` に付け替え、loops version を 0.25.0 に上げる。README に「配備済み憲法は再生成が必要」を 1 行追記
- [ ] 3.6 `scripts/test-auto-merge-workflow.sh` の非聖域パス例（`skills/github-issue/SKILL.md` / `commands/work-issue.md`）を `skills/develop/SKILL.md` / `commands/develop.md` に置き換える

## 4. 検証

- [ ] 4.1 `scripts/test.sh` を全件実行し合格（exit 0）を確認する
- [ ] 4.2 `openspec validate dev-workflow-develop-orchestrator` が通ることを確認する
- [ ] 4.3 `grep -rn "github-issue" plugins/ README.md scripts/ openspec/specs/` が archive 以外で 0 件であることを確認する
