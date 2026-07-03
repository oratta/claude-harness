# workflow-tool-reference.md — 移動済み（MOVED）

> このファイルの本体は配布物内へ移動しました（plugin-review-fixes / change-2）。

Workflow ツールのシグネチャ・制約の一次ソースは、配布物内の以下に同梱されています:

**`plugins/longrun/references/workflow-tool-reference.md`**

（実行時パスは `${CLAUDE_PLUGIN_ROOT}/references/workflow-tool-reference.md`）

## 移動の理由

この run ディレクトリ（`_longruns/2026-06-12_harness-workflow-overhaul/`）は archive / plugin 更新で
消えうるため、`commands/exec.md` や workflow テンプレートが一次ソースとして参照するには不適切でした。
配布物（`plugins/longrun/references/`）へ同梱し、参照元を `${CLAUDE_PLUGIN_ROOT}/references/` 起点に
書き換えました。過去の run/archive からこのパスを辿った場合は、上記の新パスを参照してください。
