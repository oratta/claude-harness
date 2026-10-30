# ci-bats-shards Specification

## Purpose
TBD - created by archiving change ci-bats-shards. Update Purpose after archive.
## Requirements
### Requirement: scripts/test.sh は TEST_SHARD で全体を分けた 1 組だけを実行できる

`scripts/test.sh` は、環境変数 `TEST_SHARD=k/N`（k と N は 1 以上の整数で k ≦ N）が与えられたとき、`git ls-files -- '*.bats' ':(exclude)_longruns/'` の一覧の i 番目（1 始まり）のうち `(i − 1) mod N + 1` が k に等しいものだけを対象にしなければならない（MUST）。組の割り当ては、位置引数のフィルタと `TEST_EXCLUDE` を当てる前の一覧に対して決めなければならない（MUST）。割り当てのあとの対象には、既存のフィルタと `TEST_EXCLUDE` をそのまま当てる。

`TEST_SHARD` が未設定か空文字のとき、`scripts/test.sh` は分割せず、この変更の前と同じ対象を実行しなければならない（MUST）。

`TEST_SHARD` が指定されたとき、`scripts/test.sh` は実行前の表示に、どの組を実行しているかを `  (shard k/N)`（行頭に空白 2 つ。k と N は受け取った値）という 1 行で出さなければならない（MUST）。この行は `  (skipped by TEST_EXCLUDE: <件数>)` の行のすぐ次、区切り線の前に置き、`▶ bats suites:` の下に並ぶ対象スイートの行のあいだに混ぜてはならない（MUST NOT）。`TEST_SHARD` が未設定か空文字のとき、この行を出してはならない（MUST NOT）。対象スイートの一覧は、`▶ bats suites:` の次の行から、`  (` で始まる最初の行の手前までである。

#### Scenario: 全部の組を合わせると全件と一致する

- **WHEN** 追跡下の `.bats` が 7 本ある使い捨てリポジトリで、`TEST_SHARD=1/3`・`2/3`・`3/3` のそれぞれで `scripts/test.sh` を実行し、表示された対象スイートを集める
- **THEN** 集めた一覧に重複が無く、`git ls-files -- '*.bats' ':(exclude)_longruns/'` の 7 本と一致する

#### Scenario: 割り当ては一覧の順番で決まる

- **WHEN** 追跡下の `.bats` が `s1.bats` 〜 `s7.bats` の 7 本ある使い捨てリポジトリで `TEST_SHARD=2/3 scripts/test.sh` を実行する
- **THEN** 対象として表示されるのは `git ls-files` の 2 番目と 5 番目（`s2.bats` と `s5.bats`）だけで、`  (skipped by TEST_EXCLUDE: 0)` の行のすぐ次に `  (shard 2/3)` の行が出る

#### Scenario: 未指定なら全件を実行する

- **WHEN** 同じ使い捨てリポジトリで `TEST_SHARD` を設定せずに `scripts/test.sh` を実行する
- **THEN** 7 本すべてが対象として表示され、`(shard` を含む行は出ず、exit code は 0 になる

#### Scenario: フィルタと組み合わせても割り当ては変わらない

- **WHEN** 同じ使い捨てリポジトリで `TEST_SHARD=2/3 scripts/test.sh s5` を実行する
- **THEN** 対象は `s5.bats` だけになる（フィルタに一致する `s5.bats` は、フィルタなしのときと同じ 2 番目の組に入っている）

#### Scenario: 除外されたスイートは属する組でだけ数えられる

- **WHEN** 同じ使い捨てリポジトリで `TEST_EXCLUDE=s2` を付けて `TEST_SHARD=1/3`・`2/3`・`3/3` のそれぞれを実行する
- **THEN** `skipped by TEST_EXCLUDE` の件数は `2/3` の実行で 1、ほかの 2 つの実行で 0 になる

### Requirement: 不正な TEST_SHARD と空の組は成功にしない

`scripts/test.sh` が受け付ける `TEST_SHARD` は、「0 で始まらない 10 進の数字の並び」「`/`」「0 で始まらない 10 進の数字の並び」をこの順につないだ文字列（`1/4`、`12/12` など）で、k ≦ N のものだけである。それ以外の空でない値（`k/N` の形でない、k か N が 0、k が N より大きい、先頭にゼロがある、前後や途中に空白がある）のとき、`scripts/test.sh` は bats を実行せずに 0 以外の exit code で終わり、受け取った値を含むメッセージを標準エラーに出さなければならない（MUST）。全件の実行に切り替えてはならない（MUST NOT）。

分割の結果、その組の対象が 1 件も無いとき、`scripts/test.sh` は 0 以外の exit code で終わらなければならない（MUST）。

