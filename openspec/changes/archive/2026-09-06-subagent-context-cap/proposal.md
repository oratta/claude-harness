# subagent-context-cap — サブエージェントのコンテキスト上限・共有枠モード・W の既定を sonnet に

## Why

2026-08-31〜09-05 の使用量監査（`~/.claude/projects` の 521 セッション、API 定価換算 12,159 USD）で、消費の 3 分の 2 が develop の W / G / R1 で、うち W が 44.5%（31 本・平均 174 USD・最大 745 USD）だった。単価を押し上げていたのはモデルではなくコンテキスト: W は SendMessage 再開のたびに全履歴を読み直すため履歴が畳まれず、Opus の W は平均 32.6 万トークンを毎ターン投げていた（W 消費の 63% が 30 万トークン超のリクエスト。全体でも 28%）。develop にはコンテキスト量を閾値にした手渡し・分割の仕組みが無い（あるのは編集ファイル数ベースの規模超過トリップワイヤーだけ）。

さらに W 31 本に Sonnet が 1 本も無く（既定が `opus` なので昇格ラダー sonnet → opus → fable の Sonnet 段が構造的に通らない）、W の 4 割が Fable で走っていた（事前分類に加えて `abundant` が W の既定も押し上げるため）。Fable 残量モードは 4 段すべて下限 Opus で、Fable が尽きた 09-04 に同じ W が Opus に落ちて走り、その日が週で最も消費が大きかった。全モデル共通の週次枠（`weekly_all_pct`）は snapshot にあるのに導出に使われていない。

別コンテキスト（sonnet）で再集計したところ、分類境界の差で W の本数は 19〜31 の幅があるが、機構（Opus の W の平均コンテキスト 34 万・30 万超のリクエストが W 消費の 68%・Sonnet ゼロ・畳む仕組み無し）は一致した。

## What Changes

- **コンテキスト上限（手渡し）**: `scripts/subagent-context.sh <agent-name>` を新設し、名前付きサブエージェントのトランスクリプト末尾の usage（input + cache_creation + cache_read）を読んで上限超なら exit 2 を返す。本体は W / G を SendMessage で再開する前に毎回測り、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）超なら再開せず、前回 return を渡した新しい W / G に手渡す。W は工程ごとに必ず return し、return に成果・判明した事実・埋めた決定・残作業を列挙する。昇格トリップワイヤーに【コンテキスト上限 → 手渡し】を追加（rate-limit 実エラーは 4 → 5）
- **共有枠モード `SHARED_BUDGET_MODE`**: `session-tripwires.sh` が `weekly_all_pct` から `ok` / `throttled`（週経過ペースより速い）/ `depleted`（90% 超）を導出して Fable 残量モードと並べて注入する。`throttled` は W / R1 / G の既定を sonnet・昇格上限 opus・abundant の押し上げ無効、`depleted` は全役割 sonnet 固定。Fable 残量モードと食い違えば共有枠モードの下限が勝つ
- **W の既定を `opus` → `sonnet`**: `opus` は記録先が設計判断を含むときと失敗ループ昇格、`fable` は事前分類（従来どおり）。`abundant` が押し上げるのは R1 / G だけで W は上げない

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: Requirement「役割のモデルは事前分類と残量モードで決める」を、W 既定 sonnet・共有枠モードの下限・再開前のコンテキスト計測に合わせて改訂する
- `dev-workflow-execution-strategy`: Requirement「残量モードによる閾値調整」の abundant を R1 / G 限定に改訂し、Requirement「共有枠モード」「サブエージェントのコンテキスト上限」を追加する

## Impact

- `plugins/dev-workflow/scripts/subagent-context.sh`（新規）、`scripts/session-tripwires.sh`（共有枠モードの導出と注入）
- `skills/develop/SKILL.md`・`references/decision-criteria.md`・`references/roles/{worker,gate-runner,spec-reviewer}.md`・`templates/escalation-tripwires.md`・README
- flatmate の burn-mode は develop の W を通らず直接サブエージェントを起こすため対象外（別 issue）
