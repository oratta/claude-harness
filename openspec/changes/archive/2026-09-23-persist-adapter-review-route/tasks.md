## 1. テスト（Red）

- [x] 1.1 `plugins/dev-workflow/tests/develop-adapter-review-routing.bats` に、`レビュー経路: adapter` で起動済みの同一 G は行の無い再開指示でも adapter 経路を保持することと、行の無い従来経路の既定は新しい G の起動指示（手渡しで起こされた後任を含む）だけに適用することを照合するテストを追加する
- [x] 1.2 同じ bats に、`plugins/dev-workflow/skills/develop/SKILL.md` と `plugins/dev-workflow/references/codex-develop.md` の対になる記述が、同一 G の行無し再開と新しい G の行無し起動を区別していることを照合するテストを追加する
- [x] 1.3 `bats plugins/dev-workflow/tests/develop-adapter-review-routing.bats` を実行し、新規テストが既存文書に対して失敗する Red を確認する

## 2. レビュー経路契約の更新（Green）

- [x] 2.1 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`「レビュー経路の判別」と従来経路の適用箇所を更新し、adapter で起動済みの同一 G は行の無い再開でも adapter を保持し、行無しを従来経路にするのは新しい G の起動指示（手渡しで起こされた後任を含む）だけだと明記する
- [x] 2.2 `plugins/dev-workflow/skills/develop/SKILL.md` の Role profile の選択節を同じ境界へ揃える。本体が起動・再開・手渡しのすべてに常に `レビュー経路: adapter` を書く責任は維持し、sticky 規則を行の省略許可として扱わない
- [x] 2.3 `plugins/dev-workflow/references/codex-develop.md`「品質と transport 差分」の G の規則を同じ境界へ揃え、fresh G の起動指示に行が無い場合だけ従来経路になると明記する
- [x] 2.4 `bats plugins/dev-workflow/tests/develop-adapter-review-routing.bats` を実行し、新規・既存テストがすべて通る Green を確認する

## 3. 仕上げ

- [x] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version を同じ新しい値へ上げる
- [x] 3.2 `bash scripts/test.sh` を全件フォアグラウンドで実行し、常時注入予算を含む全テストが exit 0 であることを確認する
- [x] 3.3 `openspec validate persist-adapter-review-route --strict` を実行し、exit 0 を確認する
