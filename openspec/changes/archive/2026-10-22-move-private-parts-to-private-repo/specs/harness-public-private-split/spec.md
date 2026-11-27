## ADDED Requirements

### Requirement: 個人版に移した部品は移した記録に載せ、公開版に残さない

issue #1129 で個人版のリポジトリ `oratta/claude-harness-oratta` に移した部品（`rules/plugin-editing.md`・プラグイン `weekly-report`・プラグイン `daily-report`・`plugins/dev-workflow/docs/auto-merge-deployments.md`・`plugins/capability-registry/scripts/fmtoken.sh`・`plugins/capability-registry/skills/capability-registry/1password.md`・`plugins/capability-registry/skills/capability-registry/SKILL.md` の「表記規約（生成文にも適用すること）」と「資格情報の階層（どこに置くかはプロジェクトごとに決めない）」の 2 節）は、`docs/public-private-split.md` の節「個人版に移した部品」の表に 1 行ずつ載せなければならない（MUST）。各行は部品・移した先（個人版のリポジトリの中のパス）・写し元の公開版の commit SHA を持つ。移した部品の行は仕分けの表に置いてはならない（MUST NOT）。

公開版は移した部品を持ってはならない（MUST NOT）。具体的には、移したファイルとディレクトリのパスの `git ls-files` が 0 件で、`.claude-plugin/marketplace.json` の `plugins[]` と bundle に `weekly-report`・`daily-report` が無く、capability-registry の SKILL.md に移した 2 節の見出しが無い。`tests/public-private-split.bats` が、移した部品のパスと見出しを節「個人版に移した部品」の表から読んで確かめる。プラグイン `weekly-report`・`daily-report` を移したことで付属のファイル（`changes/`・`tests/` など）もプラグインごと公開版から無くなる。capability-registry の `tests/fmtoken.bats` は付属のファイルの扱いに従い `fmtoken.sh` と一緒に移す。

個人版の固有名（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy` など）が公開版の作業ツリーに残っていないかは、個人版のリポジトリに置いた辞書と検査（`scripts/check-public-leak.sh`）で確かめ、公開版の辞書には足さない（要件「公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く」）。

この要件を確かめる公開版の検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: このリポジトリの管理者が書く節「個人版に移した部品」の表と、テストの実行時点の `git ls-files`・`marketplace.json`・SKILL.md の `## ` の見出し
- 拾う誤り: 移した部品が公開版に戻ること（ファイルの復活・marketplace への再登録・節の見出しの復活）／移した部品の行が仕分けの表に残ること／節の表の行が移した先か写し元の SHA を欠くこと
- 通してよい具体例: 個人版に移した中身が写し元と一致しているか、写し元の SHA が実在するか、公開版に残った文に個人版の固有名があるか。個人版の `scripts/check-public-leak.sh` と人のレビューが見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

個人版の検査（`scripts/check-public-leak.sh <公開版の作業ツリー>`）は、個人版の辞書を公開版の `plugins/dev-workflow/scripts/forbidden-words-check.sh` に `--dict` で渡し、当たりが許可に載った行を除いて 1 件でもあれば終了コード 1 で終わり、当たりを `<パス>:<行番号>:<語>` の形で出さなければならない（MUST）。当たりが無ければ終了コード 0 で終わる。公開版の消す PR は、終了コード 0 の結果を本文に載せるまでマージしない。この検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: 引数に渡した公開版の作業ツリーの `git ls-files` のうち、`rules/`・`output-styles/`・`scripts/`・`plugins/` の配下とルート直下の `README.md`・`CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md`（`openspec/`・`docs/public-private-split.md`・`_longruns/`・`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）と、オーナーが書く個人版の辞書と許可。敵対的な入力は想定しない
- 拾う誤り: 辞書の語（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy`）が、検索の範囲のファイルの本文かパス名に、許可に無い形で残ること
- 通してよい具体例: 辞書に無い個人版の固有名、除いた範囲（経緯の記録や公開版の検査）に残る語、公開版の過去の履歴に残る語。人のレビューと辞書の整備が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 移した部品が公開版に無い
- **WHEN** 公開版で、節「個人版に移した部品」の表の各パスを `git ls-files` で調べ、`marketplace.json` と capability-registry の SKILL.md の見出しを読む
- **THEN** どのパスも 0 件で、`weekly-report`・`daily-report` は `plugins[]` にも bundle にも無く、移した 2 節の見出しは SKILL.md に無い

#### Scenario: 移した部品を戻すと落ちる
- **WHEN** 公開版に `rules/plugin-editing.md` を置き直す
- **THEN** `tests/public-private-split.bats` が、そのパスを挙げて落ちる

#### Scenario: 移した部品の行を仕分けの表に残すと落ちる
- **WHEN** 仕分けの表に `plugins/capability-registry/scripts/fmtoken.sh` の行を残す
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 移した記録が読める
- **WHEN** `docs/public-private-split.md` の節「個人版に移した部品」を読む
- **THEN** 移した部品ごとに移した先のパスと写し元の commit SHA が書かれている

