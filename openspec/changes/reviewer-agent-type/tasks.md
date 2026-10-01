## 1. テストを先に書く（失敗を確かめる）

- [x] 1.1 `role-agent-types.bats` に `agents/reviewer.md` の frontmatter（`name: reviewer`・`model: opus`・`tools: Read, Bash, Grep, Glob, TaskStop`、`Edit`/`Write`/`NotebookEdit`/`mcp__`/`WebFetch`/`WebSearch`/`Skill`/`Agent` が無い）と本文（`skills/pr-review-gate/stages/reviewer-brief.md` を指す・編集しない・サブエージェントを起こさない・投稿せず返す）の検査を足し、plugin.json の `agents` 配列の期待値に `./agents/reviewer.md` を足す。触る範囲: plugins/dev-workflow/tests/role-agent-types.bats:7-33
- [x] 1.2 `agent-model-guard.bats` に `dev-workflow:reviewer` + `model: fable` が deny、同じ種別で `sonnet`・`opus`・省略が無出力 exit 0 になる検査を足す。触る範囲: plugins/dev-workflow/tests/agent-model-guard.bats:64-77（"new executor types reject Fable ..." の test）
- [x] 1.3 `subagent-context-audit.bats` の混在 fixture に `agentType: dev-workflow:reviewer`・description が `Reviewer:` で始まらない個体を足し、`--by-role` で `Reviewer` の count が 2 になる検査に改める（合計が全体の count と一致する test も通ること）。触る範囲: plugins/dev-workflow/tests/subagent-context-audit.bats:94-120（seed_role_mix）、plugins/dev-workflow/tests/subagent-context-audit.bats:456-492
- [x] 1.4 レビュアーの spawn の記述が `dev-workflow:reviewer` を書き、`general-purpose` でレビュアーを起こす記述が無いことの検査を足す（prepare.md の needs-reviewer 段落と `推奨モデル` 行、review-run.md 2-1 の表のフォールバック行、develop SKILL.md の Agent ツール行とモデル表の「G が要求するレビュアー」行、codex-develop.md の Claude role の段落）。検査は、レビュアーの段落・行に `subagent_type: general-purpose` と `` Agent ツール（`general-purpose`） `` の形が無いことで判定する（既存の `` `general-purpose` に `model: fable` は付けない `` の grep（develop-roles.bats:402 など）は残る文言なので壊さない）。触る範囲: plugins/dev-workflow/tests/develop-roles.bats（近い test の並び。codex-develop の test は 975-1003 付近）
- [x] 1.5 1.1〜1.4 のテストを実行し、新しい検査だけが落ちることを確かめる

## 2. 種別の定義と宣言

- [x] 2.1 `agents/reviewer.md` を作る（frontmatter は 1.1 のとおり、description は 1 文。本文は reviewer-brief.md を指し、ファイルを編集しない・サブエージェントを起こさない・PR / issue にコメントを投稿せず三表と指摘を起こした側に返す、だけを書く。手順を写さない）。触る範囲: plugins/dev-workflow/agents/reviewer.md（新規）
- [x] 2.2 plugin.json の `agents` 配列に `./agents/reviewer.md` を足し、description にレビュアーの種別（`dev-workflow:reviewer`）を短く足す。marketplace.json の dev-workflow の description を同じ文に揃える。触る範囲: plugins/dev-workflow/.claude-plugin/plugin.json:3、plugins/dev-workflow/.claude-plugin/plugin.json:18-22、.claude-plugin/marketplace.json:127

## 3. spawn の指示を新種別に替える

