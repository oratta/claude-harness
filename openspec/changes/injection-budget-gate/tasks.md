## 1. 集計ヘルパを一覧渡しで書く（実 repo を汚さない形）

- [ ] 1.1 `tests/injection-budget.bats` を新規作成し、テスト名を ASCII のみで書く（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。`setup()` で `REPO_ROOT` を `$BATS_TEST_FILENAME` の親の親から解決し、`teardown()` で一時ディレクトリを消す
- [ ] 1.2 `sum_files <ファイルパス…>` を書く。渡されたファイルの `wc -c` の合計をバイトで返す。**テストは実 repo のファイルを書き換えず、この一覧を差し替えて異常系を作る**
- [ ] 1.3 `list_synced_md <ディレクトリ>` を書く。`<dir>/*.md` から basename が `README.md` のものを除いた一覧を返す。「注入対象の正本は `scripts/sync.sh` の `link_dir`（sync.sh:79, 108-109）。rules と output-styles で同じ 1 条件」とコメントに書く
- [ ] 1.4 `sum_descriptions <ファイルパス…>` を書く。各ファイルの最初の `^description:` 行から `description: ` の接頭辞を落とした**値のみ**を連結して `wc -c` に流す。「末尾改行は数えない（1 行ずつ流すとファイル本数ぶんずれる）」とコメントに明記する
- [ ] 1.5 8 カテゴリの実測値を返す関数と、その合計を返す関数を書く。カテゴリは rules（`list_synced_md rules`）/ CLAUDE.md / output-styles（`list_synced_md output-styles`）/ SKILL description（`plugins/*/skills/*/SKILL.md`）/ agent description（`plugins/*/agents/*.md`）/ command description（`plugins/*/commands/*.md`）/ local SKILL description（`.claude/skills/` 配下の `SKILL.md`）/ local command description（`.claude/commands/` 配下の `*.md`）。description の 5 カテゴリはディレクトリ配下を任意の深さで走査する（1 階層深く置いて集計から逃げられないようにする）
- [ ] 1.6 ヘルパ単体の Red/Green テストを書く: 一時ディレクトリで README.md が除外されること（spec の「README.md は rules と output-styles のどちらでも合計に含まれない」）、description 3 本の合計がちょうど 3N になること（同「末尾改行を数えない」）

## 2. 判定本体と予算ファイル

- [ ] 2.1 判定関数を書く。整数演算のみで (a) `total > budget` なら超過側 fail、(b) `budget * 10 > total * 11` なら下振れ側 fail、(c) それ以外は pass（`budget == total` は pass）
- [ ] 2.2 8 カテゴリの現状値を測る。design 時点の実測は rules 23,274 / CLAUDE.md 5,252 / output-styles 6,863 / SKILL 8,623 / agent 2,956 / command 2,395 / local SKILL 1,510 / local command 640 = 合計 51,513 だが、実装時点で測り直した値を使う
- [ ] 2.3 `tests/injection-budget.txt` を作り、実測合計に約 5% の余裕を足した値（design 時点の実測 51,513 に対する想定は 54,000）を数値 1 行だけで書く。テストがこのファイルを読み、閾値をスクリプトに直書きしていないことを確認する
- [ ] 2.4 常駐テストとして「予算が実測以上、かつ実測の 1.1 倍以下」を毎回検査する本体テストを書く（初期値の一度きりの確認にしない）
- [ ] 2.5 境界のテストを書く: 予算 == 実測で pass、`budget * 10 > total * 11` を満たす最小の予算で下振れ fail（「実測 × 1.1 + 1」は実測が 10 の倍数でないと整数にならないので使わない）、実測 = 予算 + 1 で超過 fail
- [ ] 2.6 `scripts/test.sh injection-budget` を実行し、exit code 0 で pass することを確認する

## 3. 失敗時の出力

