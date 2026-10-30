# dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。開発の 1 ループ（`develop`）から PR の品質ゲート（`pr-review-gate`）・自動マージ（`templates/auto-merge/`）まで、「開発するときはこうする」という汎用的な手順を集約する。

## 含まれるスキル

### develop

コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときに、入口（issue 番号・URL・自然文・会話・cron・エピックの子）を問わず通す標準ワークフロー。旧スキル（issue 限定の入口だったもの）の後継。

- **本体はオーケストレータ専任**: Edit でコードを書かず、レビューを代行しない。作業者 W（dev-workflow:worker）・仕様レビュアー R1・ゲート実行者 G（dev-workflow:gate-runner） を `model` 明示で spawn し、return の要約と記録先のコメント・ラベルだけを見て次に誰を起こすかを決める（役割の指示書は `skills/develop/references/roles/`）
- **入口 0（記録先の決定）**: issue があればそれ、無ければ issue を切らず、worktree 直後の空 commit → push → Draft PR を記録先にする（受け入れ条件は PR 本文。PR 本文に issue 参照を書かない）
- **1 ループ**: W（仕様化判断の記録 → 分割判定 → `openspec new change`）→ R1（別コンテキストの仕様レビュー・2 周キャップ）→ W 再開（(3a) TDD 実装 → verify で return。本体が計測してから (3b) archive → PR → 仕様宣言）→ G（pr-review-gate 手順 1〜5・2 周キャップ）
- **モデル**: W（dev-workflow:worker）と G（dev-workflow:gate-runner）は既定 `sonnet`、R1 は既定 `opus`。G が要求するレビュアーは既定 `opus` で、編集の道具を持たない `dev-workflow:reviewer` で起こす。**W（実行役）の上限は `opus`** で、`skills/develop/references/pre-classification.md` の事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たってもそこ止まり。Fable を使うのは読んで判断する役（R1・G が要求するレビュアー）が事前分類に当たるときだけで、`subagent_type: dev-workflow:decider` で spawn する（`general-purpose` に `model: fable` は付けない。判定は `scripts/agent-model-guard.sh`）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が `throttled` / `depleted` なら全役割 `sonnet` 起点。W の SendMessage 再開は毎回 `scripts/subagent-context.sh` で測る（G は段ごとに新しく起こすので測らない）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、正本を読むまで手渡さない。残量モード（`FABLE_BUDGET_MODE`）は `skills/develop/references/decision-criteria.md`
- **エピック**: 条件・作り方・回し方・完了条件を skills/develop/references/epic.md に規定。子 issue ごとに 1 ループを並列に回し（`orca` があり本体が Orca 管理のワークツリーにいれば Orca の子ワークツリー、そうでなく本体が tmux の中にいれば tmux のウィンドウで独立した Claude Code セッションとして起動する。どちらでもないときと unmanned は `isolation: "worktree"` のサブエージェント。起動部品は `scripts/epic-launch-<名前>.sh` の差し替えで、`scripts/epic-dispatch.sh` が呼ぶ）、子が全部マージされただけでは閉じない。別セッション方式では、子がループの終わりに「用が済んだ」の印を付けたワークツリーを、親セッションが安全確認（マージ済み PR の最終コミットと HEAD の一致・作業ツリーがきれい・`LLM/` が無い）のうえで片付ける。Orca を使う場合の前提は、`orca` CLI があり本体が Orca 管理のワークツリーにいること。子セッションの起動コマンドは `EPIC_DISPATCH_CLAUDE_CMD` で決め、未設定なら `epic-dispatch.sh` の既定（`bin/cld` の絶対パス。シェル関数には頼らず、非ログインのシェルでも起動できる。説明は下の「Claude アカウントの起動時選択」）になる。Orca 側の Claude の起動コマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変える

人間が `/develop` で直接依頼した場合でも、loop-dev-agent（各リポの憲法 `docs/agent-loop.md`）が無人サイクルの中から呼ぶ場合でも同じループを回す（`--unmanned` では憲法のメインが本体を務め、G は憲法 Step 1 に委ねる）。

