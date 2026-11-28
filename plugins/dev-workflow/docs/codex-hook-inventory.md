# Codex 向け hook 一覧

#1861 / G001 の正本。調査基準は `702a1888282102e1f4f35f44f1cb96f8387e444c`。dev-workflow 17 登録＋capability-registry 2 登録を記す。同一 script の別 event も別行とする。

## 読み方と接続契約

方針は「Codex で動く」「載せ替える」「Codex では持たない」。現状の「載せ替えた」は実装が完了した場合だけ使う。G002 / #1862 では下記3登録の拒否判定を載せ替えた（fixture 検証）。配布・信頼設定・対象別の実機確認は G003 / #1863 に残り、「Codex で動く」とはまだ判定していない。「持たない」も目的が不要という意味ではなく、代替のない不足を理由欄に残す。

3 対象は Codex 本体・native subagent・`codex-worker.py` の役。各行の未確認は対象別の実機証跡が未取得という意味。worker の一時 CODEX_HOME は認証リンクと最小 config のみを作る（`plugins/dev-workflow/scripts/codex-worker.py:220-236`）。他の 2 対象への継承・配布・信頼も未検証であり、通常 profile の設定や Claude の役で hook が動いた証拠を代用しない。hook コマンドの exit 0 や worker の completed だけで有効としない。

#1856 A1 の Codex 用ファイルは、その作成時にこの一覧を参照し、複製しない。現時点の入口は [Codex 開発案内](codex-develop.md)。将来の参照元パスや #1856 の構成・操作対応表をこの子では新設しない。G002（#1862）は拒否判定、G003（#1863）は配布・信頼・実機証跡を担当し、同じ行の現状・移植先・対象別証跡を更新する。

## 登録一覧

event・matcher・command は hooks.json の値をそのまま保持する。matcher の空欄は未指定、セル内の縦棒は `&#124;`。ソース根拠のパスは repo 相対。追加属性は理由と別に根拠欄へ記す（記載がなければ type=command、timeout 指定なし）。

