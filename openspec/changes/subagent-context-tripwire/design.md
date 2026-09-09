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

なお、この実験は当初「一時的な hook を仕込んだ `claude -p` の入れ子セッション」で行おうとしたが、worktree 隔離エージェントのガードが `claude` の実行を拒否するため実行できず、（a）ファイル配置と環境変数の実測、（b）配布バイナリの hook payload 構築コードと入力スキーマ本文の読み取り、の 2 つで確定させた。この「隔離エージェントからは `claude` を起動できない」制約は実装後の実地確認にもそのまま効く（Decision 9）。

## Goals / Non-Goals

**Goals:**
- 1 起動の途中でコンテキスト量を測り、`DEV_WORKFLOW_CONTEXT_CAP` 超で「締めて return せよ」を**モデルに届く経路で**本人に届ける
- `DEV_WORKFLOW_CONTEXT_HARD_CAP` 超で編集系ツールを拒否し、commit と return だけができる状態にする
- `isolation: "worktree"` のサブエージェントでも同じように効く（#243 の解消）
- 計測の式を spec の要件として 1 つに定める（実装は 2 本のスクリプトが各自持つ）
- 上限内では完全に無音で、hook 1 回あたりのコストを無視できる範囲に抑える

**Non-Goals:**
- 上限 `150,000` そのものの見直し（エピック #257 で据え置きと判断済み。既定値の妥当性は #259 の監視で見る）
- 役割（W / R1 / G / decider）ごとの閾値の出し分け（全サブエージェント一律。R1 / decider は短いので影響しない）
- 「return を強制する」機能（hook 仕様にそのボタンは無い。ツールを拒否された結果としてターンが終わる）
- メインスレッド（親セッション）の計測・停止
- `subagent-context.sh` の名前 glob の廃止（fallback として残す）
- 計測ロジックを共有ファイルに抽出すること（Decision 4）

## Decisions

### 1. 計測対象は `agent_id` から導出する（`transcript_path` をそのまま使わない）

`transcript_path` は親セッションのトランスクリプトなので、そのまま測ると「親の消費」で全サブエージェントを止めてしまう。`transcript_path` は**ディレクトリの起点**としてだけ使い、`session_id` と `agent_id` を組んで `<projects>/<slug>/<session_id>/subagents/agent-<agent_id>.jsonl` を作る。

- 代案 A（`transcript_path` をそのまま測る）: 実験の結果、意味が違うので却下。
- 代案 B（`~/.claude/projects` を名前 glob で探す。#243 の当初案）: worktree 隔離ではファイル名に名前が入らないので原理的に直らない。エピックの判断どおり採らない。
- 代案 C（`agent-<id>.meta.json` の `name` で引く）: 実験中に、各トランスクリプトの隣に `{"agentType","worktreePath","spawnedWithWorktree","description","name","toolUseId","spawnDepth","model"}` を持つ `.meta.json` があることを確認した。hook 側は `agent_id` を直接持っているので不要だが、**`subagent-context.sh` の名前解決の fallback としては glob より確実**。今回は hook 経路を主とし、meta.json 経由の名前解決は後続（#243 の残りが必要になったとき）に回す。

### 2. 直接パスが無いときの探索は深さ 3 段・上限つき

入れ子のサブエージェント（`spawnDepth` ≥ 2）では `subagents/` の下にさらに階層が入る。配布バイナリ 2.1.266 の読み取り側のパス検証は `subagents/` の下に**任意段数**のサブディレクトリを許す（パス分解の中間セグメントが長さ 0 以上の配列）ため、「1 段だけ」では 2 段以上を取りこぼす。

- 深さ **3 段**まで（`subagents/` 直下を 1 段目と数える）を探索する。任意段数を許さないのは、探索が**毎ツール呼び出しのコスト**になるため。
- あわせて走査の上限（例: 走査するディレクトリエントリ 200 件、または探索に費やす時間 20ms）を要件に置き、上限に達したら探索を打ち切って fail-open（無音）にする。
- 4 段以上に置かれたトランスクリプトは測れないが、fail-open なので害は「その 1 体で途中計測が効かない」だけに留まる。

### 3. 2 段の閾値と、拒否するツールの範囲