#### Scenario: 公開版に個人版の固有名が残っていない
- **WHEN** 個人版のリポジトリで `scripts/check-public-leak.sh <公開版の作業ツリー>` を実行する
- **THEN** 終了コードが 0 で、結果が公開版の消す PR の本文に載っている

#### Scenario: 公開版に個人版の固有名が残っていると落ちる
- **WHEN** 公開版の作業ツリーの `README.md` に `weekly-report` を含む行が残ったまま、個人版のリポジトリで `scripts/check-public-leak.sh <公開版の作業ツリー>` を実行する
- **THEN** 終了コードが 1 で、`README.md:<行番号>:weekly-report` が出る。公開版の消す PR はこの状態ではマージしない

#### Scenario: 除いた範囲の語は個人版の検査を通る
- **WHEN** 公開版の `docs/public-private-split.md` の節「個人版に移した部品」に `fmtoken.sh` がある
- **THEN** 個人版の検査は終了コード 0 で終わる

## MODIFIED Requirements

### Requirement: dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない

公開版に残る部品のうち dev-workflow 以外（`rules/README.md`・`scripts/sync.sh`・`scripts/test-auto-merge-workflow.sh`・capability-registry・statusline・worktree・product-handover・casting・cost-ledger・infra）は、固有記述の一覧で担い手なしだった行の語を、許可に載った行を除いて持たない。次の検索の当たりは、許可の行を除いて 0 件でなければならない（MUST）。検索は共有スクリプト `plugins/dev-workflow/scripts/forbidden-words-check.sh` に、検索範囲のファイル一覧と辞書と allow を渡して行い、大文字と小文字を区別しない固定文字列の部分一致で、ファイルの本文とパス名の両方に当てる。

- 検索語: `moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`flatmate`・`/Users/oratta`。語は辞書のファイル（`tests/public-names/dict/` の `moko.txt`・`other-projects.txt`・`flatmate.txt`・`owner-pc-path.txt`）にだけ書き、`tests/public-private-split.bats` に正規表現で書かない。さらに `/Users/oratta` は許可なしでも別に検索し、当たりは 0 件でなければならない
- 対象: 上の部品の公開版のファイル・節
- 公開版のファイル・節: 上の部品の git 管理下のファイル。#1129 で個人版のリポジトリへ移したファイルと節（capability-registry の `scripts/fmtoken.sh`・`1password.md`・`SKILL.md` の「表記規約」と「資格情報の階層」の節）は公開版に無いので、ファイルや節を除く手当てはしない（MUST NOT。capability-registry の `SKILL.md` は全体を検索の対象にする）。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は含めない
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

#### Scenario: capability-registry の SKILL.md は全体が検索の対象になる

- **WHEN** `plugins/capability-registry/skills/capability-registry/SKILL.md` の「原則」の節に `moko` を書き足す
- **THEN** 検索のテストが落ちる（個人版の節を除く手当てが無いので、SKILL.md のどの節に書いても当たる）

#### Scenario: 辞書に無い固有名は検査を通る

- **WHEN** 対象のファイルに辞書に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない

公開版に残る dev-workflow の部品は、固有記述の一覧で担い手なしだった Orca 経路以外の行の語を、許可に載った行を除いて持たない。次の検索の当たりは、許可の行を除いて 0 件でなければならない（MUST）。検索は共有スクリプト `plugins/dev-workflow/scripts/forbidden-words-check.sh` に、検索範囲のファイル一覧と辞書を渡して行い、大文字と小文字を区別しない固定文字列の部分一致で、ファイルの本文とパス名の両方に当てる。語は辞書のファイル（`tests/public-names/dict/`）にだけ書き、`tests/public-private-split.bats` に正規表現で書かない。

- `moko`（`moko.txt`）: `plugins/dev-workflow/` の公開版のファイル
- `new-resident`（`new-resident.txt`）と `flatmate`（`flatmate.txt`）: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`・`plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/dev-workflow/scripts/pr-state.sh`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`（`new-resident` は同じ 7 ファイルに当てる）
- `CLAUDE_HARNESS_DEV_DIR`（`dev-dir-env.txt`）: `plugins/dev-workflow/references/ci-watch.md`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`
- 公開版のファイル: `plugins/dev-workflow/` の git 管理下のファイル。#1129 で個人版のリポジトリへ移した `plugins/dev-workflow/docs/auto-merge-deployments.md` は公開版に無いので、ファイルを除く手当てはしない（MUST NOT）。#1129 で公開版に確定したエピック実行の部品（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）は対象に含める。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は含めない
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

#### Scenario: 確定したエピック実行の部品も moko の検索の対象になる

- **WHEN** `plugins/dev-workflow/scripts/stop-judge.sh` に `moko` を書き足す
- **THEN** `tests/public-private-split.bats` が落ちる
