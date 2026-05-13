# experience-to-skill

Claude Code セッションの jsonl ログを素材に、**自然言語の依頼で SKILL.md を蒸留する**ための専門プラグイン。コミット運用には一切関与せず、`/e2s:distill` 1 コマンドで対話完結する。

## Overview

Claude Code は `~/.claude/projects/<encoded-cwd>/*.jsonl` にセッションの全履歴を網羅的に書き出している。本プラグインはこの jsonl を「後から自然言語で参照してスキル化する」素材として活用するためのツールで、以下の特徴を持つ：

- **後付け・自然言語起動**: 「先週やった動画生成の作業をスキル化して」のような自然な依頼で起動できる。事前準備（verified タグ・commit 整形）は不要
- **対話完結 1 コマンド**: 旧 `reflect → distill` 2 段階フローを廃し、`/e2s:distill` 1 コマンドで（jsonl 探索 → 候補絞り込み → サニタイズ → SKILL.md 書き出し）まで完了
- **限定的な auto-trigger**: スキル化依頼フレーズ（「スキル化して」「スキルにして」等）にのみ反応。コミット完了や archive 完了では起動しない（コンテキスト浪費を抑制）
- **PII / secret 2 層サニタイズ**: Layer 1（正規表現セット） + Layer 2（LLM 意味判定）の二重防衛

## Quick Start

### インストール

```
/plugin install experience-to-skill@oratta-claude-harness
/reload-plugins
```

### 使い方

任意のリポジトリで（過去にそのディレクトリで Claude Code を起動していれば）：

```
/e2s:distill 先週どこかで動画の生成を行ったと思う。最終的に成功したプロセスをスキルにしてほしい
```

または対話の流れで：

```
ユーザー: そういえばこの作業、スキル化しておきたいんだけど
LLM: experience-to-skill スキルが起動。/e2s:distill フローに沿って候補を提示...
```

`/e2s:distill` を引数なしで実行すると、cwd の jsonl 一覧（日付・サイズ）が表示され、ユーザーが自然言語で絞り込みヒントを与えるところから対話が始まる。

## アーキテクチャ

```
[後付けのスキル化依頼]
  ↓ /e2s:distill <自然言語指示>  または  「〜スキル化して」フレーズ
  experience-to-skill skill / e2s-distill command
    ├─ jsonl-finder.sh: cwd → ~/.claude/projects/<encoded>/ 解決 (逆引きフォールバック付き)
    ├─ 4 段スキャン: dir 確認 → mtime → サイズ 50MB → grep
    ├─ 候補提示 → ユーザー選択
    ├─ ターン抽出（成功手順周辺）
    ├─ Layer 1 サニタイズ (sanitize.sh: 正規表現セット)
    ├─ Layer 2 サニタイズ (LLM 意味判定)
    └─ SKILL.md 書き出し (e2s-/distilled- prefix 必須)
  ↓
[配置先選択]
  - <repo>/.claude/skills/distilled/<name>/SKILL.md  (プロジェクトローカル)
  - ~/.claude/skills/distilled/<name>/SKILL.md       (ユーザーグローバル)
```

## 起動条件（厳格）

スキル auto-trigger 対象フレーズ：

- 「〜をスキル化して」「〜をスキルにして」
- 「過去の作業からスキルを作って」
- 「振り返ってスキル抽出して」
- 「先週の〜の作業をスキルにしておいて」
- `/e2s:distill` の明示起動

**意図的に起動しないケース**:

- 「完了です」「done」「commit して」のような汎用完了フレーズ
- `longrun:archive` / `openspec:archive` の完了通知
- ファイル編集完了の assistant 報告

これは旧 e2s が全コミット境界で起動してコンテキストを浪費した反省を踏まえている。

## jsonl ディレクトリ命名規約

`~/.claude/projects/` 配下のディレクトリ名は cwd 絶対パスを以下のルールで変換したもの：

- `/` → `-`
- `.` → `-`（連続ハイフンも保持）

実例:

| cwd | encoded directory |
|---|---|
| `/Users/oratta/foo/bar` | `-Users-oratta-foo-bar` |
| `/Users/oratta/.claude-mem` | `-Users-oratta--claude-mem` |
| `/Users/oratta/.superset/worktrees/abc/foo-bar` | `-Users-oratta--superset-worktrees-abc-foo-bar` |

規約未知の文字や Claude Code 側の細部差異に備えて、`scripts/jsonl-finder.sh` の `e2s_resolve_jsonl_dir` は **逆引きフォールバック**（cwd の prefix が一致する `~/.claude/projects/<entry>` の longest prefix match を優先）を併設している。

## サニタイズ

