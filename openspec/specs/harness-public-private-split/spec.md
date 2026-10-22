# harness-public-private-split Specification

## Purpose
TBD - created by archiving change harness-public-private-split. Update Purpose after archive.
## Requirements
### Requirement: 仕分けの表はどの部品も漏らさず 1 行ずつ載せる

`docs/public-private-split.md` の仕分けの表は、`rules/*.md` の各ファイル、`output-styles/*.md` の各ファイル、`.claude-plugin/marketplace.json` の `plugins` に載る各プラグイン、リポジトリ直下の `scripts/` の各項目（ファイルとディレクトリ）を、それぞれ 1 行ずつ載せなければならない（MUST）。

#### Scenario: すべての部品が表にある
- **WHEN** `rules/*.md`・`output-styles/*.md`・`marketplace.json` のプラグイン名・直下の `scripts/` の項目を列挙して表の部品の欄と突き合わせる
- **THEN** どの部品も表にちょうど 1 行ある

#### Scenario: 部品を足して表を直し忘れる
- **WHEN** `rules/` に新しいファイルを足し、表に行を足さない
- **THEN** `tests/public-private-split.bats` が落ちる

### Requirement: 各行は決めた分類と理由を持つ

表の各行の分類は「公開版」「個人版」「保留（#1123 の後）」のどれかでなければならない（MUST）。ただし 1 つのプラグインの中で行き先が割れるプラグインの行は「分割」とし、そのプラグインを次の要件「分割したプラグインは部品の行で全体を重複なく覆う」に従って部品の行で覆わなければならない（MUST）。どの行も理由の欄が空であってはならない（MUST NOT）。理由は #1128 の判断の基準（公開版: 誰の環境でも意味がある道具・住人のふるまいに効くもの・営業で見せる動き。個人版: オーナーに固有の業務・アカウント・資格情報の置き場・固有名に依存するもの）のどれに当たるかが読めるように書く。

#### Scenario: 分類の値が決めた値だけである
- **WHEN** 表の分類の欄を読む
- **THEN** すべての値が「公開版」「個人版」「保留（#1123 の後）」「分割」のどれかで、部品の行の分類は「分割」以外の 3 つのどれかである

#### Scenario: 理由が空の行がない
- **WHEN** 表の理由の欄を読む
- **THEN** 空の行がない

#### Scenario: 保留の行は何を見て、誰がいつ決めるかを書く
- **WHEN** 分類が「保留（#1123 の後）」の行を読む
- **THEN** 理由の欄に、#1123 の結果のどこを見て公開版か個人版かを決めるかが書かれ、文書の冒頭に、保留の行は #1129 の着手時に #1129 の担い手が #1123 の結果を見て確定し、同じ PR でこの表を直すことが書かれている

### Requirement: 分割したプラグインは部品の行で全体を重複なく覆う

分類が「分割」のプラグインについて、表は部品の行の集まりで、そのプラグインのディレクトリ配下の git 管理下のファイル（付属のファイルを除く）を、どのファイルもちょうど 1 つの部品の行に決まるように覆わなければならない（MUST）。

- 部品の行の部品の欄は、プラグインのディレクトリ配下のファイルのパス、ディレクトリのパス（末尾 `/`）、Markdown のファイルの節（`<パス>#<## の見出しの文字列>`）、または Markdown のファイルの冒頭（`<パス>#冒頭`）のどれかを書く
- 1 つのファイルがどの行に決まるかは、そのファイルに当てはまる行（パスが一致するファイルの行、またはそのファイルを含むディレクトリの行）のうち、いちばん深い（長い）パスの行で決める。同じパスの行を 2 行置いてはならない（MUST NOT）
- 節の行を置いた Markdown のファイルは、そのファイルの `## ` の見出しをすべて、節の行でちょうど 1 回ずつ覆わなければならない（MUST）。そのファイルにはファイルの行を置かない（節の行がファイルの行より優先されるのではなく、併置を禁じる）。最初の `## ` より前の部分（frontmatter と冒頭の文）は節に含めず、独立した単位として `<パス>#冒頭` の行をちょうど 1 行持たなければならない（MUST）。最初の `## ` より前が空のファイルには `#冒頭` の行を置かない。`#冒頭` は冒頭の単位を表す予約の書き方で、`## 冒頭` という見出しの節を表さない（そういう見出しのあるファイルは節で分けない）
- どのファイルにも当てはまらない部品の行を置いてはならない（MUST NOT）
- 付属のファイルは部品の行で覆わない: `.claude-plugin/plugin.json`・`changes/` 配下・`tests/` 配下・`README.md`・`CHANGELOG.md`・`hooks/hooks.json`。付属のファイルは、それが記録・検査・配線している部品と同じ行き先に従い、ファイルの中で行き先が割れるとき（例: `hooks/hooks.json` の中で配線先のスクリプトの行き先が割れる）の書き分けは #1129 で行う。文書の冒頭にこの扱いを書く

