## 1. コンテキスト上限

- [x] 1.1 `subagent-context.sh` のテストを書く（Red）: 最後の assistant usage の合算 / exit 2 と over_cap / `DEV_WORKFLOW_CONTEXT_CAP` / cwd 一致の優先 / 見つからない・usage 無しは exit 1
- [x] 1.2 `subagent-context.sh` を実装する（Green）
- [x] 1.3 SKILL.md の 1 ループと worker.md / gate-runner.md に「再開前に測る・上限超は手渡し・W は工程ごとに return」を書く。templates/escalation-tripwires.md に 4【コンテキスト上限 → 手渡し】を足し rate-limit を 5 にする

## 2. 共有枠モード

- [x] 2.1 tripwire-hook.bats に共有枠モードの導出テストを書く（Red）: abundant × throttled / depleted / ok / 明示 env
- [x] 2.2 session-tripwires.sh に `weekly_all_pct` からの導出と注入を実装する（Green）
- [x] 2.3 decision-criteria.md に共有枠モード表と下限の優先規則を書く

## 3. W の既定を sonnet に

- [x] 3.1 develop-skill.bats の役割表テストを W = sonnet に締める（Red）
- [x] 3.2 SKILL.md 役割表・worker.md・decision-criteria.md の abundant 行を改訂する（Green）
- [x] 3.3 CHANGELOG 2.3.0・plugin.json / marketplace.json のバージョン
