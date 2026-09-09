## Context

develop の本体は W / G を SendMessage で再開する前に `scripts/subagent-context.sh <名前>` を実行し、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150,000）を超えていたら再開せず手渡しする。この経路は「再開の瞬間」しか見ないため、1 回の起動の中で膨らむぶんは素通りする。さらに `isolation: "worktree"` で起こしたサブエージェントは名前 glob に引っかからず（#243）、`exit 1`（＝測れないので止めない）になるので上限確認そのものが効いていない。

このリポジトリは Claude Code プラグインの配布元で、`hooks/hooks.json` は install 先の全セッションで発火する層間契約であり、聖域パスにあたる。fail-open（判定できないときは止めない）を崩すと、全プラグイン利用者のツール実行が止まる。

### 着手前実験で判明した事実（設計の前提が 1 つ覆った）

issue #261 の手順 0 は「hook が stdin で受け取る `transcript_path` がサブエージェント自身のトランスクリプトを指す」ことを前提にしていた。実験の結果、**指さない**。

1. `~/.claude/projects/<slug>/<親セッションID>/subagents/agent-<agentId>.jsonl` にサブエージェントのトランスクリプトが置かれる。`isolation: "worktree"` でも置き場所は同じで、違いは**ファイル名だけ**（名前つき非隔離は `agent-a<名前>-<hash>.jsonl`、worktree 隔離は `agent-a<16 桁 hex>.jsonl` で名前を含まない）。これが #243 の直接原因。
2. worktree 隔離のサブエージェントの中で `CLAUDE_CODE_SESSION_ID` は**親セッションの UUID**（実測: 自分のトランスクリプトが `…/bf3fed15-…/subagents/agent-ab9e20b3cde9ae07f.jsonl` であるのに対し、環境変数は `bf3fed15-…`）。サブエージェントは独立したセッション ID を持たない。
3. Claude Code 本体（2.1.266）の hook payload 構築は、セッションから `session_id` と `transcript_path` を作り、`transcript_path` は「セッション ID のトランスクリプト」しか返さない（`subagents/agent-*.jsonl` を返す分岐が存在しない）。`SubagentStop` だけが `agent_transcript_path`（＝ agentId から作る `subagents/agent-<id>.jsonl`）を**別フィールドとして追加**しており、これは `transcript_path` が親のものであることの裏返しの証拠。
4. hook 入力スキーマの `agent_id` の説明は「サブエージェントの中から hook が発火したときだけ存在する。メインスレッドでは `--agent` セッションでも存在しない。サブエージェント呼び出しの判別には（`agent_type` ではなく）このフィールドを使え」。つまり **`agent_id` が「今サブエージェントの中か」の唯一の正しい判定材料**。

したがって計測対象は `dirname(transcript_path) + "/" + session_id + "/subagents/agent-" + agent_id + ".jsonl"` として導出する。

なお、この実験は当初「一時的な hook を仕込んだ `claude -p` の入れ子セッション」で行おうとしたが、worktree 隔離エージェントのガードが `claude` の実行を拒否するため実行できず、（a）ファイル配置と環境変数の実測、（b）配布バイナリの hook payload 構築コードと入力スキーマ本文の読み取り、の 2 つで確定させた。

## Goals / Non-Goals

**Goals:**
- 1 起動の途中でコンテキスト量を測り、`DEV_WORKFLOW_CONTEXT_CAP` 超で「締めて return せよ」を本人に届ける
- `DEV_WORKFLOW_CONTEXT_HARD_CAP` 超で編集系ツールを拒否し、commit と return だけができる状態にする
- `isolation: "worktree"` のサブエージェントでも同じように効く（#243 の解消）
- 計測ロジックを hook と `subagent-context.sh` で 1 本に保つ
- 上限内では完全に無音で、hook 1 回あたりのコストを無視できる範囲に抑える

**Non-Goals:**
- 上限 `150,000` そのものの見直し（エピック #257 で据え置きと判断済み。既定値の妥当性は #259 の監視で見る）
- 役割（W / R1 / G / decider）ごとの閾値の出し分け（全サブエージェント一律。R1 / decider は短いので影響しない）
- 「return を強制する」機能（hook 仕様にそのボタンは無い。ツールを拒否された結果としてターンが終わる）
- メインスレッド（親セッション）の計測・停止
- `subagent-context.sh` の名前 glob の廃止（fallback として残す）

## Decisions

### 1. 計測対象は `agent_id` から導出する（`transcript_path` をそのまま使わない）

`transcript_path` は親セッションのトランスクリプトなので、そのまま測ると「親の消費」で全サブエージェントを止めてしまう。`transcript_path` は**ディレクトリの起点**としてだけ使い、`session_id` と `agent_id` を組んで `<projects>/<slug>/<session_id>/subagents/agent-<agent_id>.jsonl` を作る。

- 代案 A（`transcript_path` をそのまま測る）: 実験の結果、意味が違うので却下。
- 代案 B（`~/.claude/projects` を名前 glob で探す。#243 の当初案）: worktree 隔離ではファイル名に名前が入らないので原理的に直らない。エピックの判断どおり採らない。
- 代案 C（`agent-<id>.meta.json` の `name` で引く）: 実験中に、各トランスクリプトの隣に `{"agentType","worktreePath","spawnedWithWorktree","description","name","toolUseId","spawnDepth","model"}` を持つ `.meta.json` があることを確認した。hook 側は `agent_id` を直接持っているので不要だが、**`subagent-context.sh` の名前解決の fallback としては glob より確実**。今回は hook 経路を主とし、meta.json 経由の名前解決は後続（#243 の残りが必要になったとき）に回す。
- 入れ子のサブエージェント（`spawnDepth` ≥ 2）では `subagents/` の下にさらに階層が入りうるため、直接パスが無ければ `<session_id>/subagents/` 以下を再帰的に `agent-<agent_id>.jsonl` で探す fallback を 1 段だけ持つ。

