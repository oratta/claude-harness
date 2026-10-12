行番号は仕様づくりの時点（HEAD 85dd795e）の値。編集の前に該当範囲を読んで確かめる。

この change で触ってよいのは下の「触る範囲」に書いたファイルだけ。`plugins/dev-workflow/skills/` の下（`stages/triage.md`・`hold.md`・`pass.md`・`reviewer-brief.md`・`declarations.md`・`decision-criteria.md`・`worker/spec.md`・`spec-reviewer.md`・develop の `SKILL.md`）は、issue #973 の別の change が触るので変えない。

## 1. テストを先に書く（落ちることを確かめる）

- [x] 1.1 `plugins/dev-workflow/tests/review-issue-candidates.bats` を作り、`setup` で一時ディレクトリに偽物の `gh` を置いて `PATH` の先頭に足す。偽物は呼び出しの引数を 1 行 1 回でログに残し、`issue list` には検索語ごとに用意した JSON（`[{"number":…,"title":…}]`）を、`api …/sub_issues` には用意した JSON を返し、用意した印のファイルがあれば非 0 で終わる。形は `plugins/dev-workflow/tests/pr-state.bats` の `setup` に合わせる。触る範囲: plugins/dev-workflow/tests/review-issue-candidates.bats（新規）、参照のみ plugins/dev-workflow/tests/pr-state.bats:13-39（setup・teardown）
- [x] 1.2 要件「パスごとに open の issue を 1 回検索して番号と題名を返す」の 5 つの Scenario を 1 つずつテストにする（呼び出しの回数と検索語はログで確かめる。本文が出ないことは、偽物が返す JSON に `body` を入れて確かめる）。触る範囲: plugins/dev-workflow/tests/review-issue-candidates.bats（新規）
- [x] 1.3 要件「外す番号を除き、パスごとに最大 15 件で打ち切る」の 4 つの Scenario をテストにする（`--limit 18`、16 件と 15 件の境界）。触る範囲: plugins/dev-workflow/tests/review-issue-candidates.bats（新規）
- [x] 1.4 要件「エピックを指定すると子かどうかを添え、子だけに絞ることもできる」の 4 つの Scenario をテストにする。触る範囲: plugins/dev-workflow/tests/review-issue-candidates.bats（新規）
- [x] 1.5 要件「検索に失敗したら候補なしと区別できる形で終わる」の 10 個の Scenario をテストにする（終了コード 1 と 2、標準出力が空、`gh` のログが空）。`gh`・`jq` が無いときは `PATH` を絞って確かめる。触る範囲: plugins/dev-workflow/tests/review-issue-candidates.bats（新規）
- [x] 1.6 `bats plugins/dev-workflow/tests/review-issue-candidates.bats` を実行し、スクリプトが無いので全件落ちることを確かめる。触る範囲: なし（実行のみ）

## 2. スクリプトを書く

- [x] 2.1 `plugins/dev-workflow/scripts/review-issue-candidates.sh` を作り、実行権限を付ける。先頭のコメントに使い方・出力の形・終了コードの表を書く（書き方は `owner-reply-check.sh` の先頭に合わせる）。引数を読み、仕様の要件「検索に失敗したら候補なしと区別できる形で終わる」にある不備（と `gh`・`jq` が無いとき）を終了コード 2 で弾く。触る範囲: plugins/dev-workflow/scripts/review-issue-candidates.sh（新規）、参照のみ plugins/dev-workflow/scripts/owner-reply-check.sh:1-45（先頭のコメントと引数の検査）
- [x] 2.2 パスごとの検索（ファイル名の取り出し、同じパスの重複を除く、`--limit` に「15 ＋ 外す番号の個数 ＋ 1」、`--json number,title`）と、外す番号の除外、15 件の打ち切り、題名のタブの置き換え、見出し行・`(該当なし)`・打ち切りの行の出力を書く。出力は全部の検索が済んでからまとめて出し、`gh` が 1 つでも失敗したら標準出力を空のまま終了コード 1 で終わる。触る範囲: plugins/dev-workflow/scripts/review-issue-candidates.sh（新規）
- [x] 2.3 `--epic`（`gh api --paginate` で `sub_issues` を 1 回取り、3 列目に `child` / `other`）と `--epic --children-only`（検索語に `parent-issue:<owner>/<name>#<番号>` を足し、3 列目はすべて `child`、`sub_issues` は取らない）を書く。触る範囲: plugins/dev-workflow/scripts/review-issue-candidates.sh（新規）
- [x] 2.4 `bats plugins/dev-workflow/tests/review-issue-candidates.bats` が全件通ることを確かめる。触る範囲: なし（実行のみ）
- [x] 2.5 実物の `gh` で 1 回動かして出力を目で確かめる: `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo oratta/claude-harness --exclude 973 --exclude 984 --epic 725 plugins/dev-workflow/skills/pr-review-gate/stages/triage.md plugins/dev-workflow/scripts/no-such-file-zzz.sh`（1 つ目に候補が出て #973 と #984 のどちらも無く、2 つ目が `(該当なし)`）。続けて `--children-only` を足して、検索語に `parent-issue:` が効くこと（エピック #725 の子は全部 closed なので 2 つとも `(該当なし)` になる）を確かめる。結果は PR 本文の動作確認に書く。触る範囲: なし（実行のみ）

