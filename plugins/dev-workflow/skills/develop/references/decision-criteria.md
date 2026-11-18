# 判定基準リファレンス（develop スキル）

本体（オーケストレータ）が読む。本体のモデル選択（`SKILL.md`「モデル」）で使う残量モード・共有枠モード、サブエージェントのコンテキスト上限と手渡しの許可、モード不変ルールの詳細版。仕様化判断（Step B）と分割判定（Step C）は `references/spec-decision.md`、軽い通し方は `references/light-path.md`、W と G の return の 1 行目の宣言は `references/return-declaration.md`。

## 残量モード `FABLE_BUDGET_MODE` と共有枠モード `SHARED_BUDGET_MODE`

**Fable 残量モード `FABLE_BUDGET_MODE`**: サブスクの Fable 枠の残り具合を表す環境変数。役割（W / R1 / G）の既定モデルと昇格上限を決める。**明示設定が最優先**で、未設定時はセッション記録と usage snapshot の実効値からの自動導出結果を用いる（後述）。導出もできなければ `conserve` 扱い（安全側）。settings.json の `env` ブロックで明示的に固定することもできる。

**共有枠モード `SHARED_BUDGET_MODE`**: 全モデル共通の週次枠（`weekly_all_pct`）の残り具合。Fable 残量モードと独立に導出され、**役割の既定モデルの下限**を決める。明示 env が最優先、未設定時は active スロットの実効値から自動導出（式は `scripts/usage_view.py` の 1 か所、セッションへの注入は `scripts/session-tripwires.sh`）。

優先順位の表（正本はこの 1 つ）。上の段ほど優先し、下の段は上の段が許す範囲の中でだけ効く（Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝つ。例: `throttled` なら R1 も Sonnet 起点）。新しい起動への適用は `codex-develop.py request` が行う。

| 段 | 値 | 意味・導出 | 効果 |
|---|---|---|---|
| ①共有枠モード | `ok` | データ無し、または消費が週の経過ペース以下 | 制約なし。役割表の既定どおり |
| ①共有枠モード | `throttled` | `weekly_all_pct` が週経過% より大きい（このペースだと週末までに枠が尽きる） | W / R1 / G と G が要求するレビュアーの既定を **Sonnet** に落とす。昇格上限 Opus。`abundant` の押し上げは無効 |
| ①共有枠モード | `depleted` | `weekly_all_pct > 90` | 全役割 Sonnet 上限・昇格なし。事前分類に当たっても Fable / Opus を使わない（枠が無いので使えば全員が止まる） |
| ②事前分類 | マージ権限・層間契約・課金/法務 | `references/pre-classification.md` の表（聖域パスだけでは当たらない） | ①の範囲内で、読んで判断する役（R1 / G が要求するレビュアー）を `subagent_type: dev-workflow:decider` で起こす。そのモデルは③が決める。実行役（W）は上げない |
| ③Fable 残量モード | `abundant` | Fable が余っている（消費が週の経過ペースより遅い） | **どの役割の既定も上げない**。役割表の既定どおりで、Fable が使われる経路は決める役（`subagent_type: dev-workflow:decider`）だけ。余った Fable 枠は人間の対話と verify に回す（abundant を役割の既定引き上げに使うと、消費ペースが遅い週ほど大半の実行が Fable に流れ、温存のつもりが最大消費の経路になる） |
| ③Fable 残量モード | `conserve` | 使い切りそう / 消費が週の経過ペースより速い（既定） | 役割表の既定どおり（W = Sonnet、R1 = Opus、G = Sonnet）。事前分類（`references/pre-classification.md`）のマージ権限・層間契約・課金/法務に当たる場合、読んで判断する役（R1 / G が要求するレビュアー）だけ `subagent_type: dev-workflow:decider` で Fable（聖域パスだけでは上げない）。実行役（W）はどの分類でも `opus` 止まり |
| ③Fable 残量モード | `reserve` | Fable 枠を人間用に温存 | conserve に加えて、**自動実行（unmanned / cron / loop 経由）では Fable をいかなる役割でも使わない**。昇格ラダーは Opus 上限。Opus でも2連続失敗が続く問題は `needs-approval` で人間に返す。interactive は conserve と同一 |
| ③Fable 残量モード | `exhausted` | Fable 週次枠を実質使い切った（`fable_weekly_pct > 90`、または明示宣言） | **reserve と異なり interactive を含む全経路で Fable を一切使わない**（枠が実際に無いため）。昇格ラダーは Opus 上限。加えて rate-limit 実エラーで reactive に Opus へ降格する（`escalation-tripwires.md` トリップワイヤー5） |

