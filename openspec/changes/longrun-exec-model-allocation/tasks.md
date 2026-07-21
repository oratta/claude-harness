## 1. テスト先行（Red）

- [ ] 1.1 bats に fable 系テストを追加する: fable 解決（`'fable'`）、reserve+automated 降格（`'opus'` + 警告）、interactive 非降格、reserve の他ティア非影響、model-tiers.md の fable 行存在、plan-template の 4 値ヘッダ。fixture `fable.plan.md` を追加。実行して Red を確認する

## 2. 実装（Green）

- [ ] 2.1 `references/model-tiers.md` に fable 行と reserve 降格ルール（FABLE_BUDGET_MODE=reserve && LONGRUN_AUTOMATED=1 → 'opus'、配線側の責務注記付き）を追記する
- [ ] 2.2 `scripts/resolve-model-allocation.mjs` に fable ティア（KNOWN_TIERS / tierMap / フォールバック）と reserve 降格 + 警告を実装する
- [ ] 2.3 `templates/plan-template.md` の語彙を 4 値に更新し、表ヘッダを `ティア(haiku/sonnet/fable/inherit)` に、サンプル行を新推奨（builder=sonnet / verifier=fable / reviewer=fable）に更新する
- [ ] 2.4 `skills/longrun-plan/SKILL.md` の Step 5c ヒューリスティクスを4象限準拠（判断集中→fable、builder出発点→sonnet、迷ったら inherit 維持、reserve 降格の注記）に更新する
- [ ] 2.5 `commands/exec.md` のモデル割り当ての消費の記述に fable と reserve 降格を反映する
- [ ] 2.6 bats を実行して全テスト Green を確認する（既存テストの後方互換含む）

## 3. リリース

- [ ] 3.1 `plugins/longrun/.claude-plugin/plugin.json` のバージョンを上げ、CHANGELOG に追記する
- [ ] 3.2 commit / push で Draft PR #29 を更新する