### pr-review-gate

PR を作成したら必ず通す品質ゲート。「PR を作った」「レビューして」「マージまで進めて」「保留を再開する」で発火する。genetta-inc の flatmate リポで実運用検証済みの手順を全リポ向けに昇格したもの。

- 実装と**別コンテキスト**（既定 Codex CLI、フォールバック Task サブエージェント）でレビューする
- **リスク宣言の positive affirmation**: 「リスクなし」か「主のリスク許容が必要」のどちらかを必ず PR コメントに残す（書かないは選べない・fail-closed）
- 動作確認の**証拠**（HEAD SHA 付き）を添付し、API で実在を実測してから `agent-review:passed` を付ける
- 収束ルール: レビューは既定2周キャップ・再レビューは差分限定（方式の書き換え後は全体レビュー）・マージ後に直せるものは blocking にしない・マージを止めるのは全周共通で `blocking` かつ `confirmed` かつ違反文の引用（または例外 3 種）を G が照合できた指摘だけで、それ以外は止めない指摘の振り分け表に通す（段 A〜E。無条件では issue にしない）・2周目の終わりに止める指摘が残れば `needs-approval` で主に上げる（3周目を自動で開けない）。レビュアーには手順 2-1 の固定書式（深刻度・検証・根拠・受け入れ条件の要否・場所・何が起きるか・直し方）で指摘を書かせ、「何が起きるか」は「こういう条件だと、こうなる」の形にする
- auto-merge workflow 配備済みリポでは passed 付与で機械マージ、未配備リポではマージは人間操作（ゲート手順は同一）

### push-guard-setup

マージ済み PR のブランチへの push を全リポで拒否するグローバル pre-push ガードの導入。

### issueify

タスクメモ・バックログ md・TODO・受け入れ条件の無い issue を、測定可能な受け入れ条件付き GitHub issue に変換する（`skills/issueify/SKILL.md`。#205 で旧プラグインから移設）。入力はテキスト・ファイルパス・引数なし（`docs/` の未チェック項目や `TODO`/`FIXME` を自動発見）・`--existing`（既存 issue の補筆のみ）。1 issue = 1 論理タスクに原子化し、受け入れ条件を「実行コマンド + 期待値」に落とし、不足だけをヒアリングして、承認後に `gh issue create` する。`/develop` の issueify フォールバックはこのスキルを同プラグイン内で Read する。

## Claude アカウントの起動時選択

複数アカウントを `accounts.json` に登録済みなら、`bin/cld` が週の進行に対する余裕が最大のアカウントを起動時に選んで `claude` を起動する。`bin/cld-account <slot-id>` はアカウントを明示する。どちらも実行ファイルで、`~/.zshrc` に関数定義は要らない。`.zshrc` に書くのは次の 2 行だけ（marketplace clone の場所を変えたときだけ、PATH の行のパスを直す）。

```zsh
export PATH="$HOME/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/bin:$PATH"
export CLD_DEFAULT_ARGS="--dangerously-skip-permissions --remote-control"   # 個人の既定フラグ。要らなければ書かない
```

`CLD_DEFAULT_ARGS` の語は空白で区切られ、`claude` の引数の先頭に置かれる（`eval` はしないので、引用符や空白を含む引数は書けない）。個人の既定フラグはここに置き、実行ファイルには埋めていない。`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` は `cld` が上書きも既定値の追加もしないので、要る人は `.zshrc` に `export` を書く。scripts の場所は `CLAUDE_HARNESS_SCRIPTS` で差し替えられる（未設定なら実行ファイル自身の位置から `../scripts`）。

関数定義で入れていた端末は、`~/.zshrc` から次を消す（関数は PATH の実行ファイルより先に解決されるので、残ると古い挙動のまま動く）。

