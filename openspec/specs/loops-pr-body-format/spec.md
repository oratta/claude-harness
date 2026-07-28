# loops-pr-body-format Specification

## Purpose
TBD - created by archiving change agent-pr-issue-body-format. Update Purpose after archive.
## Requirements
### Requirement: PR 本文フォーマット reference の新設
`plugins/loops/references/pr-body-format.md` は、エージェントが書く PR 本文の 5 セクション型を定義しなければならない（MUST）。セクションは上から順に「これで何が変わるか」「良くなること / 悪くなりうること」「壊れうるポイント」「動作確認ポイント」「実装メモ」であり、この順序（判断に必要な順）を入れ替えてはならない（MUST NOT）。末尾に `Closes #<番号>` と、再生成可能な出力（検証ログ等）のみを入れる任意の `<details>` 折りたたみを置く。

#### Scenario: reference ファイルが 5 セクションを順序どおり定義している
- **WHEN** `plugins/loops/references/pr-body-format.md` を読む
- **THEN** 「これで何が変わるか」「良くなること / 悪くなりうること」「壊れうるポイント」「動作確認ポイント」「実装メモ」の 5 見出しがこの順で定義されている

#### Scenario: 折りたたみは再生成可能な出力に限定される
- **WHEN** reference の `<details>` 規定を読む
- **THEN** テスト出力・ビルドログ等の再生成可能なものだけを入れ、設計判断・制約・却下した代案を入れてはならない（LLM が折りたたみを読み飛ばす実装があるため）と明記されている

### Requirement: 二重読者のための設計原則
reference は以下の設計原則を明文化しなければならない（MUST）: (1) 人間向け/機械向けの二重管理をせず同じ情報を 2 回書かない、(2) 技術用語を冒頭に出さず機構名ではなく発生する事象を書く（翻訳の規律）、(3) ネガティブ欄（悪くなりうること・壊れうるポイント)に「なし」と書く場合は根拠を 1 行添える、(4) セクションごとに行数上限を明示し超える内容は issue へ切り出す。翻訳の規律にはエージェントが真似できる良い例/悪い例を 3 組以上含めなければならない（MUST）。

#### Scenario: 翻訳の良い例/悪い例が 3 組ある
- **WHEN** reference の翻訳の規律の節を読む
- **THEN** 「機構名の記述（❌）→ 発生する事象の記述（✅）」の対が 3 組以上例示されている

#### Scenario: ネガティブ欄の空欄が禁止されている
- **WHEN** reference の設計原則を読む
- **THEN** 「なし」と書く場合も根拠 1 行が必須である旨が明記されている

### Requirement: 誇張防止の検証紐付け制約
reference は「『これで何が変わるか』『良くなること』に書く主張は、動作確認ポイントの項目で検証できるものに限る」という制約を規定しなければならない（MUST）。動作確認ポイントは「操作 → 期待される結果」形式のチェックリストで、「これで何が変わるか」と「壊れうるポイント」の各項目と 1:1 で対応させる。

#### Scenario: 検証できない効能の記載が禁止されている
- **WHEN** reference の動作確認ポイントの規定を読む
- **THEN** 動作確認ポイントで検証できないことを効能として書いてはならない旨が明記されている

### Requirement: 軽量モードの規定
reference は軽量モード（「これで何が変わるか」＋「動作確認ポイント」の 2 節のみ必須）を定義しなければならない（MUST）。発動条件はエージェントの自己判断とし、reference に明文化された基準（typo・docs のみ・振る舞い不変等）に該当する場合に限る。軽量モードを適用した PR は冒頭に「軽量モード適用（理由: …）」を 1 行明記しなければならない（MUST）。迷った場合はフル 5 節を書く。

#### Scenario: 軽量モード適用時に理由行が要求される
- **WHEN** reference の軽量モードの節を読む
- **THEN** 適用基準の明文リストと、PR 冒頭への適用理由 1 行の明記義務が定義されている

### Requirement: agent-loop-template からの参照配線
`plugins/loops/templates/agent-loop-template.md` の実装モード Step 3 の Draft PR 作成手順は、PR 本文について `pr-body-format.md` の型に従う旨を参照しなければならない（MUST）。従来の「本文に `Closes #<番号>` と検証ログを書き」という独自規定は参照に置き換える。

#### Scenario: 憲法テンプレートが reference を参照している
- **WHEN** `plugins/loops/templates/agent-loop-template.md` の Draft PR 作成手順を読む
- **THEN** `pr-body-format.md` への参照があり、本文構造の独自規定が残っていない

### Requirement: issue ドラフトへの承認判断 2 節の追加
`plugins/loops/skills/loops-issueify/SKILL.md` の issue ドラフト構造および `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 3 の `agent-task.md` テンプレートは、既存 4 節（概要 / 触るファイル・関数 / 受け入れ条件 / 備考）の先頭に「これで何が変わるか」（最大 3 行・技術用語禁止）と「やらないとどうなるか / 今のコスト」（最大 3 行）の 2 節を追加しなければならない（MUST）。既存 4 節の構造は変更してはならない（MUST NOT）。

#### Scenario: issueify のドラフト構造に 2 節が先頭追加されている
- **WHEN** `plugins/loops/skills/loops-issueify/SKILL.md` のドラフト生成手順を読む
- **THEN** 「これで何が変わるか」「やらないとどうなるか / 今のコスト」が既存 4 節の前に定義され、既存 4 節が維持されている

#### Scenario: インストールされる issue テンプレートに 2 節が含まれる
- **WHEN** `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 3 の `agent-task.md` テンプレートを読む
- **THEN** 同 2 節が既存 4 節の前に含まれている

### Requirement: プラグインバージョンの更新
本変更を含むリリースでは `plugins/loops/.claude-plugin/plugin.json` のバージョンを 0.16.1 から上げなければならない（MUST）。同バージョンのままではプラグインキャッシュにより他プロジェクトへ反映されないため。dev-workflow 側の追従変更も同様に `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げる。

#### Scenario: バージョンが更新されている
- **WHEN** 両 plugin.json の `version` を読む
- **THEN** loops は 0.16.1 より大きく、dev-workflow は 1.5.0 より大きい

