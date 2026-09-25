## Context

`epic-dispatch.sh launch`（#420、#458）は子ごとに `orca worktree create --agent claude --json` でワークツリーと Claude Code の端末を同時に作り、JSON 出力のハンドルに `orca terminal wait --for tui-idle` → `orca terminal send` で最初の指示を送っている。`--agent claude` のとき Orca は設定（`orca-data.json` の `settings.agentDefaultArgs.claude`、この環境では `--dangerously-skip-permissions`）を付けて `claude` を起動するが、モデルは指定しない。Claude Code の既定モデル（`~/.claude/settings.json` の `model`）がそのまま使われる。

Orca 1.x の CLI（2026-09-25 時点）で確かめた事実:

- `orca worktree create` のオプションは `--agent <id>` と `--prompt` だけで、モデルや起動コマンドを指定する口は無い。`--agent` を付けないとワークツリーだけができ、JSON 出力は `result.worktree.path` を持ち、`result.startupTerminal` と `result.agentTerminalHandle` は null
- `orca terminal create --worktree <selector> --command <text> --json` は、指定したワークツリーに端末を作り、ログインシェルに `<text>` を打ち込む。help は「既存のワークツリーで新しいエージェントを起こすときはこれを使う」と案内している。JSON 出力のハンドルは `result.terminal.handle`
- 実機確認（使い捨てのワークツリー `w475-modeltest` で実施し、確認後に `orca worktree rm` で消した）: `~/.claude/settings.json` の `model` が `opus[1m]` の環境で `orca terminal create --command "claude --model haiku --dangerously-skip-permissions"` を実行すると、Orca はその端末を `agentIdentity: claude` と認識し、`terminal create` 直後の `orca terminal wait --for tui-idle` は Claude Code の画面が出るまで待って（約 2 秒）満たされた。続く `orca terminal send --enter --wait-submit 30` の `stages` は `["input_accepted","turn_started"]` で、transcript の `message.model` は `claude-haiku-4-5-20251001` だった

## Goals / Non-Goals

**Goals:**

- `launch` で起動した子セッションが、Claude Code の既定モデルにかかわらず、指定したモデルで動く
- 既定のモデルを `opus` とし、環境変数で変えられるようにする
- #458 で入れた「起動完了を待ってから最初の指示を送り、`turn_started` を見て `launched` を出す」流れはそのまま使う

**Non-Goals:**

- メインセッション（ユーザーが起動したセッション・エピックの親セッション）のモデル。起動時にユーザーが選ぶので、ハーネスからは強制しない
- サブエージェント方式で起こす W / R1 / G のモデル（develop の SKILL.md「モデル」の役割表が決める）
- Orca の設定ファイル（`orca-data.json`）の読み書き

## Decisions

### 子セッションを `orca terminal create --command` で起動する

`orca worktree create` を `--agent` なしで呼んでワークツリーだけを作り、JSON 出力の `result.worktree.path` を `path:` セレクタにして `orca terminal create --worktree path:<子> --command "claude --model <model> --dangerously-skip-permissions" --json` を呼ぶ。以降の wait / send は `result.terminal.handle` に対して行う。

比べた案:

- **`--agent claude` のまま、最初の指示の前に `/model <model>` を送る**: `/model` の変更が Claude Code のユーザー設定に保存されると、ユーザーのメインセッションの既定まで書き換わる。指示の送信も 2 回になり、#458 の「1 回送って `turn_started` を見る」判定が複雑になる。採らない
- **Orca の agent 設定（`agentCmdOverrides.claude` や `agentDefaultEnv.claude` に `ANTHROPIC_MODEL`）で渡す**: Orca 全体の設定で、ユーザーが Orca から手で起動するメインセッションにも効いてしまう。CLI から起動ごとに変える口も無い。採らない
- **環境変数 `ANTHROPIC_MODEL` を `launch` の環境に置く**: 端末は Orca アプリがログインシェルで起動するので、`launch` を呼んだプロセスの環境は子に届かない。`--command "ANTHROPIC_MODEL=... claude"` と書けば届くが、`--model` のほうが Claude Code の設定より優先することが明確で読みやすい。採らない

`terminal create --command` は Orca の help が「既存のワークツリーで新しいエージェントを起こす方法」として案内している経路で、実機で `agentIdentity`・`tui-idle`・`turn_started` がすべて `--agent claude` のときと同じに動くことを確かめた。

### 起動コマンドに `--dangerously-skip-permissions` を明示する

`--agent claude` をやめると Orca の `agentDefaultArgs.claude` が付かなくなる。今の子セッションは `--dangerously-skip-permissions` で動いており（spec の「エピックの条件・作り方・回し方・完了条件を規定する」も SKILL.md もそう書いている）、付けないと子が許可の確認画面で止まる。Orca の設定を読みにいくと設定ファイルの形に依存するので、スクリプトが同じ引数を明示する。

### モデルの既定は `opus`、環境変数 `EPIC_DISPATCH_MODEL` で変える

子セッションは `/develop` の 1 ループを丸ごと回すオーケストレーターで、メインセッションと同じ扱いにする。公式の方針（2026-09-22 以降「たいていの仕事は Opus 5.5 から始める」）に合わせて `opus` を既定にする。変更の口は既存の `EPIC_DISPATCH_BASE` などと同じく環境変数にする。`launch` のフラグは足さない（本体が SKILL.md の手順どおりに呼ぶスクリプトで、子ごとにモデルを変える要求は無い）。値は `claude --model` にそのまま渡すので、エイリアス（`opus` / `sonnet`）でも完全な ID でも `opus[1m]` でもよい。端末ではログインシェル（zsh）に打ち込まれるので、`[1m]` がグロブとして解釈されないよう単一引用符で囲む（既存の `shq` を使う）。空文字は使い方を出して exit 1（子を 1 件も作らない）。

### 端末を作れなかった子は `failed` にし、端末を作り直すコマンドを出す

ワークツリーはできたが `terminal create` が失敗した・パスやハンドルが取れなかった子は `failed <N>` にする。ワークツリーが残るので再実行では `skipped` になり端末が作られない。そこで、パスが取れていれば `orca terminal create --worktree path:<子> --command ... --json` のコマンドを stderr に出す（#458 の送り直しのコマンドと同じ扱い）。

## Risks / Trade-offs

- [Orca の設定 `agentDefaultArgs` / `agentCmdOverrides` を変えても子セッションには効かなくなる] → SKILL.md に「子の起動コマンドは `epic-dispatch.sh` が決める」と書く。起動引数を変えたいときはスクリプトを直す
- [`terminal create` の JSON の形（`result.terminal.handle`）と `worktree create` の `result.worktree.path` は 2026-09-25 の実機の形を信じる] → 読めないときは `failed` として表に出すだけで、形の変化の検知は範囲外（#458 と同じ扱い）
- [`--command` の文字列はログインシェルに打ち込まれるので、ユーザーのシェル設定（`claude` のエイリアスなど）の影響を受ける] → `--agent claude` のときも Orca はログインシェルで `claude` を起動しており、条件は変わらない
