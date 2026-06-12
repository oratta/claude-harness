---
name: mvp
description: 短時間・人間実装向けの軽量 MVP plan.md を対話的に作成する
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

Skill tool を使って `longrun:longrun-mvp-plan` スキルを引数 `$ARGUMENTS` で呼び出してください。
自分で処理せず、必ず Skill tool で委譲すること。

**Agent tool は使わないこと。** `longrun-mvp-plan` は Skill であり、Agent ではない（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer` などの -er/-or 終わりの Agent 命名と混同しないよう注意）。Agent tool で起動しようとすると `Agent type 'longrun:longrun-mvp-plan' not found` エラーで失敗する。

skill 本体に実行手順（軽量テンプレ読み込み → Gap Analysis → Interview → 並列リサーチ → 軽量 Synthesis → 並列レビュー → 人間ハンドオフ）・`<!-- mvp-mode -->` マーカー埋め込み・Validation/Review ステップが定義済みのため、ここでは追加指示は不要。
