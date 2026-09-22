## 1. テストを先に書く（TDD）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、手順 2-1 の `text` ブロック内で `変更点の一覧` → `照合表` → `ハンク被覆` → 自己点検 → 指摘の順になること、各受け入れ条件への対応・検索語・revision-safe な検索コマンド・全ヒット・ハンクごとの指摘番号または `問題なし` を要求することの検査を足す
- [ ] 1.2 同 bats に、固定書式の `場所` 欄の「diff と重なる範囲で 10 行以内」と同じ行に、食い違いの指摘は diff 外を含む 2 か所を書ける但し書きがあること、および Codex 優先度出力の読み替え表が三表の欠落を完全な結果として扱わないことの検査を足す
- [ ] 1.3 照合スクリプト用の bats を追加し、順 3 の第 1 段と一周目照合が同じ `修正前 SHA`・repository-wide な `git grep ... <rev> -- .`・4 列の全ヒット表を入力できること、照合表に無いヒットを 1 件含む入力が exit 1 と差分の `file:line` を返すこと、一致する入力が exit 0 になること、検索結果に無い表の行も差分になることを先に書く
- [ ] 1.4 同 bats に、別ディレクトリの未変更ファイルに同じ語があると missing になるケース、追跡対象パスを除外または検索起点をサブディレクトリへ狭めたコマンドを拒否するケース、順 3 の第 1 段と一周目照合で第 4 列の値が違っても同じヒット集合として照合するケースを足す
- [ ] 1.5 `plugins/dev-workflow/tests/develop-roles.bats` に、G が受け入れ条件・照合表・ハンク被覆を機械照合すること、初回不足は固定 HEAD・元の三表・残差・`補足済み回数: 0` を持つ `needs-reviewer` になること、fresh reviewer/G に交代しても 1 回補足後の残差は `review-incomplete` になり追加依頼が増えないこと、二周目以降の指摘の四分類を Gate Result に記録することの検査を足す
- [ ] 1.6 `plugins/dev-workflow/tests/test_codex_develop.py` と必要な既存テストに、review phase が gate-runner.md と pr-review-gate SKILL.md を正本として渡し、従来の Codex 雛形と needs-reviewer payload も同じレビュアー向け指示ブロックを参照すること、および本体が `review-incomplete` では fresh reviewer を起動しない契約の検査を足す
- [ ] 1.7 追加・変更したテストだけを実行し、現行実装に対して期待どおり Red になることを記録する

## 2. 一周目レビュアー契約を実装する

