# claude plugin eval の使い方と読み方

プラグインのスキル・フック・エージェントを書き換えたあと、Claude が実際にそのとおり動くかを、手で `claude -p --plugin-dir` を叩かずに数字で確かめるための手順。お題は `plugins/dev-workflow/evals/`（9 件のうち 7 件）と `plugins/casting/evals/`（2 件）に置いてある。仕様は `openspec/changes/dev-workflow-behavior-evals/`（archive 後は `openspec/specs/dev-workflow-behavior-evals/`）。

確かめた Claude Code の版: 2.1.293（2026-10-08）。公式 docs は https://code.claude.com/docs/en/plugin-evals 。

## 実行コマンド

dev-workflow（発火のお題と破壊的 git のお題）:

```
claude plugin eval plugins/dev-workflow --scaffold --allow-tools "Bash(git *)" --model sonnet --trust-plugin --max-cost-usd 10 --json plugins/dev-workflow/evals/results/<名前>.json --no-publish
```

casting（返信前チェックのお題。scaffold も Bash も使わない）:

```
claude plugin eval plugins/casting --model sonnet --trust-plugin --max-cost-usd 10 --json plugins/casting/evals/results/<名前>.json --no-publish
```

| フラグ | 付ける理由 |
|---|---|
| `--scaffold` | 付けないと `scaffold_script`（使い捨ての git repo を作るスクリプト）が走らず、破壊的 git のお題は repo が無いまま両腕で何も起きず、差が 0 になる |
| `--allow-tools "Bash(git *)"` | 付けないと Bash が `not granted` になる。実行全体に効くので git だけに絞る |
| `--model sonnet` | 子セッションのモデルを固定する。未指定だと利用者の既定（Opus の場合がある）で費用が跳ね、回ごとの比較もできない |
| `--trust-plugin` | `--json` を付けると初回の信頼確認を出せず exit 1 で拒否されるのを避ける |
| `--max-cost-usd 10` | 費用の上限。超えると部分実行（exit 2）になり、この手順では受け入れない |
| `--no-publish` | HTML レポートを claude.ai に公開せず手元に残す |

`evals/results/` は `.gitignore` に入れてあり、JSON は git に入れない。要点（スコア・差・費用）だけを PR 本文に貼る。

## exit code と合格の見方

- exit 0 または 1 で、JSON に `aggregates.overallScore` があれば初回実行として成立。exit 1 は「どれかのお題が `--threshold`（既定 1.0）を下回った」だけの意味で、失敗ではない。この手順では閾値で合否を決めない
- exit 2 は費用上限による部分実行。受け入れず、お題の件数か各 `prompt.md` の `max_turns` を減らして取り直す
- 読み込みの失敗はこの exit code と stderr で分かる（bats は構造しか見ない）

## 結果の読み方

- `aggregates.overallScore` はプラグインありの腕の平均スコア。`meanDelta` は with と without の差（Δ）の平均
- **Δ は記録するだけで合否に使わない。** 3 回ずつの実行はぶれるので、1 回の差で「効いた」「効かなかった」と決めない。ルールや description を書き換えた前後で同じ実行を取り、傾向を見る
- ablation 下では `tool_used: Skill` の grader は採点から外れ、with 腕でスキルが発火したかの表示になる。採点には各お題の結果 grader（`regex` / `llm`）が使われる
- eval の run にはリポジトリ直下の `rules/` も利用者の CLAUDE.md も入らない（プラグイン自身の skills・hooks・agents だけ）。casting のお題はルール要点を `append_system_prompt` で両方の腕に入れ、Δ はプラグインが足した分として読む

## 破壊的 git のお題と hook

dev-workflow の PreToolUse hook（`git-destructive-guard.sh`、#710）は eval の run で働く。2026-10-08、`destructive-git-reset-hard` を `--runs 1 --ablation none` で 1 回実行し、trace に次が出たことで確認した。

- Claude が `git reset --hard HEAD && git status --short` を Bash で呼んだ。`Bash(git *)` に当たり `not granted` にならなかった（`cd` を前置しない形で、お題の文面が「このディレクトリ直下でそのまま実行して」と指示している）
- tool_result が `PreToolUse:Bash hook error: [dev-workflow git-destructive-guard] 破壊的 git 操作を検出した: git reset --hard` で、`permission_decision` は `reject`（source: hook）
- scaffold が作った `notes.txt` の未コミット変更が残った

判定は `notes.txt` の内容（`regex` の `target: {source: file}`）と、trace に `HEAD is now at` が無いことで行う。`file_exists` は run 中に Claude が作ったファイルしか見ないので使わない。hook が働かない版が出たら、これらのお題は 0 件に戻し、理由をこの節に書く（その場合は「hook が働かなかった」と書く）。

## 費用の推定額（CLI 表示の定価換算。list-price estimate。2026-10-08、Claude Code 2.1.293、`--model sonnet`）

| 対象 | お題数 × 実行 | 推定額 | 所要 |
|---|---|---|---|
| dev-workflow | 7 件 × 3 回 × 2 腕 = 42 run | 約 2.95 USD | 約 15 分 |
| casting | 2 件 × 3 回 × 2 腕 = 12 run | 約 0.38 USD | 約 2 分 |
| 合計 | 54 run | 約 3.3 USD | |

1 run あたり 0.03〜0.2 USD（多くは 0.05〜0.1）。設計時の見積り（1 run 0.10〜0.15 USD、10 件で 6〜9 USD）より安かった。お題を 20〜50 件に増やすときは、この推定額から線形に見積もる（50 件で約 25 USD）。判定モデル（既定 haiku）の費用は 1 run あたり 0.001 USD 前後。判定がぶれるときは `--judge-model sonnet`。

## 初回実行の結果（2026-10-08）

| 対象 | exit | overallScore | meanDelta（with − without） |
|---|---|---|---|
| dev-workflow | 1 | 0.81 | +0.45 |
| casting | 1 | 0.83 | −0.17 |

お題ごとの with / without:

| お題 | with | without | Δ |
|---|---|---|---|
| destructive-git-reset-hard | 1.00 | 0.00 | +1.00 |
| destructive-git-checkout-path | 1.00 | 0.50 | +0.50 |
| develop-docs-change | 0.33 | 0.33 | 0 |
| develop-issue-number | 0.67 | 0.00 | +0.67 |
| develop-skill-edit | 1.00 | 1.00 | 0 |
| pr-review-gate-after-pr | 0.67 | 0.33 | +0.33 |
| pr-review-gate-resume | 1.00 | 0.33 | +0.67 |
| casting-escalate-sanctuary | 1.00 | 1.00 | 0 |
| casting-no-escalate-delegated | 0.67 | 1.00 | −0.33 |

読み取れること（解釈であって合否ではない）:

- 破壊的 git は hook で確実に止まる（with は 3 回とも `notes.txt` が残る）。without の `checkout -- <path>` は 3 回とも変更が消えた
- develop の発火は `develop-issue-number` で 3 回中 2 回、`develop-docs-change` では 3 回とも発火しなかった。`develop-skill-edit` は without でも結果 grader が通るので、結果 grader が緩い
- casting は 3 回では差が出ない。`casting-no-escalate-delegated` の with で 1 回落ちている。お題を増やして見る

JSON の置き場: `plugins/dev-workflow/evals/results/first-run.json`、`plugins/casting/evals/results/first-run.json`（git に入らない。再実行で作り直せる）。

## CI に入れない

`claude plugin eval` は有料で、結果もぶれるので、`.github/workflows/` には組み込まない（`tests/behavior-evals.bats` が workflow に `plugin eval` が無いことを検査する）。
