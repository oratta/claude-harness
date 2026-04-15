# experience-to-skill

Claude Code での作業履歴（コミット差分 + セッション jsonl）を素材に、LLM 駆動で **都度コミット → verified タグで検証点記録 → 区間から skill を蒸留する** 統合ワークフローを提供するプラグイン。

## Overview

LLM との共同開発では、試行錯誤・決定・学びが会話と編集差分に分散して蓄積される。本プラグインはそれを「再利用可能な skill」として抽出できる状態に持ち込むための3段階アーキテクチャを提供する：

```
[作業中]
  ↓ 作業完了フレーズ / archive / /e2s:commit
  experience-to-skill スキル（auto-trigger）
    ├─ 自セッション編集ファイル特定（LLM context から）
    ├─ secret filter（Layer 1 正規表現 + Layer 2 LLM review）
    └─ Conventional Commits subject + Intent/Result/Prompted-by body でコミット
  ↓
[検証完了]
  ↓ /e2s:ok
  verified/YYYYMMDD-HHMMSS-<label> タグ付与
  ↓
[区間の振り返り]
  ↓ /e2s:reflect
  verified タグ区間の commit + session jsonl を分析 → skill 候補提示
  ↓ /e2s:distill <id>
  候補を SKILL.md に実体化
```

**特徴:**

- **Stop hook を使わない**: LLM駆動コミットなのでマルチセッション並行実行時の衝突がない
- **外部状態ファイルなし**: セッション context のみで自編集ファイルを判定、state 管理ゼロ
- **secret filter 二重構造**: 正規表現 + LLM review で credentials 混入を防ぐ
- **安全な巻き戻し**: `/e2s:rewind` は必ず backup タグを先に打つ

## Quick Start

### インストール

```
/plugin install experience-to-skill@oratta-claude-harness
/reload-plugins
```

### 初回確認

任意のリポジトリで以下を実行して動作確認：

```
# 適当なファイルを編集した後...

/e2s:status      # 現在の状態を表示
/e2s:commit      # 編集した内容をコミット（LLM が Intent/Result を生成）
/e2s:ok          # 動作確認 OK なら verified タグ付与
```

以降は作業完了時に「確認お願いします」「完了」「done」などのフレーズを入れるだけでスキルが auto-trigger してコミットが走る。

## Commit Message Format

生成されるコミットメッセージのフォーマット：

```
<type>(<scope>): <imperative subject, 50 chars max>

Intent: <ユーザーが達成したかったこと 1-2行>
Result: <何が起きたか・どう解決したか 1-3行>
Prompted-by: <session-id>#turn-<N>

🤖 via experience-to-skill
```

**Type**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`（Conventional Commits 準拠）

**Intent と Result の書き分け**:
- Intent = ユーザーが何をしたかったか（抽象化、プロンプト原文は転記しない）
- Result = 何がコミットとして残ったか（差分から導出）

**Prompted-by**: session-id + turn 番号のポインタのみ。プロンプト本文は**絶対に埋め込まない**（secret / PII 混入リスク回避）。

## Verified Tags

動作確認済みコミットには `verified/YYYYMMDD-HHMMSS-<label>` 形式の lightweight tag を付ける：

- **付与**: `/e2s:ok [label]` でタグ作成
- **巻き戻し**: `/e2s:rewind [tag]` で verified タグへ reset（必ず backup タグを先に作成）
- **一覧**: `/e2s:ok --list` または `/e2s:rewind --list`

verified タグは `/e2s:reflect` の分析区間境界としても機能する。

## Skill Distillation

```
/e2s:reflect                              # 最新 verified タグ以降を分析
/e2s:reflect verified/A..verified/B       # 区間指定
/e2s:reflect --last 50                    # 直近50コミット

/e2s:distill <candidate-id>               # 候補を SKILL.md として書き出し
```

分析はコミットと session jsonl（Prompted-by trailer 経由）を突き合わせて行う。session jsonl が削除・紛失されている場合は `session-unavailable` とマークしてコミット情報のみで分析を続行する。

生成される SKILL.md は：

- `<repo>/.claude/skills/distilled/<name>/SKILL.md` (プロジェクトローカル)
- `~/.claude/skills/distilled/<name>/SKILL.md` (ユーザーグローバル)

のいずれかに配置（ユーザー選択）。frontmatter の `name:` は必ず `e2s-` または `distilled-` prefix 付き。

## Security（secret filter）

すべてのコミット実行前に以下2層の secret filter が走る：

### Layer 1: 決定論的

- **ファイルパス除外**: `.env*`, `*.key`, `*.pem`, `credentials.*`, `*_secret*`, `id_rsa*` 等は無条件除外
- **コンテンツ正規表現**: AWS access key / OpenAI API key / Anthropic API key / GitHub token / JWT / PEM block / 汎用 hex secret patterns をスキャン

Layer 1 で検出されたらコミット中断、ユーザーに詳細報告（該当ファイル・行・先頭12文字だけの抜粋）。

### Layer 2: LLM semantic review

Layer 1 通過後、LLM が差分全体を一度レビューして、独自形式トークン / PII / URL に埋め込まれた credentials / コメント内の「仮」credentials を検出する。疑わしければコミット中断。

## Multi-Session Behavior

同一リポジトリで複数の Claude セッションが並行動作している場合：

1. 各セッションの context は独立しているので、「自セッションが編集したファイル」は context から一意に特定できる
2. `git status` には両セッションの変更が見えるが、各スキル実行時に**自セッション編集分とだけ交集合**を取ってステージングする
3. race condition は原理的に発生しない

**両セッションが同じファイルを同時編集した場合**は通常の git 挙動と同じく、後にコミットする側が前の変更を巻き込む。これは受容する設計。

`/e2s:status` で「どのファイルが自セッション由来か」を可視化できる。

## Session jsonl の場所と挙動

Claude Code のセッションログは `~/.claude/projects/<project-hash>/<session-id>.jsonl` に保存される。

- `<project-hash>` は現在の working directory から git リポジトリルートを導出して hash 化したもの
- `<session-id>` は UUID で、`$CLAUDE_SESSION_ID` 環境変数から取得（なければ最新 jsonl から推定）
- `/e2s:reflect` は `Prompted-by` trailer の `<session-id>#turn-<N>` を使って jsonl を読み戻す