この検査の守備範囲は次のとおり。値の出どころは `.github/workflows/ci.yml` の `env`（`${{ matrix.shard }}/<分母>` を展開したもの）と、手元のシェルで人が書いた値の 2 つで、どちらもこのリポジトリを編集できる人が書く。拾いたい誤りは 1 つで、`ci.yml` の書き間違いで値が崩れたときに、各ジョブが黙って全件を走らせ「遅いだけで通る」状態になることである。通ることを許す入力は上の形だけで、`01/4` や `1/4 `（末尾に空白）は `1/4` と読み替えずに落とす。`ci.yml` の展開結果には先頭ゼロも空白も現れないので、読み替えを足しても拾える誤りは増えず、落とす側に倒したほうが規則が 1 つで済むためである（先頭ゼロを通すと sh の算術展開が 8 進数として読む）。悪意のある値や、シェルの整数に収まらない桁数の値まで塞ぎ切ることは完了条件にしない。

#### Scenario: 形式が不正な値を拒否する

- **WHEN** `TEST_SHARD` に `0/4`・`5/4`・`2`・`a/4`・`1/0`・`1/4/2`・`01/4`・`1/04`・` 1/4`（先頭に空白）・`1/4 `（末尾に空白）のそれぞれを設定して `scripts/test.sh` を実行する
- **THEN** どの場合も exit code が 0 以外で、標準エラーに受け取った値が出て、対象スイートの一覧（`▶ bats suites:`）は表示されない

#### Scenario: 対象が無い組は失敗する

- **WHEN** 追跡下の `.bats` が 2 本の使い捨てリポジトリで `TEST_SHARD=3/3 scripts/test.sh` を実行する
- **THEN** exit code が 0 以外になる

### Requirement: CI は bats を複数のジョブに分け、全部の組で全件を実行する

`.github/workflows/ci.yml` は、`scripts/test.sh` を `TEST_SHARD` の異なる複数のジョブ（matrix）で実行しなければならない（MUST）。matrix の組の番号はちょうど 1 から N までの整数で、各ジョブに渡す `TEST_SHARD` の分母は N に等しくなければならない（MUST）。分けたジョブは、1 つが失敗しても残りを最後まで実行しなければならない（MUST。`fail-fast: false`）。

`ci.yml` が実行する全部の組の対象スイートを合わせたものは、`git ls-files -- '*.bats' ':(exclude)_longruns/'` と重複なく一致しなければならない（MUST）。これを確かめるテストが `scripts/test.sh` の全件実行に含まれなければならない（MUST）。

bats の `--jobs` を使ってはならない（MUST NOT）。

組の番号と分母を確かめるテストの守備範囲は次のとおり。読む入力はこのリポジトリの `.github/workflows/ci.yml` だけで、書くのはこのリポジトリを編集できる人である。拾いたい誤りは、分割数を変えるときに matrix と分母の片方だけを直して、どのジョブにも入らない組ができることである。テストが読める形は、組の番号を 1 行のリストで書いた `shard: [1, 2, 3, 4]` と、分母を数字で直接書いた `TEST_SHARD: ${{ matrix.shard }}/4` の 2 つだけ（数字と要素の数は変わってよい）で、この形であれば通ることを許す。複数行で書いた matrix、`include:` で足した組、変数や式を経由した分母は「読めない」として失敗にする。読めないまま通すと、番号がそろっているかを確かめないまま CI が緑になるので、落とす側に倒す。YAML として同じ意味になる別の書き方をすべて読めるようにすることは完了条件にしない。

#### Scenario: ci.yml の組の番号と分母がそろっている

- **WHEN** `scripts/test.sh ci-bats-shards` を実行する
- **THEN** `ci.yml` の matrix の組の番号がちょうど 1〜N で、`TEST_SHARD` の分母が N に等しいことを確かめるテストが `ok` になる

#### Scenario: 実物のリポジトリで合計が全件と一致する

- **WHEN** `ci.yml` から読んだ N について、何も実行せず exit 0 する `bats` の代役を PATH の先頭に置き、このリポジトリの `scripts/test.sh` を `TEST_SHARD=1/N` 〜 `N/N` で実行して、表示された対象スイートを集める
- **THEN** 集めた一覧の行数が `git ls-files -- '*.bats' ':(exclude)_longruns/' | wc -l` と等しく、重複が無く、内容が一致する

#### Scenario: 組の番号が欠けた ci.yml は検知される

- **WHEN** matrix の組の番号を 1〜3 にしたまま `TEST_SHARD` の分母を 4 にした `ci.yml` の写しに対して、組の番号と分母を確かめる検査を当てる
- **THEN** 検査が失敗する

#### Scenario: 読めない形の matrix は失敗になる