### 2. 2 段の閾値と、拒否するツールの範囲

通知 150,000 / 強制停止 220,000。差の 70,000 は、編集の途中で切られて壊れた木を次の担当に渡さないための余裕。強制停止では `Edit` / `Write` / `NotebookEdit` を拒否し、`Bash` は `git status` / `git diff` / `git add` / `git commit` / `git push` だけ通す。**読み取り系（Read / Grep / Glob）と return は拒否しない**（自分の成果を列挙して return するには読めた方がよい）。

- 代案（PreToolUse で全ツールを拒否）: commit できずに未コミットの差分を抱えたまま落ちるので却下。
- Bash の判定は「先頭コマンドが許可リストに一致するか」で行い、判定できない複合コマンド（パイプ・`&&`・サブシェル）は**拒否側**に倒す（強制停止は既に異常状態で、通す方が危ない）。

### 3. fail-open を守る境界

`python3` が無い・stdin が読めない・`agent_id` が無い・トランスクリプトが無い・usage が読めない・閾値の環境変数が数値でない、のいずれでも**何もせず exit 0**。止めてよいのは「測れて、閾値を超えていると分かったとき」だけ。全解除の環境変数（`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`）も置く（`agent-model-guard.sh` の `DEV_WORKFLOW_MODEL_GUARD=off` と同じ形）。

### 4. 末尾だけ読む

PostToolUse は全ツール呼び出しで走るので、トランスクリプト全体を JSON パースしてはいけない。ファイル末尾から固定バイト（例: 256KB）だけ `seek` して読み、最後の `assistant` レコードの `usage` を拾う。見つからなければ fail-open。`subagent-context.sh` の既存の「全行走査」は本体の再開前チェック用に残し、共通化するのは「usage レコードから合算する」部分にとどめる。

- 代案（全部読む）: 5MB のトランスクリプトで毎ツール数百 ms かかるので却下。要件は「5MB でも 100ms 未満」。

### 5. 通知は PostToolUse、停止は PreToolUse

PostToolUse の出力は Claude に見える追加コンテキストとして届き、ツールは既に実行済みなので副作用がない。PreToolUse は `permissionDecision: deny` で実行前に止められる。役割を分けることで、通知が誤って作業を止めることがない。

### 6. hooks.json の変更は聖域パス・層間契約として扱う

`hooks/hooks.json` は install 先の全セッションで発火する。matcher を広く取る（PostToolUse は全ツール）ため、事故ると全ユーザーのツール実行が遅く・止まる。したがって（a）fail-open を全経路で守る、（b）閾値・全解除を環境変数で上書きできる、（c）テストを hook スクリプト単体（stdin → stdout / exit code）で書く、の 3 点を要件に落とす。

### 7. 手順書への追記は最後の commit に分ける

`skills/develop/` 配下の 5 本は PR #253 が同時に書き換えている。コード（hook・`--file`・テスト）は先に進め、手順書への追記だけ #253 マージ後に最後の commit で載せる。この順序は tasks.md に明示する。

## Risks / Trade-offs

- [PostToolUse が全ツールで走るので、ツールごとに python3 の起動コストが乗る] → 末尾読みに限定し、5MB で 100ms 未満をテストで担保。それでも重ければ matcher を編集系＋Bash に絞る余地を残す（要件は「全ツール」だが、閾値変数と同じく環境変数で狭められる形にはしない — 変えるなら仕様変更として扱う）
- [閾値を超えた状態が続くと、以降すべてのツール呼び出しで通知が出て、その通知自体がコンテキストを食う] → 出力は 1 行程度に抑える。同一起動での重複抑制は状態を持つことになるので今回はやらない（#259 の監視で頻度を見てから）
- [強制停止で Bash を絞ると、テスト実行やビルドの途中で止まって「壊れた作業ツリー」が残りうる] → 通知と停止の間に 70,000 の余裕を置き、通知で自発的に締めさせるのが主。停止は最後の安全網
- [`transcript_path` / `agent_id` の意味は Claude Code の内部仕様で、将来変わりうる] → 変わったら「導出したパスが存在しない」に落ち、fail-open で無害に無効化される。テストは実ファイル配置を固定的に作って検証する
- [PR #253 とのマージ順が崩れると手順書がコンフリクトする] → tasks.md で最後の commit に分離し、順序を受け入れ条件に含める

## Migration Plan

1. hook スクリプトとテストを先に入れる（`hooks.json` 登録込み）。既定閾値では既存の動きは変わらない（上限内は無音）
2. 小さい閾値（`DEV_WORKFLOW_CONTEXT_CAP=20000` 等）を環境変数で与えて、名前付きサブエージェントと `isolation: "worktree"` のサブエージェントの両方で通知・停止が出ることをトランスクリプトで確認し、証拠を PR 本文に貼る
3. #253 マージ後に手順書 5 本への追記を最後の commit で載せる
4. ロールバック: `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`（即時・全解除）、または `hooks.json` から 2 エントリを外す

## Open Questions

- 強制停止の既定値 220,000 は #257 の案のまま採る。実データでの妥当性は #259 の監視結果を見て見直す
- 同一起動での通知の重複抑制（1 回だけ出す）が要るかは、#259 の監視で頻度を見てから決める
