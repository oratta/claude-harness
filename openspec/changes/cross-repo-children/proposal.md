## Why

エピックの子が親と別のリポジトリにある場合（例: flatmate のエピックに積んだ claude-harness の子）、今の `epic-dispatch.sh launch` はその子を `failed <child> other-repo` で返すだけで、ワークツリーを作れない。develop の SKILL.md も、子が親と同じリポジトリにある前提で書かれていて（`gh api repos/{owner}/{repo}/...` は親のリポジトリを指す）、別リポジトリの子の依存の読み方・子エピックの判定・コメントの書式・マージ待ちの手順・子の側の記録の置き場がどこにも書かれていない。flatmate #896 では、別リポジトリの子（claude-harness の #470）だけを人が開発用 clone に手でワークツリーを切って起動した。

この change は issue #1123 を 3 つに割った 2 つ目で、別リポジトリの子を `launch` に渡すとそのリポジトリにワークツリーができ、親が見張れるようにする。1 つ目（`epic-state-files`、PR #1148 でマージ済み）が、子を `<owner>/<repo>#<N>` で識別する記録と、記録だけで動く親の見張りを入れた。その design.md の Decision 11 に、別リポジトリの挙動 5 項目（依存と子エピックの判定・ワークツリーの作り先・書き込み権・PR とゲートとマージ・子の側）の決めた内容が置いてあるので、この change はそれを spec と SKILL.md に起こす。起動部品の境目（Decision 12）は 3 つ目の change の範囲で、ここでは扱わない。

## What Changes

- `launch` が、エピックと別のリポジトリの子（`<owner>/<repo>#<N>` で渡された子）のワークツリーを、子のリポジトリのローカル clone に作る。clone は (1) 親のワークツリーの clone（子がエピックと同じリポジトリのとき）→ (2) 環境変数 `EPIC_DISPATCH_CLONES` → (3) Orca に登録されたリポジトリ、の順に探し、候補ごとに origin が子のリポジトリを指すことを確かめる。見つからなければ自動で clone せず `failed <child> no-clone`、同じ段に 2 つ以上あれば `failed <child> ambiguous-clone`（どちらも記録も枠も使わない）
- ワークツリーを作る前に `gh api repos/<o>/<r> --jq .permissions.push` を読み、`true` でなければ `failed <child> no-push`、読めなければ `failed <child> permission-lookup-failed`（記録も枠も使わない）。fork から PR を出す経路は作らない
- 別リポジトリの子のワークツリーの起点は、`--base` / `EPIC_DISPATCH_BASE` があればそれ、無ければ子のリポジトリの既定ブランチ。子の起動の指示・`EPIC_DISPATCH_PARENT_EPIC`・注意書きのコメント・親から子への返事の頭は、別リポジトリのエピックの形（エピックの番号のあとにリポジトリを足す）にする
- `reap` の `gh pr list` と base の照会は、別リポジトリの子では子のリポジトリ（`-R <repo>`）と子のワークツリーの origin に向ける（同じリポジトリの子の呼び出しの形は変えない）。`stop-judge.sh` が別リポジトリの子を受けられるようにする
- develop の SKILL.md「エピックの扱い」に複数リポジトリの挙動を書く: 依存と子エピックの判定を子のリポジトリに対して読む、エピックの子の一覧の組み立て、コメント・完了報告の書式、マージ待ちの子の PR を子のリポジトリで扱う手順、子の側が親エピックに残す記録の置き場、clone・書き込み権の `failed` を主に報告すること
- `dev-workflow-epic-state` の「launch は別のリポジトリの子を作らない」を、別リポジトリの子を作る要件に置き換える

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-epic-state`: `launch` の別リポジトリの子の扱い（`other-repo` で返す要件を、clone・書き込み権・起点・指示の書式を定める要件に置き換える）と、`reap` の別リポジトリの子の照会先
- `dev-workflow-develop`: SKILL.md「エピックの扱い」の複数リポジトリの挙動、`epic-dispatch.sh` と `stop-judge.sh` の別リポジトリの子の受け方

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`launch` の clone の探索・書き込み権・起点・指示とコメントの書式、`reap` の照会先、`reply` の頭）
- `plugins/dev-workflow/scripts/stop-judge.sh`（子の引数に `<owner>/<repo>#<N>` を受ける）
- `plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/tests/develop-skill.bats`
- `plugins/dev-workflow/skills/develop/SKILL.md`（エピックの扱い。経路の決め方・子エピックの判定・手順 1〜8・マージ待ちの子・nested を受けたセッション・完了条件）、`plugins/dev-workflow/references/ci-watch.md`（親から届く返事の頭の照合に、番号のあとにリポジトリが付く形を足す）
- `plugins/dev-workflow/changes/1123.md`（変更の記録に追記）
- 依存: change 1（`epic-state-files`）はマージ済み。change 3（起動部品の差し替え）はこの change のあとに回す
