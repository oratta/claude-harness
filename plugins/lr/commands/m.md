---
name: m
description: "軽量 MVP plan.md を対話的に作成する（/longrun:mvp の短縮）"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

Skill tool を使って `longrun:longrun-mvp-plan` スキルを引数 `$ARGUMENTS` で呼び出してください。
自分で処理せず、必ず Skill tool で委譲すること。Agent tool は使わない（longrun-mvp-plan は Skill であり Agent ではない。Agent tool で起動すると `Agent type 'longrun:longrun-mvp-plan' not found` で失敗する）。

`$ARGUMENTS` はそのまま skill に渡るため、ブレインダンプ / テーマがそのまま転送される。
例: `/lr:m 1時間で作る料理レシピ提案ツール` → 軽量 MVP plan.md / 並列レビュー / 人間ハンドオフ。