#### Scenario: 分割したプラグインのファイルがどれも 1 行に決まる
- **WHEN** 分割のプラグインについて `git ls-files <プラグインのディレクトリ>` から付属のファイルを除いたファイルを列挙し、いちばん深いパスの規則で行に割り当てる
- **THEN** どのファイルも行が 1 つに決まり、行の決まらないファイルが無い

#### Scenario: 部品の行を落とすと落ちる
- **WHEN** 分割のプラグインの部品の行を 1 行消し、そのファイルを覆う上位のディレクトリの行も無い
- **THEN** `tests/public-private-split.bats` が、行の決まらないファイルの名前を出して落ちる

#### Scenario: 節の行が見出しを覆いきらないと落ちる
- **WHEN** 節の行を置いた Markdown のファイルの `## ` の見出しのどれかに節の行が無い、または同じ見出しの節の行が 2 行ある、または同じファイルにファイルの行もある、または最初の `## ` より前が空でないのに `<パス>#冒頭` の行が無い（2 行ある）
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 節で分けたファイルの冒頭は節と別に行き先が決まる
- **WHEN** frontmatter を持つ Markdown のファイルを節で分け、最初の `## ` の節を個人版にする
- **THEN** frontmatter と冒頭の文は `<パス>#冒頭` の行の分類に従い、最初の節の分類には引きずられない

#### Scenario: 存在しないパスの行を置くと落ちる
- **WHEN** 部品の行のパスが、どの git 管理下のファイルにも当てはまらない（ファイルが無い、またはディレクトリの配下が空）
- **THEN** `tests/public-private-split.bats` が落ちる

### Requirement: capability-registry の扱いを選ばなかった案と後続の割り当てとともに残す

`docs/public-private-split.md` は capability-registry をどう仕分けたかを、部品ごとの行き先、選ばなかった案（丸ごと個人版・丸ごと公開版）とその理由、公開版に残る部品から個人版の部品（`fmtoken.sh` など）への参照を外す作業の対象と担い手、その作業で更新が要る既存の仕様（`openspec/specs/capability-registry-browser-guard/spec.md`・`openspec/specs/capability-registry-skill/spec.md`）とともに書かなければならない（MUST）。

#### Scenario: capability-registry の決定が読める
- **WHEN** 文書の capability-registry の行と説明を読む
- **THEN** browser-guard の hook・スキルの各節・サービス別ファイル・`fmtoken.sh` のそれぞれの行き先と、選ばなかった案の理由が書かれている

#### Scenario: 参照を外す作業の担い手が読める
- **WHEN** 文書の capability-registry の説明を読む
- **THEN** 公開版に残る部品のうち `fmtoken.sh` を参照している箇所の一覧とそれを直す後続の issue（#1164）、`fmtoken.sh` を伴わず保管庫名だけを参照している箇所は担い手なしとして本体に渡すこと、既存の仕様の要件を更新する時期が書かれている

### Requirement: 公開版に残る部品の固有記述を一覧にする