通知 150,000 / 強制停止 220,000。差の 70,000 は、編集の途中で切られて壊れた木を次の担当に渡さないための余裕。強制停止では `Edit` / `Write` / `NotebookEdit` を拒否し、`Bash` は許可した git サブコマンドだけ通す。**読み取り系（Read / Grep / Glob）と return は拒否しない**（自分の成果を列挙して return するには読めた方がよい）。

Bash の許可判定は**先頭一致ではなく `git` のグローバルオプションを読み飛ばした形**にする。「先頭トークンが `git` で、`-C <path>` / `-c <k=v>` を読み飛ばした次のトークンが `status` / `diff` / `add` / `commit` / `push` のいずれか」。worktree 作業では `git -C <worktree のパス> commit` を常用するので、素朴な先頭一致だと commit できず、強制停止の目的（commit して return できる状態を残す）が達成できない。

判定できない複合コマンド（パイプ・`&&`・`;`・サブシェル・コマンド置換 `$(…)`）は**拒否側**に倒す（強制停止は既に異常状態で、通す方が危ない）。ただしコマンド置換の拒否は commit メッセージの trailer を `-m "$(printf '…')"` で作る書き方を巻き込むため、**拒否理由に回避手段**（「commit メッセージは `-m` を複数回に分けて 1 行ずつ渡せ。`$(…)` は拒否される」）を含めることを要件にする。理由を読んでも次の手が分からない拒否は、目的を達成できない。

- 代案（PreToolUse で全ツールを拒否）: commit できずに未コミットの差分を抱えたまま落ちるので却下。
- 代案（コマンド置換を許可する）: `$(…)` の中身は判定できないまま実行されるので却下。

### 4. 計測ロジックは共有せず、式を spec で 1 つに定める

`subagent-context.sh` は PR #253 が同じファイルを触っており、主の制約で**変更は引数処理（と `--help` の行範囲）に限る**。共有ファイルへの抽出も本体の python ブロックの書き換えも、その範囲を超える。

したがって共有はしない。代わりに**計測の式**（対象トランスクリプトの最後の `assistant` レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を合算する）を spec の要件として 1 つに定め、`subagent-context.sh` と `context-tripwire.sh` はそれぞれ自前で実装する。式が 1 箇所（spec）にあれば、実装が 2 本でもずれたときにテストで検出できる。

- 代案（第 3 のファイルに抽出して両者が source する）: 制約違反であることに加え、hook は起動コストを削るために独自の末尾読みが要るので、共有できるのは数行の合算だけになる。割に合わない。

### 5. 末尾だけ読む（256KB は環境変数にしない）

PostToolUse は全ツール呼び出しで走るので、トランスクリプト全体を JSON パースしてはいけない。ファイル末尾から固定 256KB だけ `seek` して読み、最後の `assistant` レコードの `usage` を拾う。見つからなければ fail-open。`subagent-context.sh` の既存の「全行走査」は本体の再開前チェック用にそのまま残す。

**256KB は意図的に環境変数化しない。** 閾値（`DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP`）は運用で調整する値だが、末尾バイト数は「1 レコードが収まるか」という実装の内部事情で、install 先が触って得るものが無く、小さすぎる値を入れられると静かに fail-open して途中計測が全体で無効になる。変えたくなったら仕様変更として扱う。

- 代案（全部読む）: 5MB のトランスクリプトで毎ツール数百 ms かかるので却下。要件は「5MB でも 100ms 未満」。

### 6. `agent_id` の有無は python3 を起動する前に bash で判定する

この hook は install 先の**全ユーザー・全セッションの全ツール呼び出し**で走る。メインスレッド（`agent_id` 無し）が大多数なのに、そこでも python3 を起動すると 1 ツールあたり数十 ms を全ユーザーに課す。

`agent-model-guard.sh` が `DEV_WORKFLOW_MODEL_GUARD=off` と `command -v python3` を bash 側で先に見ているのと同じ形で、**stdin を読んで文字列 `"agent_id"` を含まなければ python3 を起動せず exit 0** にする。`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` の判定も同じく bash 側で先に行う。

design の Risks にあった「matcher を編集系に絞る」は最後の手段で、先に払うべきはこの早期脱出。

### 7. 通知は PostToolUse の `additionalContext`、停止は PreToolUse の `deny`