| plugin | event | matcher | command | 方針 | 現状 | 入力・出力依存 | 理由 | ソース根拠 | 載せ替え先・後続 | Codex 本体 | native subagent | codex-worker.py |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `dev-workflow` | `SessionStart` | `startup&#124;clear&#124;compact` | `"${CLAUDE_PLUGIN_ROOT}/scripts/session-tripwires.sh"` | 載せ替える | 未実装・未配布 | CLAUDE_PLUGIN_ROOT・template・usage_view → SessionStart additionalContext | 注入と残量規約を Codex の入口へ接続する必要があり、Claude 用 JSON 出力だけでは届かない | plugins/dev-workflow/scripts/session-tripwires.sh:1-17; plugins/dev-workflow/scripts/session-tripwires.sh:158-162 | #1856（注入） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `SessionStart` | `startup&#124;resume&#124;clear&#124;compact` | `"${CLAUDE_PLUGIN_ROOT}/scripts/team-mode-warning.sh"` | Codex では持たない | 代替なし・未配布 | CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS → systemMessage / additionalContext | Claude Teams 固有の設定警告。Codex native の役制限が守られるかの警告は未提供で、不足は残る | plugins/dev-workflow/scripts/team-mode-warning.sh:1-16 | #1856（役制限の確認） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `SessionStart` | `compact` | `"${CLAUDE_PLUGIN_ROOT}/scripts/develop-compact-reread.sh"` | 載せ替える | 未実装・未配布 | source・transcript_path の Claude JSONL → 読み直し additionalContext | Claude Skill 呼出し履歴に依存する。Codex の圧縮後の再読取を別途接続する必要がある | plugins/dev-workflow/scripts/develop-compact-reread.sh:1-21; plugins/dev-workflow/scripts/develop-compact-reread.sh:30-98 | #1856（圧縮後再読取） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `UserPromptSubmit` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/prompt-tripwires-refresh.sh"` | 載せ替える | 未実装・未配布 | session_id・plugin root の前回値 → UserPromptSubmit additionalContext | Claude cache パスの変更検知と再注入。Codex の更新検知・再読取は未提供 | plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh:22-35 | #1856（注入更新） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `UserPromptSubmit` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/unclear-reply-rephrase.sh"` | Codex では持たない | 代替なし・未配布 | prompt の語・引用除外 → UserPromptSubmit additionalContext | Claude output-style の節を参照する促し。Codex で言い直しを自動注入する仕組みはなく不足が残る | plugins/dev-workflow/scripts/unclear-reply-rephrase.sh:19-21; plugins/dev-workflow/scripts/unclear-reply-rephrase.sh:58-96 | #1856（注入の境界。追加対応は未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `UserPromptSubmit` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/epic-child-state.sh"` | 載せ替える | 未実装・未配布 | session_id・prompt / 終了発言・epic state → 状態更新 / block | 子の状態遷移は必要だが Claude の入力 / Stop 経路に依存。timeout=30 の登録 | plugins/dev-workflow/scripts/epic-child-state.sh:120-178; plugins/dev-workflow/scripts/epic-child-state.sh:249-301; timeout=30 | #1855（子の状態） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreToolUse` | `Agent` | `"${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh"` | 載せ替える | 未実装・未配布 | Agent tool_input.model / subagent_type・usage_view → deny | Claude Agent と Fable の格を直接移せない。Codex の選択と役の上限は入口側で接続する必要がある | plugins/dev-workflow/scripts/agent-model-guard.sh:1-28; plugins/dev-workflow/scripts/agent-model-guard.sh:45-68 | #1856（モデル選択） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreToolUse` | `Edit&#124;Write&#124;NotebookEdit&#124;Bash` | `"${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh"` | Codex では持たない | 代替なし・未配布 | agent_id・session_id・Claude JSONL usage → deny（編集前） | Claude の input/cache token 和と subagents のパスに依存。Codex ログを同形と仮定できず、途中計測の歯止めは未提供 | plugins/dev-workflow/scripts/context-tripwire.sh:1-24; plugins/dev-workflow/scripts/context-tripwire.sh:130-175; plugins/dev-workflow/scripts/context-tripwire.sh:205-285 | #1858（Codex 計測は後続未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreToolUse` | `AskUserQuestion` | `"${CLAUDE_PLUGIN_ROOT}/scripts/unattended-ask-guard.sh"` | 載せ替える | 載せ替えた（判定fixture検証）・未配布 | DEV_WORKFLOW_UNATTENDED・AskUserQuestion → deny | 無人の質問停止防止は必要。確認済み同期 request_user_input のみ deny へ適合。非同期・nested call は未確認 | plugins/dev-workflow/scripts/unattended-ask-guard.sh:1-36 | hooks/codex/pretool-guard.py（G002 判定検証は下記） / #1863（配布・信頼・実機） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreToolUse` | `Write&#124;Edit&#124;NotebookEdit` | `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` | Codex では持たない | 代替なし・未配布 | agent_id・file_path / notebook_path・cwd → deny | Claude 用 permit store への直接書込防止。Codex の子の識別と許可保存先への同等の保護は未提供 | plugins/dev-workflow/scripts/git-guard-base-write-guard.sh:1-18; plugins/dev-workflow/scripts/git-guard-base-write-guard.sh:50-87 | #1862（git 判定との境界確認。保護の移植は未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreToolUse` | `Bash` | `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` | 載せ替える | 載せ替えた（判定fixture検証）・未配布 | Bash command・agent_id・session_id・cwd・permit → ask / deny / allow | 破壊的 git の拒否は必要。NO_ASK 固定と入力正規化で Claude の permission モード・親子許可を外し deny へ適合 | plugins/dev-workflow/scripts/git-destructive-guard.sh:1-34 | hooks/codex/pretool-guard.py（G002 判定検証は下記） / #1863（配布・信頼・実機） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PermissionRequest` | `Bash` | `"${CLAUDE_PLUGIN_ROOT}/scripts/rm-permission-guard.sh"` | Codex では持たない | 代替なし・未配布 | PermissionRequest・command・agent_id・permission_mode・permit → decision | Claude の確認画面と親の一回許可を消費する仕組み。Codex の同等の rm 許可応答は未提供で不足が残る | plugins/dev-workflow/scripts/rm-permission-guard.sh:1-24; plugins/dev-workflow/scripts/rm-permission-guard.sh:35-68 | #1858（rm 確認の代替は後続未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PostToolUse` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh"` | Codex では持たない | 代替なし・未配布 | agent_id・session_id・Claude JSONL usage → additionalContext（実行後通知） | Claude の input/cache token 和と subagents のパスに依存。Codex ログを同形と仮定できず、途中計測の歯止めは未提供 | plugins/dev-workflow/scripts/context-tripwire.sh:1-24; plugins/dev-workflow/scripts/context-tripwire.sh:130-175; plugins/dev-workflow/scripts/context-tripwire.sh:205-285 | #1858（Codex 計測は後続未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `SubagentStart` | `^dev-workflow:(worker&#124;reviewer&#124;gate-runner)$` | `"${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh"` | 載せ替える | 未実装・未配布 | agent_type・plugin root・閾値 env → SubagentStart additionalContext | Claude の役名と起動時注入に依存。Codex の各役へ規約を渡す接続が必要 | plugins/dev-workflow/scripts/subagent-start-context.sh:1-18; plugins/dev-workflow/scripts/subagent-start-context.sh:26-44; plugins/dev-workflow/scripts/subagent-start-context.sh:73-86 | #1856（役への注入） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `SubagentStop` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh"` | Codex では持たない | 代替なし・未配布 | agent_id・transcript・background_tasks → block | Claude の背景タスク台帳と起動記録の積集合に依存。Codex の待機漏れを機械的に止める代替は未提供 | plugins/dev-workflow/scripts/subagent-stop-guard.sh:1-23; plugins/dev-workflow/scripts/subagent-stop-guard.sh:116-154 | #1858（停止ガードの代替は後続未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `PreModelSwitch` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/model-switch-recache-notice.sh"` | Codex では持たない | 代替なし・未配布 | PreModelSwitch・context_tokens・cache 費用・prompt_cache_warm → systemMessage | Claude の切替前 cache 費用に固有。Codex の費用通知の代替はなく、必要性と取得元は未決定 | plugins/dev-workflow/scripts/model-switch-recache-notice.sh:1-14; plugins/dev-workflow/scripts/model-switch-recache-notice.sh:56-89 | #1858（費用通知は後続未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `dev-workflow` | `Stop` | `` | `"${CLAUDE_PLUGIN_ROOT}/scripts/epic-child-state.sh"` | 載せ替える | 未実装・未配布 | session_id・prompt / 終了発言・epic state → 状態更新 / block | 子の状態遷移は必要だが Claude の入力 / Stop 経路に依存。timeout=30 の登録 | plugins/dev-workflow/scripts/epic-child-state.sh:120-178; plugins/dev-workflow/scripts/epic-child-state.sh:249-301; timeout=30 | #1855（子の状態） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `capability-registry` | `PreToolUse` | `mcp__claude-in-chrome__.*&#124;mcp__playwright__.*` | `"${CLAUDE_PLUGIN_ROOT}/scripts/browser-guard.sh"` | Codex では持たない | 代替なし・未配布 | browser MCP matcher・session_id・初回 marker → allow + additionalContext | Claude MCP 名による CLI 優先の注意喚起で拒否はしない。Codex のブラウザ前の同等の通知は未提供 | plugins/capability-registry/scripts/browser-guard.sh:1-40 | #1856（注入の境界。browser 通知は未割当） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |
| `capability-registry` | `PreToolUse` | `Bash&#124;Read` | `"${CLAUDE_PLUGIN_ROOT}/scripts/secret-guard.sh"` | 載せ替える | 載せ替えた（判定fixture検証）・未配布 | Bash command / Read file_path → deny JSON | 秘密値を表示する操作の拒否は必要。Bash/command のみ既存判定へ渡し deny へ適合。Read は対象外。timeout=10 | plugins/capability-registry/scripts/secret-guard.sh:1-17; plugins/capability-registry/scripts/secret-guard.py:60-65; plugins/capability-registry/scripts/secret-guard.py:190-204; timeout=10 | hooks/codex/pretool-guard.py（G002 判定検証は下記） / #1863（配布・信頼・実機） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） | 未確認（実機証跡未取得） |

