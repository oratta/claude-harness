# Proposal

## Why

claude-harness の自動マージの聖域（`.github/workflows/auto-merge.yml` の `SACRED`）は `^plugins/[^/]+/hooks/` だけを数え、hook の本体である `plugins/<name>/scripts/` のスクリプトは対象外になっている。そのため、`plugins/dev-workflow/scripts/git-destructive-guard.sh` だけを変えた PR #1157 が、主が「マージは主がする」と答えていたのに、ゲート合格の直後に自動マージされた（issue #1163）。エピックや PR 本文の「hook は聖域」という前提と、実際の定義が食い違っている。

## What Changes

- claude-harness の展開先 `SACRED` に、全 `plugins/*/hooks/hooks.json` の `command` が直接指すスクリプト（5 プラグイン計 24 本）と、許可を判定する hook（PreToolUse / PermissionRequest）が判定の本体として直接読み込む補助ファイル 3 本（`plugins/dev-workflow/scripts/git-guard-scratchpad.py`・`plugins/dev-workflow/scripts/usage_view.py`・`plugins/capability-registry/scripts/secret-guard.py`）を、ファイル名ちょうどで足す。
- 展開先の `scripts/test-auto-merge-workflow.sh` に、全 `plugins/*/hooks/hooks.json` の `command` を集めて、指すスクリプトのパスがすべて `SACRED` に一致するかを確かめる検査を足す。hook を足して `SACRED` に書き忘れると CI が落ちる。あわせて must-match / must-not-match の代表パスを足す。
- `MERGE_CONDITION` は変えない。hook のスクリプトは `plugins/*/hooks/` と同じく、親の判断の印で `human-merge` を外せる側に置く。
- 原本（`plugins/dev-workflow/templates/auto-merge/`）の正規表現とテストは変えない。hook の置き場はリポごとに違い、原本の既定はどのリポにも共通の分だけを持つため。
- 運用ガイド `docs/auto-merge.md` の聖域パスの表に hook のスクリプトの行を足し、残る限界（補助ファイルは 1 段だけ・手で選ぶ、親が許可を書くスクリプトは聖域に入らない）を書く。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-automerge-templates`: claude-harness の展開先で、hook が実行するスクリプトを聖域に含めることと、hooks.json との突き合わせを CI で検査することを要件に足す（ADDED Requirement 2 つ。聖域に入れる範囲と、CI の検査）。

## Impact

- 対象: `.github/workflows/auto-merge.yml`（`SACRED` と説明コメント。聖域かつマージ条件そのもの）、`scripts/test-auto-merge-workflow.sh`、`docs/auto-merge.md`、`plugins/dev-workflow/changes/1163.md`（新規）。
- 変えないもの: `MERGE_CONDITION`、原本 `plugins/dev-workflow/templates/auto-merge/` 一式、`plugins/dev-workflow/tests/automerge-templates.bats`、hook のスクリプト自体。
- マージ経路: この PR は `.github/workflows/` を変えるので、自動マージの処理が `human-merge` を付け、マージ条件そのもののパスなので親の判断でも外れない。主がマージする。
- 以後の影響: 24 本＋3 本のどれかに触れる PR は `human-merge` で止まる（親の判断の印があれば外せる）。
- 分割判断: 聖域の定義と、その漏れを拾う CI の検査は 1 つの判断（聖域に入れる範囲）で決まり、既存の 1 capability に閉じる。単一 change・1 PR とする。
- エピック #1476 の他の子（#1155・#1153・#1610・#1166・#1159・#1173）の範囲には触れない。
