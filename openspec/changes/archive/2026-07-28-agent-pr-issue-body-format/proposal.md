# Proposal: agent-pr-issue-body-format

## Why

自律開発ループ（loop-dev-agent）が書く PR / issue 本文が人間の承認判断に耐えない。技術的な変更内容しか書かれておらず、「これを入れると何が良くなり、何が壊れうるのか」を読み手が diff から自力で復元する必要がある。PR 本文の構造化ルールは現状存在せず（`agent-loop-template.md` の「`Closes #<番号>` と検証ログを書き」の一文のみ）、改善ではなく新設が必要。一方で本文は別セッションの LLM も読む（引き継ぎ・現状把握）ため、人間向けの平易化と LLM 向けの技術文脈保持を 1 つの型で両立させる（issue #47）。

## What Changes

- `plugins/loops/references/pr-body-format.md` を新設: PR 本文 5 セクション型（これで何が変わるか / 良くなること・悪くなりうること / 壊れうるポイント / 動作確認ポイント / 実装メモ）＋設計原則（順序・翻訳の規律・ネガティブ欄の根拠必須・行数上限）＋翻訳の良い例/悪い例 3 組＋軽量モード規定
- `plugins/loops/templates/agent-loop-template.md` の Step 3-5「本文に `Closes #<番号>` と検証ログを書き」を新 reference への参照に差し替え
- `plugins/loops/skills/loops-issueify/SKILL.md` の issue ドラフト構造に承認判断用 2 節（「これで何が変わるか」「やらないとどうなるか / 今のコスト」）を先頭追加
- `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 3 の `agent-task.md` テンプレートに同 2 節を追加
- `plugins/dev-workflow/commands/work-issue.md` の fail-soft 縮退手順（issue 構成の簡略版）を追従
- plugin.json バージョン更新: loops 0.16.1 → 0.17.0、dev-workflow 1.5.0 → 1.5.1

決定済みの設計判断（issue #47 の D-1〜D-5）:

- **D-1**: 置き場所は `plugins/loops/references/`（既存 references/ 慣例に合致、PR 本文生成の実体が loops 側にあるため）
- **D-2**: Git trailer 形式の機械可読メタデータは初版不採用。実装メモの散文に一本化（「同じ情報を 2 回書かない」原則との衝突・乖離リスク回避）
- **D-3**: 軽量モードはエージェントの自己判断＋PR 冒頭に適用理由 1 行明記（ラベル基盤の追加不要。理由行で導入後評価が可能。ユーザー決定 2026-07-28）
- **D-4**: flatmate 本体の `PULL_REQUEST_TEMPLATE.md` 新設は別リポジトリのためスコープ外（issue にフォローアップ記載）
- **D-5**: 誇張防止として「動作確認ポイントで検証できないことは『これで何が変わるか』に書いてはならない」制約を採用（主張と検証手順の 1:1 紐付け）

## Capabilities

### New Capabilities

- `loops-pr-body-format`: エージェントが書く PR / issue 本文の構造化フォーマット。5 セクション型・二重読者（人間の承認判断 + LLM の引き継ぎ）設計原則・軽量モード・誇張防止制約と、loops / dev-workflow 両プラグインからの参照配線を規定する

### Modified Capabilities

- `dev-workflow-issue-entry`: issueify フォールバックの fail-soft 縮退手順が生成する issue ドラフトの最小構成に、承認判断用 2 節（「これで何が変わるか」「やらないとどうなるか / 今のコスト」）が加わる

## Impact

- 影響コード: `plugins/loops/references/`（新規）、`plugins/loops/templates/agent-loop-template.md`、`plugins/loops/skills/loops-issueify/SKILL.md`、`plugins/loops/skills/loops-dev-agent-install/SKILL.md`、`plugins/dev-workflow/commands/work-issue.md`、両 plugin.json
- 導入先リポジトリへの波及: `docs/agent-loop.md` はテンプレート由来の生成物のため、flatmate 本体＋workspace 各リポジトリへの反映（`/loops:dev-agent-install` 再実行 or 手動 diff）が別途必要（本 change のスコープ外、issue #47 チェックリストに残置）
- コスト影響: 全 PR で本文生成トークンが増える。軽量モードで小型 PR の膨張を抑止
- 形骸化リスク: 導入後に実 PR 3 本で「冒頭 5 行で承認判断できたか」を評価する運用チェックが issue #47 に定義済み
