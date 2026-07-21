## 1. テスト先行（Red）

- [x] 1.1 `plugins/dev-workflow/tests/tripwire-hook.bats` を新設（hooks.json 構造・注入 JSON の内容・fail-soft・テンプレ導入手順の更新）。実行して Red を確認

## 2. 実装（Green）

- [x] 2.1 `scripts/session-tripwires.sh` を作成（節抽出 + JSON 出力 + fail-soft、実行権限付与）
- [x] 2.2 `hooks/hooks.json` を作成（SessionStart、matcher startup|clear|compact、${CLAUDE_PLUGIN_ROOT}）
- [x] 2.3 テンプレート冒頭の導入手順を更新（hook 既定・手動コピーはオプション）
- [x] 2.4 bats 全 Green + リポジトリ全体の回帰なしを確認

## 3. リリース

- [x] 3.1 plugin.json v1.2.0、marketplace 同期（dev-workflow 1.2.0 / top-level 2.23.0）
- [x] 3.2 commit / push で PR #31 を更新
