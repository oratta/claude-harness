## 1. テスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/` に bats を足す: `gate-runner.md` に、`レビュー経路: adapter` / `レビュー経路: 従来` の判別規則・行が無いときは従来経路とする規則・`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成を指し従来モードの表は `従来`（または行が無い）ときだけ適用する 1 文・adapter 経路では full でも Codex・companion・レビュアーを呼ばず `needs-reviewer` を返す規則・payload の判定 `full（adapter 経路）`・証拠欄（選んだ経路・実行コマンド・終了コード・出力の要点・実待ち時間）の値 `未実行（adapter 経路）`・phase `review` のレビュアーには適用しない限定がある
- [ ] 1.2 同じ bats に: `gate-runner.md` のレビュー実行者の表で、従来経路の full が今までどおり G の Bash から Codex を直接呼ぶ記述を保っている
- [ ] 1.3 同じ bats に: `SKILL.md` の (4) と Role profile の選択節の両方に、G の起動・再開・手渡しの指示へ起動形を問わず**常に** `レビュー経路: adapter` を書くこと（条件付きでない文言）と、develop の本体は `レビュー経路: 従来` を書かないことがある。(4) に、adapter 経路の `needs-reviewer` で `codex-develop.py request --phase review` による選び直し・選択（構成・reason・両 provider の余裕・`fetched_at`）の dispatch 記録・記録してからレビュアーを起動する順序・要約と executor / model・dispatch 記録の URL を G に渡すこと・渡し方が Claude の G（SendMessage で再開）と Codex の G（新しい phase `gate`）で分かれることが書かれている
- [ ] 1.4 同じ bats に: `codex-develop.md` の G の規則が `レビュー経路: adapter` の明示に触れている
- [ ] 1.5 同じ bats に: `gate-runner.md` と `pr-review-gate/SKILL.md` の両方に「レビュー実行者:」の adapter 経路の形 `（adapter 経路・dispatch 記録:` がある
- [ ] 1.6 bats を実行して Red を確認する

## 2. 指示書の変更（Green）

- [ ] 2.1 `gate-runner.md` に「レビュー経路の判別」の節を足し、レビュー実行者の表の前で adapter 経路の規則を書く（G として起動されたときに限る。用語の 1 文を含む）。needs-reviewer の payload に判定 `full（adapter 経路）` と証拠欄の値 `未実行（adapter 経路）` を足し、「レビュー実行者:」コメントの adapter 経路の形 `<executor>/<model>（adapter 経路・dispatch 記録: <URL>）` を足す。あわせて `pr-review-gate/SKILL.md` の「レビュー実行者:」の書き分けと PR コメント雛形に同じ 1 形を足す
- [ ] 2.2 `SKILL.md` の Role profile の選択節に、(4) で G の起動・再開・手渡しの指示へ起動形を問わず常に `レビュー経路: adapter` を書く責任を足す。Codex の G では request の instructions（`--input` の指示ファイル）にも書くことを含める。develop の本体は `レビュー経路: 従来` を書かないことも書く
- [ ] 2.3 `SKILL.md` の (4) を直す: G の起動指示に常に `レビュー経路: adapter` を書くことを足し、`needs-reviewer` 行を adapter 経路の手順（選び直し → dispatch 記録 → レビュアー起動 → 要約と executor / model・dispatch 記録の URL を G に渡す。渡し方は Claude の G と Codex の G で分けて参照先を書く）に書き換える。develop 本体以外から G を起こす従来経路の手順は gate-runner.md の既存記述のまま残す
- [ ] 2.4 `codex-develop.md`「品質と transport 差分」の G の項に、本体が G の起動・再開指示（request の instructions を含む）に `レビュー経路: adapter` を書くことを足す
- [ ] 2.5 bats を実行して Green を確認する

## 3. 仕上げ

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version を 2.13.23 から上げる
- [ ] 3.2 `bash scripts/test.sh` を全件フォアグラウンドで実行し exit 0 を確認する（常時注入の予算テストを含む）
- [ ] 3.3 `openspec validate develop-adapter-review-routing --strict` が通る
