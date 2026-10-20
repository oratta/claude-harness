## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 6 ファイルの検索のテストを足す: Scenario「6 ファイルに固有名が無い」（`grep -n -i -E 'oratta|genetta|suimei|flatmate|fmtoken|Dropbox|marketplaces/'` が 6 ファイルで 0 件）。触る範囲: tests/public-private-split.bats:422-427（末尾の `@test` のあと）
- [ ] 1.2 「hook との分担」の節のテストに、条件つきの書き方（「入っていれば」と、hook が無ければこのルールだけが止める旨）と `rules-archive` が無いことの検査を足す。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:957-964
- [ ] 1.3 `browser-infra-env-capture.md` の昇格の文が `capability-registry` を「入っていれば」の条件つきで書くことのテストを足す（置き場: 1.1 と同じ `tests/public-private-split.bats`）。触る範囲: tests/public-private-split.bats:422-427
- [ ] 1.4 `bats tests/public-private-split.bats plugins/dev-workflow/tests/git-destructive-guard.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. 規則の本文を直す

- [ ] 2.1 `rules/communication-style.md` の最終段落を、clone の絶対パスなしで Output Style `readable` を全文の正本と書く（「原則を増減させたときは両方を直す」は残す）。触る範囲: rules/communication-style.md:15
- [ ] 2.2 `rules/browser-infra-env-capture.md` の昇格の文を、製品名なし・`capability-registry` スキルは「入っていれば」・無い環境の手順つきに直す。触る範囲: rules/browser-infra-env-capture.md:10
- [ ] 2.3 `rules/destructive-git-guard.md` の `rules-archive` のパスを外し、「hook との分担」の節に条件と「hook が入っていなければこのルールだけが止める」を足す。節の中の語は同じ行に残す。触る範囲: rules/destructive-git-guard.md:3、rules/destructive-git-guard.md:22-24
- [ ] 2.4 6 ファイルの検索（受け入れ条件 1）が 0 件になり、1 で足したテストが通ることを確かめる

## 3. 付属の文書と記録

- [ ] 3.1 `rules/README.md` の 3 本の行を、外した参照の行き先（clone のパス・製品名・`rules-archive` のパス）がオーナーの環境の読む場所として読める形に直す。destructive-git-guard の行は子と無人のセッションの語を残す（bats が見る）。触る範囲: rules/README.md:5、rules/README.md:36-38
- [ ] 3.2 `docs/public-private-split.md` の固有記述の一覧から、直した 3 行を外す。触る範囲: docs/public-private-split.md:145-147
- [ ] 3.3 変更の記録を 2 本書く。外した参照ごとに 1 行（元の場所・行き先）。触る範囲: plugins/dev-workflow/changes/1098.md（新規）、plugins/capability-registry/changes/1098.md（新規）

## 4. 確かめる

- [ ] 4.1 `bats tests/always-on-injection-scope.bats tests/injection-budget.bats tests/rules-sync.bats tests/public-private-split.bats plugins/dev-workflow/tests/git-destructive-guard.bats` が通る。injection-budget が落ちたら、予算の値を動かすのでなく本文を削って収める。収まらなければ値の変更理由を PR 本文に書く。触る範囲: tests/injection-budget.txt:1（動かす場合のみ）
- [ ] 4.2 `git diff --name-status origin/main` に `R`/`A`/`D` の `rules/*.md` `output-styles/*.md` が無いこと（受け入れ条件 4。開発用 worktree の `sync.sh` は実行しない）
