# infra-actions-freshness Specification

## Purpose
TBD - created by archiving change infra-fixes. Update Purpose after archive.
## Requirements
### Requirement: GitHub Actions version pins MUST match verified latest major tags

`plugins/infra/templates/workflows/*.yml.template` が pin する `actions/checkout` / `actions/setup-node` / `actions/upload-artifact` / `actions/github-script` / `supabase/setup-cli` の各バージョンは、実装時点で `gh api /repos/<owner>/<repo>/tags` により実在確認された最新メジャータグでなければならない。確認できなかった action は現行バージョンを維持し、その旨を該当テンプレート内にコメントで注記しなければならない。This requirement MUST be satisfied.

#### Scenario: No stale v4 pins for checkout/setup-node remain

- **WHEN** `grep -rn "actions/checkout@v4\|actions/setup-node@v4" plugins/infra/templates/workflows/` を実行する
- **THEN** 一致件数は 0 件でなければならない

#### Scenario: No stale v4 pin for upload-artifact remains

- **WHEN** `grep -rn "actions/upload-artifact@v4" plugins/infra/templates/workflows/` を実行する
- **THEN** 一致件数は 0 件でなければならない

#### Scenario: No stale v7 pin for github-script remains

- **WHEN** `grep -rn "actions/github-script@v7" plugins/infra/templates/workflows/` を実行する
- **THEN** 一致件数は 0 件でなければならない

#### Scenario: No stale v1 pin for supabase/setup-cli remains

- **WHEN** `grep -rn "supabase/setup-cli@v1" plugins/infra/templates/workflows/` を実行する
- **THEN** 一致件数は 0 件でなければならない

#### Scenario: All five workflow templates still pass node --check equivalent (YAML parse)

- **WHEN** バージョン bump 後の各 `.yml.template` を `render-workflow` 相当の置換処理を経て YAML としてパースする（例: `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))"` または同等ツール）
- **THEN** 5 ファイル全てがパースエラーなく成功しなければならない

### Requirement: Vercel Token CLI feasibility MUST be documented with the investigation outcome

`agents/infra-phase-4-github-actions.md` と `skills/infra-setup/SKILL.md` は、Vercel Token 取得を CLI 化できるかを検証した結果（検証日時点で Vercel CLI に `tokens`/`token` サブコマンドが存在しないため CLI 化不可と判定したこと）を明記しなければならない。既存の Playwright MCP / 手動フォールバック方式のロジック自体は変更してはならない。This requirement MUST be satisfied.

#### Scenario: Investigation note present in Phase 4 agent

- **WHEN** `agents/infra-phase-4-github-actions.md` の Vercel Token 取得ステップ（Step 5）を読む
- **THEN** CLI 化を検証し不可と判定した旨の注記が存在しなければならない

#### Scenario: Investigation note present in SKILL.md

- **WHEN** `skills/infra-setup/SKILL.md` の「技術メモ」節にある Vercel Token の記述を読む
- **THEN** CLI 化を検証し不可と判定した旨の注記が存在しなければならない

#### Scenario: Fallback logic is unchanged

- **WHEN** Step 5（自動モード / 手動モード）の分岐構造を変更前後で比較する
- **THEN** Playwright MCP 自動モードと手動モードの 2 分岐構造、および各モードの操作手順に実質的な差分がない（注記の追加のみ）ことを確認できる