- `cld()` と `cld-account()` の関数定義と、`unalias cld cld-account` の行
- `CLAUDE_HARNESS_SCRIPTS` を `scripts` に向けるだけの `export`（実行ファイルが自分の位置から求める）
- 関数の中に書いていた個人のフラグ（`--dangerously-skip-permissions` `--remote-control` など）は `CLD_DEFAULT_ARGS` に移す

`cld` は probe を best-effort で実行してから自動選択し、`cld-account a --resume` のような明示選択では先頭の slot id を除いた引数をそのまま `claude` に渡す（slot id が無ければ usage を出して exit 2）。selector の理由行は stderr に残る。空の選択値は既定アカウントを意味するため環境変数を空文字で設定せず `env -u` で解除する。未登録 id などで selector が非 0 なら実行ファイルも同じ status で終了し、Claude は起動しない。

エピックの子セッションは `epic-dispatch.sh launch` と、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）が、親の環境の `CLD_DEFAULT_ARGS` を子の起動コマンドへ代入として渡す。子の `--dangerously-skip-permissions` もここから来るので、親の環境に `CLD_DEFAULT_ARGS` を置く（親に値が無ければ渡らず、子は許可の確認画面で止まる）。

`usage-probe.sh` の取得先は `https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1` になった（非公開の呼び方で、予告なく変わりうる）。応答に含まれるリセット権を snapshot の `accounts.<id>.reset_grants` に書き、ステータスラインが表示する。取得に失敗したアカウントの `reset_grants` は消え、試みなかったアカウントの値は保つ。

アカウント登録簿（`accounts.json`）の一覧・追加・オン・オフは `scripts/accounts.sh` で行う。

```bash
export CLAUDE_HARNESS_SCRIPTS="${CLAUDE_HARNESS_SCRIPTS:-$HOME/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/scripts}"

# 既定アカウント（CLAUDE_SECURESTORAGE_CONFIG_DIR を設定していないシェル）を、b を足す前に登録する
env -u CLAUDE_SECURESTORAGE_CONFIG_DIR "$CLAUDE_HARNESS_SCRIPTS/accounts-init.sh" --id a --label A

"$CLAUDE_HARNESS_SCRIPTS/accounts.sh" list           # id・label・on|off・securestorage をタブ区切りで 1 行ずつ
"$CLAUDE_HARNESS_SCRIPTS/accounts.sh" add b --label B  # 認証情報の置き場所 ~/.claude-accounts/b を作って登録し、ログインするコマンドを 1 行出す
"$CLAUDE_HARNESS_SCRIPTS/accounts.sh" off b          # b をオフにする
"$CLAUDE_HARNESS_SCRIPTS/accounts.sh" on b           # b をオンに戻す
```

`add` が出したコマンドをそのまま実行して `claude` を起動し、`/login` でログインする。置き場所の基点は環境変数 `CLAUDE_ACCOUNTS_HOME`（絶対パス。既定 `$HOME/.claude-accounts`）で変えられる。同じ id の `add` は拒否される。`add` / `on` / `off` は書き換える前に登録簿を `accounts.json.bak` に控える（1 世代）。登録簿が壊れているときは何も書かずに止まる。`add` は既定アカウントのスロットを作らない。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定していないシェルで、`add` の前に `accounts-init.sh --id a --label A` を実行して既定アカウントを登録する。登録しないと、既定アカウントのセッションの使用量が `b` のものとして扱われる（`select-account.sh` は `@unregistered-default` を返す）。`add` のあとに登録すると、登録簿の順が `b`、`a` になる。

使っていないアカウントは `accounts.sh off <id>` でオフになる。オフのアカウントは `cld` の自動選択で選ばれず（理由行の `margins` に `<id>:off` と出る）、`usage-probe.sh` も使用量を取得しない。`cld-account <id>` でオフのアカウントを指定すると、戻し方を stderr に出して exit 2 で終わり、Claude は起動しない。全アカウントがオフのときは既定アカウントで起動する（理由は `default-due-to-all-off`）。既定アカウントへの縮退は `enabled` を見ないので、既定アカウント自体をオフにしていても、全アカウントがオフのとき、またはオンのアカウントがすべて欠測か 5 時間枠 90% 以上のときは、そのオフの既定アカウントで起動する。戻すときは `accounts.sh on <id>` を実行する。

