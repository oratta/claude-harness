# infra-actions-freshness Specification

## Purpose
TBD - created by archiving change infra-fixes. Update Purpose after archive.
## Requirements
### Requirement: GitHub Actions version pins MUST match verified latest major tags

`plugins/infra/templates/workflows/*.yml.template` が pin する GitHub 公式 action（`actions/*`）の各バージョンは、実装時点で `gh api /repos/<owner>/<repo>/tags` により実在確認された最新メジャータグでなければならない。確認できなかった action は現行バージョンを維持し、その旨を該当テンプレート内にコメントで注記しなければならない。`actions/*` 以外のサードパーティ製 action は可変タグではなく 40 桁のコミット SHA で参照し、対応するバージョンを同じ行のコメントに併記しなければならない（下の別 Requirement で規定する）。This requirement MUST be satisfied.

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

### Requirement: Third-party actions in workflow templates MUST be pinned to a commit SHA

`plugins/infra/templates/workflows/*.yml.template` の `uses:` のうち GitHub 公式（`actions/*`）以外のものは、40 桁のコミット SHA で参照し、その SHA が指すバージョンを同じ行のコメントに併記しなければならない。テンプレートの展開先では production のデプロイ／マイグレーションという secrets を持つジョブで動くため、可変タグ／ブランチ参照（例: `supabase/setup-cli@v2` は tag ではなくブランチ）は上流の push だけで別コードの実行につながる。この検査は「抽出」「公式判定」「コメント形」の 3 点で fail-closed でなければならない — 抽出はキー形（`uses[[:space:]]*:`。コロン前の空白・行頭の `- `・キーの引用（`- "uses": ...` / `- 'uses': ...`）・flow mapping（`- { uses: ... }`）を許容する）を対象とし、公式判定は行全体の部分一致ではなく `uses:` の値の位置で行い、コメントはバージョンらしい形（`v` 省略可の数値列。直後は空白か行末で終わる）でなければならない。This requirement MUST be satisfied.

#### Scenario: Every third-party `uses:` in the templates carries a SHA and a version comment

- **WHEN** `plugins/infra/templates/workflows/` 配下の全 `*.yml.template` から、キー形（正規表現 `^[[:space:]]*-?[[:space:]]*["']?uses["']?[[:space:]]*:`）または flow mapping 形（正規表現 `^[[:space:]]*-?[[:space:]]*\{[^#]*["']?uses["']?[[:space:]]*:`。`[^#]*` はコメント中の `uses:` を実在のキーと誤認しないための境界）に一致する行を全数抽出し、その値の直後に密着する flow mapping の終端記号（`}` `,`）は値に含めず、その `uses:` の**値**（行内で最初に現れるキーの値。前後の引用符は除く）が `actions/` で始まらないものを検査する
- **THEN** 値が `<owner>/<action>@<40 桁 16 進数>` の形（`<owner>` に `/` を含まず、`<action>` は `repo/subdir` のようなサブパスを許す）でなければならない
- **AND** 同じ行の**YAML 本文**に、`#` の直後（空白は挟んでよい）がバージョンらしい形（`v` は省略可、`1` / `v2.1.1` のような数値列で、直後は空白か行末）のコメントが併記されていなければならない。走査ツールが前置するファイルパス・行番号は判定材料にしてはならない
- **AND** 抽出された `uses:` 行が 1 件以上存在しなければならない（テンプレートの改名・移動で走査対象が 0 件になり無言で pass するのを防ぐ）

#### Scenario: Known bypasses of the check are rejected

- **WHEN** 次の 6 形をテンプレートに置いて検査する — ① `uses: <owner>/<action>@<40 桁 16 進数> # TODO`（バージョンでないコメント）② `uses: evil/action@v1 # mimics uses: actions/cache@v4`（コメント中の `actions/` で公式を騙る）③ `uses : evil/action@v1`（コロン前に空白）④ `uses: evil@<40 桁 16 進数> # v1`（`<owner>/` が無い）⑤ `# v1evil` / `# 1.` / `# TODO (#176)` / `# 2026-08-22`（バージョンに見えるだけのコメント）⑥ ファイルパスに `# v9` を含む dir に置いた `# TODO` 行（走査ツールの前置がコメント判定を肩代わりする形）⑦ `- "uses": evil/action@v1` / `- 'uses': evil/action@v1`（引用したキー）⑧ `- { uses: evil/action@v1 }` / `- {name: deploy, uses: evil/action@v1}`（flow mapping）
- **THEN** 8 形すべてが検査に fail しなければならない
- **AND** 正しく固定された行（`uses: <owner>/<action>@<40 桁 16 進数> # v2.1.1`。引用符で囲んだ形・`owner/repo/subdir@<40 桁 16 進数>` のサブパス形・キーを引用した形・flow mapping 形（バージョンコメントは閉じ括弧の後）を含む）と GitHub 公式（`actions/*`）の行は pass しなければならない

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