`reserve` と `exhausted` の差: reserve は「温存」で自動実行のみ Fable を禁じ interactive は自由。exhausted は「枠が実際に無い」ため interactive を含む全経路で禁じる。

**Fable 残量モードは総量を絞る装置ではない。** 4 段のどれも Fable と Opus のあいだで役割を付け替えるだけで、Fable が尽きた日に同じ W が Opus に落ちて走れば消費は減らない。総量を絞るのは共有枠モードとコンテキスト上限。

`haiku` の役割（explore と summarize）は `throttled` でも `depleted` でも `haiku` のまま（上限なので最安を上げない）。

週次余裕を使う provider 選択では、Codex の週次 snapshot も Claude 側も、取得からの経過時間では捨てない。どちらも後述の実効値を headroom（`scripts/headroom.py`）が数えた行で判定する（`cld` の起動 account は余りが最大のもの、codex-develop の margin は行の値）。Codex の snapshot は 7 日より先のリセット時刻も欠測にしない（余裕が負になるだけ）。

## コンテキスト上限（サブエージェントの手渡し）

W と G が return の 1 行目に書く宣言（`工程完了:` / `工程中断:`）の書式と、途中計測の通知・強制停止を受けたときの W と G の振る舞いは `references/return-declaration.md` に置く。この節は本体が読む部分を持つ。

W は名前付き spawn ＋ SendMessage 再開でコンテキストを引き継ぐが（G は再開せず段ごとに新しく起こす。develop SKILL.md の (4)）、再開のたびに全履歴を読み直すため、履歴が畳まれずに伸び続ける。2026-08-31〜09-05 の監査では W の平均コンテキストが 33 万トークン（最大 1 本 745 USD 換算）で、W の消費の 3 分の 2 が 30 万トークン超のリクエストだった。モデルを下げるより先にここを畳む。

計測には 2 経路ある。**本体が再開の前に測る**経路（下の「再開前チェック」）と、**サブエージェントの起動の途中で hook が自分自身を測る**経路（「途中計測」）で、後者は 1 回の起動の中で膨らむぶんを止める。閾値と全解除は次の 3 つの環境変数で、**数値と環境変数名はこの節にだけ置く**（他の面はこの節を指すだけにする。同じ規則を言い換えて複数の面に置くと、次に閾値が変わったときどれかが必ず取り残される）。

| 環境変数 | 既定 | 何が起きるか |
|---|---|---|
| `DEV_WORKFLOW_CONTEXT_CAP` | 150000 tokens | 再開前チェックでは exit 2（＝再開しない条件）。途中計測では PostToolUse で締めの通知が本人に届く |
| `DEV_WORKFLOW_CONTEXT_HARD_CAP` | 220000 tokens | 途中計測の強制停止。PreToolUse が `Edit` / `Write` / `NotebookEdit` と `Bash`（コマンド内容によらず全件）を deny する |
| `DEV_WORKFLOW_CONTEXT_TRIPWIRE` | `on` | `off` で途中計測を全解除する（再開前チェックは残る） |
| `DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT` | 1800 秒 | 停止確認が返らないときの終端の条件の 1 つ目（停止を指示してからの経過時間） |
| `DEV_WORKFLOW_STOP_CONFIRM_STALL` | 600 秒 | 終端の条件の 2 つ目（前任のトランスクリプトが更新されていない時間） |

**再開前チェック（本体が測る）**