- **WHEN** 組の番号を複数行のリストで書いた `ci.yml` の写しと、分母を `${{ env.SHARDS }}` のような式にした `ci.yml` の写しのそれぞれに対して、組の番号と分母を確かめる検査を当てる
- **THEN** どちらも検査が失敗する

### Requirement: 分けたジョブの結果は bats suites という名前のジョブにまとめて報告される

`ci.yml` は、分けたジョブをすべて `needs` で待つジョブを 1 つ持ち、その `name:` は `bats suites` でなければならない（MUST）。このジョブは分けたジョブの結果にかかわらず実行され（`if: always()`）、`needs` のジョブの result がすべて `success` のときだけ成功し、1 つでも `failure`・`cancelled`・`skipped` があれば失敗しなければならない（MUST）。

このジョブの判定は、ジョブ ID を列挙せずに `needs.*.result` を使い、`needs` の全要素が `success` のときだけ成功しなければならない（MUST）。`needs.<ジョブ ID>.result` の形で個別のジョブを指してはならない（MUST NOT）。`if: always()` を付けたジョブは、`needs` のジョブが失敗しても実行されるので、「`needs` に書けば、そのジョブが落ちたときに止まる」という保証が無くなる。判定が特定のジョブ ID しか見ていないと、あとから `needs` に足したジョブが落ちても `bats suites` が成功し、自動マージされる。

`.github/workflows/auto-merge.yml` の `REQUIRED_CHECKS` は `shellcheck` と `bats suites` のまま変えてはならない（MUST NOT）。分けたジョブの `name:` は `bats suites` と異なる名前でなければならない（MUST）。

まとめるジョブの構造を確かめるテストの守備範囲は次のとおり。読む入力はこのリポジトリの `.github/workflows/ci.yml` だけで、書くのはこのリポジトリを編集できる人である。拾いたい誤りは 2 つで、`if: always()` を外して、分けたジョブが落ちたときに `bats suites` が「失敗」ではなく「飛ばされた」になること、判定を `needs.<ジョブ ID>.result` の形に書き換えて、`needs` に足したジョブを見落とすことである。テストが見るのは、`name: bats suites` のジョブのブロックに、1 行で書いた `needs:`、インデント 4 の `if: always()`、文字列 `needs.*.result` があり、`needs.<ジョブ ID>.result` の形が無いことで、この条件を満たせば、判定の書き方（式の中で `contains` を使う、環境変数に渡してシェルで比べる、など）は問わずに通す。判定の式やシェルの論理が正しいことはこのテストでは確かめず、1 件わざと落とした PR の CI で確かめる（下の Scenario）。文字列を満たしながら判定を無効にする書き方（判定のステップに `continue-on-error` を付ける、など）まで塞ぎ切ることは完了条件にしない。

#### Scenario: まとめるジョブの構造

- **WHEN** `scripts/test.sh ci-bats-shards` を実行する
- **THEN** `ci.yml` に `name: bats suites` のジョブがちょうど 1 つあり、そのジョブが分けたジョブを `needs` に持ち、`if: always()` を持ち、判定のステップが `needs.*.result` を参照し、`needs.<ジョブ ID>.result` の形を含まないことを確かめるテストが `ok` になる

#### Scenario: ジョブ ID を列挙した判定は検知される

- **WHEN** まとめるジョブの判定を `needs.*.result` から、分けたジョブの ID を使った `needs.<ジョブ ID>.result` に書き換えた `ci.yml` の写しと、`if: always()` の行を消した `ci.yml` の写しのそれぞれに対して、まとめるジョブの構造を確かめる検査を当てる
- **THEN** どちらも検査が失敗する

#### Scenario: 1 つの組でテストが落ちると bats suites が失敗する

- **WHEN** 分けたジョブのうち 1 つに入るスイートのテストを 1 件わざと失敗させた PR を作り、CI を走らせる
- **THEN** その組のジョブが failure になり、ほかの組は最後まで走り、`bats suites` のチェックの conclusion が `failure` になって、その PR は自動マージされない

### Requirement: ci.yml の全ジョブは必須チェックか、必須チェックが待つジョブである

`scripts/test-auto-merge-workflow.sh` は、`REQUIRED_CHECKS` と `ci.yml` について次の 3 つをすべて確かめ、1 つでも満たさなければ 0 以外の exit code で終わらなければならない（MUST）。

1. `REQUIRED_CHECKS` の名前それぞれが、`ci.yml` のちょうど 1 つのジョブの `name:` に一致する
2. `ci.yml` のすべてのジョブに `name:` がある
3. `ci.yml` のジョブのうち `name:` が `REQUIRED_CHECKS` に無いものは、`REQUIRED_CHECKS` に名前があるジョブの `needs:` にジョブ ID が挙がっている

