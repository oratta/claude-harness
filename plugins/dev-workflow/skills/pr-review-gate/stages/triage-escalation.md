# triage-escalation — pr-review-gate

#### 2-2. 修正サイクルのモデル昇格（failed → 修正実装）

`agent-review:failed` に付け替えて修正サイクルへ戻すときは、**修正を書くサブエージェントのモデルを決めてから戻す**（Agent ツールの `model` パラメータ。PR を持っているセッション本体のモデルは変えない）。

| failed の原因 | 戻し方 |
|---|---|
| **実装品質起因**（テスト不足・エッジケース漏れ・既存コードとの不整合・安全機構の穴） | 失敗の原因が判断側（指示を解釈できなかった・指示自体が外れていた）か実行側（指示どおりやって結果が違う）かで、**決める役と実行役のどちらか一方だけ**を上げる（両方同時に上げない）。実行側なら `codex-develop.py request --phase implement --failure executor` を呼び、`request` が返した model で実行役を起こす。判断側なら `request --phase decider --failure first|judgment` を呼び、`request` が返した model で `subagent_type: dev-workflow:decider` を立てて修正方針を作らせ、実行役は据え置く。判断側の値は、そのゲートの 1 回目の failed なら `--failure first`（上位の格。Claude では `opus`）、そのゲートの 2 回目以降の failed（1 回目の原因が実行側だったときも含む）なら `--failure judgment`（最上位の格。Claude では `fable`）。残量モードと共有枠モードの上限は `request` の返り値に適用済み |
| **仕様が曖昧**（受け入れ条件から一意に決まらない） | モデル昇格ではなく仕様修正で返す。issue の受け入れ条件を確定させてから修正に入る（unmanned なら `needs-approval` を付けて主に返す） |
| **レビュアーの誤検出**（指摘が事実と違う） | モデル昇格ではなく反証で返す。該当コード・テスト結果を PR コメントに書いて指摘を閉じる |

**昇格は実装品質起因のときだけ。** 原因が仕様側・レビュアー側にあるのに上の格へ上げても、同じ往復をもう1周するだけになる。

**段 A だけで戻した failed では昇格を当てない。** 戻した指摘が止めない指摘の振り分け表の段 A だけ（止める指摘が無い）なら、上の表を当てず、W のモデルを据え置く（戻す中身が止めない指摘で、モデルを上げても収束の見込みは変わらない）。原因分類には「段 A だけ（昇格なし）」と書く。止める指摘（順 2〜4）が同じ failed に混ざるときは、上の表をそのまま当てる。

**`request` が返した model を使い、model が変わるなら新しい thread に手渡す。** 使うモデルは `--failure` の値を渡した `request` の返り値で、ここに書いた値（括弧内は Claude での例）から計算し直さず、返った model と違う model を独自に指定しない。返った model が起こし済みの W の model と違うときは SendMessage で再開せず、新しい thread に手渡す（細目の正本は `plugins/dev-workflow/references/codex-develop.md`）。

**実行役を最上位の格に上げない。** 実行役の格の上限は上位（Claude では `opus`）で、修正実装を `model: fable` で spawn しない（`scripts/agent-model-guard.sh` が PreToolUse で拒否する）。最上位の格が消費するのはターン数（会話履歴の cache 読込）で、修正ループは数十〜数百ターン回るため、実行役を最上位にすると週次枠が溶ける。最上位を使うのは決める役（`subagent_type: dev-workflow:decider`。`Bash` を持たないので、その return を PR に書くのは呼び出し側）だけで、決める役はどの段階でも種別を固定し、model は `--failure` の値を渡した `request` の返り値で切り替える。ラダーの正本は develop スキルの `templates/escalation-tripwires.md`。

**なぜ 1 回目の failed で上げるのか**: G のレビューループは 2 周キャップで**2 周目が既定の最終周**にあたる（3 周目以降は直し方の判定・主の回答・順 6 の裁定のどれかがあるときだけ開く）ため、1 回目の failed の時点で原因側を一方だけ上げてキャップ内での収束確率を上げる（昇格トリップワイヤーの「1 回目の失敗では誰も上げない」は同じテストの 2 連続失敗を数える別の発火条件で、こちらとは数え方が違う）。

**収束ルール（2周キャップ）との関係**: 再レビューは既定2周なので**2周目が既定の最終周**にあたる（3 周目以降は直し方の判定・主の回答・順 6 の裁定のどれかがあるときだけ開く）。最終周の前に、失敗の原因側を一方だけ上げる（決める役は 1 回目の failed では上位の格、最上位の格は 2 回目以降。値は `--failure` を渡した `request` の返り値）ことで、キャップ内で収束する確率を上げる（3周目へ持ち越さないための配分）。

**Fable が使えないときのフォールバック**: レート制限・週次枠切れ（`FABLE_BUDGET_MODE=exhausted` 相当）で `request` が決める役に最上位の格の model を返せない場合は、種別は `dev-workflow:decider` のまま `request` が返した model（Claude では `opus`）で進め、その旨を PR コメントに1行残す（レビュー実行者行と同形式。この記録形式がフォールバック記録の正本）:

```bash
gh api -X POST repos/$R/issues/$N/comments \
  -f body='決める役モデル: opus（fable レート制限のためフォールバック。subagent_type は dev-workflow:decider のまま）'
```

1周目からモデルを上げる「重要実装」の事前分類（聖域パス・マージ権限・層間契約・課金/法務。実行役はどの分類でも上位の格止まりで、読んで判断する役が分類に当たるときは `subagent_type: dev-workflow:decider`）は **develop スキルの references/pre-classification.md が正本** — このゲートでは再掲しない。
