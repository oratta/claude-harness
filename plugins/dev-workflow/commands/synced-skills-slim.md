---
name: synced-skills-slim
description: 同期スキルを name-only にする
allowed-tools: Read, Bash, AskUserQuestion
---

claude.ai から同期されたスキル（`~/.claude/skills/synced/` にあるもの）を、`settings.json` の `skillOverrides` で `name-only` にする。起動時に送られるスキルの説明が減る。名前を指定した呼び出しは今までどおり動く。

## 手順

### 1. スクリプトを探す

```bash
plugin_root="${CLAUDE_PLUGIN_ROOT}"
DW_NG=; if [ -n "${ZSH_VERSION:-}" ] && [[ ! -o nullglob ]]; then setopt nullglob; DW_NG=1; fi
for dir in \
  "${plugin_root:+$plugin_root}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow \
  ~/.claude/plugins/installed/*/dev-workflow; do
  [ -n "$dir" ] && [ -f "$dir/scripts/synced-skills-name-only.sh" ] && echo "$dir" && break
done
if [ -n "$DW_NG" ]; then unsetopt nullglob; fi
unset DW_NG
```

見つからなければ「dev-workflow プラグインが見つからない」と報告して終了する。

### 2. まず `--dry-run` で足すキーを出す

```bash
bash "<プラグインルート>/scripts/synced-skills-name-only.sh" --dry-run
```

出力をそのまま利用者に見せる。「同期スキルが無い」「足すキーは無い」と出たら、そのことを伝えて終了する（何も書いていない）。非 0 で終わったら、標準エラーの理由を伝えて終了する。

### 3. 書いてよいか AskUserQuestion で確認する

足す予定のキーの一覧と、書き換える `settings.json`（`CLAUDE_CONFIG_DIR` があればその下、無ければ `~/.claude/settings.json`）を見せて、適用してよいか聞く。断られたらスクリプトを `--dry-run` なしで呼ばずに終了し、`settings.json` は変えていないと伝える。

### 4. 適用する

```bash
bash "<プラグインルート>/scripts/synced-skills-name-only.sh"
```

足したキーとバックアップのファイル名（`settings.json.bak-<日時>`）を報告する。既にあるキーの値は変えない。同期スキルが後から増えたら、もう一度実行すると増えた分だけ足される。

## 元に戻す

- バックアップを戻す: `cp ~/.claude/settings.json.bak-<日時> ~/.claude/settings.json`（その後に入れた他の設定変更も戻る）
- 足したキーだけを消す: `jq 'del(.skillOverrides["anthropic-skills:<名>"])' ~/.claude/settings.json`（出力を一時ファイルに書いてから置き換える）。キーは手順 4 の出力に出ている

## 注意

- 実測は Claude Code 2.1.314（同期スキル 13 本で、最初のリクエストが 9,282 バイト減った）。同期スキルに `skillOverrides` が効くことは公式文書に書かれていない
- `name-only` にすると、名前を指定しない依頼でスキルが自動で選ばれにくくなる可能性がある（比較していない）。名前で指定すれば使える
- hook から自動では呼ばない。確認なしに `settings.json` を書き換えない

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