- **測り方**: 本体が W を SendMessage で再開する**前に毎回** `scripts/subagent-context.sh <agent-name>` を実行する（トランスクリプトの最後の usage から input + cache_creation + cache_read を読む。exit 2 が上限超）
- **上限超のとき（再開の禁止は無条件）**: 前任の状態にかかわらず、**作業の継続を指示する SendMessage（＝再開）を送らない**。ただし下記の「前任が動作中に交代させる場合」の**停止を指示する SendMessage は禁止の対象外**（作業の継続ではなく停止の指示なので別扱い）
- **手渡しの許可（前任の `工程完了:` return か停止確認が条件）**: 手渡し（前回の return と記録先を渡して**同じ役割の新しいエージェント（W なら新しい W、G なら新しい G）を spawn する**こと）を行ってよいのは、①前任の直近の return の 1 行目が `工程完了: <工程名>` に完全一致するとき、②前任へ停止を指示し、停止確認（何を編集したか・何を投稿したかの報告）を受け取ったとき、のいずれかだけ。上限超過（exit 2）は「次に再開するときは手渡しに切り替える」という条件であって、「今すぐ交代させる」条件ではない。手渡し先は前任の return を前提に続け、記録先とファイルの現状から再出発する（前任の履歴は読めないし読まない）
- **どちらの書式にも一致しない return の扱い**: 1 行目がどちらの書式にも完全一致しない return は `工程中断:` と同じに扱う（本体は内容を読んで「実質これは工程完了だ」と読み替えない）。この書式を知らない世代の W / G、キャッシュ済みの古いプラグインを読んだ W / G、書式を無視した W / G は展開直後に必ず現れるので、不一致の既定を安全側（手渡さない）に固定する
- **idle と return の違い**: バックグラウンドコマンドの完了を待って一時的に応答が止まっている（idle）状態は工程の終わりではない。そのコマンドが終われば前任は再び動き出す。本体は return の 1 行目の完全一致だけで見分け（どちらの書式にも一致しないものは上のとおり `工程中断:` 扱い）、内容を読んで独自に判定しない
- **前任が動作中に交代させる場合**: 先に前任へ停止を指示し（自分で元に戻そうとしないこと＝破壊的 git 操作をしないことを含める）、停止確認（何を編集したか・何を投稿したかの報告）を受け取ってから手渡し先を spawn する（MUST）。停止確認を受け取る前に手渡し先を spawn しない
- **停止確認を待つ間**: 本体はブロックせずに待つ。他に進められる役割（別 worktree の並列作業）があれば先に進めてよい。前任が停止確認より先に `工程完了:` で return したら、この停止の手順は要らなくなり、上の「手渡しの許可」の条件①を満たした通常の手渡しとして扱う（停止確認を待たない）。unmanned（1 サイクル 1 仕事）で他に進められる作業が無ければ、そのサイクル内で停止確認を待ち続けず、そのサイクルを終える（次サイクルで同じ判定をやり直す）
- **停止確認が返らないときの終端**: 前任へ停止を指示してから `scripts/subagent-context.sh <agent-name> --stop-since <停止を指示した epoch 秒>` で測り、**停止指示からの経過時間が `DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT` 以上、かつ前任のトランスクリプトの無更新時間が `DEV_WORKFLOW_STOP_CONFIRM_STALL` 以上**（2 条件とも。exit 3）になったら終端とする。本体のターン数は条件に使わない（進められる作業が無い interactive ではターンが進まず、終端が来ないため）。終端に達したときは**手渡し先を spawn せず、その作業を止めて人間に報告する**。報告には前任の名前・停止を指示した時刻・その worktree の `git status` を添え、前任の再開の可否は人間の指示を待つ。人間の返事も経過時間も、停止確認の代わりにならない: 手渡しを行ってよいのは終端に達したあとも上の「手渡しの許可」の①か②を満たしたときだけで、終端は第 3 の経路ではない（前任を放置したまま手渡し先を spawn してはならない）。値は env で上書きでき、閾値の数値はこの節の環境変数の表にだけ置く
- 上限は初期値。品質が落ちる（手渡し先が前任の判断を取りこぼす）なら上げ、まだ肥大するなら下げる。監査の再集計は `~/.claude/projects` のトランスクリプトから行う

**途中計測（hook が本人を測る）**

再開前チェックは「再開の瞬間」しか見ないので、1 回の起動の中で膨らむぶんは素通りする（実測で W が 497,552 トークンに達した）。`hooks/hooks.json` に配線した `scripts/context-tripwire.sh` が PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）で走り、**そのサブエージェント自身の**トランスクリプトを測ってこれを止める。計測対象は hook が受け取る `agent_id` から導出するので、`isolation: "worktree"` で起こしたサブエージェントでも同じように効く。メインスレッド（親セッション）は対象外。

