## ADDED Requirements

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
