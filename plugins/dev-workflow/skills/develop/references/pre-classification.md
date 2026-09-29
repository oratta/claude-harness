# 重要実装の事前分類 — develop スキル

本体が W・R1・G が要求するレビュアーを起こすときのモデル選択の表。W は自分のモデルを選ばないので、W の指示書（`references/roles/worker/`）には置かない。

## 重要実装の事前分類（1 周目のモデルを上げる条件）

W の既定モデルは `sonnet`（役割表の正本は `SKILL.md`「モデル」。設計判断を含む記録先は `opus`）。この表に当たる実装だけが 1 周目からモデルを上げる。

本体が W を spawn するときのモデル選択の正本（**この分類表がモデル事前分類の正本**。pr-review-gate スキル・R1・G からも参照される。ここ以外に再掲しない）。次のいずれかに触れる実装は、失敗 1 周のコスト（再実装＋再レビュー＋ゲート往復＋コンテキスト肥大）が単価差を上回るため、**トリップワイヤーの昇格を待たず最初から表の「1 周目」のモデルで spawn する**（4 分類のいずれでも `model: opus`。Agent ツールの `model` パラメータ。セッション本体のモデル＝`AGENT_MODEL` は変えない）。

| 分類 | 具体 | 1 周目 |
|---|---|---|
| 聖域パス | auto-merge の SACRED 定義に含まれるもの（`.github/workflows/` / `CLAUDE.md` / `.claude/` 配下 / 憲法 doc） | `opus`（聖域の安全はゲート側の判定が見る。エージェント設定が製品であるリポではほぼ全実装が聖域に当たり、ここを Fable にすると、Fable の枠の大半をこの行だけで使う） |
| マージ権限 | マージ条件・ラベル判定・レビューゲートの通過条件そのもの | `opus` |
| 層間契約 | プラグイン間・スキル間で共有する規約（hook 契約・スキーマ・レシピ形式・環境変数の意味） | `opus` |
| 課金/法務 | 支払い・レート/使用量制御・ライセンス・個人情報の扱い | `opus` |

**W の上限は `opus`。** 4 分類のどれに当たっても W を `model: fable` で spawn しない（`scripts/agent-model-guard.sh` が PreToolUse で拒否する）。Fable が消費するのはターン数（会話履歴の cache 読込）で、実装・修正ループは 1 件で数十〜数百ターン回るため、実行役を Fable にすると週次枠が溶ける。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体（Fable）の判断で吸収し、**W は確定した内容を落とす作業だけを担う**。

**読んで判断する役は種別で上げる。** R1（仕様レビュー）と G が要求するレビュアーがこの表の分類に当たるときは、`subagent_type: dev-workflow:decider` で spawn する。`general-purpose` に `model: fable` を付けない（ガードが拒否する）。当たらなければ従来どおり `opus`。

- **残量モードが優先する**: `FABLE_BUDGET_MODE=reserve` の自動実行と `exhausted` の全経路では、決める役も `dev-workflow:decider` のまま `model: opus` を上限とする（`skills/develop/references/decision-criteria.md` の残量モード表がそのまま効く）。共有枠モード `SHARED_BUDGET_MODE=depleted` では事前分類に当たっても Sonnet 固定
- `FABLE_BUDGET_MODE=abundant` はどの役割の既定も押し上げない。Fable が使われる経路は決める役（`dev-workflow:decider`）だけ
- Fable がレート制限等で使えなかったときのフォールバック記録の形式は pr-review-gate スキルの「修正サイクルのモデル昇格」が正本。ここでは再掲しない