- [ ] 2.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の順 3 と一周目レビュアー向け `text` ブロックが参照する共通一覧契約を 1 か所に置く。`修正前 SHA: <40桁>`、repository-wide な `git grep -n <語の指定> <rev> -- .`、`| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |` を定め、追跡対象パスの除外・検索起点の限定を禁止する
- [ ] 2.2 同ブロックに、`変更点の一覧`・`照合表`・`ハンク被覆` の固定見出しと、`変更点の一覧 → 照合表 → ハンク被覆 → 自己点検 → 指摘` の順序を追加する。変更点ごとの受け入れ条件と検索語、diff 外を含む全ヒットの `一致` / `食い違い: <finding ID>`、全ハンクの finding ID / `問題なし`、保証範囲は一覧に載った項目までであることを追加し、順 3 の第 4 列だけは `直した` / `該当しない: <理由>` である差分を明記する
- [ ] 2.3 固定書式の `場所` 欄に、食い違いの指摘だけは変更箇所と diff 外の既存箇所の 2 か所を書ける但し書きを足し、`Codex が優先度付きの形で返したときの読み替え` に三表が出なかった場合の扱いを足す
- [ ] 2.4 `grep -c '変更点の一覧\|照合表\|ハンク被覆' plugins/dev-workflow/skills/pr-review-gate/SKILL.md` が 3 以上で、三語がすべて手順 2-1 のレビュアー向け `text` ブロック内にあることを確認する
- [ ] 2.5 `grep -n 'diff と重なる範囲で 10 行以内' plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の該当行に、食い違いの指摘は diff 外を含む 2 か所を書ける旨があることを確認する

## 3. G の機械照合と効果測定を実装する

- [ ] 3.1 `plugins/dev-workflow/scripts/` に、共通一覧契約と G が固定 SHA で再実行した grep のヒット集合を比較し、一致なら exit 0、差分があれば exit 1 と missing/extra の `file:line` を出すスクリプトを追加して 1.3・1.4 を Green にする。このスクリプトを一周目照合と順 3 の第 1 段で共用し、順 3 固有の修正後 HEAD に対する本文・件数・削除行の第 2 段は既存どおり別に維持する
- [ ] 3.2 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の一周目処理に、受け入れ条件から変更点 ID への被覆、照合スクリプトによる全ヒット集合、固定 diff の全ハンク被覆を指摘の仕分け前に照合する手順を追加する
- [ ] 3.3 同ファイルに、初回差分は固定 HEAD・元の三表・残差・`補足済み回数: 0` を持つ `needs-reviewer` で不足項目だけを補うよう return し、補足結果では `補足済み回数: 1` を維持し、それでも残れば差分を記録して terminal `review-incomplete` で return する分岐を追加する。どちらも合格処理へ進めない
- [ ] 3.4 Gate Result の return/PR コメント契約に、二周目以降の各指摘を `同じ文が複数か所`・`場合分けの漏れ`・`直したつもりで直っていない`・`直しで新しく入った` のいずれか 1 つに分類する欄を追加し、この分類が停止判定と仕分け順を変えないことを書く
- [ ] 3.5 `grep -c '同じ文が複数か所' plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` が 1 以上であることを確認する
- [ ] 3.6 `plugins/dev-workflow/skills/develop/SKILL.md` の G return 分岐へ `review-incomplete` を追加し、この status では reviewer を再起動せず `agent-review:pending` のまま残差を報告して工程を止める。本体が `needs-reviewer` で fresh reviewer を起こす場合は同じレビューの補足 payload をそのまま渡す

## 4. 全レビュー経路を揃えて実測する

- [ ] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` と gate-runner.md の needs-reviewer payload が、三表を含む SKILL.md 手順 2-1 のレビュアー向け指示ブロックを参照することを確認し、足りない参照だけを更新する（表の定義は再掲しない）
- [ ] 4.2 `plugins/dev-workflow/references/codex-develop.md` と `plugins/dev-workflow/scripts/codex-develop.py` の review phase が gate-runner.md と pr-review-gate SKILL.md を fresh reviewer に渡すことを確認する。補足目的では固定 HEAD・元の三表・残差・補足済み回数を渡し、fresh thread でも同じレビューの不足分だけを補い、`review-incomplete` では新しい review phase を開始しない契約を、テストが示す欠落箇所へ追加する
- [ ] 4.3 待ち方の正本と既存の不可条件に従い、レビュアー向け指示ブロックを渡した `codex exec` を 1 回実測し、三表が出たか、出なければ実際の出力形と欠けた表（実測不能なら実測した不可条件）を記録する
- [ ] 4.4 (3b) で 4.3 の実測結果を PR コメントへ投稿し、そのコメント URL を動作確認証拠に含める

## 5. 検証・仕様・版

- [ ] 5.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` と照合スクリプト用 bats を実行し、すべて exit 0 を確認する
- [ ] 5.2 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` を実行し、exit 0 を確認する
- [ ] 5.3 `bash scripts/test.sh` を実行し、`tests/injection-budget.bats` を含む全件が exit 0 になることを確認する
- [ ] 5.4 `openspec validate review-change-inventory --strict` と `openspec validate --specs --strict` を実行し、どちらも exit 0 になることを確認する
- [ ] 5.5 `origin/main` と open PR の version 変更を確認してから、`plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version を 1 つ上げ、`plugins/dev-workflow/CHANGELOG.md` に三表・機械照合・四分類を記録する
- [ ] 5.6 issue #355 の受け入れ条件 8 件が、tasks 2.4・2.5・1.3/3.1・4.3/4.4・5.1・5.3・5.4・3.4/3.5 のいずれかに対応していることを最終確認する
