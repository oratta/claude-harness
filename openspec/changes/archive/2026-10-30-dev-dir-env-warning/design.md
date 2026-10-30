## 方式の選択

- 採る: SessionStart フックで警告する。読み取りだけで副作用が無い
- 採らない: セットアップ用コマンド。settings.json の書き換え（バックアップ、既存値を上書きしない）という壊れうる部品が増える。入れ方は README で足りる

## 雑音を出さない条件

harness を直さない一般利用者には毎セッションの雑音になるため、次の全部を満たすときだけ出す。

1. 環境変数 `CLAUDE_HARNESS_DEV_DIR` が未設定か空
2. 作業ディレクトリが git リポジトリで、その最上位に `.claude-plugin/marketplace.json` があり `name` が `oratta-claude-harness`

2 は「harness の開発に関わる作業の前提が欠けているとき」の近似で、開発用 clone とその worktree に当たる。他のリポジトリでは無出力。

## 失敗の扱い

何が起きても exit 0（wt-setup-guard.sh と同じ fail-soft）。stdin は読み捨てる。

## 出力

JSON の `systemMessage` に 1 行（変数名・意味・README の節への案内）。利用者に見える。
