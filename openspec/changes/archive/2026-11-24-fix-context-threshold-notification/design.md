# Design

## Context

change `model-context-threshold-wiring`（archive 済み・編集しない）は診断を stderr 限定にし、cap 内の hook stdout を空に保つ設計だった。ゲート一周目で、これでは AC3「検証をやり直す作業を知らせる」が再開されない作業者（G など）に届かないと分かった。公式仕様では exit 0 の hook の stderr は Claude に届かず、`hookSpecificOutput.additionalContext` は PreToolUse・PostToolUse とも Claude の文脈に配送される。一方、共通 API が欠けた場合の例外が出力契約を破る実装漏れも見つかった。

## Decisions

### 1. 通知先は hook が動くサブエージェント本人、経路は `additionalContext`

候補は stderr のみ・`additionalContext`・`systemMessage` だった。stderr のみは本人に届かず AC3 を満たさない。`systemMessage` は利用者の画面向けで、本人への到達が目的に合わない。`additionalContext` なら対象の全サブエージェントを一律に被覆できる。CLI（`subagent-context.sh`）は本体が実行する人向けの道具なので stderr と測定 JSON のままとし、`systemMessage` は追加しない。

### 2. 出力の組み立て

利用する文脈指標に `revalidation_required` があるとき、要求モデル・根拠モデル・対象指標・手順の絶対パスを含む再検証通知文を作り、stderr にも同じ診断を出す。通知文は「根拠モデルと異なるため、案内した手順でしきい値を再検証する必要がある」と明示し、締め・今すぐの return・拒否は要求しない。受けた本人は、この通知だけを理由に作業を止めず、自分で再検証も始めず、次の return に再検証が要る旨（要求モデル・根拠モデル・対象指標）を書く。通知文にこの動きを明示する。

| 状況 | stdout |
|---|---|
| 再検証通知なし・閾値以内 | 空 |
| 再検証通知あり・閾値以内（両イベント、cap 超 hard 以内の Pre、`hard <= cap` の Pre を含む） | `hookSpecificOutput`（`hookEventName` と `additionalContext`）だけの単一 JSON |
| cap 超の PostToolUse | 既存 NOTIFY 本文をそのまま保ち、別段落で再検証通知を追記した単一 JSON |
| hard 超の対象ツールの PreToolUse | 既存の deny と `permissionDecisionReason` は不変、同じ `hookSpecificOutput` に再検証の `additionalContext` を追加 |
| 解除・計測不能・解決失敗・正数条件違反・メインスレッド | 空（従来どおり） |

通知は環境上書きでも消さず、呼出しごとに出す。状態保存や一度だけの抑制はしない。`permissionDecision`・`decision`・`continue:false`・`systemMessage` は診断だけの出力に付けない。

### 3. 解決失敗の境界

両スクリプトとも、ロード時の try の中で `resolve = resolver.resolve_thresholds` の取得と callable 確認までを行い、呼出しは `resolve(model, env)` にする。`ValueError` は既存どおり `invalid_table` / `invalid_override`。API 欠損・非 callable・呼出しの `RuntimeError` 等と、必須の戻り値の欠損・診断準備の例外は `resolver_unavailable` にする。捕捉は resolver との境界に限り、`BaseException` や処理全体の握り潰しにしない。CLI は呼出元名・コード・理由を stderr、error 文字列を持つ 1 行 JSON を stdout に出して exit 1。hook は stderr に同じ情報を出して stdout 空・exit 0。途中出力や traceback は出さない。そのため、結果の取り出しと検証を終えてから stderr と stdout に出す順で実装し、必須キー欠損の戻り値では fallback や再検証の診断を先に出さない。

### 4. 仕様の同期範囲

- token-thresholds: 診断の要件を stderr＋本人への `additionalContext` の契約へ改訂し、未知モデル・環境上書き・根拠違い・配布先パスの各シナリオで hook の通知 JSON も検査する。上書き要件は再検証通知があるときの stdout 例外（拒否・締めの境界は不変）を明記する。解決失敗の要件に API 欠損・通常例外を含める。
- execution-strategy: 途中計測 hook の閾値内の stdout 空を再検証通知が無い場合に限り、PostToolUse の締め通知に既存本文を保つ追記を許し、強制停止の要件と「閾値の間」「大小が逆」のシナリオで拒否しない場合の通知 JSON を許す。
- `decision-criteria.md` の文脈計測の説明を同期する。

archive 済み change は編集せず、この change の delta を後工程で主仕様へ同期する。

## Risks / Trade-offs

- 根拠違いのモデルでは cap 内でも毎ツール呼出しに通知が文脈へ入り、文脈を少しずつ消費する → 黙って古い値を使い続けない契約を優先。再検証が要らないモデルでは従来どおり無音。
- 通知の到達は公式仕様と Bats の出力検査が根拠で、実機の配送は観測していない → 記録でも観測済みと書かない。
- 捕捉を境界に限るため、予測できない全障害は完全には拾わない → 完了条件にしない。

## Migration Plan

5 ファイルの実装と 2 Bats の回帰確認後に導入する。テストは一時プラグイン配置に実体と表をコピーし、ロード可能な一時モジュールで API 欠損等を模擬する（本物の共通処理・表は変えない）。切り戻しはこの 5 ファイルの変更を戻せば前の archive 済み change の状態へ戻る。仕様レビューの APPROVE 前には実装に進まない。
