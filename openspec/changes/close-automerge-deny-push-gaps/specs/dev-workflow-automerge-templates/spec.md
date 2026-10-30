## MODIFIED Requirements

### Requirement: deny 設定が auto-merge 配線と同じ場所から配布される

テンプレートは `.claude/settings.json` に、LLM による `gh pr merge`・main / master への直接 push・force push（`-f` / `--force` / `--force-with-lease`）・`--no-verify` push を塞ぐ `permissions.deny` 断片を含まなければならない（MUST）。拒否範囲にはオプションの前置形・後置形と main/master 宛て明示 refspec を含め、通常の feature push は拒否してはならない（MUST NOT）。README は既存 deny を消さないマージ手順を提供し（SHALL）、配布用 docs/auto-merge.md は各 deny の経路を説明する（SHALL）。配布は他プラグインに依存しない（SHALL）。

#### Scenario: deny 断片の内容

- **WHEN** `templates/auto-merge/.claude/settings.json` を jq で検査する
- **THEN** `permissions.deny` に既存の `Bash(gh pr merge:*)` / `Bash(git push origin main:*)` / `Bash(git push origin master:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git push --force-with-lease:*)` / `Bash(git push --no-verify:*)` の 7 件が保持され、以下の拒否範囲を満たす追加エントリがある

#### Scenario: オプション前置形と後置形の拒否

- **WHEN** 各オプション `--force` / `-f` / `--force-with-lease` / `--no-verify` を単独の引数として `git push <option> origin feature`、`git push origin feature <option>`、`git push origin <option> feature` の位置に置いて照合する
- **THEN** すべて deny に一致する

#### Scenario: 値付き force-with-lease の拒否

- **WHEN** `git push --force-with-lease=refs/heads/feature:abc123 origin feature`、`git push origin feature --force-with-lease=refs/heads/feature:abc123` を照合する
- **THEN** どちらも deny に一致する

#### Scenario: main と master 宛て refspec の拒否

- **WHEN** `git push origin HEAD:<destination>` と `git push origin HEAD:<destination> --porcelain` を、宛先 `main` / `master` / `refs/heads/main` / `refs/heads/master` ごとに照合し、さらに `git push origin feature:main other:feature/bar` と `git push -u origin HEAD:master` を照合する
- **THEN** すべて deny に一致し、送り元や refspec の位置に依存しない

#### Scenario: 通常 push と似た名前の宛先を拒否しない

- **WHEN** `git push origin feature/foo`、`git push -u origin feature/foo`、`git push origin HEAD:feature/foo`、`git push origin feature:main-fix`、`git push origin HEAD:master-fix`、`git push origin HEAD:refs/heads/main-fix`、`git push origin main-fix`、`git push origin master-fix` を照合する
- **THEN** いずれもこのテンプレートの deny に一致しない（他の permission 設定による許可を保証する意味ではない）

#### Scenario: 照合方法と証拠が残る

- **WHEN** deny の追加を検証し、`changes/629.md` に結果を記録する
- **THEN** 公式 permission 仕様の参照元・照合方法・前後の一致/不一致・通常 push と過剰一致の対照例・実行コマンドと終了コードを記載する。公式仕様に基づく再現を使った場合はその旨と対象範囲を明示し、Claude Code 実マッチャーの実測として扱わない。Bats は JSON の要素存在だけでなくコマンドの一致/不一致を検証する

#### Scenario: 既存 settings.json へのマージで既存 deny が残る

- **WHEN** README のマージコマンド（jq 式）を、既存の deny と他キー（allow / env）を持つ settings.json とテンプレートの断片に対して実行する
- **THEN** 既存 deny・allow・env が保持され、テンプレートの deny が和集合で足され、重複は 1 件に畳まれる
