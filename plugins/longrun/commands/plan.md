---
name: plan
description: 自律実行用のplan.mdを対話的に作成する
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

Skill tool を使って `longrun:longrun-plan` スキルを引数 `$ARGUMENTS` で呼び出してください。
自分で処理せず、必ず Skill tool で委譲すること。

**Agent tool は使わないこと。** `longrun-plan` は Skill であり、Agent ではない（`longrun-builder` / `longrun-reviewer` / `longrun-verifier` などの -er/-or 終わりの命名と混同しないよう注意）。Agent tool で起動しようとすると `Agent type 'longrun:longrun-plan' not found` エラーで失敗する。

skill 本体に実行手順・ディレクトリ構造ルール・Validation/Review ステップが定義済みのため、ここでは追加指示は不要。
