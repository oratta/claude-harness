# 修正サイクルへ戻す — pr-review-gate

以下 `$R` = `<owner>/<repo>`、`$N` = PR 番号。`agent-review:failed` で W に戻すときに読む。

**順 4（今直す 3 条件）**: 直し方が行レベルで 30 行以内、spec を変えない、この PR でその場で直した累計が 30 行以内、のすべてを満たせば W が直す。閾値は手順 2-0 と同じ 30 行。仕分け欄に「受け入れ条件の外・その場で直した・直し方 N 行」と記録。1 回で閉じなかったら、2 回目は順 6 に落とす。

## 修正サイクルのモデル昇格（手順 2-2）

failed で戻す前に修正サブエージェントのモデルを決める（Agent の `model`。本体のモデルは変えない）。

| failed の原因 | 戻し方 |
|---|---|
| 実装品質起因（テスト不足・エッジケース漏れ・不整合・安全機構の穴） | 判断側（指示を解釈できなかった・指示自体が外れていた）なら `subagent_type: dev-workflow:decider` で方針を作り W は据え置く。実行側（指示どおりやって結果が違う）なら W を `opus` にする。決める役と実行役の一方だけを上げる。残量・共有枠モードの上限内 |
| 仕様が曖昧 | 昇格せず受け入れ条件を確定してから修正。unmanned は `needs-approval` |
| レビュアーの誤検出 | 昇格せずコード・テスト結果の反証コメントで閉じる |

昇格は実装品質起因のときだけ。段 A だけで戻した failed は W のモデルを据え置く（原因分類は「段 A だけ（昇格なし）」）。止める指摘（順 2〜4）も混ざれば表を当てる。
実行役の上限は `opus`。修正実装を `model: fable` で spawn しない（`scripts/agent-model-guard.sh`）。決める役は種別 `dev-workflow:decider` を固定して `model`（`opus` → `fable`）だけを切り替える。Bash を持たないので呼び出し側が return を PR に書く。ラダーの正本は develop の `templates/escalation-tripwires.md`。
2 周キャップ（収束ルールの2周キャップ）では2周目が既定の最終周なので、1 回目の failed で原因側を上げる。3周目以降の開始条件は収束ルール（`stages/convergence.md`）の直し方の判定・主の回答・順 6 の裁定。トリップワイヤーの同一テスト2連続失敗とは別に数える。
Fable のレート制限・週次枠切れ（`FABLE_BUDGET_MODE=exhausted`）では決める役を種別固定で `model: opus` にフォールバックし、次の正本書式で記録する:

```bash
gh api -X POST repos/$R/issues/$N/comments \
  -f body='決める役モデル: opus（fable レート制限のためフォールバック。subagent_type は dev-workflow:decider のまま）'
```

重要実装の事前分類（聖域パス・マージ権限・層間契約・課金/法務）は develop スキルの references/pre-classification.md が正本。実行役は `opus` 上限、該当する判断役は `dev-workflow:decider`。

## failed の return と次の段（develop の G）

`stages/triage.md` の「return の書式」の欄に続ける。

```markdown
### failed のとき
- 原因分類（pr-review-gate 手順 2-2）: 実装品質起因 | 仕様が曖昧 | レビュアーの誤検出 | 段 A だけ（昇格なし）
- 指摘一覧（再現手順・修正点）と PR コメント URL
- 本体への提案: 実装品質起因なら、失敗の原因が実行側（指示どおりやって結果が違う）か判断側（指示を解釈できなかった・指示自体が外れていた）かを書き添えて、実行側なら W を `opus` で再開、判断側なら `subagent_type: dev-workflow:decider`（`model` は `opus` → `fable`。種別は固定して `model` だけ切り替える）を立てて修正方針を作らせるよう提案する（**決める役と実行役のどちらか一方だけ**を上げる。W を `fable` にはしない。残量モードと共有枠モードの上限内）。仕様が曖昧なら受け入れ条件の確定（unmanned は needs-approval）、誤検出なら反証コメントの投稿
```

- **failed の `次の段:`**: 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外（順 2・4 が混ざる場合と、段 A だけで戻した場合を含む）は `前提確認と重さ判定` と書く。順 3 と順 2・4 が同じ failed に混ざったときは、W の修正後に起こされる前提確認と重さ判定から続く照合と振り分けの G が、再レビューの要約と一緒に順 3 の一覧表のコメントも照合する
