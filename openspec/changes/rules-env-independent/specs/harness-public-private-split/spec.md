## ADDED Requirements

### Requirement: 配る候補の規則は環境固有の記述を持たず、プラグインの前提を条件つきにする

`rules/communication-style.md` `rules/link-when-requesting-review.md` `rules/dev-server.md` `rules/browser-infra-env-capture.md` `rules/destructive-git-guard.md` `output-styles/readable.md` の 6 ファイルは、固有名とオーナーの環境のパスを書いてはならない（MUST NOT）。具体的には `grep -n -i -E 'oratta|genetta|suimei|flatmate|fmtoken|Dropbox|marketplaces/'` が 6 ファイルで 0 件でなければならない（MUST）。また 6 ファイルは Harness のプラグイン（capability-registry・dev-workflow）が入っていない環境でも指示として実行できなければならず、プラグインやその hook を前提にする記述は「入っていれば」の条件つきで書かなければならない（MUST）。外した参照の行き先は、変更の記録（`plugins/<name>/changes/<issue番号>.md`）に 1 行ずつ書く（MUST）。

#### Scenario: 6 ファイルに固有名が無い

- **WHEN** 上の `grep` を 6 ファイルに対して実行する
- **THEN** 0 件である

#### Scenario: プラグインを前提にする記述が条件つきである

- **WHEN** `rules/browser-infra-env-capture.md` の昇格の手順の文と `rules/destructive-git-guard.md` の「hook との分担」の節を読む
- **THEN** `capability-registry` スキルと dev-workflow の hook は「入っていれば」の条件つきで書かれ、入っていない環境での手順（保管庫への昇格はその場で置き場と登録する人を決める、一覧の操作はこのルールだけが止める）が書かれている

#### Scenario: 外した参照の行き先が記録にある

- **WHEN** `plugins/dev-workflow/changes/1098.md` と `plugins/capability-registry/changes/1098.md` を読む
- **THEN** 外した参照ごとに、元の場所・行き先（`rules/README.md` の行、条件つきに直した文、またはなし）が 1 行ずつ書かれている
