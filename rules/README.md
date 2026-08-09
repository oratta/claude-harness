# rules/ — Claude Code グローバルルール集

全プロジェクト共通で Claude Code に読み込ませる行動ルール。`~/.claude/rules/*.md` として配置すると全セッションの冒頭に読み込まれる。

実運用で繰り返し起きた問題（認知負荷・事故・手戻り）から抽出したエッセンスだけを置く。事故の具体的経緯・個人向けの詳細な分析はローカルの `~/.claude/rules-archive/`（repo には含めない）に保存する方針。

## 導入

marketplace として install 済みなら、各ファイルを `~/.claude/rules/` に symlink する:

```bash
HARNESS=~/.claude/plugins/marketplaces/oratta-claude-harness
mkdir -p ~/.claude/rules
for f in "$HARNESS"/rules/*.md; do
  [ "$(basename "$f")" = "README.md" ] && continue
  ln -sf "$f" ~/.claude/rules/"$(basename "$f")"
done
```

- symlink 先は marketplace dir（plugin 更新で再 clone されても tracked ファイルなので復元される）
- ローカル限定のルールを追加したい場合は、symlink せず `~/.claude/rules/` に実ファイルとして置けばよい（共存可能）

## ファイル一覧

| ファイル | 内容 |
|---|---|
| `communication-style.md` | 参照は中身で書く・比喩を作らない・判断依頼は背景から推奨まで・ヒアリングは1問ずつ（全文は Output Style `readable` が正本） |
| `destructive-git-guard.md` | 破壊的 git 操作の事前承認必須と「戻すだけ」自己正当化への警戒 |
| `git-commit-policy.md` | 細かい自律コミット・PR運用/ローカルmain運用の判定・承認が要る操作 |
| `browser-infra-env-capture.md` | ダッシュボード操作で生成された認証情報の即時 env 保存 |
| `link-when-requesting-review.md` | 人間に確認を求めるときは必ずクリック可能なフル URL を添える |
| `plugin-editing.md` | プラグイン編集は marketplace 版のみ・バージョン同期 |
| `dev-server.md` | 他プロジェクトのプロセス kill 禁止・ポート運用 |
