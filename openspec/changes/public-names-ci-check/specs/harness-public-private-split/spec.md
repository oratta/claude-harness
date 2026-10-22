## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: 公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く

公開版の部品に対する辞書は `tests/public-names/dict/` に置き、語は `tests/public-private-split.bats` に書かれていた語（`moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`flatmate`・`new-resident`・`/Users/oratta`・`CLAUDE_HARNESS_DEV_DIR`）だけでなければならない（MUST）。新しい固有名を公開側の辞書に足してはならない（MUST NOT。新しい固有名は個人版の辞書に書き、共有スクリプトの `--dict` の引数で足す）。同じ語を複数の辞書に書いてはならない（MUST NOT）。`tests/public-private-split.bats` には、検索語の正規表現も許可の配列も残してはならない（MUST NOT。範囲の決定と共有スクリプトの呼び出しだけを持つ）。この検索は `scripts/test.sh` の bats の全スイートの一部として CI で走る。

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
