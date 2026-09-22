## 1. テスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/` に bats を足す: `gate-runner.md` に `レビュー経路: adapter` / `レビュー経路: 従来` の判別規則・行が無いときは従来経路とする規則・adapter 経路では full でも Codex・companion・レビュアーを呼ばず `needs-reviewer` を返す規則・payload の判定 `full（adapter 経路）`・phase `review` のレビュアーには適用しない限定がある
- [ ] 1.2 同じ bats に: `gate-runner.md` のレビュー実行者の表で、従来経路の full が今までどおり G の Bash から Codex を直接呼ぶ記述を保っている
- [ ] 1.3 同じ bats に: `SKILL.md` の (4) に、adapter 経路の `needs-reviewer` で `codex-develop.py request --phase review` による選び直し・選択（構成・reason・両 provider の余裕・`fetched_at`）の dispatch 記録・記録してからレビュアーを起動する順序が書かれ、G の起動・再開指示に `レビュー経路:` を必ず書くことが (4) と Role profile の選択節の両方にある
- [ ] 1.4 同じ bats に: `codex-develop.md` の G の規則が `レビュー経路: adapter` の明示に触れている
- [ ] 1.5 bats を実行して Red を確認する

## 2. 指示書の変更（Green）

- [ ] 2.1 `gate-runner.md` に「レビュー経路の判別」の節を足し、レビュー実行者の表の前で adapter 経路の規則を書く（G として起動されたときに限る）。needs-reviewer の payload に判定 `full（adapter 経路）` を足し、「レビュー実行者:」コメントの adapter 経路の書き方を足す
- [ ] 2.2 `SKILL.md` の Role profile の選択節に、G の起動・再開指示へ `レビュー経路:` を書く責任を足す
- [ ] 2.3 `SKILL.md` の (4) の `needs-reviewer` 行を、従来経路と adapter 経路に分けて書く
- [ ] 2.4 `codex-develop.md`「品質と transport 差分」の G の項に、本体が G の起動・再開指示に `レビュー経路: adapter` を書くことを足す
- [ ] 2.5 bats を実行して Green を確認する

## 3. 仕上げ

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version を 2.13.23 から上げる
- [ ] 3.2 `bash scripts/test.sh` を全件フォアグラウンドで実行し exit 0 を確認する（常時注入の予算テストを含む）
- [ ] 3.3 `openspec validate develop-adapter-review-routing --strict` が通る
