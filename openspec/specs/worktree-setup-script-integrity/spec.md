# worktree-setup-script-integrity Specification

## Purpose
TBD - created by archiving change worktree-command-dedup. Update Purpose after archive.
## Requirements
### Requirement: wt-setup.sh の find -path グロブと settings.local.json symlink の挙動を検証し意図を文書化する

`plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` パターン展開に使う `find -path "./$pattern"` グロブ（`.worktreeinclude` の各パターンをメインリポ配下のファイルに展開する処理）と、`.claude/settings.json` / `.claude/settings.local.json` を worktree に symlink する処理について、実挙動を確認しなければならない (MUST)。確認の結果、問題がなければ現状の挙動を維持し (MAY keep)、その判断意図を説明するコメントをスクリプトに追記しなければならない (MUST document)。問題が確認された場合は修正すること。いずれの結論でも、`bash -n plugins/worktree/scripts/wt-setup.sh` の構文検証を通過しなければならない (MUST)。

#### Scenario: find -path グロブの挙動が検証され意図がコメント化されている

- **WHEN** ユーザーが `plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` 展開ループ（`find -path "./$pattern"` を含む箇所）を読む
- **THEN** `find -path` のグロブ展開挙動（例: `.env.*` のような 1 階層パターンとサブディレクトリを含むパターンで一致範囲が異なる点）についての確認結果を示すコメントが存在する、または挙動を是正する修正が入っている

#### Scenario: settings.local.json の symlink 是非が判断・文書化されている

- **WHEN** ユーザーが `plugins/worktree/scripts/wt-setup.sh` の `.claude/` 配下ファイルを symlink するループ（`settings.json` / `settings.local.json` を対象とする箇所）を読む
- **THEN** `settings.local.json`（マシンローカルな権限設定を含みうる）を worktree に symlink する／しないの判断理由を示すコメントが存在する、または是正する修正が入っている

#### Scenario: スクリプトの構文検証が通る

- **WHEN** ユーザーが `bash -n plugins/worktree/scripts/wt-setup.sh` を実行する
- **THEN** 構文エラーなく終了する（exit 0）

