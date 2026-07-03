# post-merge-steps.md — change-6 (plugin-retirement) 後始末

このドキュメントは `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` の完全削除に伴う、ユーザー向け後始末手順と `LLM/` 退避結果の記録です。マージ後、各作業環境で以下を実施してください。

## 1. プラグインの uninstall

```bash
/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness
/plugin uninstall skill-aware-workflow@oratta-claude-harness
/reload-plugins
```

## 2. 各プロジェクトの `settings.local.json` から `enabledPlugins` キーを削除

marketplace 側の削除だけでは、各プロジェクトの `.claude/settings.local.json`（または相当の設定ファイル）に残る `enabledPlugins` 個別キーは自動では消えません。`plugins/skill-pack/skills/skill-pack/SKILL.md` の `enabledPlugins` 編集パターンを参考に、以下の2キーを手動で削除してください:

```json
{
  "enabledPlugins": {
    "obsidian-llm-session-rules@oratta-claude-harness": false,
    "skill-aware-workflow@oratta-claude-harness": false
  }
}
```

上記のような `"obsidian-llm-session-rules@oratta-claude-harness"` / `"skill-aware-workflow@oratta-claude-harness"` キーが存在するプロジェクトでは、そのエントリ自体を削除（`false` に設定するのではなく、キーごと除去）してください。

## 3. `LLM/` 退避結果（llm-log-relocation）

change-6 着手時点でリポジトリ直下 `LLM/` に存在した untracked ファイルを、`$LLM_LOG_DIR`（Obsidian Vault の `90 - LLM`）へ snapshot 基準で退避しました。

- 退避直前スナップショット: 1ファイル（`2026-07-03_07e59a64.md`。本 longrun run 自身のセッションログ）
  - スナップショット記録先: `_longruns/2026-07-03_plugin-review-fixes/llm-log-evacuation-snapshot.txt`
- 移動成功: 1ファイル
- **衝突（同名ファイルが `$LLM_LOG_DIR` に既存）: 衝突ゼロ**
- **hook 起因のスナップショット外新規ファイル: 発生なし**（`_longruns/2026-07-03_plugin-review-fixes/llm-log-evacuation-report.txt` に機械記録済み）
- 退避完了後のリポジトリ直下 `LLM/` の状態: 空（衝突ゼロのため）

### 補足: 退避後に `LLM/` が再出現する可能性について

`obsidian-llm-session-rules` の Stop hook（`auto-save.py`）は、本 change を実装しているこの longrun セッション自身に対しても稼働していました（退避対象の1ファイルはこのセッション自身のログ）。本 change は退避直後に `plugins/obsidian-llm-session-rules/` を `git rm` しているため、以降 hook が発火しても `${CLAUDE_PLUGIN_ROOT}/scripts/auto-save.py` は既に存在せず no-op になる想定ですが、hook 設定がセッション開始時にメモリへロードされている場合は、このセッションの最終ターン終了時（Stop イベント）に1回だけ発火を試みる可能性があります。これは本 change の実行内では観測・検証できない領域のため、次回このリポジトリで作業する際にリポジトリ直下 `LLM/` が非空でないか確認し、あれば同様の手順（`$LLM_LOG_DIR` へ手動 mv）で退避してください。

## 使用したスクリプト

`_longruns/2026-07-03_plugin-review-fixes/scripts/evacuate-llm-log.sh`（snapshot / execute の2サブコマンド、bats テスト: `_longruns/2026-07-03_plugin-review-fixes/tests/llm-log-relocation.bats`）。将来的に同種の untracked ディレクトリ退避が必要になった場合は、このスクリプトを流用できます（本 run 専用の一時スクリプトとして `_longruns/` 配下に配置。恒久的なプラグイン機能としては提供しません）。