## 3. 変更の記録とリポジトリ全体のテスト

- [x] 3.1 `plugins/dev-workflow/changes/984.md` を作り、足したスクリプトとテスト、呼ぶ箇所がまだ無いこと（次の change で `stages/triage.md` から呼ぶ）、戻し方（この PR の差分を戻す）を書く。版（`plugin.json` の `version`・`CHANGELOG.md`）は上げない。書き方は `plugins/dev-workflow/changes/945.md` に合わせる。触る範囲: plugins/dev-workflow/changes/984.md（新規）、参照のみ plugins/dev-workflow/changes/945.md:1-6
- [x] 3.2 リポジトリのルートで `bats tests/` と `bats plugins/dev-workflow/tests/` を実行し、どちらも exit 0 であることを確かめる。`tests/bats-assertion-guard.bats`（単独の `[[ ]]` を検査の最後以外に置かない）と `tests/shell-multibyte-expansion.bats`（日本語の直前の変数展開は `${var}` と波括弧を付ける）に当たったら、足したファイルの側を直す。`tests/injection-budget.bats` が落ちたら、常時注入される文書を触っていないはずなので原因を調べる（予算ファイル `tests/injection-budget.txt` は動かさない）。触る範囲: なし（実行のみ。直すときは 1・2 で作ったファイル）
- [x] 3.3 `openspec validate review-finding-issue-candidates --strict` が通ることを確かめる。触る範囲: なし（実行のみ）

## 4. 仕上げの段（archive と PR）

- [ ] 4.1 `openspec archive review-finding-issue-candidates` で仕様を `openspec/specs/dev-workflow-review-issue-candidates/spec.md` に入れ、`bats tests/openspec-specs-format.bats` が通ること（先頭の題名の行、`## Purpose` と `## Requirements` の節）を確かめる。`Purpose` が仮の文のままなら、このスクリプトが何を返す規約かを 1〜2 文で書く。触る範囲: openspec/specs/dev-workflow-review-issue-candidates/spec.md（新規。archive が作る）、openspec/changes/archive/（archive が移す）
- [ ] 4.2 PR を作る。本文は `Closes #984` にする（#973 には `Closes` を向けない。#973 は残り 2 つの change が済むまで閉じない）。本文に、issue #984 の受け入れ条件 4 項目（スクリプトがあり、パスの一覧・除外する番号・エピックの子だけに絞る指定を受け取って番号と題名を返す／`bats plugins/dev-workflow/tests/` が exit 0／`bats tests/` が exit 0／このリポジトリの実物の issue に対して走らせた結果を PR 本文に載せる）を満たしたことを書く。bats の置き場を `plugins/dev-workflow/tests/` に読み替えたこと（本体の決定 https://github.com/oratta/claude-harness/issues/973#issuecomment-6116671563 ）、2.5 の実物での実行結果、常時注入の予算は動かしていないことも書く。触る範囲: なし（PR の本文）