Codex を使わない期間は、`accounts.json` のトップレベル（`accounts` の配列の外）に `"codex": {"enabled": false}` を足すと Codex がオフになる。

```json
{ "schema": 1, "accounts": [ ... ], "codex": { "enabled": false } }
```

オフのあいだ、develop の自動選択は Codex の使用量を読まずに Claude 既定構成を選び（reason `codex-off`）、Codex に投げる明示指定（Codex の role を含む `--profile`、旧形式の `--account`/`--model`）は戻し方を出して exit 2 で終わる。pr-review-gate の従来経路は、full 判定でも Codex を探さず呼ばず、Task サブエージェントでレビューする（`レビュー実行者: Task サブエージェント（full・Codex オフ）`）。ステータスラインは Codex 行を出さない。オフになるのは値が JSON の `false` のときだけで、`"false"`・`0`・`null` や `codex` の省略はオンとして読む。いまの設定は `python3 scripts/usage_view.py --codex-enabled` が `on` / `off` で返す。戻すときは `codex` のキーを消すか `enabled` を `true` にする。

## references/（他プラグインと共有する契約）

複数プラグインから参照される契約と、dev-workflow 内の複数スキル（develop の役割指示書と pr-review-gate）が共通で読む契約は、スキル配下ではなくプラグイン直下の `references/` に置く（#205 で旧プラグインから移設）。

| ファイル | 内容 |
|---|---|
| `references/self-verification.md` | 自己検証の共通原則（完了は主張であり証明ではない。evidence を提示してから完了を宣言する）。worktree / infra / push-guard-setup の `## 自己検証` 節が参照する |
| `references/pr-body-format.md` | エージェントが書く PR / issue 本文の型（5 セクション・軽量モード・issue の承認判断 2 節）。`.github/PULL_REQUEST_TEMPLATE.md` と W の PR 手順が参照する |
| `references/model-tiers.md` | Workflow スクリプトの `opts.model` に渡すロール別ティア → エイリアスの対応表と、残量モードによる降格。`rules/subagent-model-selection.md` が正本として指す |
| `references/workflow-execution.md` | develop の 1 ループに収まらない規模をネイティブ Workflow ツールで回す型（Review → Build → Verify・Build Contract レビュー・verifier のしきい値・`resumeFromRunId`）。スクリプトの書き方は `workflow-authoring` スキルが正本 |
| `references/subagent-waiting.md` | サブエージェントが長時間処理の完了を待つ方法の契約（完了待ちでターンを終えない・完了シグナルの経路別定義・前景ポーリングの雛形・待ち値と総待ちの上限）。develop の W / R1 / G の指示書と pr-review-gate スキルが参照する |

## テンプレート

### templates/auto-merge/

`agent-review:passed` が付いた PR を決定論的な条件（ラベル / CI green / 聖域非接触 / 緊急停止なし）だけで機械マージするロボットと、ワンクリック巻き戻し・攻撃再現テスト・staging デプロイ後の外形スモーク + auto-revert（staging を持つリポのみ）・LLM に `gh pr merge` / force push を禁じる `.claude/settings.json` の deny 断片のリポ展開用一式。展開手順（差し替え必須3点: 聖域パス・REQUIRED_CHECKS・AUTOMERGE_PAT、スモークの導線差し替え、deny のマージ）は `templates/auto-merge/README.md` を参照。

## コマンド

| コマンド | 説明 |
|---|---|
| `/develop [issue番号\|URL\|自然文]` | develop スキルを interactive モードで起動する（issue が無ければ Draft PR を記録先にする） |
| `/work-issue [issue番号\|URL\|自然文]` | `/develop` のエイリアス（旧名） |
| `/dev-workflow:synced-skills-slim` | 同期スキルを `skillOverrides` で `name-only` にする |