配布バイナリ 2.1.266 の hook 説明文では PostToolUse は「Exit code 0 - stdout shown in transcript mode (ctrl+o) / Exit code 2 - show stderr to model immediately」で、**exit 0 の素の stdout はトランスクリプト表示にしか出ずモデルには届かない**。同バイナリの hook 出力スキーマは `{hookEventName: "PostToolUse", additionalContext: string?, classifierContext: …}` を持ち、`additionalContext` は `hook_additional_context`（Non-error feedback）としてモデルに渡る経路として定義されている。

したがって通知は `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` を stdout に出して exit 0 とする。exit 2（stderr をモデルに即時表示）は「エラー」の意味づけでツール結果の扱いが変わるため採らない。

停止は PreToolUse の `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}` + exit 0（既存 `agent-model-guard.sh` と同じ形）。通知と停止を別イベントに分けることで、通知が誤って作業を止めることがない。

### 8. `工程中断:` と `工程完了:` の使い分け

#253 の申告規約では return の 1 行目 `工程完了:` が手渡しの条件になっている。手渡し先の W / G が「未コミット差分と残作業を先に確認する」必要があるのは**中断のとき**だけなので、この 2 つを区別しないと手渡し先が余計な確認をするか、必要な確認を飛ばす。

- **強制停止（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超でツールを拒否された）で止まった場合は、必ず `工程中断:`。** 拒否された時点で予定していた作業は残っている。
- **通知（`DEV_WORKFLOW_CONTEXT_CAP` 超）を受けて締める場合は、そのとき進めていた tasks グループの項目がすべて済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:`。** 判定材料を「そのとき進めていた tasks グループの項目」に固定するのは、W が迷わずに機械的に判断できるようにするため。

この使い分けは hook が出す通知本文と拒否理由の中に書く（W が手順書を読み返さなくても判断できる）。

### 9. 実地確認は worktree 隔離されていないセッションから回す

`DEV_WORKFLOW_CONTEXT_CAP` を小さくしてサブエージェントを起こす確認は、`claude` の起動を伴う。worktree 隔離のエージェントからは `claude` の起動そのものがガードに拒否されるため（着手前実験で実際にぶつかった）、**この change を実装している W 本人には実行できない**。

したがって tasks の 4 章は「W は 4.1（単体テスト）までを行い、実セッションでの確認は本体または隔離なしのセッションに依頼して証拠を受け取る」と段取りを決めておく。段取りが無いと、着手した W（または手渡し先の W）が同じ壁に再度ぶつかって、受け入れ条件 7 件のうち 3 件が埋まらないまま実装だけ終わる。

### 10. hooks.json の変更は聖域パス・層間契約として扱う

`hooks/hooks.json` は install 先の全セッションで発火する。matcher を広く取る（PostToolUse は全ツール）ため、事故ると全ユーザーのツール実行が遅く・止まる。したがって（a）fail-open を全経路で守る、（b）閾値・全解除を環境変数で上書きできる、（c）テストを hook スクリプト単体（stdin → stdout / exit code）で書く、の 3 点を要件に落とす。

hooks.json の登録内容の検査は**新規の `tests/context-tripwire.bats`** に置く。既存の hooks.json 検査は `tests/tripwire-hook.bats` にあるが、そこは PR #253 が編集中で、追記するとマージ順の制約に違反する。

### 11. 手順書への追記は最後の commit に分け、規則の本文は 1 箇所に置く

`skills/develop/` 配下の手順書と `templates/escalation-tripwires.md` は PR #253 が同時に書き換えている。コード（hook・`--file`・テスト）は先に進め、手順書への追記だけ #253 マージ後に最後の commit で載せる。

書き方も制約する。**規則の本文（閾値・2 経路・通知/強制停止時の振る舞い・`工程中断:` の使い分け）は `references/decision-criteria.md`「コンテキスト上限」の節 1 箇所に置き**、`SKILL.md` / `references/roles/worker.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md` は**その節へのポインタと、その役割固有の動作**（手渡し先が `git status` / `git diff` を先に見る、等）だけを書く。`README.md` を対象に含めるのは、着手時点で `README.md:14` にも「150K tokens 超なら再開せず…」という再掲が実在し、プラグインの概観だからといって外すと次に閾値を動かしたとき README だけ取り残されるため。同じ規則を複数ファイルに言い換えて置くと、次に閾値や振る舞いが変わったとき必ずどれかが取り残される（#253 で 3 周続けて言い換え漏れが出た）。

### 12. G が強制停止に当たったときのレビュー結果は本体が代理投稿する

強制停止中は Bash が git 系だけになるので `gh pr comment` も拒否される。これは意図どおり（#253 の事故ではこれで被害が止まった）だが、G（ゲート実行者）が強制停止に当たると**レビュー結果を記録先に投稿できないまま return する**。

そこで手順書側に「G が `工程中断:` で return したら、return に含まれるレビュー結果を**本体が代理投稿する**」経路を決めておく。R1 の仕様レビューを本体が代理投稿している（`subagent_type: dev-workflow:decider` は `gh` を実行できない）のと同じ形で、既に前例がある。

## Risks / Trade-offs

- [PostToolUse が全ツールで走るので、ツールごとにコストが乗る] → メインスレッドは bash 側の早期脱出で python3 を起動しない（Decision 6）。サブエージェントでも末尾読みに限定し、5MB で 100ms 未満をテストで担保。それでも重ければ matcher を編集系＋Bash に絞る余地を残す（要件は「全ツール」なので、絞るなら仕様変更として扱う）
- [閾値を超えた状態が続くと、以降すべてのツール呼び出しで通知が出て、その通知自体がコンテキストを食う] → 出力は数行に抑える。同一起動での重複抑制は状態を持つことになるので今回はやらない（#259 の監視で頻度を見てから）
- [強制停止で Bash を絞ると、テスト実行やビルドの途中で止まって「壊れた作業ツリー」が残りうる] → 通知と停止の間に 70,000 の余裕を置き、通知で自発的に締めさせるのが主。停止は最後の安全網
- [`transcript_path` / `agent_id` の意味は Claude Code の内部仕様で、将来変わりうる] → 変わったら「導出したパスが存在しない」に落ち、fail-open で無害に無効化される。テストは実ファイル配置を固定的に作って検証する
- [`agent_id` の実値は payload として一度も観測されていない（ファイル名からの逆算のみ）] → 実地確認（tasks 4 章）で観測した `agent_id` と実ファイル名の対を証拠として PR 本文に貼り、後続が同じ検証をやり直さずに済むようにする
- [PR #253 とのマージ順が崩れると手順書と plugin.json がコンフリクトする] → tasks.md で最後の commit に分離し、version は 2.7.0 を事前割当（#253 が 2.6.1）して 1 行衝突に留める

## Migration Plan

1. hook スクリプトとテストを先に入れる（`hooks.json` 登録込み）。既定閾値では既存の動きは変わらない（上限内は無音）
2. 小さい閾値（`DEV_WORKFLOW_CONTEXT_CAP=20000` 等）を環境変数で与えて、名前付きサブエージェントと `isolation: "worktree"` のサブエージェントの両方で通知・停止が出ることをトランスクリプトで確認し、証拠を PR 本文に貼る。**この確認は worktree 隔離されていないセッションから回す**（Decision 9）
3. #253 マージ後に手順書 5 本への追記を最後の commit で載せる
4. ロールバック: `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`（即時・全解除）、または `hooks.json` から 2 エントリを外す

## Open Questions

- **`additionalContext` が実際にモデルへ届かなかった場合の退避**: 出力スキーマ（`hookEventName: "PostToolUse"` + `additionalContext`）とセッション側の `hook_additional_context`（"Non-error feedback from hookSpecificOutput.additionalContext"）の存在までは配布バイナリ 2.1.266 で確認済みだが、PostToolUse の説明文が明記しているのは exit code の挙動だけなので、モデルに届くことの最終確認は実地確認（tasks 4.3）が担う。**届かなかった場合は exit 2 + stderr に切り替える**（同バイナリの説明文は exit 2 を "show stderr to model immediately" としている）。その場合は「エラー扱いでツール結果の扱いが変わる」（Decision 7 で採らなかった理由）を受け入れることになるので、仕様変更として扱う
- 強制停止の既定値 220,000 は #257 の案のまま採る。実データでの妥当性は #259 の監視結果を見て見直す
- 同一起動での通知の重複抑制（1 回だけ出す）が要るかは、#259 の監視で頻度を見てから決める
