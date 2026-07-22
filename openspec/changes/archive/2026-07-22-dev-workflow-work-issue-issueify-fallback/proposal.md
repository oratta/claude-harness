## Why

`/work-issue` は既存 issue の特定を前提としており、issue 未起票の依頼を渡すと「一覧提示で停止」する（issue #36）。一方、実行戦略の4象限判定（`dev-workflow-execution-strategy`）は github-issue パイプラインの Step B/C でしか発火しないため、issue を経由しないタスクは判定系に一度も乗らない配線ギャップがある。issue #26 の設計判断（自動の入口分類は却下）を守ったままこのギャップを埋めるには、**ユーザーが明示的に起動する `/work-issue` 自体を入口ルーターに拡張する**のが最小手段である。

## What Changes

- `/work-issue` の引数解釈を5分岐に拡張する: 対象 issue が特定できない場合（番号不存在・自然文マッチなし・引数なしで新規希望）、`loops-issueify` の手順を読み込んで issue を起票してから、起票された番号で `github-issue` パイプラインに接続する
- 番号指定で issue が不存在の場合は、新規作成に直行せず **typo 確認を先に行う**（近い番号の提示 → ユーザーが希望した場合のみ起票フローへ）
- `loops-issueify` は github-issue と同じ path-discovery パターンで解決し、loops プラグイン未導入時は **fail-soft**（測定可能な受け入れ条件付きの最小 `gh issue create` 手順にフォールバック）とする
- issueify の原子化で複数 issue に割れた場合は「全起票 → 着手する1件を選択 → 残りは起票のみ」とする
- 既存の分岐（番号/URL/自然文で issue が特定できるケース）の挙動は変更しない（純粋拡張）
- `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを 1.4.0 に上げる（marketplace キャッシュ反映のため必須）

## Capabilities

### New Capabilities

- `dev-workflow-issue-entry`: `/work-issue` コマンドの入口分岐仕様。対象 issue の特定（番号/URL/自然文/引数なし）と、特定できない場合の issueify フォールバック（起票 → github-issue 接続）、loops 未導入時の縮退動作を定める

### Modified Capabilities

（なし — `dev-workflow-execution-strategy` / `dev-workflow-escalation-tripwires` の要件は変えない。本 change はそれらの判定系に到達する経路を増やすだけ）

## Impact

- `plugins/dev-workflow/commands/work-issue.md` — 引数解釈の5分岐拡張 + issueify フォールバック節の追加
- `plugins/dev-workflow/.claude-plugin/plugin.json` — 1.3.0 → 1.4.0
- `plugins/dev-workflow/tests/work-issue-command.bats` — 新規（コマンド定義の構造検証）
- 依存: `plugins/loops/skills/loops-issueify/SKILL.md`（実行時に Read で読む疎結合。ビルド時依存なし）
- 影響を受けない: `skills/github-issue/SKILL.md`（呼ばれ方は従来と同一。issue 番号確定後に入る）