`needs:` は 1 行の形（`needs: <id>` か `needs: [<id>, ...]`）で読み、それ以外の形で書かれているときは検査を失敗にしなければならない（MUST）。

`ci.yml` は `scripts/test-auto-merge-workflow.sh` を 1 回の CI につき 1 回だけ、必須チェックのジョブ（`shellcheck`）の中で実行しなければならない（MUST）。

この検査の守備範囲は次のとおり。読む入力は `.github/workflows/auto-merge.yml` の `# >>> required-checks` マーカーのあいだと、`.github/workflows/ci.yml` の 2 つで、書くのはこのリポジトリを編集できる人である（どちらも聖域パスで、変更は人間がマージする）。`ci.yml` で読む形は 1 つだけで、`jobs:` の直下のインデント 2 のキーをジョブ ID、そのジョブのインデント 4 の `name:` と `needs:` をジョブ名と依存として読み、`needs:` は 1 行の形だけを読む。拾いたい誤りは 2 つで、必須チェックの名前とジョブ名がずれて永久にマージされなくなること、足したジョブを必須チェックにも `needs:` にも入れ忘れて、そのジョブが落ちてもマージされることである。

通ることを許す入力は次のとおり。必須チェックのジョブに `if:` の条件が付いていても、この検査は見ずに通す（条件でジョブが飛ばされたときは、`auto-merge.yml` が conclusion を `success` と比べる時点でマージが止まる）。`name:` の値は、`${{ }}` の式や YAML のアンカーで組み立てられていても展開せず、`name: ` より後ろの文字列をそのまま `REQUIRED_CHECKS` の名前と比べる。したがって `bats shard ${{ matrix.shard }}/4` のような名前は「必須チェックでないジョブ」として扱われ、引用符で囲んだ `name: "bats suites"` は `bats suites` と一致しない（落ちる側に倒れる）。

推移的な依存は認めない。ジョブ A を待つジョブ B を、必須チェックのジョブが待っている場合でも、A のジョブ ID が必須チェックのジョブの `needs:` に直接挙がっていなければ、A について検査を失敗にしなければならない（MUST）。B が `if: always()` を持つと、A が落ちても B が成功しうるためである。

`ci.yml` 以外のワークフローのジョブ、再利用ワークフロー（ジョブ直下の `uses:`）の中のジョブ、必須チェックのジョブが `needs` の結果を実際に判定しているか（これは「分けたジョブの結果は bats suites という名前のジョブにまとめて報告される」の要件が受け持つ）は、この検査では見ない。YAML として同じ意味になる別の書き方をすべて読めるようにすること、検査を通しながら意味を変える書き方を塞ぎ切ることは完了条件にしない。

#### Scenario: このリポジトリの ci.yml が通る

- **WHEN** このリポジトリで `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 になる

#### Scenario: 必須チェックにも needs にも入っていないジョブは検知される

- **WHEN** このリポジトリのワークフローと docs を写した木の `ci.yml` に、`name:` が `REQUIRED_CHECKS` に無く、どの必須チェックのジョブの `needs:` にも挙がっていないジョブを 1 つ足し、`AUTOMERGE_TEST_ROOT` をその木に向けて `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になり、出力に足したジョブが分かる情報（ジョブ ID か名前）が含まれる

#### Scenario: 推移的にしか待たれていないジョブは検知される

- **WHEN** 同じ写しの `ci.yml` に、必須チェックでないジョブ `extra` を足し、分けたジョブの `needs:` に `extra` を書く（`bats suites` のジョブの `needs:` には `extra` を書かない）状態で `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になり、出力に `extra` が含まれる

#### Scenario: 複数行の needs は失敗になる

- **WHEN** 同じ写しの `ci.yml` で、`bats suites` のジョブの `needs:` を複数行のリストに書き換えて `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になり、出力に `needs:` を 1 行の形で書くよう求める文が含まれる

#### Scenario: 必須チェックのジョブに付いた if は通る

- **WHEN** このリポジトリの `ci.yml`（`bats suites` のジョブが `if: always()` を持つ）に対して `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** 必須チェックと `ci.yml` のジョブの対応の検査は ok になる

#### Scenario: 必須チェックの名前に一致するジョブが無いと検知される

- **WHEN** 同じ写しの `ci.yml` で、まとめるジョブの `name:` を `bats suites` 以外に変えて `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になる

#### Scenario: name の無いジョブは検知される

- **WHEN** 同じ写しの `ci.yml` で、分けたジョブの `name:` の行を消して `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** exit code が 0 以外になる

#### Scenario: 不変条件の検査は 1 回だけ走る

- **WHEN** `ci.yml` を確認する
- **THEN** `scripts/test-auto-merge-workflow.sh` を実行するステップは `name: shellcheck` のジョブにちょうど 1 つあり、matrix で分けたジョブには無い

