---
catalog_version: 1
---

# 委任宣言（この repo で働くエージェント共通）

「委任＝許可ツール × 任された観点」の宣言を 1 か所に書くファイル。定義の正本は casting プラグイン内の
delegation.md（インストール先 `~/.claude/plugins/marketplaces/*/plugins/casting/catalog/delegation.md`）。

**この 2 表は要約であり正本ではない。** 許可ツールの正本は Claude Code の permission 設定
（`.claude/settings.json` / `settings.local.json` の allow / deny）、任された観点の正本は配役表の 3 層
（`project.md` → `local.md` → セッション宣言。合成結果は
`~/.claude/plugins/marketplaces/*/plugins/casting/scripts/casting-check.sh resolve <repoルート>`）。
食い違ったら正本が勝つ。permission や配役表を変えたら、この表の該当行も同じ変更で直す。
任された観点表は第 3 層の上書きではない（観点の担い手を変えるのは `project.md` の 5 列行）。

## 委任

### 許可ツール

`許可` 列は「許可／要承認／禁止」の 3 語。`出どころ` はその許可がどこで決まっているか（settings のパス・主の指示・ロール名）。

<!--
記入例（コメントアウト。実際に書くときはコメントを外して値を書き換える）:
| Bash(npm test:*) | 許可 | .claude/settings.json allow |
| Bash(git push:*) | 要承認 | 主の口頭指示（2026-08-28） |
-->

| ツール/パターン | 許可 | 出どころ |
|---|---|---|

### 任された観点

`観点` は catalog.md の語彙、`担い手` は「エージェント／主」、`根拠` はどの層の行から来ているか（カタログ既定／project.md／local.md）と移譲文書のファイル名。

<!--
記入例:
| 財務・コスト | エージェント | project.md（予算方針文 policies/budget.md） |
| 信用・レピュテーション | 主 | カタログ既定 |
-->

| 観点 | 担い手 | 根拠 |
|---|---|---|
| Bash(npm test:*) | 許可 | .claude/settings.json allow |
