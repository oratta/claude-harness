# dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。今は `github-issue` スキル1つだが、コミット規約・PR規約など「開発するときはこうする」という汎用的な手順が増えたら、ここに追加していく想定。

## 含まれるスキル

### github-issue

GitHub issue（番号・URL・自然文）に取り組む時の標準ワークフロー。

- worktree 上なのに `wt-setup` が未実行なら先に実行する
- 仕様として残すべき変更なら opsx（openspec）フローに乗せ、そうでなければコード直行する
- 単一 change で足りるか複数 change に割れるかを判定し、複数なら change ごとに分けて処理する
- 全経路で TDD（テスト先行）を徹底する

人間が `/work-issue` で直接依頼した場合でも、`loops` プラグインの loop-dev-agent が無人サイクルの中から呼ぶ場合でも、同じ判定ロジックを共有する（`--unmanned` で無人モードに切り替え）。

## コマンド

| コマンド | 説明 |
|---|---|
| `/work-issue [issue番号\|URL\|自然文]` | github-issue スキルを interactive モードで起動する |

## loop-dev-agent との関係

`loops` プラグインの loop-dev-agent（無人常設ループ）は、実装モード（Step 3）の中身をこのプラグインの `github-issue` スキルに委譲する。ラベル操作・Draft PR 作成・Review Queue 連携などの「無人運用の外形」は引き続き loop-dev-agent 側の責務。詳細は `github-issue/SKILL.md` の「このスキルの立ち位置」を参照。

```bash
/plugin install dev-workflow@oratta-claude-harness
```
