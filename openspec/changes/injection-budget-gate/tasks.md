## 1. 測定ロジックを Red から書く

- [ ] 1.1 `tests/injection-budget.bats` を新規作成し、テスト名を ASCII のみで書く（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。`setup()` で `REPO_ROOT` を `$BATS_TEST_FILENAME` の親の親から解決する
- [ ] 1.2 rules の合計バイト数を返すヘルパを書く。`rules/*.md` から basename が `README.md` のものを除き `wc -c` で合計する。「注入対象の正本は `scripts/sync.sh` の symlink 対象」とコメントに書く
- [ ] 1.3 `CLAUDE.md` の合計バイト数を返すヘルパを書く（`AGENTS.md` は含めない）
- [ ] 1.4 `plugins/*/skills/*/SKILL.md` の frontmatter `description` の値を抜き出して合計バイト数を返すヘルパを書く。ファイルごとに最初の `^description:` 行のみを採り、`description: ` の接頭辞を落とした値を `wc -c` に流す
- [ ] 1.5 3 種の合計と予算を比較して判定する本体テストを書く。この時点では `tests/injection-budget.txt` が無いので fail することを確認する（Red）

## 2. 予算ファイルを置いて Green にする

- [ ] 2.1 現状値を測る（`rules` / `CLAUDE.md` / `SKILL.md description` の 3 種を上のヘルパと同じ方法で）。設計時の実測は合計 37,166 バイトだが、実装時点の値を測り直して使う
- [ ] 2.2 `tests/injection-budget.txt` を作り、実測合計に約 5% の余裕を足した値（設計時の想定は 39,000）を数値 1 行だけで書く。テストがこのファイルを読み、閾値をスクリプトに直書きしないことを確認する
- [ ] 2.3 予算値と実測合計の差が実測合計の 10% 以内であることを検査するテストを足す（余裕を取りすぎてゲートが効かなくなるのを防ぐ）
- [ ] 2.4 `scripts/test.sh injection-budget` を実行し、exit code 0 で pass することを確認する（Green）

## 3. 超過時の出力を作る

- [ ] 3.1 超過時に「予算値・実測合計・超過量」の 3 数値を標準エラーへ出す
- [ ] 3.2 超過時に rules / CLAUDE.md / SKILL.md description の内訳 3 行を出す
- [ ] 3.3 超過時に「削る」か「`tests/injection-budget.txt` を上げて PR 本文に理由を書く」かの 2 択を出す
- [ ] 3.4 一時ファイルで超過を再現するテストを書く。実ファイルを書き換えずに済むよう、ヘルパを「対象ファイル一覧を受け取って合計を返す」形にし、テスト側で余分なファイルを足した一覧を渡して超過を作る（実 repo を汚さない。`teardown` で後始末する）
- [ ] 3.5 超過を再現した状態で失敗メッセージに上の 3 要素が含まれることを検査する

## 4. 変更手続きを CLAUDE.md に定める

- [ ] 4.1 リポジトリ直下の `CLAUDE.md` に、`tests/injection-budget.txt` の変更を聖域扱いとし、引き上げる PR の本文に理由（何を削ろうとして、なぜ超えるままにするか）を書く旨を 1 行足す
- [ ] 4.2 `AGENTS.md` に同じ変更を反映し、`scripts/test.sh agents-md-sync` が pass することを確認する
- [ ] 4.3 この規約が `rules/` に入っていないことを確認する（`grep -rn 'injection-budget' rules/` が 0 件）
- [ ] 4.4 `CLAUDE.md` への追記そのものが予算を消費するので、4.1 の後にもう一度 `scripts/test.sh injection-budget` を実行して pass を確認する

## 5. 仕上げ

- [ ] 5.1 `scripts/test.sh` を引数なしで全件実行し、exit code と TAP サマリをターン内に表示する（既存スイートを壊していないことの証拠。push 前の規約）
- [ ] 5.2 `scripts/lint.sh` を実行して pass を確認する
- [ ] 5.3 `openspec/changes/injection-budget-gate/` の artifact と実装の一致を `/opsx:verify` で検証する
- [ ] 5.4 `/opsx:archive` で change をアーカイブし、`tests/openspec-specs-format.bats` が pass することを確認する（delta 見出しが `openspec/specs/` に残っていないこと）
