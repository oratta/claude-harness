## Context

`--apply` は設定ファイルを書くが、git の無視対象にしないため、書いた直後から worktree が dirty に見える。`reap` は porcelain が空であることを片付けの条件にしている。

## Decisions

- **除外先は `$(git rev-parse --git-common-dir)/info/exclude`。** 却下案: (a) このリポジトリの `.gitignore` に足す: develop は他のリポジトリでも動き、そこでは効かない。作業リポジトリの追跡ファイルも書き換えてしまう。(b) `reap` 側で `.claude/settings.local.json` だけの dirty を無視する: dirty 判定の例外が増え、reap の規則を複雑にする。common dir の exclude は同じリポジトリの全 worktree に効き、コミットに載らない。
- **exclude を先に書き、設定ファイルをあとに書く。** 設定ファイルが現れた時点で既に無視されているようにするため。ただし入力の検証と JSON の直列化が済んだあと（今の「拒否した入力は新しい path を作らない」の位置）に行う。
- **足すのは `--apply` が設定ファイルを書く経路だけ。** `--check` と、false 済みで何も書かない経路は exclude も触らない（「false 済みは無変更」を保つ）。
- **重複判定は行の完全一致。** 末尾改行が無い既存ファイルには改行を足してから追記する。`info` ディレクトリが無ければ作る。
- **追跡済みのファイルは特別扱いしない。** exclude は追跡済みファイルに効かないので、追跡は変わらない。
- **exclude を書けないときは exit 1 で、設定ファイルも書かない。** 先に書く順序なので、設定だけ作って dirty になる状態を残さない。

## Risks

- 既に false のファイルが除外されていない worktree は、`--apply` が呼ばれない（check が exit 0）ので直らない。今回は対象外（新しい develop 開始のみ直す）。
