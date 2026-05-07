# longrun:plan に MVP モードを追加する案 — brain dump

> **ステータス**: brain dump（未着手）。本 doc は設計案を残すのみで、実装は別 longrun で行う。
> **作成経緯**: 1h-cooking longrun `cooking-lifecycle-redesign` change-E
> **作成日**: 2026-05-07

---

## 1. 背景

1h-cooking では `/cooking:planning` コマンドを完全に廃止した。当初は「LLM の時間見積もり精度を上げる」方向で改善を試みたが、運用してみると以下が判明した:

- 60 分セッションという極短スパンでは、計画立案そのものが overhead になり、計画と実態の乖離を埋めるための retrospect も負担が重い。
- `plan_done` / `retrospect_start` といったイベント名・データモデルが「計画フェーズ」を前提にしてしまっており、計画を捨てると下流（movie / property 等）にも影響が波及する。
- 60 分で実装まで終わらせる前提の MVP は、人間が手で見積もるほうが速い。LLM に時間配分させる必要がない。

この経緯と意思決定の背景は以下を参照:

- `1h-cooking/docs/2026-05-06_network-filter-tool_session-review.md`（5 章「追加で作るべきもの」P0「`/cooking:requirements` — 要件定義オーケストレーター」）
- `1h-cooking/_longruns/2026-05-07_cooking-lifecycle-redesign/plan.md`

時間見積もり精度向上の方針は撤回した。代わりに「session_start / session_finish の事実だけ記録し、計画は人間がやる」というシンプルな lifecycle に再設計した。

---

## 2. 現状の機能ギャップ

`/cooking:planning` を捨てたことで「ヒアリング → 類似サービス調査 → 実装パターン調査 → 統合プラン」というオーケストレーション機能のスロットが空いた。これがレビューレポート P0「`/cooking:requirements` — 要件定義オーケストレーター」が解こうとした問題である。

ここで、似た役割を担うものとして oratta-claude-harness の `longrun:plan` がすでに存在する。ただし現状の `longrun:plan` は **自律実行用の plan.md を作る**ことに最適化されており、以下を内蔵していない:

- 類似サービス・先行事例のリサーチ subagent
- 実装パターン・アーキテクチャ参考例のリサーチ subagent
- 並列リサーチ結果の統合 → 初期プラン v0 の生成
- ベストプラクティス観点でのプランレビュー subagent

つまり「**brain dump からヒアリング + 並列リサーチ → 統合プラン**」を一発で回すフローが、harness 全体としても欠けている。

ユーザーの仮説:

> 1h-cooking 側に `/cooking:requirements` を新設するより、`longrun:plan` に **MVP モード** を追加して同じスロットを埋めるほうが筋がいい。後者なら他プロジェクトでも使える汎用機能になり、1h-cooking は単に呼び出すだけで済む。

---

## 3. 設計案

`longrun:plan --mode=mvp`（仮）として軽量フローを足す。フル `longrun:plan` のフローは温存し、フラグでモード切り替え。

### MVP モードのフロー

1. **brain dump 受領**
   - ユーザーが「やりたいこと」をフリーテキストで投げる。
2. **ヒアリング**
   - `AskUserQuestion` で曖昧点を 3〜5 個に絞って質問。
   - 60 分で実装可能なスコープに収まるかを check する観点を内蔵。
3. **並列リサーチ subagent（フェーズ 1）**
   - (a) **類似サービス調査**: 既存 OSS / 商用サービスでの実例を収集。
   - (b) **実装パターン調査**: 一般的な実装アーキテクチャ・ライブラリ選定例。
4. **統合 → 初期プラン v0**
   - フェーズ 1 の結果を統合し、scope / non-goals / acceptance criteria を含む v0 を生成。
5. **並列レビュー subagent（フェーズ 2）**
   - (c) **プランレビュー**: スコープが MVP として過大でないか、矛盾はないか。
   - (d) **ベストプラクティス調査**: 該当ドメインの落とし穴・anti-pattern。
6. **最終プラン**
   - フェーズ 2 のレビューを反映し plan.md を確定。
7. **ハンドオフ**
   - `/longrun:exec` を呼ぶか、人間が手で実装に入るかをユーザーに選ばせる。

### 軽量化の方針

MVP モードでは以下の重装備をスキップする:

- Build Contract レビュー（API / 型 / インターフェース契約）
- TDD 強制（Red / Green / Refactor のテンプレ駆動）
- Verifier 起動による自動受け入れ判定

理由: **1h で人間が手で MVP を作る**前提なので、自律実行の安全装置は不要。レビューは人間がその場でやる。

---

## 4. 既存 longrun:plan との差分

| 項目 | 既存 longrun:plan（フル） | MVP モード |
|---|---|---|
| ヒアリング（AskUserQuestion） | あり | あり（軽量化） |
| Changes 分解（複数 change への分割） | あり | あり（簡素化） |
| Validation（plan.md の構造検査） | あり | あり |
| 類似サービスリサーチ subagent | **なし** | **あり**（追加） |
| 実装パターンリサーチ subagent | **なし** | **あり**（追加） |
| ベストプラクティス subagent | **なし** | **あり**（追加） |
| Build Contract レビュー | あり | **切る** |
| TDD 強制 | あり | **切る** |
| Verifier 自動起動 | あり | **切る** |
| 想定アウトプット | 自律実行用 plan.md | 人間実装用 plan.md（軽量） |
| 想定実装時間 | 数時間〜数日 | 60 分以内 |

要点:

- **残す**: ヒアリング、Changes 分解、Validation。共通骨格は再利用。
- **足す**: 並列リサーチ subagent（類似サービス / 実装パターン / ベスプラ）。
- **切る**: Build Contract / TDD / Verifier。重装備は MVP では overhead。

---

## 5. 別 longrun での実装宣言

本 doc は **brain dump のみ**であり、実装は行わない。

- 1h-cooking の `_longruns/2026-05-07_cooking-lifecycle-redesign` では「時間見積もり撤廃と lifecycle 再設計」に集中する。MVP モード追加はここでは扱わない。
- 実装は **別の longrun** を立ち上げ、そこで設計を詰めてから着手する。具体的には:
  - 別 longrun の名前（仮）: `longrun-plan-mvp-mode`
  - スコープ: 本 doc の 3 章 / 4 章を起点に、subagent の prompt 設計・並列実行制御・既存 `longrun:plan` との統合方法を詰める。
  - 着手タイミング: 1h-cooking lifecycle 再設計が安定運用に入ってから。

ここでは「設計案を残す」ことだけが完了条件であり、これ以上踏み込まない。
