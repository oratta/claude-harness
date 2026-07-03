# longrun-workflow-reference-bundle Specification

## Purpose
TBD - created by archiving change longrun-browser-verify-restore. Update Purpose after archive.
## Requirements
### Requirement: workflow-tool-reference.md を配布物内に同梱する
Workflow ツール仕様の一次ソース `workflow-tool-reference.md` は、archive・plugin 更新で消える `_longruns/2026-06-12_harness-workflow-overhaul/` ではなく、配布物内の `plugins/longrun/references/workflow-tool-reference.md` に存在しなければならない（MUST）。内容（Workflow ツールのシグネチャ・制約のエビデンス）は移動元と等価でなければならない（MUST）。

#### Scenario: reference が references ディレクトリ配下に存在する
- **WHEN** `plugins/longrun/references/workflow-tool-reference.md` の有無を確認する
- **THEN** ファイルが存在し、Workflow ツールのシグネチャ・制約の記述を含む

### Requirement: 参照元 3 箇所を配布物内パスに書き換える
`commands/exec.md`・`templates/workflow/build-verify.workflow.js`・`templates/workflow/review.workflow.js` の一次ソース参照は、`_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` ではなく `${CLAUDE_PLUGIN_ROOT}/references/workflow-tool-reference.md`（テンプレートのコメント内は `plugins/longrun/references/workflow-tool-reference.md` 相当の配布物内パス）を指さなければならない（MUST）。`references/model-tiers.md` 内の同 reference への参照、および bats フィクスチャ内の `_longruns/2026-06-12*` 文字列も掃除し、`plugins/` 配下から `_longruns/2026-06-12` への参照が完全に消えていなければならない（MUST）。

#### Scenario: plugins 配下に _longruns/2026-06-12 参照が残っていない
- **WHEN** `grep -rn "_longruns/2026-06-12" plugins/` を実行する
- **THEN** 一致行が 0 件である

#### Scenario: 参照元 3 箇所が配布物内パスを指す
- **WHEN** `commands/exec.md` / `build-verify.workflow.js` / `review.workflow.js` の一次ソース参照記述を確認する
- **THEN** 3 箇所すべてが `${CLAUDE_PLUGIN_ROOT}/references/`（またはテンプレートコメントの `plugins/longrun/references/`）配下の workflow-tool-reference.md を指し、`_longruns/2026-06-12` を含まない

### Requirement: 元 run ディレクトリに移動先スタブを残す
移動元の `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` には、内容を全削除せず、移動先（`plugins/longrun/references/workflow-tool-reference.md`）を示すスタブを残さなければならない（MUST）。これにより過去の run ディレクトリ・archive を辿った際に参照の行き先が失われない。

#### Scenario: 元パスに移動先を示すスタブが残る
- **WHEN** 移動後に `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を確認する
- **THEN** ファイルが存在し、移動先 `plugins/longrun/references/workflow-tool-reference.md` へのポインタ（移動済みである旨と新パス）が記載されている

