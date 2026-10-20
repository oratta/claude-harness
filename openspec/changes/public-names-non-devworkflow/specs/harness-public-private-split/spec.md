## ADDED Requirements

### Requirement: dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない

公開版に残る部品のうち dev-workflow 以外（`rules/README.md`・`scripts/sync.sh`・`scripts/test-auto-merge-workflow.sh`・capability-registry・statusline・worktree・product-handover・casting・cost-ledger・infra）は、固有記述の一覧で担い手なしだった行の語を持たない。次の検索がそれぞれ 0 件でなければならない（MUST）。検索は大文字と小文字を区別し、付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は対象に含めない。

- `moko|suimei|uranai|shukan|sns-autopilot`: 上の部品の全ファイル
- `/Users/oratta`: `plugins/worktree/` の全ファイル
- `flatmate|FLATMATE`: `rules/README.md`・`scripts/sync.sh`・capability-registry・worktree・product-handover・casting・cost-ledger・infra の全ファイル。statusline は、互換のために旧名を読む行（載せない行の基準）だけを除く

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上の部品に戻ってくること
- 通してよい具体例: 検索語に無い別の固有名・書き換えた例の文の良し悪し・載せない行の基準の判定の正しさ。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/worktree/skills/wt-clean/SKILL.md` に `/Users/oratta/wt/bar` を書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 検索語に無い固有名は検査を通る

- **WHEN** 対象のファイルに検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: 載せない行の基準に互換のために残す旧名の読み取りを含める

`docs/public-private-split.md` の「載せない行の基準」は、「互換のために残す旧名の読み取り」を載せない行に含めなければならない（MUST）。当たる行は、新しい名前が主であることと、旧名を互換として読むことが同じ箇所に書かれていなければならない（MUST）。

#### Scenario: 旧名の読み取りの行が一覧から外れる

- **WHEN** 新名を主、旧名を互換と明記した statusline の行を候補語で検索する
- **THEN** 当たった行は基準で説明でき、一覧に載せなくてよい
