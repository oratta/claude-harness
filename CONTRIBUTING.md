# コントリビューションガイド

このリポジトリへの貢献を歓迎します!

## 貢献の種類

### 1. バグ報告

Issue を作成し、以下を含めてください：
- 再現手順
- 期待される動作
- 実際の動作
- 環境情報（Claude Code バージョン等）

### 2. 機能リクエスト

Issue で提案してください：
- ユースケースの説明
- 期待される動作
- 代替案の検討

### 3. プラグイン/スキルの追加

新しいプラグインやスキルを追加する場合：

#### プラグインの追加

1. `plugins/your-plugin-name/` を作成
2. 必須ファイル:
   - `.claude-plugin/plugin.json`
   - `README.md`
   - `skills/` または `commands/`
3. `.claude-plugin/marketplace.json` を更新

#### スキルの追加

1. `skills/your-skill-name/` を作成
2. 必須ファイル:
   - `SKILL.md`（フロントマター必須）
3. `.claude-plugin/marketplace.json` を更新

## 品質基準

### SKILL.md の要件

```yaml
---
name: skill-name           # 必須: kebab-case
description: "..."         # 必須: 第三者視点、トリガーフレーズを含む
version: 1.0.0             # 必須: SemVer
---
```

### 命名規則（Skill / Agent / Command）

種別ごとに命名を分けることで、ユーザーと Claude の両方が「これは何か」を見た瞬間に判別できる。Claude Code では Skill / Agent / Command が同じディスカバリカタログに混在表示されるため、名前から種別を区別できないと誤起動（例: Skill を Agent tool で起動して失敗）の温床になる。

| 種別 | 形 | 意味論 | 例 |
|---|---|---|---|
| **Skill** | 名詞（プロセス・能力・成果物） | 「これは○○の能力です」 | `infra-setup`, `longrun-plan`, `weekly-report`, `longrun-orchestration` |
| **Agent** | `-er` / `-or`（人格・役割） | 「これは○○する人/役です」 | `code-reviewer`, `longrun-builder`, `longrun-verifier` |
| **Command** | 動詞（命令） | 「○○せよ」 | `/wt-setup`, `/exec`, `/archive` |

#### NG パターン

- **Skill 名を `-er` / `-or` で終わらせない**: Agent と区別がつかず、Skill tool / Agent tool のどちらで呼ぶべきか命名から判断できない。
  - 悪い: `data-fetcher`, `image-processor`
  - 良い: `data-fetching`, `image-processing`
- **Command 名を `-er` / `-or` で終わらせない**: 動詞由来の slash command という慣習が崩れる。

### 記述スタイル

- 命令形を使用（「〇〇する」ではなく「〇〇すること」）
- 第二人称を避ける（「あなたは」を使わない）
- 具体例を含める
- リファレンスは `references/` に分離

### テスト

- 実際に Claude Code で動作確認
- エッジケースの考慮
- エラーハンドリング

## プルリクエスト

1. Fork してブランチを作成
2. 変更を加える
3. テストを実行
4. PR を作成

### PR テンプレート

```markdown
## 概要
[変更内容の簡潔な説明]

## 変更の種類
- [ ] 新規プラグイン
- [ ] 新規スキル
- [ ] バグ修正
- [ ] ドキュメント更新

## チェックリスト
- [ ] SKILL.md のフロントマターが正しい
- [ ] marketplace.json を更新した
- [ ] README を更新した
- [ ] 動作確認済み
```

## ライセンス

貢献されたコードは MIT ライセンスの下で公開されます。
