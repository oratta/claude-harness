## Context

#397 の worker は `execution.model_resolution` に要求した model と、実際に `model/list` から選んだ ID を返す。通常の Codex 委譲手順には両値の記録があるが、adapter 経路の review phase では本体が G に executor / model と dispatch コメント URL だけを渡し、G はその model を `レビュー実行者:` 行に写す。利用者向け docs は旧形式の完全 ID しか示していない。archive 済み tasks の 3.2 と 3.3 も現行ファイル・spec と食い違う。

## Goals / Non-Goals

**Goals:**
- 利用者が系統名と完全 ID の両方を指定でき、系統名は実行直前に解決されることを読めるようにする。
- Codex review の要求モデルと解決後 ID を PR の記録先コメントから追えるようにする。
- archive 済み tasks の確認記録を実際の判断に一致させる。

**Non-Goals:**
- worker の解決規則、結果 JSON、adapter の選択規則を変えること。
- Claude review のモデル表記やレビューゲートの合否条件を変えること。
- archive 済み change を再 archive すること。

## Decisions

### 解決後 ID は review 実行結果から受け渡す

本体は phase `review` の Codex worker が返した `execution.model_resolution.requested` / `resolved` をレビュー要約と一緒に G へ渡す。dispatch 時点の request にある model だけでは、worker が呼ぶ直前に決めた最新版を知ることができないため、dispatch 記録や profile の値から解決後 ID を推測しない。G が Claude 起動でも Codex 起動でも同じ payload を受け取る。

### 既存のコメント形に値を載せる

Codex の場合だけ既存の `<executor>/<model>` の model 部分を `<requested>→<resolved>` として記す。light/full と dispatch 記録 URL は既存の括弧内のままにする。新たなコメント行や別コメントへ分ける案は、既存の `レビュー実行者:` 行と証拠を照合する手順を増やすため採らない。Claude の場合は従来の model 表記を維持する。`resolved` が未観測なら実行結果の null を未観測と明示し、要求値・dispatch 値から補完しない。

### archive の訂正は履歴の事実修正に限る

3.2 の誤った docs 不在の記述と 3.3 の括弧内の誤記だけを #405 の指定どおり直す。完了チェック、当時の判断や実装範囲は変更しない。

## Risks / Trade-offs

- `requested` と `resolved` を混同すると、実際に使ったモデルを誤記する → worker 結果の対応する二つのフィールドを直接使うことを手順に明記し、文言テストで受け渡し箇所を検証する。
- 既存テストはコメント雛形の固定文字列に依存する → 雛形自体を置換せず、Codex の model 部分の埋め方を説明する文を追加する。

## Migration Plan

手順書と archive の記述を更新し、文言テストと全体回帰で確認する。データ移行はない。

## Open Questions

なし。
