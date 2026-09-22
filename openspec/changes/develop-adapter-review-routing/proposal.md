## Why

develop を自動選択（または明示 profile・旧形式の account/model 指定）で走らせても、PR レビューだけは G が指示書 `gate-runner.md` の既定どおり Codex を Bash から直接呼ぶ。#375 の受け入れ条件 7 の実機確認（`/dev-workflow:develop 307`、dev-workflow 2.13.22）で、自動選択が `claude-default`（Codex の余裕 −27.56）を選んだのに PR #382 のレビューは `codex exec` で実行され、phase `review` の選び直しも記録も無かった。

原因は、「adapter 経路では G は `codex exec`・companion・Claude reviewer を呼ばず `needs-reviewer` を返す」という規則が `references/codex-develop.md` にしか無く、G はこのファイルを読まないこと。加えて `SKILL.md` の (4) は `needs-reviewer` を「Codex が使えないとき」と「light のとき」だけの経路として書いており、本体側から見ても G が Codex を直接呼ぶのが正規の経路に見える。

## What Changes

- develop の本体は (4) で G を起動・再開する指示（Codex の G なら request の instructions）に、起動形を問わず常に `レビュー経路: adapter` の 1 行を書く。`レビュー経路: 従来` は develop 本体以外の呼び出し元のための値で、develop の本体は書かない。G はこの行だけで経路を判別し、行が無ければ従来経路とする
- `gate-runner.md` に、`レビュー経路: adapter` のとき G は full でも Codex・companion・レビュアーを自分で呼ばず、手順 1 と手順 2-0 まで済ませて `needs-reviewer`（判定 `full（adapter 経路）` または `light`）を返す、と書く。行が無い・`従来` のときは今の既定（full は G が Codex を直接呼ぶ）を変えない
- `SKILL.md` の (4) に、adapter 経路で `needs-reviewer` を受けた本体の手順を書く: `codex-develop.py request --phase review` で投げ先を選び直す → 選択（構成・reason・両 provider の余裕・`fetched_at`）を記録先の dispatch 記録に残す → 選ばれた投げ先でレビュアーを起動する → 要約と executor / model・dispatch 記録の URL を G に渡す（Claude の G は SendMessage で再開、Codex の G は新しい phase `gate` で渡す）
- `pr-review-gate/SKILL.md` の「レビュー実行者:」の書き分けと PR コメント雛形に、adapter 経路の 1 形 `<executor>/<model>（adapter 経路・dispatch 記録: <URL>）` を足す
- `codex-develop.md` の該当規則に、G への経路の明示（`レビュー経路: adapter`）が本体の責任であることを足す
- 上記の文言を照合する bats テストを足し、dev-workflow の version を上げる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: adapter を適用した develop での PR レビュー経路（G の判別方法・G の `needs-reviewer` 返却・本体の選び直しと記録）の要件を足す。従来経路の要件は変えない

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（G の指示書）
- `plugins/dev-workflow/skills/develop/SKILL.md`（(4) と Role profile の選択節）
- `plugins/dev-workflow/references/codex-develop.md`（G の規則の 1 か所）
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（「レビュー実行者:」の書き分けと PR コメント雛形に 1 形追加）
- `plugins/dev-workflow/tests/`（文言照合の bats）
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version
- adapter を適用しない従来経路の G の動き（full は Codex を直接呼ぶ）は変わらない。`codex-develop.py` のコードは変えない
