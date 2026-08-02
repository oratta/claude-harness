---
name: setup
description: 使用量ステータスラインを settings.json に配線する（導入・更新・アンインストール）
argument-hint: "[--dry-run|--uninstall]"
allowed-tools: Read, Bash, AskUserQuestion
---

`statusline` プラグインの `scripts/install.sh` を使って、ステータスラインを Claude Code に配線する。

## 手順

### 1. プラグインルートを特定する

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:-}" \
  ~/.claude/plugins/marketplaces/*/plugins/statusline \
  ~/.claude/plugins/installed/*/statusline; do
  [ -n "$dir" ] && [ -f "$dir/scripts/install.sh" ] && echo "$dir" && break
done
```

見つからなければ「statusline プラグインが見つからない」と報告して終了する。

### 2. `--uninstall` が渡された場合

`settings.json` の `.statusLine` を削除する。バックアップを取ってから jq で書き換える:

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cp "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak-$(date +%Y%m%d%H%M%S)"
tmp=$(mktemp) && jq 'del(.statusLine)' "$CONFIG_DIR/settings.json" > "$tmp" && mv -f "$tmp" "$CONFIG_DIR/settings.json"
```

`<config>/statusline.sh` 自体は消さない（ユーザーが色や幅を調整している可能性があるため）。消したい場合は手で消すよう案内して終了する。

### 3. まず `--dry-run` で差分を出す

```bash
bash "<プラグインルート>/scripts/install.sh" --dry-run
```

出力をそのままユーザーに見せる。ここで確認すべきは 2 点:

- `statusLine` が `set`（未設定 → 新規）か `replace`（既存の別スクリプトを置き換え）か
- `replace` の場合、`現在:` に出ているコマンドが何か

### 4. 適用の可否を確認する

- `statusLine: set` かつ `script: install`（まっさらな導入）→ 確認不要でそのまま適用してよい
- `statusLine: replace`（**既存のステータスラインを置き換える**）→ 現在のコマンドを見せて適用してよいか確認する。既存スクリプトは消えないが、settings.json の向き先は変わる
- `--dry-run` が引数で渡されていた場合 → ここで終了。適用しない

### 5. 適用する

```bash
bash "<プラグインルート>/scripts/install.sh"
```

### 6. 動作確認して結果を報告する

サンプル入力を流して描画を確認する（実際の値ではなくダミー）:

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
now=$(date +%s)
printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":3,"resets_at":%s},"seven_day":{"used_percentage":25,"resets_at":%s}}}' \
  "$PWD" "$((now + 14000))" "$((now + 420000))" | bash "$CONFIG_DIR/statusline.sh"
```

報告には次を含める:

- 書き換えたファイルとバックアップの接尾辞
- 反映タイミング（次のステータスライン再描画から）
- Fable 行が出るのは `dev-workflow` プラグインが `.usage-snapshot` を書いている環境のみ、という注記
- 色・バー幅を変えたい場合は `<config>/statusline.sh` を直接編集してよい（プラグイン更新で消えない）が、`/statusline:setup` を再実行すると上書きされる（バックアップは取られる）こと

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
