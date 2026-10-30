# Tasks

行番号は仕様づくり時点の `9a459b51`。編集前に範囲を読み直す。実装は issue #1150 に R1 の APPROVE が記録されたあと、本体の再開指示を受けてから行う。

## 1. 子の会話量による起動し直し

- [x] 1.1 `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（未設定時 150000、非負整数、0 可）を有効な `--resolve` の待つ前に検査し、会話量の `>=` と既存の時間条件を OR にする。既定値未満・ちょうど・超過、上書き・0・空・単位付き・負数、旧変数を無視するケースを対象の Bats に追加する。既存の「60 分未満は送る」と時間閾値上書きの fixture は N を新閾値未満にし、それぞれの条件を分けて検証する。対象 Bats で、短時間・149999 は既存端末へ送り、150000 / 150001 は起動し直して `/develop` と返事を送り、時間条件の既存ケースも通ることを確認する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:179-184（判定の説明）、plugins/dev-workflow/scripts/epic-dispatch.sh:1023-1055（decide_relaunch）、plugins/dev-workflow/scripts/epic-dispatch.sh:1219-1226（有効な resolve の設定検査）、plugins/dev-workflow/tests/epic-dispatch.bats:4755-4853（fixture と再開判定テスト）
- [x] 1.2 既存の `subagent-context.sh --file` の JSON の `context_tokens` を使い、exit 0 と 2 を計測成功として扱う。既存スクリプトは変更せず、計測失敗は会話量の条件だけ不明とする。compact 前後の最新の有効 usage・3 種の入力の合計・末尾の API エラー・有効 usage 無し・時刻不明・計測失敗を対象 Bats に追加し、会話量不明でも古い時刻なら起動し直すこと、時刻不明でも大きい会話なら起動し直すこと、両方不明・ファイル無し・複数ならそのまま送ることを確認する。送れたあとにエピックの判断記録が残り、待ち受けの stdout の契約が維持されることも確かめる。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1023-1055（decide_relaunch）、plugins/dev-workflow/tests/epic-dispatch.bats:4755-4853（fixture と再開判定テスト）
- [x] 1.3 子の表に時間の行より優先する会話量の行（新変数名・既定値 150000）を足し、会話量の測り方・独立した条件と不明時の扱い・#1046 の結論と集計の限りを説明する。対象の文書検査を更新し、表の順序と変数・値・測り方・既存の #1323 の時間条件を検証する。親の表・親の値・#1324 / #1085 の範囲に差分が無いことを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:3-7（子の規則の導入）、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:18-42（子の表・判定の事実・根拠）、plugins/dev-workflow/tests/epic-dispatch.bats:3907-3924（子の表の検査）
- [x] 1.4 `changes/1150.md` に条件・新変数の既定値と上書き・#1046 の根拠と限り・#1323 の条件の維持・計測できない場合の扱い・既存の停止記録からの再開と対象外・戻し方を記録する。ファイルの記載と実装・仕様の一致を読み合わせ、版の差分が無いことを確認する。触る範囲: plugins/dev-workflow/changes/1150.md（新規）

## 2. 対象範囲の結合確認

- [x] 2.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats --filter 'wait --resolve relaunch:|reply-after-idle:'`、`openspec validate relaunch-child-by-context-size --type change --strict`、`git diff --check` を実行して終了コードを記録する。issue の短時間・閾値以上と未満の受け入れ条件を、既存の送信結果に対応する端末操作・送信内容・送信後の記録で確認し、会話量と時間のどちらかの計測失敗が他方の条件を妨げないことを確認する。全体テストは CI に委ねる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3907-3924、plugins/dev-workflow/tests/epic-dispatch.bats:4755-4853（検証対象。追加編集は失敗の修正時のみ）

## Workflow follow-up

- 本体が独立した R1 に仕様レビューを依頼する。この spec 工程では実装タスクを進めない。
- 実装・verify の工程が完了したあと、別の finish 工程で archive と PR の仕様宣言を行う。この作業者は merge・auto-merge を行わない。
