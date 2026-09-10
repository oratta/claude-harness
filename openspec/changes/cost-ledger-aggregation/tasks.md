## 1. プラグインの骨格

- [x] 1.1 `plugins/cost-ledger/.claude-plugin/plugin.json` を作る（name・version・description・author・license・keywords。他プラグインと同じ形式。python3 を実行時依存にするなら description に明記する）
- [x] 1.2 リポジトリルート `.claude-plugin/marketplace.json` に cost-ledger の行を足す（name・description・source・category・version・author・keywords を plugin.json と一致させる）
- [x] 1.3 `bash scripts/test.sh` を実行し、S130b と S131（`tests/marketplace-sync.bats`）が green になることを exit code つきで確認する（このブランチは prototypes を先に commit したため、着手前は S130b が fail している。1.1 と 1.2 で解消する）

## 2. 料金表と単価の適用（Red → Green）

- [x] 2.1 `plugins/cost-ledger/pricing.json` を作り、プロトタイプ 5 本の `P` から単価（$/MTok の 入力・出力・キャッシュ書込5m・キャッシュ書込1h・キャッシュ読出）と固定の円換算レートを移す
- [x] 2.2 「単価を書き換えると `/cost` の出力が変わる」テストを先に書く（Red）
- [x] 2.3 「単価が最長一致の前方一致で引かれ、`claude-fable-5-1` が `claude-fable-5` より優先される（表の並び順に依存しない）」テストを先に書く（Red）
- [x] 2.4 「日付付きのモデル名 `claude-haiku-4-5-20251001` が `claude-haiku-4-5` の単価で引かれる」テストを先に書く（Red）
- [x] 2.5 「どの鍵にも前方一致しないモデルが 0 円で黙って落ちず、名前と行数が出力に出る」テストを先に書く（Red）
- [x] 2.6 「円換算が固定レートで、環境変数で上書きでき、出力にレートが添えられる」テストを先に書く（Red）
- [x] 2.7 `message.model` で最長一致の前方一致により単価を選び、トークン 5 種に掛けて合計する実装と、固定レートによる円換算を書く（Green）

## 3. テスト用 fixture

- [x] 3.1 PII と秘密を含まない fixture jsonl を `plugins/cost-ledger/tests/fixtures/` に作る。sidechain の行（`isSidechain: true`）・重複した `requestId`・削除済み `cwd`・複数 issue への投稿・キャッシュ書込の内訳が無い古い形の行を含める（前例: `plugins/experience-to-skill/tests/fixtures/sample-session.jsonl`）
- [x] 3.2 fixture が PII と秘密を含まないことをアサートするテストを書く（前例: `plugins/experience-to-skill/tests/sanitize.bats` の sanitize-idempotent）

## 4. 事実の抽出と重複排除（Red → Green）

- [x] 4.1 「1 行から抽出される事実に区間の帰属先 issue が含まれない」テストを先に書く（Red）
- [x] 4.2 「同一 `requestId` が複数ファイルにあっても 1 回しか集計されない」テストを先に書く（Red）
- [x] 4.3 「`cache_creation` が無く `cache_creation_input_tokens` だけがある行が、キャッシュ書込 5m として読まれる」テストを先に書く（Red）
- [x] 4.4 「ログのルートが `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects` で解決され、リポジトリ内に固定パスが無い」ことを `grep -rn` で確かめるテストを先に書く（Red）
- [x] 4.5 会話ログを 1 パスで読み、`requestId` で重複排除し、行ごとに事実（`requestId`・`timestamp`・`sessionId`・`isSidechain`・リポジトリ識別子・`gitBranch`・モデル・トークン 5 種・触った issue 番号の列・投稿の印）を抽出する実装を書く（Green）

## 5. 帰属（ブランチとリポジトリ識別子）（Red → Green）

- [x] 5.1 「`isSidechain: true` の行もブランチの合計に含まれる」テストを先に書く（Red）
- [x] 5.2 「`gitBranch` が無い行が黙って消えず未帰属として残る」テストを先に書く（Red）
- [x] 5.3 「メイン worktree と副 worktree が同一のリポジトリ識別子に畳まれる」テストを先に書く（Red）
- [x] 5.4 「`cwd` が削除済みでも集計が中断せず、リポジトリ識別子が『不明』として記録される」テストを先に書く（Red）
- [x] 5.5 「未帰属とリポジトリ不明を含めた合計が、全行のコストの総額と一致する」テストを先に書く（Red）
- [x] 5.6 `gitBranch` による帰属と、`cwd` からの `git -C <cwd> rev-parse --path-format=absolute --git-common-dir` によるリポジトリ識別子の導出および worktree の畳み込みを実装する（Green）

