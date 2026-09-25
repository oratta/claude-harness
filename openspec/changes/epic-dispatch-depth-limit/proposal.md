# エピックの並列起動を 1 段で止める

## Why

`epic-dispatch.sh launch` で並列起動された子セッションは、自分の issue がエピックだと、親と同じ手順で孫を展開する。子ワークツリーは Orca 管理なので `route` は条件がそろえば `orca` を返し、孫のワークツリーとセッションがさらに作られる。深さを数える仕組みも、子であることをスクリプトが知る仕組みも無いので、展開はエピックの入れ子が尽きるまで続き、セッション数と使用枠が一気に増えて、どのセッションが何を待っているか追えなくなる（確認結果は #460 のコメント）。親の `wait` は子エピックが閉じるまで待ち続け、親の完了報告に「子がエピックだった」ことが載る経路も無い。

## What Changes

- `launch` は子セッションの起動コマンドの前に環境変数 `EPIC_DISPATCH_PARENT_EPIC=<エピック番号>` を置く（`EPIC_DISPATCH_PARENT_EPIC=<epic> <cmd> --model '<model>'`）。子セッションとその中で動く Bash・サブエージェントにこの値が引き継がれる
- `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では、`route` は子の件数や `orca` の有無によらず `nested` の 1 行を出して exit 0 で終わり、`launch` は `orca` も `git` も呼ばずに exit 1 で終わる（子ワークツリーを作らない）
- develop の SKILL.md「エピックの扱い」: 親は `route` / `launch` に渡す前に、依存の解けた子のうちエピックであるもの（sub-issue を持つもの）を外し、エピックに `後で別に起動するエピック: #N` とコメントする。`route` が `nested` を返したセッション（並列起動された子がエピックだった場合）は展開せず、親エピックと自分の issue に同じ行をコメントして止まる。親は `timeout` の確認でこの行を見つけたらその子を待つ対象から外す。親の完了報告に `後で別に起動するエピック:` の番号を載せる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: エピックの展開を 1 段で止める要件を足す（`epic-dispatch.sh` の `EPIC_DISPATCH_PARENT_EPIC` の受け渡しと `route` の `nested`・`launch` の拒否、SKILL.md の子エピックの扱いと親の完了報告）。既存の 2 要件（「エピックの条件・作り方・回し方・完了条件を規定する」「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」）は書き換えず、ADDED の要件として足す（同じ 2 要件を並行する子 #429 #431〜#434 も触るため）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_route`・`cmd_launch` の冒頭と `agent_cmd` の組み立て、先頭コメント）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（route / launch / SKILL.md のテストを足す）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「エピックの扱い」の回し方と完了条件）
- `plugins/dev-workflow/changes/460.md`（変更記録）
- `wait` は変えない（#431 が触るため）
