## Context

dev-workflow のトリップワイヤーテンプレートは汎用（interactive 前提の導入手順）で、unmanned では既存の憲法経路（サブ issue 分割・Discord 質問・needs-approval・agent-blocked）に写像する必要がある。また reserve 降格は `LONGRUN_AUTOMATED=1` を見るが、この env は誰も設定していない。loops には「運用値は配線側の環境変数で解決する」という既存規約（RATE_* / AGENT_DIGEST_HOUR）がある。

## Goals / Non-Goals

**Goals:**

- 憲法テンプレートにトリップワイヤー3本を unmanned 写像で組み込む
- `LONGRUN_AUTOMATED=1` / `FABLE_BUDGET_MODE` を RATE_* と同じ「配線側環境変数」規約に載せる

**Non-Goals:**

- 配線（flatmate / cron-jobs.md）そのものの変更 — 配線は Pikke 側の責務（メモリ user_always-on-session-cron 参照）。本 change は前提の明文化まで
- dev-workflow テンプレート本文の変更（参照するのみ）
- 既導入リポジトリの docs/agent-loop.md の更新 — テンプレート更新後の再 install / 手動反映は運用に委ねる

## Decisions

1. **トリップワイヤーは Step 3 の末尾に置く**（実装モード限定の適用であることが構造上明確になる。review / propose モードは対象外）。
2. **既存経路への写像を優先し、新しい状態を増やさない**: ①は github-issue スキルの判定（workflow 型 / サブ issue 分割）にそのまま従う。③は既存の「曖昧ケース → Discord + needs-approval」と同一経路。②の reserve 上限到達時は `agent-blocked`（人間の再トリアージ待ち）ではなく `needs-approval`（人間の判断待ち）を使う — Fable なら解けるかもしれない問題を人間が判断すべき状態だから。
3. **既存の「失敗コメント2件 → agent-blocked」（Step 3-7）は維持**し、トリップワイヤー②はその手前のサイクル内昇格として合成する（②はサイクル内、3-7 はサイクル横断のセーフティネット）。
4. **env は配線側設定の規約に載せる**。憲法テンプレートには前提として記載し、install スキルの環境変数解説に追記する。設定漏れは「降格されない」方向に倒れる（安全）。

5. **（実装中の発見）S48 ガードをセクション単位に縮小**: loops の bats テスト S48「change is additive only vs merge-base」は spec の裏付けが無い change-5 時代のポイントインタイムガードで、対象7ファイル全体の行削除を恒久的に禁止しており、spec 承認済みの後続編集（longrun-exec-model-allocation による longrun-plan SKILL.md のヒューリスティクス改訂）をブロックしていた。本来の保護対象である「自己検証」セクションの削除・書き換え禁止（追記は可）に絞り直した。
6. **（実装中の発見）リリースメタデータの同期**: marketplace.json の plugins[] バージョンを plugin.json 基準で一括同期（longrun 6.5.0 / dev-workflow 1.1.0 / loops 0.16.0 / worktree 2.3.0 / infra 0.4.0。後2者は main 由来の既存不整合の解消）、top-level を 2.22.0 に bump。longrun のバージョンピンテスト3件を 6.5.0 に更新。

## Risks / Trade-offs

- [テンプレート更新が既導入リポジトリに自動反映されない] → 憲法の性質上意図的（各リポジトリの GUARDRAILS と同様、更新は明示操作）。install スキルの再実行で反映可能
- [配線側が LONGRUN_AUTOMATED を設定し忘れる] → reserve の温存だけが効かず品質影響なし。install スキルの明記で発見可能性を上げる
