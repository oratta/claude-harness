---
name: work-issue
description: /develop のエイリアス（旧名）。引数をそのまま develop の手順に渡す
argument-hint: "[issue番号|issueURL|自然文の依頼]"
allowed-tools: Read, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion
---

`/work-issue` は `/develop` の**エイリアス**であり、独自の手順を持たない。5 分岐・issueify フォールバック・承認ゲートの本文は `commands/develop.md` の 1 箇所にのみ存在する。

このコマンドが起動されたら、同じディレクトリの `commands/develop.md` を Read tool で読み込み、その手順を `$ARGUMENTS` を引数として**そのまま**実行する（Skill tool は使わない）。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
