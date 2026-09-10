# cost-ledger-aggregation — プラグインの骨格と集計エンジン、`/cost` コマンド

エピック #272 の子1（issue #273、PR #271）。台帳への焼き付け（#274）と pr-review-gate 連携（#276）はこの change の範囲外。

## Why

issue や PR ごとに、その作業に API 換算でいくらかかったかが分からない。ステータスバーには「直近30日を API 料金に換算するといくらか」が既に出ている（statusline プラグイン → ccusage）が、それは全体の合計しか出せない。どの issue に、どの PR に、どれだけ溶けたのかが見えないので、コストの高い作業パターンを特定できないし、見積もりの精度も上がらない。

Claude Code の会話ログ（`~/.claude/projects/**/*.jsonl`）は、アシスタントの 1 メッセージごとに `gitBranch`・`model`・トークン内訳を持っている。**サブエージェント（`isSidechain: true`）の行にも `gitBranch` が入る**（直近30日で 238,436 件確認）。だから追加の記録を仕込まなくても、過去にさかのぼって集計できる。全履歴 2,977 ファイル / 492,850 メッセージを 8.4 秒で集計できることが計測で確かめられている（`plugins/cost-ledger/prototypes/`）。

## What Changes

- **新しいプラグイン `plugins/cost-ledger/` を作る**。`plugins/cost-ledger/.claude-plugin/plugin.json` を新規に置き、リポジトリルートの `.claude-plugin/marketplace.json` にも登録する。statusline に混ぜないのは、statusline が描画のたびに走るため全履歴スキャン（8〜28 秒）を混ぜられないから。dev-workflow に混ぜないのは、dev-workflow が PR 運用のリポでしか効かないのに対し、コストを一番知りたいのが PR を作らない main 上の作業だから
- **集計エンジンを実装する**。`~/.claude/projects/**/*.jsonl` を読み、帰属の鍵を 2 本立てにする:
  - 第 1 の鍵は `gitBranch`。サブエージェントの行にも入るので、そのまま使える
  - 第 2 の鍵は **（リポジトリ識別子, issue 番号）の組**。issue 番号は `gh issue view` / `comment` / `edit` / `close` / `develop` に渡された番号をツール呼び出しから拾う。issue 番号はリポジトリ内でしか一意でないので、番号だけを鍵にはしない
- **区間分割**: 投稿（`gh pr comment` / `gh issue comment` / `gh pr create` / `gh pr ready`）から投稿までを 1 区間とし、区間ごとに直近に触った issue へ寄せる。区間は `sessionId` ごとに切る。1 セッションが複数 issue を触り、かつ複数セッションが同じブランチで並行するため
- **`/cost <番号>` コマンドを追加する**。PR 番号ならそのブランチのコスト、issue 番号ならその issue を触った区間のコスト合計を、USD と円で返す。issue の経路は実行した作業ディレクトリのリポジトリで絞る。番号を渡さなければ現在のブランチを見る
- **出力の 1 行目を固定書式にする**。後続のゲート連携（#276）が 1 行目だけを取って PR に貼れるようにする
- **料金表と円換算レートを 1 か所に集約する**（$/MTok の 入力・出力・キャッシュ書込5m・キャッシュ書込1h・キャッシュ読出、および固定の換算レート）。プロトタイプでは 5 本のスクリプトそれぞれの `P` に手で書かれている。単価はモデル名の**最長一致の前方一致**で引く
- 各行からはまず**事実だけ**を抽出し（`requestId`・`timestamp`・`sessionId`・`isSidechain`・リポジトリ識別子・`gitBranch`・モデル・トークン 5 種・触った issue 番号・投稿の印）、区間分割はその事実の列に対する関数として書く。区間の帰属は投稿が来るまで確定しないため、1 行ずつ追記する後続の台帳（#274）が書けるのは事実に限られる
- 重複排除は `requestId`、worktree の親リポジトリへの畳み込みは `cwd` からの `git -C <cwd> rev-parse --path-format=absolute --git-common-dir` で行う
- 会話ログのルートは `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects`。statusline と dev-workflow が既に使っている変数に揃える
- この change の時点では**会話ログを直接読む**。台帳経由への切り替えは `cost-ledger-persistence`（#274）が行う

## Capabilities

### New Capabilities

- `cost-ledger-attribution`: 会話ログの各行を、ブランチと issue 番号の 2 本立てでどの作業単位に帰属させるかの規則。区間分割・重複排除・worktree の畳み込みを含む
- `cost-ledger-pricing`: トークン内訳とモデル名から API 換算コストを求める規則。料金表の単一の置き場所と、未知モデルの扱い
- `cost-ledger-cost-command`: `/cost <番号>` の入力解釈（PR 番号か issue 番号か）と出力の形式（USD と円）

### Modified Capabilities

なし。既存 capability の要件は変えない。`marketplace-plugin-sync` はプラグイン登録の一般規則を既に定めており、その規則に従って新しい行を足すだけで要件そのものは変わらない。

## Impact

- **新規**: `plugins/cost-ledger/.claude-plugin/plugin.json`、集計エンジンの実装、`/cost` コマンドの定義、テスト
- **変更**: リポジトリルート `.claude-plugin/marketplace.json`（cost-ledger の行を追加）
- **既存への影響なし**: statusline・dev-workflow・その他のプラグインには触らない
- **テスト**: `bash scripts/test.sh` の全件 green が受け入れ条件。S131（`tests/marketplace-sync.bats`）が plugin.json と marketplace.json の整合と merge-base からのバージョン bump を検査する
- **残す**: `plugins/cost-ledger/prototypes/` は設計の根拠を再現する手段として残す。削除は #276（子3）