## G002 / #1862 の判定検証と G003 への入口

対象は上記の git-destructive-guard / secret-guard / unattended-ask-guard の3登録。入口は `plugins/dev-workflow/hooks/codex/hooks.json` と `pretool-guard.py`。PreToolUse を事前に matcher で絞らず、adapter が Bash/command と確認済みの同期 `request_user_input` だけを選別する。apply_patch・Read・非対象・壊れた入力は無出力。拒否は deny のみで、ask/allow/continue/stopReason は出さない。Python は `-I` で起動し、pending command を実行せず stdin だけを既存判定へ渡す。git は agent_id/permission_mode/permit を引き継がず NO_ASK=1 固定、FORCE を除去する。

配布側は `DEV_WORKFLOW_CODEX_GUARD_DIR` に adapter があるディレクトリの絶対パスを指定する（hooks.json の command が `python3 -I "${DEV_WORKFLOW_CODEX_GUARD_DIR}/pretool-guard.py"` を起動）。これは配置・信頼設定の完成を意味しない。依存は module 基準の repo 配置が既定で、cwd/PYTHONPATH は探索しない。配置が違う場合は次の絶対 script パスを指定する。

- `DEV_WORKFLOW_CODEX_GIT_GUARD`: `plugins/dev-workflow/scripts/git-destructive-guard.sh`
- `DEV_WORKFLOW_CODEX_SECRET_GUARD`: `plugins/capability-registry/scripts/secret-guard.sh`（隣の `secret-guard.py` も必要）
- `DEV_WORKFLOW_CODEX_ASK_GUARD`: `plugins/dev-workflow/scripts/unattended-ask-guard.sh`