`docs/public-private-split.md` は、公開版に残る部品（「分割」で公開版になった部品の行を含む）の中の、固有名（オーナーのプロジェクト名・アカウント名・保管庫名・人名・オーナーのリポジトリ名）とオーナーの環境に依存する記述（オーナーの PC のパス・オーナーだけが持つ環境変数やサービスを前提にした記述）の一覧を持たなければならない（MUST）。一覧の各行は `<リポジトリ相対パス>:<行>`・種別（固有名／環境依存）・書かれている内容・直す issue（担い手の issue が無い行は「担い手なし」）を持つ。探すのに使った候補語と、候補語に当たっても載せない行の基準も文書に書く。

#### Scenario: 一覧のパスは実在し公開版の部品に属する
- **WHEN** 一覧の各行のパスと行番号を確かめる
- **THEN** ファイルが実在し、行番号がそのファイルの行数以内で、ファイルが表で公開版に決まる部品に属する

#### Scenario: 候補語で取りこぼしを確かめられる
- **WHEN** 文書に書かれた候補語で公開版の部品を `grep` する
- **THEN** 当たった行は一覧に載っているか、文書の「載せない行の基準」で説明できる

### Requirement: 表と一覧の検査の守備範囲

`tests/public-private-split.bats` は、`docs/public-private-split.md` の表と一覧を入力として、形と網羅を機械で確かめる検査である。守備範囲を次のとおりとし、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 入力の出どころ: 文書の表と一覧は実装の担い手が部品を読んで書く。突き合わせる相手は、テストの実行時点の `git ls-files`・`rules/*.md`・`output-styles/*.md`・`.claude-plugin/marketplace.json` の `plugins[].name`・直下の `scripts/` の項目・Markdown の `## ` の見出しで、どれもテストが自分で列挙する
- 拾う誤り: 表に無い部品・同じ部品の 2 行・どのファイルにも当たらない行・分割のプラグインで行の決まらないファイル・節の行の覆い漏れと重複・決めた値以外の分類・空の理由・実在しないパスや行数を超える行番号を持つ一覧の行・公開版に決まらない部品を指す一覧の行
- 通してよい具体例: 分類の判断そのものの誤り（個人版にすべき部品を公開版と書いた）、中身の薄い理由（「汎用」の一語）、候補語に当たらない固有記述の取りこぼし、あとの編集で行番号がずれても行数以内に収まっている一覧の行。これらは人のレビュー（仕様レビューと pr-review-gate）と #1098 の再検索が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない。この検査は、部品を足したのに表を直し忘れた PR と、#1129 が移す範囲を決められない表を落とすためのもので、仕分けの正しさを保証しない

#### Scenario: 判断の誤りは検査を通る
- **WHEN** 表の形と網羅は正しく、ある部品の分類だけが判断の基準に照らして誤っている
- **THEN** `tests/public-private-split.bats` は通り、その誤りは人のレビューが見る

#### Scenario: 形の誤りは検査で落ちる
- **WHEN** 表の分類の欄に「配る」のような決めた値以外の文字列がある
- **THEN** `tests/public-private-split.bats` が落ちる

### Requirement: 配る候補の規則は環境固有の記述を持たず、プラグインの前提を条件つきにする