- [x] 3.1 prepare.md の「needs-reviewer の return」の段落の既定の種別を `subagent_type: dev-workflow:reviewer` に `model: opus` に替え、`推奨モデル` の行も合わせる（事前分類で `dev-workflow:decider`、`general-purpose` に `model: fable` は付けない の文言は残す）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md:87、plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md:101
- [x] 3.2 review-run.md 2-1 の優先順の表のフォールバック行の `Agent ツール（general-purpose）` を `dev-workflow:reviewer` に替え、「Task サブエージェントのモデル」の節に種別を書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:20、plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:47-51
- [x] 3.3 develop SKILL.md の Agent ツールの行にレビュアー（`dev-workflow:reviewer`）を足し、(4) の needs-reviewer ③ の「executor が claude なら Agent ツールで」に種別を書き、モデル表の「G が要求するレビュアー」の行に既定の種別を書く。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:42、plugins/dev-workflow/skills/develop/SKILL.md:135-148、plugins/dev-workflow/skills/develop/SKILL.md:254
- [x] 3.4 codex-develop.md の Claude role の起動の「R1 とレビュアーは `general-purpose`」を、レビュアーは `dev-workflow:reviewer`、R1 は `general-purpose` に分ける。触る範囲: plugins/dev-workflow/references/codex-develop.md:23
- [x] 3.5 README.md の役割とモデルの説明にレビュアーの種別を足す。触る範囲: plugins/dev-workflow/README.md:11-14

## 4. ガードと監査

- [x] 4.1 agent-model-guard.sh のヘッダーコメントの「worker / gate-runner は DECIDER_TYPES に入れず」に reviewer を足す（判定コードは変えない）。触る範囲: plugins/dev-workflow/scripts/agent-model-guard.sh:13
- [x] 4.2 subagent-context-audit.sh の `classify_role` に「`agentType` が `dev-workflow:reviewer` なら `Reviewer`」を decider の次に足し、ヘッダーコメントの分類の優先順位を合わせる。触る範囲: plugins/dev-workflow/scripts/subagent-context-audit.sh:47-50、plugins/dev-workflow/scripts/subagent-context-audit.sh:269-282
- [x] 4.3 usage-audit.md の担当分類の表と、`Reviewer:` 接頭辞が未規定で unknown に落ちうるという注記を、新種別は agentType で数えられる形に改める。触る範囲: plugins/dev-workflow/docs/usage-audit.md:130-138

## 5. 検査と記録

- [x] 5.1 1.1〜1.4 のテストが通ることを確かめ、`./scripts/test.sh` を実行して exit 0 を確かめる（`tests/injection-budget.bats` が落ちたら description を削り、足りないぶんだけ `tests/injection-budget.txt` を動かして理由を控える）。触る範囲: tests/injection-budget.txt（必要な場合だけ）
- [x] 5.2 変更記録を書く。触る範囲: plugins/dev-workflow/changes/650.md（新規）
- [x] 5.3 `openspec validate reviewer-agent-type --strict` を通す
- [ ] 5.4 受け入れ条件 1 の計測: worktree の `plugins/dev-workflow` を `claude -p --plugin-dir` で読み込んだセッションで、同じ指示文・`model: opus` で `general-purpose` と `dev-workflow:reviewer` を 1 体ずつ起こし、各 `subagents/agent-*.jsonl` の最初の `message.usage` の 3 項目と `meta.json` の `agentType`、Claude Code の版を控える（PR 本文の `## 新種別の計測` に (3b) で書く）。合計の差が 20,000 未満なら手を止めて return する

## 6. 受け入れ条件 2（担い手は本体。W は行わない）

- [ ] 6.1 この PR のゲートで G が `needs-reviewer` を返したら、本体が design.md「この PR のゲートでレビュアーを起こす手順」で Claude レビュアーを起こす（worktree を cwd に `claude -p --model sonnet --plugin-dir <worktree>/plugins/dev-workflow`、その中で `subagent_type: dev-workflow:reviewer`・`model: opus`・description `Reviewer: ... for PR #<N> (#650)`。区画と補足の回も同じ）。`-p` にはレビュアーの return を加工せずに出力させ、本体はそのセッションの `subagents/agent-*.jsonl` の最終 return と `meta.json`（`agentType`・description）を正として照合と振り分けの G に渡す。触る範囲: なし（実行のみ）
- [ ] 6.2 review phase の自動選択が codex を選んだ場合は、Codex のレビューに加えて 6.1 の方法で Claude レビュアーを 1 体起こし、その結果も G に渡す。できなければ PR 本文の `## 新種別の計測` に「受け入れ条件 2 は満たせなかった」と理由を書く。触る範囲: なし（実行と PR 本文）
- [ ] 6.3 PR 本文の `## 新種別の計測` に、レビュアーの description・`meta.json` の `agentType`・G の照合結果の PR コメントの URL を書く（W が (3b) で見出しを用意し、本体がゲートのあとに埋める）。触る範囲: なし（PR 本文）