## loop-dev-agent との関係

loop-dev-agent（無人常設ループ）の憲法は各リポに配備された `docs/agent-loop.md` で、**正本はそれを各リポに配るリポジトリ側（harness ではない）**。harness はテンプレートを持たず、再生成や逆同期もしない（2026-08 の解散 #205 で旧テンプレートを廃止）。憲法は実装モード（Step 3）の中身をこのプラグインの `develop` スキルに委譲する。委譲の形は「憲法のメインが develop の本体として W / R1 を spawn する」で、Step 3 をサブエージェントに丸投げしない。ラベル操作・Draft PR 作成・キューの運用などの「無人運用の外形」は引き続き憲法側の責務。詳細は `develop/SKILL.md` の「実行モード」を参照。

2026-08 に解散した旧プラグイン 3 本からの移行手順と契約の新旧パスは `CHANGELOG.md` を参照。

```bash
/plugin install dev-workflow@oratta-claude-harness
```

## plugin.json の旧 description（詳細）

plugin.json の `description` は /plugin メニューに出るため 1 文に短縮した。短縮前の説明を文ごとに分けて移す。

- この開発ハーネスでの標準開発ワークフローを集めるプラグイン。
- develop: コード・スキル・コマンド・規範文書を変えるときは入口（issue 番号/URL/自然文・会話・cron・エピックの子）を問わず必ず通すワークフロー。
- 本体はオーケストレータ専任（Edit でコードを書かず、レビューを代行しない）で、作業者 W（dev-workflow:worker）・仕様レビュアー R1・ゲート実行者 G（dev-workflow:gate-runner）・G が要求するレビュアー（dev-workflow:reviewer）を model 明示で spawn し 1 ループ（入口 0 で記録先＝issue または Draft PR を確定 → W が `仕様化判断: する|しない` を記録先に記録し change 分割と openspec new change → R1 が別コンテキストで仕様レビュー（2 周キャップ・結果を `仕様レビュー: APPROVE|REQUEST_CHANGES` で記録）→ W が (3a) TDD 実装・verify まで行って return し、本体が計測してから (3b) archive・PR・仕様宣言 → G が pr-review-gate 手順 1〜5）を回す。
- issue が無ければ issue を切らず、空 commit → Draft PR を記録先にする（issue を切るのは追跡・キュー・議論が要るときだけ）。
- エピックの条件・作り方・回し方・完了条件も規定。
- 役割のモデルは pre-classification.md の事前分類（4 分類のいずれでも W は 1 周目から opus 止まりで、W の上限は opus。
- それ以外の W は sonnet 既定。
- G は sonnet 固定で判定は needs-reviewer のレビュアーが担う。
- abundant はどの役割も押し上げない）と、Fable を渡せる唯一の種別 agents/decider.md（dev-workflow:decider。
- model: fable・tools は Read/Grep/Glob の読み取り専用で、読んで判断する役はこの種別で spawn する。
- scripts/agent-model-guard.sh が PreToolUse で他種別への model: fable を deny する）と残量モード（FABLE_BUDGET_MODE。
- reserve は自動実行のみ・exhausted は全経路で opus 上限）と共有枠モード（SHARED_BUDGET_MODE。
- 全モデル共通の週次枠から導出し、throttled / depleted で全役割 sonnet 起点）で決め、W の SendMessage 再開は毎回 scripts/subagent-context.sh でコンテキスト量を測り（G は段ごとに新しく起こすので測らない）、コンテキスト上限（既定値と閾値は decision-criteria.md「コンテキスト上限」）超なら作業継続の SendMessage を送らない（無条件）。
- 前回 return を渡した同じ役割の新しいエージェント（新しい W / 新しい G）への手渡しは、前任の return の 1 行目が `工程完了: <工程名>` のときだけ行う（`工程中断:` なら再開も手渡しもしない）。
- 昇格トリップワイヤー（templates/escalation-tripwires.md）は決める役 / 実行役の分離ラダーとして残す。
- さらに hooks/hooks.json に配線した scripts/context-tripwire.sh が、サブエージェントの起動の途中でも PostToolUse（全ツール）/ PreToolUse（Edit|Write|NotebookEdit|Bash）で自分自身のコンテキストを測り、通知の上限超で締めを通知し 強制停止の上限超で編集系を deny する（計測対象は agent_id から導出するので worktree 隔離のサブエージェントでも効く）。
- /develop（/work-issue はエイリアス）: 5 分岐で記録先を確定し、issue を切ると決めたときだけ issueify スキル（skills/issueify）で起票する。
- loop-dev-agent の無人サイクルでは憲法のメインが develop の本体を務める（--unmanned）。
- pr-review-gate: PR 作成後に必ず通す品質ゲート（別コンテキストレビュー・リスク宣言と仕様宣言の positive affirmation・動作確認証拠・agent-review:passed 付与を fail-closed で行う。
- 仕様宣言は記録先（issue → 無ければ PR 自身）の `仕様化判断:` 記録と突き合わせ、記録なし PR は合格させない。
- 規範パス接触の裏取りは scripts/spec-touch-check.sh。
- レビューの重量は変更内容から light / full に事前判定し、既定と迷ったときは full＝Codex に倒す。
- auto-merge workflow のリポ展開テンプレートは templates/auto-merge/）。
- レビュー failed からの修正は実装品質起因のときだけ昇格し、失敗の原因が判断側か実行側かで決める役（dev-workflow:decider。
- model は opus → fable）と実行役（sonnet → opus が上限）のどちらか一方だけを上げる（仕様曖昧・レビュアー誤検出はモデル昇格しない。
- フォールバック記録の正本は pr-review-gate）。
- 上流の壁打ち（/opsx:explore）は呼ばず、issue 化前の壁打ちとは切り分ける。
- references/（プラグイン直下）: 複数プラグインで共有する契約 — self-verification.md（自己検証の共通原則）・pr-body-format.md（PR / issue 本文の型）・model-tiers.md（Workflow 実行のロール別ティア → opts.model エイリアス）・workflow-execution.md（1 ループに収まらない規模をネイティブ Workflow で回す型。
- Review → Build → Verify・Build Contract・verifier のしきい値）。
- 旧プラグイン 3 本は 2026-08 に解散し、契約はここへ移設（CHANGELOG.md に uninstall 手順）。
-  usage-probe はアカウントレジストリ（`accounts.json`）の全スロットを Keychain サービス名ごとにフェッチし、snapshot を schema 2（`accounts` にスロット別の値・`active` に現在のスロット id・`five_hour` も収集）で書く。
- トップレベルの従来キーは active スロットのミラー。
- 使用量の主な情報源はステータスラインのセッション記録（`.usage-sessions/`）で、probe は補助。
- 残量モードの導出と自動選択は `scripts/usage_view.py` の実効値を使う。
- fail-open はスロット単位で、失敗したスロットは前回値と取得時刻を保持する（refresh_token でのトークン更新は本体との競合を避けるため意図的に非対応）。
- scripts/subagent-context-audit.sh は同じコンテキスト量の定義で母集団（直近 N 日の subagents/agent-*.jsonl）を集計し、初回・最終の中央値と上限超の割合を 1 行 JSON とキャッシュ（SUBAGENT_CONTEXT_AUDIT_CACHE、TTL 既定 6 時間）に出す観測専用のスクリプトで、読み方の正本は docs/usage-audit.md（強制は加えず、SessionStart にも注入しない）。
-  memory-refresh: メモリ索引の肥大を検知し（scripts/memory-tripwire.sh、session-tripwires.sh 経由で SessionStart ごとに閾値判定）、削除・統合・短縮・維持に分類して主の承認を得てから手で整理するスキル（/memory-refresh）。