- [ ] 3.1 超過側の失敗で「予算・実測・超過量」と、超過側であることの明示を標準エラーへ出す
- [ ] 3.2 下振れ側の失敗で「予算・実測・下振れ量」「下振れであること」「`tests/injection-budget.txt` を実測+5% の具体的な数値に下げること」を出す
- [ ] 3.3 どちらの失敗でも 8 カテゴリの内訳を出す。`output-styles` の行には「メインセッションのみ（サブエージェントには載らない）」の注記を添える
- [ ] 3.4 超過側の出力に「削る」か「予算ファイルを上げて PR 本文に理由を書く」かの 2 択を出す
- [ ] 3.5 一時ディレクトリと一覧渡しで超過・下振れの両方を再現し、上の出力要素が含まれることを検査するテストを書く（実 repo のファイルは 1 バイトも書き換えない）

## 4. 折りたたみ記法のガード

- [ ] 4.1 `check_single_line_description <ファイルパス…>` を書く。各ファイルで `description:` の値が `>`・`|`・`>-`・`|-` 等の折りたたみ／リテラル記法でないこと、かつ次の行が別のトップレベル frontmatter キー（`^[A-Za-z_][A-Za-z0-9_-]*:`）か frontmatter 終端（`^---$`）であることを検査する
- [ ] 4.2 `plugins/*/skills/*/SKILL.md`・`plugins/*/agents/*.md`・`plugins/*/commands/*.md`・`.claude/skills/` 配下の `SKILL.md`・`.claude/commands/` 配下の `*.md` の全 59 本に対して 4.1 を走らせるテストを足し、現状 pass することを確認する
- [ ] 4.3 一時ディレクトリに `description: >` と継続行を持つファイルを置き、違反として検出され該当ファイル名が出力されることを検査するテストを足す

## 5. 予算ファイルを聖域にする

- [ ] 5.1 `.github/workflows/auto-merge.yml` の `>>> sacred-paths` ブロック内の `SACRED` 正規表現に `^tests/injection-budget\.txt$` を足す。ブロック上部のコメントの聖域一覧にも 1 行の説明を添える。`SACRED` の抽出（`scripts/test-auto-merge-workflow.sh:70`）は正規表現が 1 行に収まっていることを前提にしているので、2 行へ折り返さず 1 行のまま伸ばす
- [ ] 5.2 `scripts/test-auto-merge-workflow.sh` の「聖域に必ず一致しなければならないパス」の `for p in` 一覧に `"tests/injection-budget.txt"` を足す（workflow のコメントがこの二重化を要求している）
- [ ] 5.3 `scripts/test-auto-merge-workflow.sh` を実行し、exit code 0 で、非聖域側の検査（`docs/innocuous-notes.md` 等）も引き続き pass することを確認する

## 6. 変更手続きを CLAUDE.md に定める

- [ ] 6.1 リポジトリ直下の `CLAUDE.md` に、`tests/injection-budget.txt` の変更は聖域扱いで、動かす PR の本文に理由（何を削ろうとして、なぜ超えるままにするか）を書く旨を **1〜2 文**で足す。詳しい手順は書かない（失敗メッセージ側が持つ。`CLAUDE.md` 自体が測定対象なので追記が予算を消費する）
- [ ] 6.2 `AGENTS.md` に同じ変更を反映し、`scripts/test.sh agents-md-sync` が pass することを確認する
- [ ] 6.3 この規約が `rules/` に入っていないことを確認する（`grep -rn 'injection-budget' rules/` が 0 件）
- [ ] 6.4 6.1 の追記そのものが予算を消費するので、追記後にもう一度測り直し、必要なら 2.3 の予算値を「実測+5%」に取り直して `scripts/test.sh injection-budget` が pass することを確認する

## 7. 仕上げ

- [ ] 7.1 `scripts/test.sh` を引数なしで全件実行し、exit code と TAP サマリをターン内に表示する（既存スイートを壊していないことの証拠。push 前の規約）
- [ ] 7.2 `scripts/lint.sh` を実行して pass を確認する
- [ ] 7.3 `openspec/changes/injection-budget-gate/` の artifact と実装の一致を `/opsx:verify` で検証する
- [ ] 7.4 `/opsx:archive` で change をアーカイブし、`tests/openspec-specs-format.bats` が pass することを確認する（delta 見出しが `openspec/specs/` に残っていないこと）
- [ ] 7.5 archive で `CLAUDE.md` 以外の測定対象が動いていないことを確認するため、最後にもう一度 `scripts/test.sh injection-budget` を実行する
