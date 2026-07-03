---
name: p
description: "plan.mdを対話的に作成する（/longrun:plan の短縮）"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

Skill toolを使って `longrun:longrun-plan` スキルを引数 `$ARGUMENTS` で呼び出してください。
自分で処理せず、必ずSkill toolで委譲すること。Agent tool は使わない（longrun-plan は Skill であり Agent ではない）。

`$ARGUMENTS` はそのまま skill に渡るため、フラグも透過的に転送される（引数透過は維持）。
なお MVP プラン作成は独立コマンド `/lr:m`（`/longrun:mvp`）に移動した。
