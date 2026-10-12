行番号は仕様づくりの時点（HEAD 7225146d）の値で、前のタスクの編集でずれうる。編集前に該当範囲を読んで確かめる。

## 1. 変更前の計測

- [ ] 1.1 `ci.yml` を変える前の PR の CI について、開始から全チェック完了までの時間を 5 回ぶん集める（`gh api "repos/oratta/claude-harness/actions/workflows/ci.yml/runs?event=pull_request&status=success&per_page=20"` の `run_started_at` と `updated_at` の差。直近の 5 run。run の URL を添える）。結果は 5.3 のコメントにまとめて書くので、ここでは値を控える。触る範囲: なし（計測のみ）

## 2. scripts/test.sh の分割指定

- [ ] 2.1 失敗するテストを先に書く: `tests/ci-bats-shards.bats` を作り、使い捨てリポジトリ（`s1.bats`〜`s7.bats`）に `scripts/test.sh` を写して回す形で、spec の「scripts/test.sh は TEST_SHARD で全体を分けた 1 組だけを実行できる」と「不正な TEST_SHARD と空の組は成功にしない」の全シナリオを書く（使い捨てリポジトリの作り方は `tests/test-sh-residual-guard.bats` の setup と同じ。内側の `.bats` は 1 件だけ通るテストにする）。触る範囲: tests/ci-bats-shards.bats（新規）、tests/test-sh-residual-guard.bats:13-22（setup。参照のみ）
- [ ] 2.2 `scripts/test.sh` に `TEST_SHARD=k/N` を足す: 値の検証（不正なら標準エラーに値を出して exit 1。bats の有無の確認より後、対象の列挙より前）、`ALL_SUITES` の i 番目を `(i − 1) mod N + 1` の組に割り当ててからフィルタと `TEST_EXCLUDE` を当てる、`  (skipped by TEST_EXCLUDE: <件数>)` の行のすぐ次に `  (shard k/N)` の 1 行を出す（対象スイートの一覧の行のあいだには混ぜない。未指定のときは出さない）。受け付ける値は「0 で始まらない数字 / 0 で始まらない数字」で k ≦ N のものだけにし、先頭ゼロや空白を含む値は読み替えずに落とす。POSIX sh のまま書く（bashism を使わない）。ヘッダのコメントに `TEST_SHARD` の説明を足し、「bats を 1 回だけ呼び」の記述は残す。触る範囲: scripts/test.sh:1-28（ヘッダ）、scripts/test.sh:47-100（対象の列挙と表示）
- [ ] 2.3 `scripts/test.sh ci-bats-shards` と `scripts/lint.sh` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 3. 必須チェックと ci.yml のジョブの対応の検査

- [ ] 3.1 失敗するテストを先に書く: `tests/ci-bats-shards.bats` に、このリポジトリの `.github/workflows/`・`docs/auto-merge.md`・`scripts/test-auto-merge-workflow.sh` を写した木を作り、`AUTOMERGE_TEST_ROOT` を向けて検査を回すテストを足す（spec「ci.yml の全ジョブは必須チェックか、必須チェックが待つジョブである」の「必須チェックにも needs にも入っていないジョブは検知される」「必須チェックの名前に一致するジョブが無いと検知される」「name の無いジョブは検知される」「推移的にしか待たれていないジョブは検知される」「複数行の needs は失敗になる」。「必須チェックのジョブに付いた if は通る」は 4.2 のあとで通る）。写した木に要るファイルは `scripts/test-auto-merge-workflow.sh` の冒頭の実在確認で確かめる。触る範囲: tests/ci-bats-shards.bats（新規）、scripts/test-auto-merge-workflow.sh:23-64（ROOT の解決と実在確認。参照のみ）
- [ ] 3.2 `scripts/test-auto-merge-workflow.sh` の検査 (2) を design の決定 5 の 3 条件に置き換える（ジョブ ID は `jobs:` の直下のインデント 2 のキー、`name:` と `needs:` はインデント 4。`needs:` は 1 行の形だけを読み、それ以外は ng にして「1 行の形で書く」と出す。ng のときは該当のジョブ ID か名前を出す。必須チェックでないジョブは、必須チェックのジョブの `needs:` に直接挙がっているものだけを通し、推移的な依存は ng にする。`name:` の値は式やアンカーを展開せず文字列のまま比べ、必須チェックのジョブの `if:` は見ない。守備範囲は spec の該当要件のとおりで、それ以上の書き方に対応しない）。ヘッダの (2) の説明も書き換える。触る範囲: scripts/test-auto-merge-workflow.sh:11-13（ヘッダ）、scripts/test-auto-merge-workflow.sh:398-416（検査 (2)）
- [ ] 3.3 この時点（`ci.yml` は未変更で 2 ジョブとも必須チェック）で `scripts/test-auto-merge-workflow.sh` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 4. ci.yml の分割

