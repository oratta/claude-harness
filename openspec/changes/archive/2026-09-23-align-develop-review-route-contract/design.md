## Context

develop のレビューは、本体が adapter で投げ先を選ぶ経路と、従来どおり G が Codex を直接呼ぶ経路を持つ。経路判別、review phase の再 dispatch、G の payload、pr-review-gate のコメント雛形が別ファイルに分かれているため、同じ契約を役割ごとの視点で正確に書き分ける必要がある。

現状は develop 本体が `レビュー経路: adapter` を常に渡すため実害が出ていない。しかし、fresh G の経路行が欠けた場合の説明は Claude executor と Codex executor で実行可能な操作が異なり、adapter 経路の `needs-reviewer` も重複着手を防ぐ確認時点が gate-runner に不足している。

## Goals / Non-Goals

**Goals:**

- develop 本体、gate-runner、pr-review-gate、Codex adapter の文言を、同じレビュー経路契約へ揃える。
- adapter 経路の handoff に必要な入力と未実行証拠を、読み手が 1 ファイルだけを見ても欠落しない形にする。
- 同一 PR/HEAD で複数の G が review phase を重複 dispatch しない前提確認を明記する。
- 6 件の follow-up を 1 つの回帰テスト群で固定する。

**Non-Goals:**

- adapter の選択アルゴリズム、account 解決、budget 上限そのものを変更しない。
- pr-review-gate の light/full 判定、レビュー品質基準、周回上限を変更しない。
- merge / auto-merge の条件を変更しない。
- provider が禁止している agent / Codex 呼び出しを Codex の G に追加しない。

## Decisions

### 1. レビュー経路と executor の実行制約を別の軸として記述する

`レビュー経路:` が無い fresh G は従来経路として扱う既存ルールを維持する。その上で、従来経路の full レビューは Claude の G なら Codex を直接呼び、Codex の G なら prompt の禁止に従って直接呼ばない、と executor ごとに書き分ける。

経路行の欠落を一律に adapter 扱いへ変える案は、develop 以外の既存呼び出し元との後方互換性を壊すため採用しない。Codex の G に直接呼び出しを許す案も、worker 間の再帰委譲を禁じる provider 契約に反するため採用しない。

### 2. model の決定元は経路ごとに一意にする

従来経路では G の `needs-reviewer` にある推奨 model を使う。adapter 経路では phase `review` の adapter が返した model に残量上限を適用した値を使い、G の推奨値は参考情報とする。

常に G の推奨 model を優先する案は、adapter の dispatch 記録と実際の起動 model が食い違うため採用しない。常に adapter を呼ぶ案も、develop 以外の従来経路を不要に adapter へ依存させるため採用しない。

### 3. adapter handoff の前提確認を G 側に置く

adapter 経路の G は、手順 1 と手順 2-0 を終え、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を返す。重複確認は handoff を発生させる G が行うことで、review phase の再 dispatch より前に競合を止める。

本体だけで重複を防ぐ案は、G が持つ固定 HEAD と着手記録の照合を本体へ重複実装することになるため採用しない。

### 4. 未実行証拠の 5 欄を同じ閉じた列挙にする

adapter 経路では G が Codex を実行しないため、`選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` の全欄に `未実行（adapter 経路）` を許す。gate-runner の payload と pr-review-gate のコメント雛形の両方へ同じ選択肢を置き、片方だけを読んでも架空の実行証拠を要求しないようにする。

欄を空にする案は「記録漏れ」と「設計上の未実行」を区別できないため採用しない。5 欄を 1 つへ統合する案は、従来経路の実測証拠契約を変えるため採用しない。

### 5. 文言整合は既存の単一 capability と回帰テストで固定する

6 件はすべて `dev-workflow-develop` のレビュー経路契約に属するため、1 change・1 delta capability とする。実装では既存の `develop-adapter-review-routing.bats` に各 issue を 1 対 1 で検出するアサーションを追加する。

ファイルごとに change を分ける案は、同じ行と plugin version を複数 PR で競合させ、契約の半端な状態を一時的に作るため採用しない。

## Risks / Trade-offs

- [Risk] 文言を完全一致で検査すると意図を保った言い換えでもテストが落ちる → 各 issue の回帰点に必要な短い不変部分だけをアサートする。
- [Risk] executor ごとの従来経路説明が別のファイルで再びずれる → delta spec に Claude G / Codex G の両 Scenario を置き、同じ bats で対応箇所を検査する。
- [Risk] 重複着手の確認方法をここで新規実装すると範囲が拡大する → 既存の手順 1 の着手確認を参照する文言追加に限定し、新しい lock や状態管理は導入しない。
