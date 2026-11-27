## Context

`orca worktree rm` は削除を非同期で進めることがあり、exit 0 で返った時点でも git のワークツリー一覧に path が残る。残っている間は、そのワークツリーがチェックアウトしているブランチを `git branch -D` で消せない。

## Goals / Non-Goals

**Goals:** ワークツリーが git から外れたら、ブランチが先端一致のときに消える。外れなくても reap は固まらず、今までの `branch-kept` に落ちる。

**Non-Goals:** `orca worktree rm` の再試行・`--force`、他の kept 理由の変更、reap 以外のコマンドの変更。

## Decisions

- **待つ条件は `git worktree list --porcelain` に `worktree <path>` の行が無いこと。** 出力を `worktree ` で始まる行だけ取り出して path と完全一致（`grep -qxF -- "worktree $path"`）で調べる。`git` が非 0 のときは「まだ残っている」と見なして待ちを続ける（安全側。上限後は branch-kept）。
- **上限と間隔は環境変数で上書きできる。** `EPIC_DISPATCH_REAP_DETACH_TIMEOUT`（秒、既定 30）と `EPIC_DISPATCH_REAP_DETACH_INTERVAL`（秒、既定 1）。数値でない値は既定に戻す。0 を指定すると待たない（1 回調べるだけ）。既存の `EPIC_DISPATCH_*` の流儀に合わせる。既定 30 秒は、#1038 の実例（rm の直後に失敗）を吸収するのに十分で、親が長く固まらない長さとして選ぶ。
- **待つのは、ブランチが残っていて先端が HEAD と一致するときだけ。** ブランチが無い・先端が違う子では待たない（待っても結果が変わらないため）。これで「先端が違えば待たずに消さない」が保たれる。
- **`sleep` は PATH 上の `sleep` を使う。** 既存のテストが `sleep` をスタブにしているのでそれに乗る。
- 待ちの途中経過は stderr にだけ出し、stdout は子ごとに 1 行のまま。

## Risks / Trade-offs

- 30 秒待っても Orca の削除が終わらない環境では、従来どおり `branch-kept` になる（悪化しない）。
- 待つ分、子 1 件あたり最大 30 秒 reap が長くなる。ブランチ削除が通る見込みのあるときだけ待つので、通常は 1 秒前後。
