## Why

エピックの親が主に出す報告（止まった子の報告・待ちを終える報告・`error` や `timeout` の報告）には、主が自分の操作を一目で読み取れる行が無い。操作が経緯の中に埋もれ、主から「各やり取りで具体的にこっちが何をすればいいかがわからない」と言われた（2026-10-18、エピック #1038）。返事の場所（親のタブ）が分からず主が聞き返して、親経由のリスク許容の確認が `not-direct` になり、報告を出し直した。子の完了報告には 1 行目 `主がこのセッションで次にすること:` があるが、親の報告には同じものが無い。

## What Changes

- develop SKILL.md の「エピックの扱い」→「回し方」の Orca 経路に、親が主に出す報告の 1 行目を `主がすること: なし` か `主がすること: <どの画面・入力欄で> <何を打つ・押す>` にする規定を足す
- 手順 8（止まった子の報告）に、親経由のリスク許容の依頼は 1 行目に「親のタブで打つ」と「この報告の直後に別の発言を挟まない」を書く規定を足す
- 子の完了報告の 1 行目 `主がこのセッションで次にすること:`（子のタブを開いた主向け）は変えない。親の報告は `主がすること:` で書き分ける
- 規定を書く SKILL.md は常時注入の対象外なので、`tests/injection-budget.txt` は動かさない

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `dev-workflow-develop`: 親が主に出す報告の 1 行目の書式を要件として足す

## Impact

- plugins/dev-workflow/skills/develop/SKILL.md
- plugins/dev-workflow/tests/epic-dispatch.bats（手順の文面を検査するテストを足す）
- openspec/specs/dev-workflow-develop/spec.md（archive 時に反映）