`rules/communication-style.md` `rules/link-when-requesting-review.md` `rules/dev-server.md` `rules/browser-infra-env-capture.md` `rules/destructive-git-guard.md` `output-styles/readable.md` の 6 ファイルは、固有名とオーナーの環境のパスを書いてはならない（MUST NOT）。具体的には `grep -n -i -E 'oratta|genetta|suimei|flatmate|fmtoken|Dropbox|marketplaces/'` が 6 ファイルで 0 件でなければならない（MUST）。また 6 ファイルは Harness のプラグイン（capability-registry・dev-workflow）が入っていない環境でも指示として実行できなければならず、プラグインやその hook を前提にする記述は「入っていれば」の条件つきで書かなければならない（MUST）。外した参照の行き先は、変更の記録（`plugins/<name>/changes/<issue番号>.md`）に 1 行ずつ書く（MUST）。

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 入力の出どころ: 検索の対象は、テストの実行時点のリポジトリにある上の 6 ファイルの本文で、テストが自分で読む。検索語は上の `grep` の語（`oratta|genetta|suimei|flatmate|fmtoken|Dropbox|marketplaces/`）に固定する。条件つきの書き方（「入っていれば」と、入っていない環境の手順）は、文書化された文を人が読んで確かめる
- 拾う誤り: 6 ファイルのどれかが検索語に 1 行でも当たる／`rules/destructive-git-guard.md` に `rules-archive` が残る／`rules/destructive-git-guard.md` の「hook との分担」の節に条件の語（「入っていれば」）が無い
- 通してよい具体例: 検索語に当たらない別の固有名（オーナーの別のプロジェクト名や人名）／条件つきの文の言い回しの良し悪し／6 ファイルの外（`rules/README.md` など）にある固有記述。これらは人のレビュー（仕様レビューと pr-review-gate）と、固有記述の一覧（`docs/public-private-split.md`）が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない。この検索は、受け入れ条件 1 の語が 6 ファイルに戻ってくるのを落とすためのもので、環境非依存であることの証明ではない

#### Scenario: 6 ファイルに固有名が無い

- **WHEN** 上の `grep` を 6 ファイルに対して実行する
- **THEN** 0 件である

#### Scenario: プラグインを前提にする記述が条件つきである

- **WHEN** `rules/browser-infra-env-capture.md` の昇格の手順の文と `rules/destructive-git-guard.md` の「hook との分担」の節を読む
- **THEN** `capability-registry` スキルと dev-workflow の hook は「入っていれば」の条件つきで書かれ、入っていない環境での手順（保管庫への昇格はその場で置き場と登録する人を決める、一覧の操作はこのルールだけが止める）が書かれている

#### Scenario: 外した参照の行き先が記録にある

- **WHEN** `plugins/dev-workflow/changes/1098.md` と `plugins/capability-registry/changes/1098.md` を読む
- **THEN** 外した参照ごとに、元の場所・行き先（`rules/README.md` の行、条件つきに直した文、またはなし）が 1 行ずつ書かれている

#### Scenario: 検索語に当たらない固有名は検査を通る

- **WHEN** 6 ファイルのどれかに、検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューと固有記述の一覧が見る

### Requirement: dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない

公開版に残る部品のうち dev-workflow 以外（`rules/README.md`・`scripts/sync.sh`・`scripts/test-auto-merge-workflow.sh`・capability-registry・statusline・worktree・product-handover・casting・cost-ledger・infra）は、固有記述の一覧で担い手なしだった行の語を、許可に載った行を除いて持たない。次の検索の当たりは、許可の行を除いて 0 件でなければならない（MUST）。検索は共有スクリプト `plugins/dev-workflow/scripts/forbidden-words-check.sh` に、検索範囲のファイル一覧と辞書と allow を渡して行い、大文字と小文字を区別しない固定文字列の部分一致で、ファイルの本文とパス名の両方に当てる。

