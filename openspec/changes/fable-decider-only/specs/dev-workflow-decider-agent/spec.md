## ADDED Requirements

### Requirement: 決める役の種別 dev-workflow:decider
dev-workflow プラグインは決める役のエージェント定義 `agents/decider.md` を配布しなければならない（MUST）。frontmatter は `name: decider`・`description`・`model: fable`・`tools: Read, Grep, Glob` を持ち、`tools` に Edit / Write / NotebookEdit / Bash を含めてはならない（MUST NOT。編集できないことが「Fable は実行役にならない」の機械的な保証であり、この定義は `plugins/casting/agents/casting-arbiter.md` の書式に倣う）。

プラグインは `.claude-plugin/plugin.json` の `agents` 配列で `./agents/decider.md` を宣言しなければならない（MUST。casting プラグインが `casting-specialist` / `casting-arbiter` を宣言しているのと同じ規約）。

本文は入力契約と出力契約を規定しなければならない（MUST）。入力契約は、**記録先の本文とコメント（受け入れ条件・`仕様化判断:` の記録などを呼び出し側が入力文に貼り付ける。決める役は `Bash` を持たないため `gh` で自分では取りに行けない）**・失敗の出力（テストログ・レビュー指摘）・対象ファイルのパス・実行役の return（「指示のどこまでやって、どこで何が起きたか」）を受け取ること。出力契約は次の 3 つを返すこと（SHALL）:

1. 原因の分類 — 判断側（指示が外れていた・実行役が解釈できなかった）か実行側（指示どおりやって結果が違う）か
2. 直す箇所・方法・確認するテストを、実行役がそのまま実行できる具体的な指示
3. 次の実行役のモデル（`sonnet` / `opus`）

verify・マージ可否で呼ばれたときは可否と根拠を返す（SHALL）。自分ではコードを書かず、「コードを触らないと直し方が決められない」と判断したときは、その旨と足りない情報を返さなければならない（MUST）。決める役は記録先へのコメント投稿も行わない（MUST NOT。`Bash` を持たないため）。記録が要る役割（仕様レビューの R1 など）を決める役として起こした場合、その return を記録先に投稿するのは呼び出し側（本体）の責務である（SHALL）。

決める役は `model` を切り替えて使い分けなければならない（SHALL）。決める役を Opus で立てたいときも `subagent_type` は `dev-workflow:decider` のまま `model: opus`（または `model` を省略して定義の既定 `fable`）とし、`general-purpose` に読み替えてはならない（MUST NOT）。これにより `FABLE_BUDGET_MODE=exhausted` / `reserve` の自動実行で決める役を Opus 上限に落とすときも、種別は変えずモデルだけが変わる。

#### Scenario: 定義が読み取り専用ツールだけを持つ
- **WHEN** `plugins/dev-workflow/agents/decider.md` の frontmatter を読む
- **THEN** `model: fable` と `tools: Read, Grep, Glob` があり、Edit / Write / NotebookEdit / Bash は含まれない

#### Scenario: 入出力契約が本文にある
- **WHEN** `plugins/dev-workflow/agents/decider.md` の本文を読む
- **THEN** 入力（記録先の本文とコメント・失敗の出力・対象ファイルのパス・実行役の return）と、出力の 3 点（原因の分類・実行役がそのまま実行できる指示・次の実行役のモデル）、コードを書かないこと、記録先への投稿は呼び出し側が行うことが書かれている

#### Scenario: プラグインが agents で宣言している
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` を読む
- **THEN** `agents` 配列に `./agents/decider.md` が含まれる

#### Scenario: Opus の決める役も同じ種別で立てる
- **WHEN** 残量モードにより決める役を Opus に落として spawn する
- **THEN** `subagent_type` は `dev-workflow:decider` のままで `model: opus` を渡し、`general-purpose` には読み替えない

### Requirement: Fable を既定モデルに持つエージェント定義は読み取り専用
リポジトリ内の `plugins/*/agents/*.md` のうち frontmatter の `model` が Fable（`fable`、または `claude-fable-*` の完全 ID）を指す定義は、`tools` に Edit / Write / NotebookEdit / Bash を含めてはならない（MUST NOT）。この規約は bats テストで検証されなければならない（MUST）。検証対象は dev-workflow の決める役に限らず、`casting-arbiter` / `casting-specialist` を含むすべてのプラグインのエージェント定義とする（SHALL）。

#### Scenario: 編集系ツールを持つ Fable 定義は検出される
- **WHEN** `model: fable` かつ `tools` に `Write` を含むエージェント定義がリポジトリに存在する状態でテストを実行する
- **THEN** テストが失敗し、どの定義が違反しているかが出力される

#### Scenario: 現在の定義はすべて規約を満たす
- **WHEN** 現在のリポジトリでこのテストを実行する
- **THEN** `dev-workflow:decider`・`casting-arbiter`・`casting-specialist` を含めて違反が無く、テストは緑になる
