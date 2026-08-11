# Proposal: loops-respond-mode

## Why

自律開発ループの入口はラベルしかない。人間が issue / PR にコメントを書いても、ラベルや
Review Queue の State が動かなければループは一生それを拾わない。結果「質問に答えた」
「追加情報を書いた」がループに届かず issue が黙って停滞し、人間は「書いても無駄」と学習する。

この穴を埋める**応答モード**（コメント本文の行頭メンションを最優先で拾って応答する）は
flatmate リポジトリにだけ実装され（`scripts/agent-loop-inbox.sh` / `agent-loop-reply.sh` と
選定スクリプトの Step 0.9 分岐）、**loops プラグインの配布テンプレートには存在しなかった**。
そのため `/loops:dev-agent-install` で導入した他リポジトリでは応答モードが永久に配線されず、
実際に genetta-inc/suimei で人間のコメントがループに届かない事故が起きている。

配布テンプレート側に無い機能は、導入先で「無いことに誰も気づけない」。テンプレートに載せ、
テストで存在を固定する。

## What Changes

- `plugins/loops/templates/agent-loop-inbox.sh` を新設（検出。検索 API 1 回 → 対象コメントのみ取得）
  - **行頭一致限定**・**投稿者アカウントを判定に使わない**・**ローカル状態ファイルを持たない**・
    **fail-open** という 4 つの設計判断を、根拠（自己発火の実測 2026-08-06 を含む）ごと移植する
- `plugins/loops/templates/agent-loop-reply.sh` を新設（返信投稿 + rocket 付与 + 投稿前の自己発火検査）
- `plugins/loops/templates/select-target.sh` に Step 0.9 の respond 分岐を追加
  （**他のどのモードよりも前・副作用を持つ処理よりも前**に判定して即 emit する）
- `plugins/loops/templates/agent-loop-template.md`（憲法テンプレ）の Step 0.9 に
  `respond` / `comment_id` / respond の `candidates` を追記し、応答モードの手順（Step 0.9b）を新設
- `plugins/loops/skills/loops-dev-agent-install/SKILL.md` を、選定スクリプト 1 本ではなく
  **3 本セット**を設置する手順に変更。メンションマーカーを `{{AGENT_MENTION}}` プレースホルダとして
  ヒアリングに追加し、既に導入済みのリポジトリへの後追い配線手順も足す
- `plugins/loops/tests/dev-agent-respond-mode.bats` を新設（テンプレの存在・設計意図コメント・
  respond の優先順位・install 手順を固定）。`tests/helper.bash` の
  `LOOPS_SCRIPT_ALLOWLIST` に新テンプレ 2 本を意図付きで追加

プロジェクト固有値は持ち込まない: マーカーは `{{AGENT_MENTION}}` プレースホルダ（実行時は
`AGENT_INBOX_MARKER`）、リアクションは `AGENT_INBOX_DONE_REACTION`（既定 `rocket`）、
リポジトリは `GH_REPO` か `gh repo view` で解決する。

## Capabilities

### Added Capabilities

- `loops-respond-mode`: 配布テンプレートが応答モード（人間の行頭メンションを最優先で拾い、
  対応済みを rocket リアクションで記録する）を含み、install スキルがそれを配線する

## Impact

- `plugins/loops/templates/agent-loop-inbox.sh`（新規）
- `plugins/loops/templates/agent-loop-reply.sh`（新規）
- `plugins/loops/templates/select-target.sh`（Step 0.9 分岐の追加。既存モードの挙動は不変）
- `plugins/loops/templates/agent-loop-template.md`（Step 0.9 の表と Step 0.9b の追加）
- `plugins/loops/skills/loops-dev-agent-install/SKILL.md`（設置手順・ヒアリング・後追い配線）
- `plugins/loops/tests/dev-agent-respond-mode.bats`（新規）/ `plugins/loops/tests/helper.bash`
- `plugins/loops/.claude-plugin/plugin.json`（0.20.0 → 0.21.0）/ `.claude-plugin/marketplace.json`
  （loops entry 同期・top-level 2.36.0 → 2.37.0。S128 / S130 / S131 / S132 の対象）
- 導入済みリポジトリ（suimei 等）は自動では直らない。SKILL.md の後追い配線手順で 3 本を配り直す必要がある