- 検索語: `moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`flatmate`・`/Users/oratta`。語は辞書のファイル（`tests/public-names/dict/` の `moko.txt`・`other-projects.txt`・`flatmate.txt`・`owner-pc-path.txt`）にだけ書き、`tests/public-private-split.bats` に正規表現で書かない。さらに `/Users/oratta` は許可なしでも別に検索し、当たりは 0 件でなければならない
- 対象: 上の部品の公開版のファイル・節
- 公開版のファイル・節: 仕分けの表（`docs/public-private-split.md`）で個人版に決まるファイルと節（capability-registry の `scripts/fmtoken.sh`・`1password.md`・`SKILL.md` の「表記規約」と「資格情報の階層」の節など）は対象に含めない。節を除くときは、対象のファイルを一時ディレクトリに同じ相対パスでコピーし、その節の行を空行にして検査する。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` も含めない
- 許可: 載せない行の基準のうち「出典や経緯としてだけ名前を挙げる行」と「互換のために残す旧名の読み取り」に当たる行は、`tests/public-names/allow/nondev.txt` に共有スクリプトの恒久の書式 `<path>:<語>:=<行に含まれる固定の文字列>` で 1 件ずつ載せたものだけを通す。各行の直前の `#` のコメント行に当たる基準を書く。許可に無い当たりは落ちる。どの当たりも打ち消さない許可の行は、共有スクリプトの「何も打ち消していない」の違反で落ちる

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上の部品の公開版のファイル・節に戻ってくること／許可に無い当たりが現れること／許可の行が何も打ち消さなくなること
- 通してよい具体例: 辞書に無い別の固有名・許可の載せ方と基準の良し悪し・書き換えた例の文の良し悪し・載せない行の基準の判定の正しさ。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/worktree/skills/wt-clean/SKILL.md` に `/Users/oratta/wt/bar` を書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 辞書の語を含む行を足すと落ちる

- **WHEN** 検索範囲のファイルに、辞書のいずれかの語を含む行を 1 行書き足す
- **THEN** 検索のテストが落ち、`<パス>:<行番号>:<語>` が出る

#### Scenario: 許可の出典の行は通る

- **WHEN** `scripts/sync.sh` の出典として flatmate の名を挙げる行が `tests/public-names/allow/nondev.txt` に載っている
- **THEN** 検索のテストは通る。同じファイルの別の行に flatmate を書き足すと、許可に無いので落ちる

#### Scenario: 大文字小文字の違いも拾う

- **WHEN** 検索範囲のファイルに、辞書の語の大文字始まりの綴り（`Uranai` など）の行があり、許可に載っていない
- **THEN** 検索のテストが落ちる

#### Scenario: 何も打ち消さない許可は落ちる

- **WHEN** `tests/public-names/allow/nondev.txt` の写しに、ファイルのどの行にも当たらない固定の文字列を持つ行を足す
- **THEN** 検索のテストが「何も打ち消していない」の違反で落ちる

#### Scenario: パス名の当たりも拾う

- **WHEN** 検索範囲に、辞書の語を名前に含むファイルがある
- **THEN** 検索のテストが `<パス>:path:<語>` で落ちる

#### Scenario: 個人版のファイルと節は検索の対象に入らない

- **WHEN** 個人版に決まる `plugins/capability-registry/scripts/fmtoken.sh` に検索語がある
- **THEN** 検索のテストは落ちない

#### Scenario: 辞書に無い固有名は検査を通る

- **WHEN** 対象のファイルに辞書に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: 載せない行の基準に互換のために残す旧名の読み取りを含める

`docs/public-private-split.md` の「載せない行の基準」は、「互換のために残す旧名の読み取り」を載せない行に含めなければならない（MUST）。当たる行は、新しい名前が主であることと、旧名を互換として読むことが同じ箇所に書かれていなければならない（MUST）。

#### Scenario: 旧名の読み取りの行が一覧から外れる

- **WHEN** 新名を主、旧名を互換と明記した statusline の行を候補語で検索する
- **THEN** 当たった行は基準で説明でき、一覧に載せなくてよい（許可リストに載せる）

### Requirement: dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない

公開版に残る dev-workflow の部品は、固有記述の一覧で担い手なしだった Orca 経路以外の行の語を、許可に載った行を除いて持たない。次の検索の当たりは、許可の行を除いて 0 件でなければならない（MUST）。検索は共有スクリプト `plugins/dev-workflow/scripts/forbidden-words-check.sh` に、検索範囲のファイル一覧と辞書を渡して行い、大文字と小文字を区別しない固定文字列の部分一致で、ファイルの本文とパス名の両方に当てる。語は辞書のファイル（`tests/public-names/dict/`）にだけ書き、`tests/public-private-split.bats` に正規表現で書かない。

- `moko`（`moko.txt`）: `plugins/dev-workflow/` の公開版のファイル
- `new-resident`（`new-resident.txt`）と `flatmate`（`flatmate.txt`）: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`・`plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/dev-workflow/scripts/pr-state.sh`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`（`new-resident` は同じ 7 ファイルに当てる）
- `CLAUDE_HARNESS_DEV_DIR`（`dev-dir-env.txt`）: `plugins/dev-workflow/references/ci-watch.md`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`
- 公開版のファイル: 仕分けの表で個人版に決まるファイル（`plugins/dev-workflow/docs/auto-merge-deployments.md`）と保留の行のファイルは対象に含めない。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` も含めない
- 許可: 載せない行の基準のうち「出典や経緯としてだけ名前を挙げる行」に当たる行は、`tests/public-names/allow/<呼び出しの名前>.txt` に共有スクリプトの恒久の書式 `<path>:<語>:=<行に含まれる固定の文字列>` で 1 件ずつ載せたものだけを通す（各行の直前の `#` のコメント行に当たる基準を書く）。許可に無い当たりは落ちる。どの当たりも打ち消さない許可の行は「何も打ち消していない」の違反で落ちる。現在、この検索に許可の行は 0 件で、allow のファイルは置かない

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上のファイルに戻ってくること／許可に無い当たりが現れること／許可の行が何も打ち消さなくなること
- 通してよい具体例: 辞書に無い別の固有名・許可の載せ方と基準の良し悪し・書き換えた文の良し悪し。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/dev-workflow/references/pr-body-format.md` に flatmate の `new-resident` が issue テンプレートを配ると書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 辞書の語を含む行を足すと落ちる

- **WHEN** 検索範囲のファイルに、その範囲の辞書の語を含む行を 1 行書き足す
- **THEN** 検索のテストが落ち、`<パス>:<行番号>:<語>` が出る

#### Scenario: 許可の出典の行は通る

- **WHEN** 検索対象のファイルに、出典としてだけ flatmate の名を挙げる行があり、その行を指す許可の行が allow のファイルにある
- **THEN** 検索のテストは通る。同じファイルの別の行に flatmate を書き足すと、許可に無いので落ちる

#### Scenario: 辞書に無い固有名は検査を通る

- **WHEN** 対象のファイルに辞書に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: 固有記述の一覧に担い手なしの行を残さない

`docs/public-private-split.md` の固有記述の一覧は、「直す issue」の欄が「担い手なし」の行を 1 件も持ってはならない（MUST NOT）。担い手のない行は、直して一覧から消すか、載せない行の基準に当たる理由を書いて一覧から外す。`tests/public-private-split.bats` は、一覧の全体（dev-workflow の行に限らない）で「担い手なし」の行が 0 件であることを確かめなければならない（MUST）。一覧の行が 0 件になってもこの検査と他の形の検査は通らなければならない（MUST）。

この検査の守備範囲は、既存の要件「表と一覧の検査の守備範囲」に従う。入力の出どころは、テストが自分で読む文書の一覧の表で、拾う誤りと通してよい具体例は次のとおり。範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 一覧の「直す issue」の欄が「担い手なし」の行が 1 件でも残ること
- 通してよい具体例: 載せない行の基準に当たると判定した理由の正しさ・直した文の良し悪し・一覧に載せ忘れた行。人のレビューと、候補語による取りこぼしの確認が見る

#### Scenario: 一覧に担い手なしの行が無い

- **WHEN** 一覧の「直す issue」の欄を読む
- **THEN** 「担い手なし」の行が 0 件である

#### Scenario: 担い手なしの行が戻ると落ちる

- **WHEN** 一覧に「直す issue」が「担い手なし」の行を 1 行足す
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 一覧が空でも検査が通る

- **WHEN** 一覧の行が 0 件で、見出しの行だけがある
- **THEN** 一覧の形の検査は通る

### Requirement: 載せない行の基準に起動部品の 1 つとして並べた行を含める

`docs/public-private-split.md` の「載せない行の基準」は、「差し替え可能な起動部品の 1 つとして Orca を並べた行」を載せない行に含めなければならない（MUST）。当たる行は、Orca を tmux など他の起動部品や方式と並べた 1 つとして書いていなければならず（MUST）、Orca だけを前提にした行（Orca 経路と名乗る・Orca に登録済みのリポジトリを探す・Orca の親が子のターミナルに打ち込む）は当たらない（MUST NOT）。develop `SKILL.md` の「部品ごとの欄」の見出しと表は、この基準に当たる行として一覧に載せない。

この基準は `epic-launch-orca.sh` が公開版に決まる前提で当てる（この部品と `epic-dispatch.sh` は仕分けの表でまだ「保留（#1123 の後）」）。#1129 で個人版に決まったら、基準で外した行を一覧に戻し、担い手を #1129 にしなければならない（MUST）。そのため、外した行の場所は `docs/public-private-split.md` の節「起動部品の 1 つとして一覧から外した行」にファイル:行で 1 行ずつ残さなければならない（MUST）。既存の基準の例「Orca や端末から起動した Claude Code」は一般の製品を並べた例で、この基準は `epic-launch-<名前>.sh` の差し替えの部品として並べた行である。

#### Scenario: 起動部品を並べた行は一覧に載せなくてよい

- **WHEN** 「部品ごとの欄」の表の Orca の部品の列の行を候補語 `Orca` で検索する
- **THEN** 当たった行は基準で説明でき、一覧に載せなくてよい

#### Scenario: 個人版に決まったら外した行を戻す

- **WHEN** #1129 が `epic-launch-orca.sh` を個人版に決める
- **THEN** 文書の節に残した場所の一覧から、外した行を一覧に戻し、担い手を #1129 にする

#### Scenario: Orca だけを前提にした行は基準に当たらない

- **WHEN** 「Orca 経路の子は…」のように Orca だけを前提にした行を候補語で検索する
- **THEN** その行は基準に当たらず、「Orca を使う場合」の書き方に直すか、一覧に載せて担い手を付ける

### Requirement: 公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く

公開版の部品に対する辞書は `tests/public-names/dict/` に置き、語は `tests/public-private-split.bats` に書かれていた語（`moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`flatmate`・`new-resident`・`/Users/oratta`・`CLAUDE_HARNESS_DEV_DIR`）だけでなければならない（MUST）。新しい固有名を公開側の辞書に足してはならない（MUST NOT。新しい固有名は個人版の辞書に書き、共有スクリプトの `--dict` の引数で足す）。同じ語を複数の辞書に書いてはならない（MUST NOT）。`tests/public-private-split.bats` には、検索語の正規表現も許可の配列も残してはならない（MUST NOT。範囲の決定と共有スクリプトの呼び出しだけを持つ）。この検索は `scripts/test.sh` の bats の全スイートの一部として CI で走る。

