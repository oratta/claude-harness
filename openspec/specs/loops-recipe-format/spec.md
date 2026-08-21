# loops-recipe-format Specification

## Purpose
TBD - created by archiving change loops-plugin. Update Purpose after archive.
## Requirements

### Requirement: レシピ形式規約は固定見出し 7 項目を定義する

`plugins/loops/references/recipe-format.md` は、レシピファイル `recipes/<name>.md` の形式規約として以下の固定見出し 7 項目を定義しなければならない (MUST): 「ループ型」「目的」「起動コマンド」「停止基準」「前提」「コスト注意」「エスカレーション」。規約は各見出しの記載内容を説明し、「ループ型」は公式 4 分類（ターンベース / ゴールベース / タイムベース / プロアクティブ）のいずれかであること、「停止基準」は必須項目であり最大試行数・時間・定量ゴールのいずれか 1 つ以上を必ず含むことを明記すること。レシピ形式は Markdown 見出し規約のみとし、JSON Schema 等による機械検証を要求してはならない (MUST NOT)。

#### Scenario: 規約文書が固定見出し 7 項目を列挙している

- **WHEN** `plugins/loops/references/recipe-format.md` を grep する
- **THEN** 「ループ型」「目的」「起動コマンド」「停止基準」「前提」「コスト注意」「エスカレーション」の 7 見出しすべてが規約として記載されている

#### Scenario: 停止基準が必須項目として明記されている

- **WHEN** `plugins/loops/references/recipe-format.md` の「停止基準」の説明を読む
- **THEN** 停止基準が必須項目であること、および最大試行数・時間・定量ゴールのいずれか 1 つ以上を含むべきことが記載されている

### Requirement: レシピテンプレートは規約準拠の雛形を提供する

`plugins/loops/templates/recipe-template.md` は、固定見出し 7 項目（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をこの構成で含む雛形でなければならない (MUST)。「起動コマンド」節には、ネイティブプリミティブ（/goal・/loop・/schedule・skill 起動）のコピペ可能なコマンド文字列を第一級の成果物として書くこと、独自 CLI やラッパースクリプトを作らないことを注記すること。

#### Scenario: テンプレートが 7 見出しを持つ

- **WHEN** `plugins/loops/templates/recipe-template.md` の見出しを grep する
- **THEN** 「ループ型」「目的」「起動コマンド」「停止基準」「前提」「コスト注意」「エスカレーション」の 7 見出しがすべて存在する

#### Scenario: 起動コマンド節にネイティブプリミティブの注記がある

- **WHEN** テンプレートの「起動コマンド」節を読む
- **THEN** コピペ可能なネイティブコマンド文字列（/goal・/loop・/schedule・skill 起動）を書くこと、および独自 CLI・ラッパースクリプトを作らないことが注記されている

### Requirement: レシピは実行機構への配線に踏み込まない

レシピ形式規約は、レシピが宣言する実行インターフェースの範囲を「発火時に投入するプロンプト」「推奨頻度」「停止基準」「実行環境の制約（例: ローカルの `~/.claude/projects/` jsonl を読むループはローカル実行が必要）」までと定めなければならない (MUST)。スケジューラへの登録方法・セッション運用・課金選択の記載をレシピに要求してはならず (MUST NOT)、これらは呼び出し側の責務であることを規約に明記すること。

#### Scenario: 宣言範囲の 4 項目が規約に定義されている

- **WHEN** `plugins/loops/references/recipe-format.md` の実行インターフェースに関する節を読む
- **THEN** レシピが宣言するのは「発火時に投入するプロンプト」「推奨頻度」「停止基準」「実行環境の制約」までであることが記載されている

#### Scenario: スケジューラ登録が呼び出し側の責務とされている

- **WHEN** 同じ節を読む
- **THEN** スケジューラへの登録・セッション運用・課金選択はレシピのスコープ外であり呼び出し側の責務であることが明記されている
