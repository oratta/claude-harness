## Why

公開版に残る部品のうち dev-workflow 以外（rules/README.md・scripts・capability-registry・statusline・worktree・product-handover・casting・cost-ledger・infra）に、オーナーの固有名（flatmate・suimei・moko・uranai・shukan・sns-autopilot）とオーナーの PC のパス（`/Users/oratta/...`）が残っている。`docs/public-private-split.md` の固有記述の一覧で「担い手なし」の行で、客の住人が読む手順書や出力例が、その環境に無いリポジトリやパスを指す。#1129 の受け入れ条件「公開版から、個人版の部品と固有名が無くなっている」を満たせない（issue #1168、エピック #1127 の子。#1168 を割った 2 つの change の 1 つ目。もう 1 つは `public-names-devworkflow-flatmate`）。

## What Changes

一覧の dev-workflow 以外の「担い手なし」の行を、行ごとに次の 3 つから選んで片付ける（選び方は design D1）。

- 固有名・オーナーの PC のパスを、一般の例（`example`・`/Users/example/...`・`<project>`）か条件つきの書き方に直す
- 個人版へ移す部品を指す行は、個人版の有無に依らない書き方に直す
- 「載せない行の基準」に当たるなら理由を書いて一覧から外す

対象の部品: `rules/README.md`・`scripts/sync.sh`・`scripts/test-auto-merge-workflow.sh`・capability-registry（`SKILL.md:65`・`stripe.md:5`・`supabase.md:5,10`）・statusline（README・`statusline.sh`）・worktree（`wt-clean/SKILL.md` の出力例・`wt-clean-orphan-detection.md:18`）・product-handover（`plugin.json:3`・README）・casting（`catalog/injection.md`・`catalog/delegation.md`）・cost-ledger（README・`commands/cost.md`）・infra（2 つのテンプレート）。

statusline の `FLATMATE_RATE_SHARE_DIR`・`FLATMATE_RATE_SHARE_CONF` は、中立の名前（`CLAUDE_RATE_SHARE_DIR`・`CLAUDE_RATE_SHARE_CONF`）を主にし、旧名を互換のために読み続ける（design D2。振る舞いの変更を含む）。

あわせて、#1168 の受け入れ条件 2 つ目のため、一覧に載っていない候補語の当たり（約 137 件、dev-workflow を除く分）を、載せない行の基準に当たるかで 1 件ずつ判定し、当たらない行は直す。

dev-workflow の Orca 経路の行の担い手は #1177 に付け替える（`public-names-devworkflow-flatmate` の tasks で行う）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `harness-public-private-split`: dev-workflow 以外の公開版の部品が、決めた固有名を持たないことを求める要件を足す。載せない行の基準に「互換のために残す旧名の読み取り」を足す
- `rate-snapshot`: 共有先の環境変数と設定ファイルの名前に中立の名前を足し、旧名を互換として残す

## Impact

- 上記の部品のファイルと `docs/public-private-split.md`（一覧の行の削除と載せない行の基準の追記）
- `plugins/statusline/scripts/statusline.sh` の挙動（新名を足す）と statusline の bats、`tests/public-private-split.bats`
- 変更の記録 `plugins/<name>/changes/1168.md`（変えたプラグインごと）
- `scripts/test-auto-merge-workflow.sh` の変更は `plugins/dev-workflow/templates/auto-merge/scripts/` の同名ファイルと別ファイル（後者は change B）