- **通知・強制停止を受けたときの W と G の振る舞い**（締めて return する・Bash を含めて拒否される・途中停止したときの 1 行目・G が強制停止に当たったとき）は `references/return-declaration.md`。強制停止で止まった W の後片付け（未コミット差分の commit）は本体が行う（本体側の手順は `skills/develop/SKILL.md` の該当箇所が正本）
- **fail-open**: 測れない・閾値が不正・`off` のときは hook は何も出力しない（作業は止まらない）。途中計測が効かないだけで、再開前チェックは従来どおり働く。この hook は `agent_id` の有無で本体（メインスレッド）を対象外にする前提だが、その前提の出どころは配布バイナリの入力スキーマという外部契約であり、将来これが崩れて本体まで巻き込んで止まった場合の逃げ道は `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` だけである（Bash に窓を残さない設計にしたぶん、本体が止まると後片付けの担い手も同時に失われるため）

モードが動かすのは役割の既定モデルと昇格上限だけで、1 ループの構造・トリップワイヤーは変えない。env のためセッション起動後の明示的な変更は次セッションから反映される（モード切替は週単位想定のため許容）。自動導出は SessionStart 毎に更新される。

### `FABLE_BUDGET_MODE` の自動導出（セッション記録と usage snapshot 契約）

使用量の主な情報源はステータスラインが値の変わった描画で書く起動アカウント別のセッション記録（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions/<アカウント鍵>.json`。5 時間枠と全体の週次）で、`scripts/usage-probe.sh` が OAuth usage API（`/api/oauth/usage`）から書く `~/.claude/.usage-snapshot`（schema 2。スロット別に `fable_weekly_pct` / `weekly_resets_epoch` などを含む JSON）は、Fable 週次と記録の無いアカウントを埋める補助である。probe は、記録が無い・記録が 3 時間（`USAGE_PROBE_STALE`）より古い、または snapshot の `fetched_at` が 3 時間より古い（無い場合を含む）スロットだけを叩き、前回の試行から 3 時間（`USAGE_PROBE_INTERVAL`）は叩かない。429 が続くスロットは待ちを倍々に延ばす（上限 1 日）。試行は結果にかかわらず `~/.claude/.usage-probe-state` に記録し、`~/.claude/.usage-probe.lock` でマシン全体 1 本に絞る。fail-open はスロット単位（失敗したスロットは使用率などの前回値を引き継ぐが、試行して失敗したスロットの `reset_grants` は引き継がずに除く。全スロット失敗なら snapshot を書かないが、除く `reset_grants` があるときはその欄だけを除いて書き直す）。`scripts/session-tripwires.sh` が SessionStart 毎にこの probe を best-effort 実行し、active スロットの実効値からモードを導出して残量ブロックを文脈に注入する。

実効値は `scripts/usage_view.py` の 1 か所で求める（`select-account.sh`・`agent-model-guard.sh`・`codex-develop.py` も同じ実装を使う）。取得からの経過時間で値を捨てず、リセット時刻より前の値は下限としてそのまま使い、リセット時刻を過ぎた値は 0% とみなす。記録と snapshot の両方にあるときは、同じ窓なら取得時刻の新しい方を取る（手動リセットで使用率は同じ窓のまま下がりうるため。取得時刻が等しい・片方無しなら大きい方）。規則の正本は openspec の `usage-session-records`「記録と snapshot から実効値を求める」。

導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較で、次の優先順位に従う:

1. **明示 env `FABLE_BUDGET_MODE` があればそれを使う**（自動導出より優先）
2. active スロットの実効値の `fable_weekly_pct` が求まらない（snapshot に無い・読めない）→ `conserve`（既定・安全側）
3. `fable_weekly_pct > 90` → `exhausted`
4. `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant`
5. それ以外（消費が週経過を上回る）→ `conserve`

週経過% = `(7日 − (リセット時刻 − 現在)) / 7日 × 100`。probe が失敗しても導出は手元の記録と前回の snapshot から行い、それも無ければ conserve に倒れ、トリップワイヤー注入自体は従来どおり行われる。

### モード不変ルール（どのモードでも変えない2本）

1. **結果が変わらない大量トークン仕事は常に安いモデル**（fan-out ワーカー、機械的編集）。abundant でも Fable を使うのは無駄撃ち
2. **判断が集中する場所は常に賢いモデル**（仕様レビュー、verify、ゲート）。reserve の自動実行と exhausted だけが例外で Opus 上限