## 6. 帰属（issue と区間分割）（Red → Green）

- [x] 6.1 「別リポジトリの同じ issue 番号が合算されない」テストを先に書く（Red）
- [x] 6.2 「main 上で `gh issue comment 148` を実行したセッションの区間が、そのリポジトリの issue 148 へ帰属する」テストを先に書く（Red）
- [x] 6.3 「`gh issue close` と `gh issue develop` だけのセッションもその issue へ帰属する」テストを先に書く（Red）
- [x] 6.4 「`gh pr ready` が区間の境界として扱われる」テストを先に書く（Red）
- [x] 6.5 「同じブランチで並行する 2 セッションの区間が混ざらない（`sessionId` ごとに切られる）」テストを先に書く（Red）
- [x] 6.6 「区間ごとのコストの合計がブランチの総額と一致する（丸め誤差を除く）」テストを先に書く（Red）
- [x] 6.7 「feature ブランチ上で `gh issue view` した行が、ブランチにも issue にも帰属する」テストを先に書く（Red）
- [x] 6.8 ツール呼び出しから `gh issue view/comment/edit/close/develop` の番号を拾って（リポジトリ識別子, issue 番号）の組を作り、`sessionId` ごとに `timestamp` 順で `gh pr comment` / `gh issue comment` / `gh pr create` / `gh pr ready` を境界として区間を切り、直近に触った issue へ寄せる実装を、事実の列に対する関数として書く（Green）

## 7. `/cost` コマンド（Red → Green）

- [ ] 7.1 「PR 番号を渡すとそのヘッドブランチのコストが返る」テストを先に書く（Red）
- [ ] 7.2 「issue 番号を渡すと、実行した作業ディレクトリのリポジトリの行だけから区間の合計が返る」テストを先に書く（Red）
- [ ] 7.3 「リポジトリ不明の行の件数と金額が別立てで出力される」テストを先に書く（Red）
- [ ] 7.4 「存在しない番号で 0 円と表示せず、見つからないと伝える」テストを先に書く（Red）
- [ ] 7.5 「番号なしで呼ぶと現在のブランチのコストが返り、git リポジトリの外ではブランチが決まらないと伝える」テストを先に書く（Red）
- [ ] 7.6 「出力の 1 行目が固定書式で、金額（USD と円）・換算レート・帰属先・帰属の種別をすべて含む」テストを先に書く（Red）
- [ ] 7.7 `plugins/cost-ledger/commands/cost.md` を作る（`commands/` 配下は自動発見されるので plugin.json への追記は不要）
- [ ] 7.8 番号が PR か issue かを GitHub に問い合わせて判別し、対応する集計を呼んで固定書式の 1 行目と内訳を返す実装を書く（Green）

## 8. 決めた振る舞いを spec に残す

- [ ] 8.1 円換算の固定レート・環境変数での上書き・出力へのレート添付が `specs/cost-ledger-pricing/spec.md` の Requirement と Scenario に残っていることを確認する（実装で変えたなら spec も直す）
- [ ] 8.2 番号なしで呼んだときの既定動作が `specs/cost-ledger-cost-command/spec.md` の Requirement と Scenario に残っていることを確認する（実装で変えたなら spec も直す）

## 9. 受け入れ条件の実測

- [ ] 9.1 `/cost` に PR #271 の番号を渡し、**同じ時点で** `python3 plugins/cost-ledger/prototypes/branch-cost.py oratta/token-optimize` を実行して、$1 以内で一致することを両方の実行結果つきで示す（会話ログは 30 日で消えるため絶対値は下がるが、同時に走らせれば一致する）
- [ ] 9.2 `/cost` に issue 番号を渡し、**同じ時点で** `python3 plugins/cost-ledger/prototypes/per-post-cost.py oratta/token-optimize` を実行して、区間の内訳が整合することを両方の実行結果つきで示す
- [ ] 9.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）を出力の要約つきで示す
- [ ] 9.4 全履歴 1 パスの所要時間を `time` で計測し、実測値を記録する
