## Context

Fable の週次枠を溶かしているのは出力ではなくターン数（会話履歴の cache 読込）で、実装・修正ループは 1 件で数十〜数百ターン回る。2026-09 の監査で W の 4 割が Fable、fork 1 本で 271 USD 換算・49 万トークンだった。決める役（修正方針・最終 verify・マージ可否・設計判断）は数ターンで終わるので Fable でよい。

現状、この線引きは develop / pr-review-gate の文書と `rules/subagent-model-selection.md` にしか無い。PR #236 で `plugins/dev-workflow/hooks/hooks.json` の `Agent` PreToolUse に配線された `scripts/agent-model-guard.sh` は「`model` 未指定の spawn」と「共有枠が減っているときの `fork`」を deny するが、`model: "fable"` を明示した spawn はどの種別でも素通りする。文書が根拠を書けば例外を作れる状態で、実際 2026-09-08 に develop の本体が「層間契約だから」を理由に実行役の W を `model: fable` で spawn した。

## Goals / Non-Goals

**Goals:**

- Fable の spawn を、決める役の種別（`dev-workflow:decider`）に限る。判定は PreToolUse ガードで機械的に行い、文書の自己申告に依存しない
- 決める役が実行ループを回せないことを、モデルの指示ではなくツール構成（Edit / Write / NotebookEdit / Bash を持たない）で保証する
- 昇格ラダーと重要実装の事前分類表を、ガードが許す形（実行役の上限 = opus、fable は決める役だけ）に一致させる。文書とガードが食い違う状態を残さない

**Non-Goals:**

- `Workflow` ツール内の `agent(prompt, {model:'fable'})` を塞ぐこと。この経路が `Agent` の PreToolUse を通るかは未確認なので実測だけ行い、通らないなら別 issue にする
- 残量モード（`FABLE_BUDGET_MODE`）をガードに持ち込むこと。残量モードは develop 側の助言値のままとし、ガードは残量に関係なく同じ判定をする
- 例外の逃がし道を新設すること。緊急の全解除は既存の `DEV_WORKFLOW_MODEL_GUARD=off` で足りる
- flatmate `docs/agent-loop.md` の書き換え（別リポ・別 issue）

## Decisions

### 強制層は新規フックではなく既存の `agent-model-guard.sh` に足す

`Agent` の PreToolUse に 2 本目のフックを足すと、deny 理由が 2 系統になり、`DEV_WORKFLOW_MODEL_GUARD=off` の逃がし道も二重管理になる。同じツール・同じ判断軸（どのモデルで誰を spawn してよいか）なので 1 本にまとめる。既存 14 テスト（`tests/agent-model-guard.bats`）がそのまま通ることを回帰の基準にする。

### 判定の順序は fork → Fable → model 有無

`fork` は `model` パラメータを無視して親モデルで動くため、既存実装どおり最初に判定して早期 return する（Fable 判定を先に置くと、`model: sonnet` の fork が Fable 判定をすり抜けた顔で通り、共有枠判定に届かなくなる）。次に Fable 判定を置き、最後に既存の「`model` があれば許可 / 無ければ NEEDS_EXPLICIT を deny」を残す。この順序なら既存の振る舞いは Fable 明示のケース以外まったく変わらない。

### Fable の検出は文字列マッチ（`fable` と `claude-fable-*`）

`model` に入りうるのはエイリアス（`fable`）か完全 ID（`claude-fable-5-1` など、将来の世代を含む）で、前者は完全一致、後者は `claude-fable` 前方一致で見る。前後の空白除去と小文字化を挟む。バージョン番号を列挙する方式は世代交代のたびに穴が開くので採らない。

### 決める役の allowlist はスクリプト内のリテラル

`DECIDER_TYPES = {"dev-workflow:decider"}` をスクリプトに直書きし、環境変数で外から足せるようにはしない。env で増やせると「今回だけ」の例外がガードの外で作れてしまい、ガードにした意味が消える。種別が増えたときはスクリプトを直してテストを足す（＝レビューを通る）。

### 決める役に編集系ツールを持たせない

`tools: Read, Grep, Glob` だけを与える。ガードは「Fable でこの種別を spawn してよい」までしか保証しないので、その種別自身が実装ループを回せてしまうと抜け穴が残る。編集できなければ、たとえ長い指示を渡しても実装ループは物理的に成立しない。この規約はリポジトリ横断のテスト（`plugins/*/agents/*.md` のうち `model` が Fable のものは編集系ツールを持たない）で守る。現在該当するのは `casting-arbiter`（`tools: Read`）だけで、新設する `decider` を含めて違反は無い。

### 決める役は記録も実行もしない。結果は呼び出し側が使う

`Bash` を持たないので `gh` でコメントを書けない。決める役の出力は呼び出し側（develop の本体・R1 を起こした本体・G）が受け取り、記録先への記録と次の実行役の spawn はそちら側で行う。決める役の責務は「原因の分類・具体的な指示・次の実行役のモデル」を返すことに限る。

### 昇格は「両方 1 段ずつ」ではなく「原因側だけ」

旧ラダー（sonnet → opus → fable を実行役に対して 1 段ずつ）は、判断が外れているときにも実行役だけを上げていた。上げても同じ間違った指示を高いモデルで実行するだけで、失敗の原因に対応していない。新ラダーは G の failed return に既にある原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）を入力にして、判断側なら決める役を、実行側なら実行役を、一方だけ上げる。決める役は数ターンなので先に上げるほうが安い。

### 事前分類表は実行役の上限を opus に落とし、レビュアーは種別で上げる

旧表は「マージ権限・層間契約・課金/法務に触れる W は 1 周目から fable」としており、実行役の上限 opus と正面から矛盾する（ガードを入れるとこの指示は deny される）。W はこれらの分類でも `opus` 止まりにし、「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体（Fable）の判断で吸収する。読んで判断する役（R1・G が要求するレビュアー）は `model: fable` の `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn する。聖域パスの `opus` は据え置き。

## Risks / Trade-offs

- **正当な Fable 利用が止まる** → 決める役として立てたいだけなら `subagent_type: dev-workflow:decider` に替えれば通る。それでも詰まる緊急時は `DEV_WORKFLOW_MODEL_GUARD=off` で全解除できる（恒久設定にしない）
- **決める役が読み取り専用ゆえに情報不足で判断できない** → 決める役の出力契約に「コードを触らないと直し方が決められないときは、その旨と足りない情報を返す」を入れ、呼び出し側が追加のパスやログを渡して再度呼ぶ形にする
- **`Workflow` 経路が抜け穴として残る可能性** → この change では塞がず、実測結果を issue #250 にコメントする。通らないなら別 issue を切る（塞ぐ範囲を広げると 1 change が 2 実装サイクルに割れる）
- **spawn 済みのチームメイト（住人）には効かない** → 既に立っているサブエージェントのモデルは再開では変わらない。プラグイン更新後に住人を再起動する必要があり、これは別リポの運用手順として issue #250 に記載済み
- **文書の書き換え箇所が多く、取りこぼすと文書とガードが食い違う** → 旧ラダー・旧表を assert している既存テスト（`model-escalation-policy.bats` / `develop-roles.bats` / `spec-decision-and-review.bats` / `develop-skill.bats`）を新しい内容の assert に直すことで、取りこぼしはテストで検出される
- **編集ファイル数が規模超過のトリップワイヤー（5 個）を大きく超える** → 大半は同じ 1 つのルールの反映で設計判断を伴わない。実装中に手が止まったら本体に return して分割を委ねる
