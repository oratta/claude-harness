## 1. プラグインの骨格

- [ ] 1.1 `plugins/cost-ledger/.claude-plugin/plugin.json` を作る（name・version・description・author・license・keywords。他プラグインと同じ形式）
- [ ] 1.2 リポジトリルート `.claude-plugin/marketplace.json` に cost-ledger の行を足す（name・description・source・category・version・author・keywords を plugin.json と一致させる）
- [ ] 1.3 `bash scripts/test.sh` を実行し、S131（`tests/marketplace-sync.bats`）が green になることを exit code つきで確認する

## 2. 料金表と単価の適用（Red → Green）

- [ ] 2.1 料金表を 1 ファイルに集約する置き場所を決め、プロトタイプ 5 本の `P` から単価（$/MTok の 入力・出力・キャッシュ書込5m・キャッシュ書込1h・キャッシュ読出）を移す
- [ ] 2.2 「単価を書き換えると `/cost` の出力が変わる」テストを先に書く（Red）
- [ ] 2.3 「未知モデルが 0 円で黙って落ちず、名前と行数が出力に出る」テストを先に書く（Red）
- [ ] 2.4 `message.model` で単価を選び `message.usage` の 5 種類のトークン内訳に掛けて合計する実装を書く（Green）

## 3. ログの読み取りと重複排除（Red → Green）

- [ ] 3.1 「同一 `requestId` が複数ファイルにあっても 1 回しか集計されない」テストを先に書く（Red）
- [ ] 3.2 「ログのルートが環境変数で解決され、リポジトリ内に固定パスが無い」ことを `grep -rn` で確かめるテストを先に書く（Red）
- [ ] 3.3 `~/.claude/projects/**/*.jsonl` を 1 パスで読み、`requestId` で重複排除する実装を書く（Green）

## 4. 帰属（ブランチと worktree の畳み込み）（Red → Green）

- [ ] 4.1 「`isSidechain: true` の行もブランチの合計に含まれる」テストを先に書く（Red）
- [ ] 4.2 「`gitBranch` が無い行が黙って消えず未帰属として残る」テストを先に書く（Red）
- [ ] 4.3 「`cwd` が削除済みでも集計が中断しない」テストを先に書く（Red）
- [ ] 4.4 `gitBranch` による帰属と、`cwd` からの `git -C <cwd> rev-parse --git-common-dir` による worktree の親リポジトリへの畳み込みを実装する（Green）

## 5. 帰属（issue 番号と区間分割）（Red → Green）

- [ ] 5.1 「main 上で `gh issue comment 148` を実行したセッションの区間が issue 148 へ帰属する」テストを先に書く（Red）
- [ ] 5.2 「1 セッションで 2 つの issue に投稿したとき、区間が別々の issue へ分かれる」テストを先に書く（Red）
- [ ] 5.3 「区間ごとのコストの合計がブランチの総額と一致する（丸め誤差を除く）」テストを先に書く（Red）
- [ ] 5.4 `message.content[].input.command` から `gh issue view/comment/edit <N>` の issue 番号を拾い、投稿（`gh pr comment` / `gh issue comment` / `gh pr create`）から投稿までを 1 区間として直近に触った issue へ寄せる実装を書く（Green）

## 6. `/cost` コマンド（Red → Green）

- [ ] 6.1 「PR 番号を渡すとそのヘッドブランチのコストが返る」テストを先に書く（Red）
- [ ] 6.2 「issue 番号を渡すとその issue を触った区間の合計が返り、区間の内訳も出る」テストを先に書く（Red）
- [ ] 6.3 「存在しない番号で 0 円と表示せず、見つからないと伝える」テストを先に書く（Red）
- [ ] 6.4 「出力に USD と円が両方含まれる」テストを先に書く（Red）
- [ ] 6.5 番号が PR か issue かを GitHub に問い合わせて判別し、対応する集計を呼んで USD と円で返す `/cost` を実装する（Green）
- [ ] 6.6 円換算のレートの取り方（固定値か取得か）を決めて実装に落とし、決めた理由を design.md の Open Questions から本文へ移す
- [ ] 6.7 番号を渡さなかったときの既定の振る舞いを決めて実装に落とし、design.md の Open Questions から本文へ移す

## 7. 受け入れ条件の実測

- [ ] 7.1 `/cost` に PR #271 の番号を渡し、`python3 plugins/cost-ledger/prototypes/branch-cost.py oratta/token-optimize` の $108 と $1 以内で一致することを実行結果つきで示す
- [ ] 7.2 `/cost` に issue 番号を渡し、`python3 plugins/cost-ledger/prototypes/per-post-cost.py oratta/token-optimize` の区間の内訳と整合することを実行結果つきで示す
- [ ] 7.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）を出力の要約つきで示す
- [ ] 7.4 全履歴 1 パスの所要時間を `time` で計測し、実測値を記録する
