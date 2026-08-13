# loops-pr-body-format Specification (Delta)

## MODIFIED Requirements

### Requirement: PR 本文フォーマット reference の新設
`plugins/loops/references/pr-body-format.md` は、エージェントが書く PR 本文の 5 セクション型を定義しなければならない（MUST）。セクションは上から順に「位置づけ」「実装方針」「リスク（重い順）」「動作確認ポイント」「実装メモ」であり、この順序（判断に必要な順）を入れ替えてはならない（MUST NOT）。「位置づけ」はプロダクトの目的 → この PR が担う部分 → 起きる変化、の 3 行で上から降りる構成とする。「リスク」は起きうること / 起きやすさ / 起きたときの影響 / 戻し方 の 4 列表とする。末尾に `Closes #<番号>` と、再生成可能な出力（検証ログ等）のみを入れる任意の `<details>` 折りたたみを置く。

#### Scenario: reference ファイルが 5 セクションを順序どおり定義している
- **WHEN** `plugins/loops/references/pr-body-format.md` を読む
- **THEN** 「位置づけ」「実装方針」「リスク（重い順）」「動作確認ポイント」「実装メモ」の 5 見出しがこの順で定義されている

#### Scenario: 折りたたみは再生成可能な出力に限定される
- **WHEN** reference の `<details>` 規定を読む
- **THEN** テスト出力・ビルドログ等の再生成可能なものだけを入れ、設計判断・制約・却下した代案を入れてはならない（LLM が折りたたみを読み飛ばす実装があるため）と明記されている

### Requirement: 二重読者のための設計原則
reference は以下の設計原則を明文化しなければならない（MUST）: (1) 人間向け/機械向けの二重管理をせず同じ情報を 2 回書かない、(2) 承認者はプロジェクトの全体像を頭に入れていない前提で「位置づけ」を上から降りる 3 段構成にする、(3) 技術用語を冒頭に出さず機構名ではなく発生する事象を書く（翻訳の規律）、(4) リスクは起きやすさ（高/中/低＋根拠一言）と影響範囲の重み付きで重い順に書き、重みのない羅列を禁止する。「なし」と書く場合は根拠を 1 行添える、(5) セクションごとに行数上限を明示し超える内容は issue へ切り出す。翻訳の規律にはエージェントが真似できる良い例/悪い例を 3 組以上含めなければならない（MUST）。

#### Scenario: 翻訳の良い例/悪い例が 3 組ある
- **WHEN** reference の翻訳の規律の節を読む
- **THEN** 「機構名の記述（❌）→ 発生する事象の記述（✅）」の対が 3 組以上例示されている

#### Scenario: リスクの重み付けが必須である
- **WHEN** reference の設計原則とリスク欄の規定を読む
- **THEN** 起きやすさ（高/中/低＋根拠）と影響範囲を伴わない事象の羅列が禁止され、「なし」と書く場合も根拠 1 行が必須である旨が明記されている

### Requirement: 誇張防止の検証紐付け制約
reference は「『位置づけ』に書く変化は、動作確認ポイントの項目で検証できるものに限る」という制約を規定しなければならない（MUST）。動作確認ポイントは「操作 → 期待される結果」形式のチェックリストで、「位置づけ」3 行目の変化と「リスク」の各行と 1:1 で対応させる。

#### Scenario: 検証できない効能の記載が禁止されている
- **WHEN** reference の動作確認ポイントの規定を読む
- **THEN** 動作確認ポイントで検証できないことを効能として書いてはならない旨が明記されている

### Requirement: 軽量モードの規定
reference は軽量モード（「位置づけ」＋「動作確認ポイント」の 2 節のみ必須）を定義しなければならない（MUST）。発動条件はエージェントの自己判断とし、reference に明文化された基準（typo・docs のみ・振る舞い不変等）に該当する場合に限る。軽量モードを適用した PR は冒頭に「軽量モード適用（理由: …）」を 1 行明記しなければならない（MUST）。迷った場合はフル 5 節を書く。

#### Scenario: 軽量モード適用時に理由行が要求される
- **WHEN** reference の軽量モードの節を読む
- **THEN** 適用基準の明文リストと、PR 冒頭への適用理由 1 行の明記義務が定義されている

### Requirement: プラグインバージョンの更新
本変更を含むリリースでは `plugins/loops/.claude-plugin/plugin.json` のバージョンを 0.21.1 から上げなければならない（MUST）。同バージョンのままではプラグインキャッシュにより他プロジェクトへ反映されないため。dev-workflow 側の追従変更（revert テンプレート）も同様に `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げる。marketplace.json の各プラグインの version は plugin.json と一致させる。

#### Scenario: バージョンが更新されている
- **WHEN** 両 plugin.json の `version` を読む
- **THEN** loops は 0.21.1 より大きく、dev-workflow は 1.9.0 より大きい

## ADDED Requirements

### Requirement: 配布テンプレートの新型追従
`plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml` が自動生成する revert PR 本文の見出しと、本リポジトリの `.github/PULL_REQUEST_TEMPLATE.md` は、PR 本文の新 5 セクション型（軽量モードは「位置づけ」＋「動作確認ポイント」）に従わなければならない（MUST）。旧セクション名（「これで何が変わるか」「壊れうるポイント」等）を PR 本文の見出しとして残してはならない（MUST NOT）。issue 本文の型（「これで何が変わるか」先頭 2 節）はこの制約の対象外である。

#### Scenario: revert テンプレートの生成本文が新型に従う
- **WHEN** `plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml` の PR body 生成部を読む
- **THEN** 軽量モードの見出し「位置づけ」が使われ、旧見出し「これで何が変わるか」が PR body に残っていない

#### Scenario: リポジトリに PR テンプレートが存在する
- **WHEN** `.github/PULL_REQUEST_TEMPLATE.md` を読む
- **THEN** 新 5 セクション型の見出しとコメントによる書き方指示が含まれている
