## ADDED Requirements

### Requirement: dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない

公開版に残る部品のうち dev-workflow 以外（`rules/README.md`・`scripts/sync.sh`・`scripts/test-auto-merge-workflow.sh`・capability-registry・statusline・worktree・product-handover・casting・cost-ledger・infra）は、固有記述の一覧で担い手なしだった行の語を、許可リストに載った行を除いて持たない。次の検索の当たりは、許可リストの行を除いて 0 件でなければならない（MUST）。検索は大文字と小文字を区別する。

- 検索語と対象: `moko|suimei|uranai|shukan|sns-autopilot` は上の部品の公開版のファイル・節、`/Users/oratta` は `plugins/worktree/` の公開版のファイル、`flatmate|FLATMATE` は `rules/README.md`・`scripts/sync.sh`・capability-registry・worktree・product-handover・casting・cost-ledger・infra・statusline の公開版のファイル・節
- 公開版のファイル・節: 仕分けの表（`docs/public-private-split.md`）で個人版に決まるファイルと節（capability-registry の `scripts/fmtoken.sh`・`1password.md`・`SKILL.md` の「表記規約」と「資格情報の階層」の節など）は対象に含めない。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` も含めない
- 許可リスト: 載せない行の基準のうち「出典や経緯としてだけ名前を挙げる行」と「互換のために残す旧名の読み取り」に当たる行は、`tests/public-private-split.bats` の中の許可リストに「ファイルのパス・行に含まれる固定の文字列・当たる基準」の 3 つ組で 1 件ずつ載せたものだけを通す。許可リストに無い当たりは落ちる。許可リストの各件は、判定の表（tasks の実施欄）に同じ行がなければならない

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上の部品の公開版のファイル・節に戻ってくること／許可リストに無い当たりが現れること
- 通してよい具体例: 検索語に無い別の固有名・許可リストの載せ方の良し悪し・書き換えた例の文の良し悪し・載せない行の基準の判定の正しさ。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/worktree/skills/wt-clean/SKILL.md` に `/Users/oratta/wt/bar` を書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 許可リストの出典の行は通る

- **WHEN** `scripts/sync.sh` の出典として flatmate の名を挙げる行が許可リストに載っている
- **THEN** 検索のテストは通る。同じファイルの別の行に flatmate を書き足すと、許可リストに無いので落ちる

#### Scenario: 個人版のファイルと節は検索の対象に入らない

- **WHEN** 個人版に決まる `plugins/capability-registry/scripts/fmtoken.sh` に検索語がある
- **THEN** 検索のテストは落ちない

#### Scenario: 検索語に無い固有名は検査を通る

- **WHEN** 対象のファイルに検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: 載せない行の基準に互換のために残す旧名の読み取りを含める

`docs/public-private-split.md` の「載せない行の基準」は、「互換のために残す旧名の読み取り」を載せない行に含めなければならない（MUST）。当たる行は、新しい名前が主であることと、旧名を互換として読むことが同じ箇所に書かれていなければならない（MUST）。

#### Scenario: 旧名の読み取りの行が一覧から外れる

- **WHEN** 新名を主、旧名を互換と明記した statusline の行を候補語で検索する
- **THEN** 当たった行は基準で説明でき、一覧に載せなくてよい（許可リストに載せる）