### Graceful fallback

session jsonl が見つからない場合（削除・手動 cleanup・別ユーザー環境）:

- エラーで中断しない
- 該当 source を `session-unavailable` とマーク
- commit 情報のみで `/e2s:reflect` 分析を続行

## Relationship to skill-creator

本プラグインは公式 `skill-creator` とは明確に役割が異なる：

| 側面 | `skill-creator` | `experience-to-skill` |
|---|---|---|
| 起点 | ゼロから新規スキルを設計 | 既にやった作業履歴から蒸留 |
| 入力 | 明示的な設計入力（説明・手順・評価基準） | コミット履歴 + session jsonl |
| 出力 | `.claude/skills/<name>/SKILL.md` | `.claude/skills/distilled/<name>/SKILL.md` |
| 出力名 prefix | なし（`<name>`） | `e2s-<name>` または `distilled-<name>` |
| 使いどころ | 「こういうスキルが欲しい」がある時 | 「この作業パターンを定着させたい」がある時 |

両者は**共存できる**:

- ディレクトリ分離: 本プラグインは `distilled/` サブディレクトリに配置
- 名前 prefix: frontmatter の `name` に `e2s-` か `distilled-` が必ず付く
- コマンド分離: 本プラグインは `/e2s:*` prefix、skill-creator は独自コマンド

## Installation

```
/plugin install experience-to-skill@oratta-claude-harness
/reload-plugins
```

インストール時に `~/.claude/rules/git-commit-policy.md` が**書き換えられる**（BREAKING）。旧ポリシーは「明示承認なしのコミット絶対禁止」だったが、新ポリシーは「作業完了単位の自動コミット許可 + push/reset/amend は引き続き承認必須」になる。

## Uninstall

```
/plugin uninstall experience-to-skill@oratta-claude-harness
/reload-plugins
```

**注意**: アンインストールしても `~/.claude/rules/git-commit-policy.md` は**自動復旧されない**。旧ポリシーに戻したい場合は手動で書き換えるか、プラグイン導入前の commit から該当ファイルだけ checkout する：

```bash
# 該当コミットを探す
git log --oneline ~/.claude/rules/git-commit-policy.md

# 旧版を復元
git checkout <pre-plugin-commit> -- ~/.claude/rules/git-commit-policy.md
```

verified / backup タグを削除したい場合:

```bash
# ローカルのみ（push はしていない前提）
git tag --list "verified/*" | xargs -r git tag -d
git tag --list "backup/*" | xargs -r git tag -d
```

## Limitations

### Prompted-by のローカル限定性

`Prompted-by: <session-id>#turn-<N>` は、そのセッションの jsonl が `~/.claude/projects/` に存在する限り意味がある。以下の状況では**解決不能**になる：

- 他のマシン / 他のユーザーで `git log` を見た時（jsonl は共有されていない）
- 古いセッションを手動で cleanup した後
- Claude Code を再インストールして `~/.claude/projects/` がリセットされた時

個人ループ（同じマシンで作業・振り返りする）では機能するが、チーム共有には不向き。

### Session jsonl の保存期限

Claude Code は基本的に session jsonl を自動削除しないが、ディスク容量の事情で手動 cleanup される可能性はある。重要な区間は `/e2s:reflect` を早めに実行して候補化しておくのが安全。

### verified タグの数

verified タグは作るたびに増えていく。100個を超えたあたりで `git tag --list "verified/*"` が見づらくなる。現時点では自動クリーンアップ機能はないので、必要に応じて手動で `git tag -d <古いタグ>` するか、将来の `/e2s:gc`（未実装）を待つ。

### 両セッション同一ファイル編集

マルチセッション safety は「違うファイルを編集している場合」に成立する。同じファイルを両セッションで同時編集すると、後にコミットする側が前の変更を巻き込む。これは git の通常挙動であり、本プラグインでは解決しない。

## 参照

- メインスキル: `skills/experience-to-skill/SKILL.md`
- スラッシュコマンド: `commands/e2s-*.md` (6本)
- OpenSpec 仕様: `openspec/specs/experience-to-skill-commit/`, `-verified-tags/`, `-distillation/`
- OpenSpec change（導入時の経緯）: `openspec/changes/experience-to-skill-plugin/`
