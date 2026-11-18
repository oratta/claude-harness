# Tasks

## 1. 出力の形を直す

- [ ] 1.1 `session-tripwires.sh` の通常の出力（`TRIPWIRES_SCOPE` が `subagent-budget` 以外）を `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": <本文>}}` にする。本文の組み立て（`head + budget + "\n\n" + tripwire`）と `subagent-budget` の本文テキスト出力は変えない。冒頭のコメントの出力の説明も合わせる。触る範囲: plugins/dev-workflow/scripts/session-tripwires.sh:1-16（ヘッダコメント）、plugins/dev-workflow/scripts/session-tripwires.sh:157（最後の print）
- [ ] 1.2 `prompt-tripwires-refresh.sh` が `session-tripwires.sh` の出力から本文を取り出す箇所を `hookSpecificOutput.additionalContext` に変える（トップレベルは読まない）。触る範囲: plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh:28-35（ヘッダコメント）、plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh:88-92（BODY の読み取り）

## 2. テストを新しい形に合わせる

- [ ] 2.1 `tripwire-hook.bats` の「注入 JSON が節を含む」テストで、`hookSpecificOutput.hookEventName == "SessionStart"`、`hookSpecificOutput.additionalContext` に 4 語を含むこと、トップレベルに `additionalContext` が無いことを確かめる。受け入れ条件の `jq -e '.hookSpecificOutput.hookEventName=="SessionStart" and (.hookSpecificOutput.additionalContext|length>0)'` と同じ判定も足す（jq が無い環境では python で同じ判定）。触る範囲: plugins/dev-workflow/tests/tripwire-hook.bats:52-62（script: outputs valid JSON …）
- [ ] 2.2 `tripwire-hook.bats` の残りの本文の取り出し（`json.loads(...)['additionalContext']`）をすべて `['hookSpecificOutput']['additionalContext']` に変える。触る範囲: plugins/dev-workflow/tests/tripwire-hook.bats:80、101、123、149（ctx_at）、229、260（copied_ctx）、304、322、338
- [ ] 2.3 `memory-tripwire.bats`・`usage-probe.bats`・`subagent-start-context.bats` のトップレベルの読み取りを同じく変える。`subagent-start-context.bats` の「unknown TRIPWIRES_SCOPE keeps the legacy JSON output」は、仕様のシナリオ「SessionStart の出力は変わらない」（変更後の中身）のテストとして直す（未設定と未知の値の両方で `hookSpecificOutput.hookEventName == "SessionStart"`、`hookSpecificOutput.additionalContext` に昇格トリップワイヤー節と残量モードのブロックがあり、トップレベルに `additionalContext` が無い。テスト名も合わせて変える）。subagent-budget のテキスト出力のテスト（同ファイル 180-203 行）は変えずに通ることを確かめる。触る範囲: plugins/dev-workflow/tests/memory-tripwire.bats:221-240、556-570、plugins/dev-workflow/tests/usage-probe.bats:129-130（ctx ヘルパ）、plugins/dev-workflow/tests/subagent-start-context.bats:212-220
- [ ] 2.4 `prompt-tripwires-refresh.bats` は実物の `session-tripwires.sh` を写して走らせるので、手を入れずに通ることを確かめる（1.2 を外すと (c) が落ちることを一度確かめてから戻す）。触る範囲: plugins/dev-workflow/tests/prompt-tripwires-refresh.bats:92-112（読むだけ）
- [ ] 2.5 トップレベルの `additionalContext` を読むテストが残っていないことを `grep -rn "\['additionalContext'\]\|\[\"additionalContext\"\]" plugins/dev-workflow/tests/` で確かめる（`hookSpecificOutput` を経由するもの・browser-guard など別スクリプトのヘルパ変数 `h[...]` は除く）
- [ ] 2.6 `bats plugins/dev-workflow/tests/` の関連スイート（tripwire-hook・memory-tripwire・usage-probe・subagent-start-context・prompt-tripwires-refresh）と `bats tests/injection-budget.bats` を通す（予算値が変わらないことの確認）

## 3. 記録

- [ ] 3.1 変更の記録を書く（何を直したか・なぜ・読み取り側も追随させたこと・実機確認の手順）。触る範囲: plugins/dev-workflow/changes/1673.md（新規）
- [ ] 3.2 実機確認は (3a) の return の `画面確認:` 行で本体に頼む（新しいセッションの会話ログの SessionStart の hook に文脈に入った印の attachment があるか、セッションに `## 昇格トリップワイヤー` と `[memory]` の行が文脈にあるかを聞く）