実行依存は bash/python3。欠落・非絶対パス・子プロセス失敗・不正な判定出力は stderr に「未検査」を記し fail-open。片方が未検査でも他方の deny は残る。git off と secret off は各々だけに効く。無人質問は既存 script の印の判定と連絡先/needs-approval の案内を保ち、子は本体へ返す。

入力根拠は `plugins/dev-workflow/tests/fixtures/codex-pretool/metadata.json`。[本体の実測（codex-cli 0.163.0）](https://github.com/oratta/claude-harness/issues/1862#issuecomment-7235173851) の Bash/command、apply_patch/command、同期 request_user_input/questions をダミー fixture に保存した（識別情報は伏せた）。同期質問は hook 到達後に exec client が非対応として拒否しており、対話UIやインストール済み guard の実機成功を意味しない。shell/unified exec の正規化は公式文書由来、shell の正規化形を本体が実測。他の command 正負例は合成で、実測を増やしたとは数えない。

検証は `python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_pretool_guards.py`。対象9種・wrapper/連結・dry-run/データ・秘密の表示/値を出さない利用・独立した off・同期質問の印・親子情報/FORCE/permit/繰返し拒否・入力型/依存失敗を確認する。これは fixture の判定検証であり、3対象の配布・信頼・実機証跡は表の未確認を維持する。

未確認は非同期質問、名前空間付き公開名と hook 名の対応、code mode 内 nested call、native subagent/worker への継承。確認済みの質問名は `request_user_input` だけで、`request_user_input_async` や `functions.request_user_input` は対象に足していない。request_permissions は対象外。#1863 は入口と依存の配置・信頼・印の継承・各対象の実機拒否を確認する。

既存判定の限界も維持する。push 済み amend・rebase -i・ブランチ名なし push・スクリプト内部/動的 git の拒否は保証しない（rules/destructive-git-guard.md の事前承認が必要）。秘密の別言語/ssh/スクリプト経由の読み出しや、hook に届かない/印が未継承の質問も検査できない。未確認経路を対応成功とは数えない。

## 完全性検査の範囲

`python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_codex_hook_inventory.py' -v` は両 hooks.json とこの表の `(plugin, event, matcher, command)` の多重集合、重複、分類の許容値、理由・根拠を含む必須列を検査する。行削除、登録追加・削除、event/matcher/command 変更、重複、不正分類、必須欄の空を repo 外の一時コピーで試す。実 hook は実行しない。件数 19 の固定値では判定しない。

保証しない範囲: 非空の理由を「今日は晴れです」に変えても通る。ソースの行範囲の形式は検査するが、その意味が分類を裏付けるか、現状の主張が正しいか、実機で働くかはレビューと後続の証拠で確認する。これらの穴を機械検査で塞ぎ切ることは G001 の完了条件にしない。

## G003 が実行する安全な実機確認手順（本 change では未実行）

1. 通常 repo・通常 profile を試験に使わず、repo 外の `mktemp -d` 領域を作る。以下はセットアップ例であり、この一覧・テスト自体は実行しない。

   ```sh
   probe_dir=$(mktemp -d)
   git init --bare "$probe_dir/remote.git"
   git init -b main "$probe_dir/repo"
   git -C "$probe_dir/repo" remote add origin "$probe_dir/remote.git"
   test "$(git -C "$probe_dir/repo" remote get-url origin)" = "$probe_dir/remote.git"
   test "$(git -C "$probe_dir/repo" remote get-url --push origin)" = "$probe_dir/remote.git"
   git -C "$probe_dir/remote.git" rev-parse --is-bare-repository
   ```

2. pushurl・url の複数値や `url.*.insteadOf` / `pushInsteadOf`、include、hook 設定で外部へ向かない隔離 git config を使い、実際の fetch / push 先が上のローカル bare remote だけであると照合する。照合できなければ実行を止め「未取得理由」とする。捨ててよいファイルとローカル author だけで commit を作り、比較用の commit を bare remote に置く。秘密試験はこの領域の `.env` に `HARNESS_PROBE_SECRET=dummy-only-not-a-real-secret` だけを置く。対象プロセスにもこのダミー変数だけを追加し、本物の秘密を表示しない。環境全体の printenv・通常 profile / auth の表示・本物の .env の Read は行わない。
3. G002 の対象操作ごとに git reset --hard・main push・force push 等の拒否入力、ダミー変数 / ダミー .env の表示入力、無人印付きの質問操作を用意する。操作はすべて隔離 repo を cwd とし、G003 が対応版の起動方法・入力契約を確認して Codex 本体・native subagent・worker の各対象から実際に要求する。G001 では未実装のインストール方法や拒否 payload を発明しない。無害な操作の対照例も実行し、単に全操作が実行不能な状態と区別する。
4. 対象ごと・操作ごとに、版、harness HEAD、対象、隔離 config / 配布・信頼の状態、入力、cwd、開始終了時刻、exit code、拒否理由・ログを repo 外に残す。前後の `git status --porcelain`、HEAD、対象ファイルの内容ハッシュ、bare remote の refs を比較し、拒否に加えて操作が未実行だったことを確認する。秘密試験はダミー値がツール結果へ出なかったこと、質問は待ち画面に入らず戻ったことも確認する。exit 0 / completed だけで合格にしない。
5. 証跡の URL または保存先を各行の対象欄へ別々に付ける。起動不能・未配布・信頼未成立・対象の操作なし・未試行なら、その対象だけ「未確認 — 未取得理由: …」と記録する。#1862 が判定を実装しても #1863 の配布・信頼・3 対象の証拠を一括で確認済みにしない。Claude 経路の成功は別の記録とする。
