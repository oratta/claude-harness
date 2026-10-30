## 事実の列の在りか（実物で確認）

- issue 経路: `issue_intervals()` が返す `matched` の各行に `row["facts"]`（区間の事実の列）がある。`cmd_issue` は既に `inferred_totals` でこれを使っている。`summarise()` に渡せば未知モデルを数えられる
- epic 経路: `cmd_epic` が呼ぶ `assign_epic_rows()` の内部の `counted`（ヘッドブランチの行＋ブランチに属さない区間の行を 1 回ずつ数えたもの）が、合計に入る行そのもの。ここに `summarise()` をかければ、合計に入った行のうち単価が引けなかったものと一致する。戻り値に `unknown_models` を 1 鍵足す
- リポジトリ不明の区間の行は、epic でも issue でも合計に入れない既存の扱いのまま、未知モデルの集計にも入れない

## 決めたこと

- 共通化する: `render_breakdown()` の末尾の未知モデルのループを `render_unknown_models(unknown_models: dict)` に切り出し、`render_breakdown()` がそれを呼ぶ。issue・epic は `{モデル名: 行数}` を渡して同じ関数で出す。文言が 1 か所にしか無いので、経路ごとに食い違わない。branch の出力は変わらない
- 数え方は `summarise()` の `unknown_models`（応答の 2 行目以降の事実は数えず、モデル名の無い行は `(モデル名なし)`）をそのまま使う。branch と数え方が揃う
- 出す位置は、issue は区間の行と `リポジトリ不明` の行の後・推定の注記の前、epic は子 issue の行の並びの後・`リポジトリ不明` の前。1 行目と、他の行の書式は変えない
- 内訳（モデル別）の表は issue・epic には足さない（今回の範囲は未知モデルの名前と行数）
- 範囲外: `issue --closing-pr` の合計に入る閉じた PR 側の行の未知モデルは、今回の issue の受け入れ条件（対象区間）に含めない。PR の分は PR 経路（branch）で見られる
- `cmd_timeline` など他の呼び出し元は `render_breakdown()` も `assign_epic_rows()` の既存の鍵も使い方が変わらない（鍵を足すだけ）ので、1 行目の書式に影響しない