### Layer 1: 決定論的（`scripts/sanitize.sh`）

stdin から読み、以下のパターンを `[REDACTED:<kind>]` に置換して stdout に書く：

- AWS access key (`AKIA[0-9A-Z]{16}`)
- OpenAI API key (`sk-[a-zA-Z0-9]{20,}`)
- Anthropic API key (`sk-ant-[a-zA-Z0-9_\-]{20,}`)
- GitHub token (`ghp_*`), GitHub PAT (`github_pat_*`)
- Slack token (`xox[baprs]-*`)
- JWT (`eyJ...eyJ...`)
- PEM private key block start
- Email address

### Layer 2: LLM 意味判定（SKILL.md / command 内に記述）

Layer 1 通過後のテキストを LLM が再レビューし、独自形式トークン・PII（個人名 + 識別子）・URL embedded credentials・TODO/FIXME 仮 credentials を抽象化または削除する。判断に自信がない場合は必ずユーザーに確認する。

## SKILL.md 命名規約

生成される SKILL.md の frontmatter `name:` は必ず `e2s-` または `distilled-` prefix 付き。デフォルトは `e2s-` を使う。これは本家 `skill-creator` との衝突回避 + 蒸留由来であることを明示するため。

## ファイル構成

| パス | 役割 |
|---|---|
| `skills/experience-to-skill/SKILL.md` | auto-trigger スキル本体（スキル化依頼フレーズ限定） |
| `commands/e2s-distill.md` | 対話完結 1 コマンドの実行手順 |
| `scripts/jsonl-finder.sh` | jsonl 列挙の補助シェル関数（encode_cwd / resolve_jsonl_dir / list_jsonl） |
| `scripts/sanitize.sh` | Layer 1 サニタイズ関数 `e2s_sanitize` |
| `tests/jsonl-finder.bats` | jsonl-finder ユニットテスト（Bats） |
| `tests/sanitize.bats` | サニタイズユニットテスト（Bats） |
| `tests/fixtures/sample-session.jsonl` | テスト用 fixture（PII / secret 含まないことを sanitize idempotent でアサート） |
| `.claude-plugin/plugin.json` | Claude Code プラグインメタデータ |

## テスト実行

```bash
bats plugins/experience-to-skill/tests/*.bats
```

shell 補助関数のユニットテストのみカバーする。LLM が jsonl を読んで判断する部分（候補絞り込み・成功手順抽出・Layer 2 意味判定）はユニットテスト不能なので、fixture jsonl による手動 E2E で担保する。

## 旧版からの BREAKING 変更

このプラグインは **0.2.0 で全面リファクタ** された。旧 0.1.0 にあった以下の機能はすべて削除：

- `experience-to-skill` skill の auto-commit 機能（コミット運用に関与しなくなった）
- `/e2s:commit` `/e2s:ok` `/e2s:rewind` `/e2s:status` `/e2s:reflect` コマンド（全削除）
- verified タグ / backup タグ機構
- session jsonl の Prompted-by trailer 参照（コミット境界の概念自体を廃止）

旧版を必要とする場合は git 履歴から該当コミットを参照すること。

## アンインストール

```
/plugin uninstall experience-to-skill@oratta-claude-harness
/reload-plugins
```

本プラグインはユーザーグローバル設定（`~/.claude/rules/*` など）を書き換えないので、アンインストール後の追加クリーンアップは不要。生成済みの `~/.claude/skills/distilled/e2s-*/SKILL.md` は残るが、必要に応じて手動で削除できる。

## skill-creator との関係

本プラグインは Claude 本家の `skill-creator` とは役割が明確に異なる：

| 側面 | `skill-creator` | `experience-to-skill` |
|---|---|---|
| 起点 | ゼロから新規スキルを設計 | 既に終わった作業の jsonl から蒸留 |
| 入力 | 明示的な設計入力 | セッション jsonl + 自然言語の依頼 |
| 出力 prefix | なし | `e2s-` または `distilled-` |
| 配置先 | `.claude/skills/<name>/` | `.claude/skills/distilled/<name>/` |
| 使いどころ | 「こういうスキルが欲しい」がある時 | 「あの作業をスキル化したかった」と後から気づいた時 |

両者は共存可能。ディレクトリ分離 (`distilled/`) と name prefix で衝突回避。

## 制約

- jsonl が存在しないディレクトリ（Claude Code 起動実績ゼロの cwd）では `/e2s:distill` は動かない
- jsonl が大きすぎる場合（デフォルト 50MB 超）は事前にサイズフィルタで除外される。`E2S_JSONL_MAX_SIZE` で上書き可能
- claude-mem MCP 連携は本プラグインの範囲外（別関心事、将来別途検討）