- [ ] 4.1 失敗するテストを先に書く: `tests/ci-bats-shards.bats` に、`ci.yml` を読むテストを足す（matrix の組の番号がちょうど 1〜N で `TEST_SHARD` の分母が N、`fail-fast: false`、`name: bats suites` のジョブがちょうど 1 つで `needs` と `if: always()` を持ち、判定のステップが `needs.*.result` を参照して `needs.<ジョブ ID>.result` の形を含まない、分けたジョブの名前が `bats suites` と異なる、`scripts/test-auto-merge-workflow.sh` を実行するステップが `name: shellcheck` のジョブにちょうど 1 つ、`--jobs` を使っていない）。組の番号と分母の検査、まとめるジョブの構造の検査はそれぞれ関数にして、`ci.yml` の写しで失敗することも確かめる（組の番号を 1〜3・分母を 4 にした写し、複数行の matrix の写し、分母を式にした写し、判定を `needs.<ジョブ ID>.result` に書き換えた写し、`if: always()` を消した写し）。読めない形は失敗に倒す。対象スイートの一覧は `▶ bats suites:` の次の行から `  (` で始まる最初の行の手前までを集める。あわせて「実物のリポジトリで合計が全件と一致する」（何もせず exit 0 する `bats` の代役を PATH の先頭に置き、`ci.yml` から読んだ N の全部の組でこのリポジトリの `scripts/test.sh` を回して一覧を集める）を足す。触る範囲: tests/ci-bats-shards.bats（新規）
- [ ] 4.2 `.github/workflows/ci.yml` を書き換える: `test` ジョブを matrix（`shard: [1, 2, 3, 4]`、`fail-fast: false`、`TEST_SHARD: ${{ matrix.shard }}/4`、名前は `bats suites` と異なるもの）にする。分けたジョブを `needs` で待つジョブ（`name: bats suites`、`if: always()`、checkout なし。判定はジョブ ID を列挙せず `needs.*.result` を使い、全要素が `success` でなければ exit 1。このジョブのブロックにはコメントも含めて `needs.<ジョブ ID>.result` の形を書かない）を足す。`if: always()` は取り消された run でも failure を付ける意図した挙動なので `!cancelled()` にしない、とコメントに書く。`auto-merge workflow invariants` のステップを `lint` ジョブへ移す。冒頭のコメントの件数（「全 990 件（2026-09-03 時点）」）と構成の説明を今の形に直し、bats の版の固定・`TEST_EXCLUDE` のコメント・`permissions`・`concurrency` は変えない。50〜54 行のサードパーティ製 action の固定方針のコメント（文字列 `#138` と `コミット SHA で固定する`）はそのまま残す（`tests/discord-plugin-retirement.bats:52-55` が要求する）。触る範囲: .github/workflows/ci.yml:4-12（冒頭のコメント）、.github/workflows/ci.yml:50-54（残すコメント。参照のみ）、.github/workflows/ci.yml:56-90（jobs）
- [ ] 4.3 `docs/auto-merge.md` の「ci.yml を変えるときの注意」を、置き換えた規則（ジョブを足すときは必須チェックに入れるか、必須チェックのジョブの `needs` に入れる。分けた bats のジョブは `bats suites` が待つ）に書き換える。書き換えたあとも文字列 `REQUIRED_CHECKS` を本文に残す（`scripts/test-auto-merge-workflow.sh` の検査 (5) が `docs/auto-merge.md` にこの文字列があることを見る）。触る範囲: docs/auto-merge.md:226-238、scripts/test-auto-merge-workflow.sh:587-604（検査 (5)。参照のみ）
- [ ] 4.4 `scripts/test.sh`（全件）・`scripts/test-auto-merge-workflow.sh`・`scripts/lint.sh` がすべて exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 5. CI での確認と計測（PR を作ったあと）

- [ ] 5.1 PR の CI で、分けたジョブが 4 つ走り、`bats suites` と `shellcheck` が success になることを確かめる。各組のログの対象スイートの件数の合計が `git ls-files -- '*.bats' ':(exclude)_longruns/' | wc -l` と一致することを確かめる。触る範囲: なし（確認のみ）
- [ ] 5.2 この PR のブランチから別のブランチを切り、テストを 1 件わざと失敗させた確認用の Draft PR を作って CI を走らせる。その組のジョブが failure、ほかの組が最後まで走り、`bats suites` の conclusion が `failure` になることを `gh api repos/oratta/claude-harness/commits/<sha>/check-runs` で確かめ、run の URL を issue #990 にコメントする。確認用の PR はマージせずに閉じる（ブランチの削除は主に確認してから行う）。触る範囲: なし（確認用のブランチでのみ 1 件のテストを書き換える）
- [ ] 5.3 変更後の CI の開始から全チェック完了までの時間を 5 回ぶん測る（この PR の run。足りないぶんは `gh run rerun <run-id>` で走らせる）。変更前の 5 回（1.1）と並べ、組ごとの所要時間を添えて issue #990 にコメントする。所要時間に合否の線は引かず、縮んだ幅と、分割数を 4 のままにするかの判断を書く。触る範囲: なし（計測のみ）