この要件の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: このリポジトリの管理者が書く辞書・allow・bats。敵対的な入力（辞書を悪意で作る者）は想定しない
- 拾う誤り: 辞書に公開済みの語以外が足されること／同じ語が複数の辞書に書かれること／bats に検索語の正規表現や許可の配列が戻ること
- 通してよい具体例: 辞書の網羅（辞書に無い固有名）・語を公開済みと判定することの正しさ・辞書のファイルの分け方の良し悪し。辞書の整備と人のレビューが見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 辞書が公開済みの語だけである
- **WHEN** `tests/public-names/dict/` のファイルの語を読む
- **THEN** 上の 9 語だけがあり、どの語も 1 つの辞書にだけ書かれている

#### Scenario: bats に語が残らない
- **WHEN** `tests/public-private-split.bats` の語の検索の部分を読む
- **THEN** 辞書の語の正規表現も `NONDEV_ALLOW`・`DEVWF_ALLOW` の配列も無く、共有スクリプトの呼び出しがある

#### Scenario: CI で固有名を足すと落ちる
- **WHEN** 公開版の部品に辞書の語を含む行を足して `scripts/test.sh public-private-split` を実行する
- **THEN** 終了コードが 0 以外になる

#### Scenario: 辞書に無い固有名は検査を通る
- **WHEN** 公開版の部品に辞書に無い固有名を書く
- **THEN** 検索のテストは通る。辞書の網羅は検査の保証の外で、辞書の整備と人のレビューが見る

