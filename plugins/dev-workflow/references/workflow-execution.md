# Workflow 実行の型（develop の 1 ループに収まらない規模の回し方）

develop スキルの 1 ループ（W → R1 → W → G）で収まらない規模——昇格トリップワイヤー 1（規模超過）が発火し、エピック化（子 issue への分割）でも足りない探索的な実装——を、**ネイティブの Workflow ツール**で回すときの型。解散した自律実行プラグインの exec（計画ファイル → Workflow スクリプト生成）から、残す価値のある知見だけをこの 1 ファイルに集約した（#205）。

**スクリプトの書き方（API・`pipeline` / `parallel`・resume・品質パターン）の正本は `workflow-authoring` スキル**であり、このファイルはそれを繰り返さない。スクリプトを書く前に必ず `workflow-authoring` を読み込む。Workflow ツールの起動は、ユーザーの明示的な opt-in（「ワークフローで」「fan out で」等）か、このファイルを指すトリップワイヤーの発火を経ていること。

## 1. 3 フェーズ構成: Review → Build → Verify

`meta.phases` で 3 フェーズを宣言し、各 `agent()` に `phase` を付ける。

| フェーズ | 誰が何をするか | ティア（`references/model-tiers.md`） |
|---|---|---|
| **Review** | 実装前に計画（change の artifact）を別コンテキストが審査する — **Build Contract レビュー**。develop では R1（`skills/develop/references/roles/spec-reviewer.md`）が担う工程で、Workflow 内では reviewer agent を立てる。APPROVE が出るまで Build に入らない | `fable` |
| **Build** | change / タスク単位で builder が TDD 実装する。1 タスク 1 コンテキスト。完了レポートは `schema` で型を固定する（コミットハッシュ・テスト結果・完了タスク） | `sonnet` から出発。失敗ループ（トリップワイヤー 2）で 1 段ずつ昇格 |
| **Verify** | builder が作ったものを**自分が作っていない立場**で壊しに行く。テスト・lint・型・ビルドを自分で再実行する（builder の自己申告を信用しない） | `fable`（checkpoint の再ランクと最終判定） |

Build Contract レビューを Workflow で行った場合、develop の仕様レビュー（R1）と二重にはレビューしない（どちらか一方で足りる）。

## 2. verifier の姿勢

- 「よくできている」は禁止。各評価軸で数値を出し、しきい値未達には具体的な修正提案を付ける
- **品質**（テスト・lint・型チェック・ビルド）は **100% 必須**。1 件でも落ちれば FAIL
- **完成度**（エッジケース・エラーハンドリングのコードレビュー）は **80% 以上**
- 疑わしい場合は **FAIL 側に倒す**
- レポートは `agent(prompt, {schema})` の `schema` で構造化し、判定（PASS / FAIL）・スコア・指摘を機械可読にする。散文の自己申告で「完了」にしない

## 3. 状態の持ち方

外部状態は Workflow の `args`（入力）と各 `agent()` の return 値（出力）で持ち、中断再開は `resumeFromRunId` を使う。独自の状態ファイル形式（旧 feature-list.json のような）を作らない。人間向けの進捗は `/workflows` のライブビューで見る。

## 4. develop との接続

- 入口: トリップワイヤー 1 が発火して本体自身が読んでいる場合、または本体がエピック化では足りないと判断した場合に、この型で Workflow を起こす。W として起動されているなら本体に return して判断を委ねる（テンプレートの規定どおり）
- 出口: Workflow の return 値（verify の判定・変更ファイル・テスト結果）を PR 本文（`references/pr-body-format.md` の型）に反映し、pr-review-gate（G）は develop と同じ手順で通す。Workflow を使ったことでゲートが免除されることはない
- 成果の引き継ぎ: 乗り換え時にここまでの編集・通ったテスト・判明した事実を `args` で渡し、やり直さない（トリップワイヤーの「乗り換え時の成果引き継ぎ」）
