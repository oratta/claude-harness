# Changelog — dev-workflow

## 2.2.0 — 2026-09-04: usage snapshot schema 2（複数アカウント対応）

`usage-probe.sh` を複数の Claude アカウントに対応させ、`~/.claude/.usage-snapshot` を schema 2 に拡張した。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると `CLAUDE_CONFIG_DIR` を共有したまま Keychain の認証情報だけを分けられるが、probe が Keychain のサービス名を `Claude Code-credentials` に固定していたため、常に既定アカウントの値しか取れず `FABLE_BUDGET_MODE` の導出もそこに固定されていた。

### アカウントレジストリ（新規）

`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）にスロットを列挙する。**ファイルが無ければ既定スロット 1 つとして扱われ、挙動も出力も従来と変わらない。** 生成は `scripts/accounts-init.sh` を登録したいアカウントのシェルで実行する（`CLAUDE_SECURESTORAGE_CONFIG_DIR` の実値をそのまま書き出すので、パスの転記ミスが起きない）。

Keychain サービス名の導出は Claude Code 本体と同じ規則: `securestorage` が空なら `Claude Code-credentials`、そうでなければ `Claude Code-credentials-` + NFC 正規化した値の sha256 先頭 8 桁。

### snapshot schema 2

| キー | 内容 |
|---|---|
| `schema` | `2` |
| `active` | 現在アクティブなスロット id |
| `accounts.<id>` | `label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active` |
| トップレベルの上記同名キー | **active スロットのミラー**（独立に計算しない） |

トップレベルのミラーを残しているのは、`session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出と statusline の 6 時間鮮度ゲート（`fetched_at` を読む）を無改修で動かすため。schema 2 は追加のみなので、古い読み手も新しい読み手も同じ snapshot で動く。

`fetched_at` は **そのスロットの値を実際に取得できた時刻**であって probe の実行時刻ではない。fail-open で前回値を引き継いだスロットは前回の `fetched_at` を保つ。

### fail-open がスロット単位になった

あるスロットのフェッチが失敗しても、そのスロットは既存 snapshot の前回値（`fetched_at` 込み）を引き継ぎ、他スロットの新しい値は書く。使っていないアカウントは OAuth アクセストークンが期限切れでフェッチが落ちるのが常態なので、1 スロットの失敗で snapshot 全体の更新が止まると使い物にならない。

全スロットが失敗したとき、および組み立て・書き込みが失敗したときに snapshot を書かない従来の契約はそのまま。

**API のエラーレスポンスも失敗として扱う。** HTTP 401 / 429 / 5xx でも API は正しい JSON のオブジェクト（`{"type":"error", ...}`）を返すので、「JSON として読めた」を成功の判定に使うと、期限切れトークンのスロットの前回値を全 `null` で上書きしてしまう。HTTP ステータスを見たうえで、使用量の数字が 1 つも取れなかったレスポンスも失敗と判定する。

### そのほか

- `Authorization` ヘッダを `curl --config -` で stdin から渡すようにした。コマンドライン引数に載せると、同一ユーザーの任意プロセスと root から `ps auxww` でアクセストークンが読める
- `label` / `securestorage` に制御文字を含むスロットは捨てる。スロット一覧は区切り付きで受け渡すため、区切りを壊すと列がずれて実在しない「幽霊スロット」が生まれ、`securestorage` が空になって既定サービス名に一致し active を乗っ取りうる
- `accounts-init.sh` が `--id` / `--label` を値なしで渡されたときに無限ループしていたのを修正（`shift 2` が失敗しても `set -e` が無いため回り続けていた）。書き込みの一時ファイル名も固定名から `mkstemp` に変更（アカウントごとに別シェルで実行する運用なので、同時実行で奪い合う）
- `label` は文字数ではなく**表示幅**（全角を 2 桁と数える）で扱い、8 桁を超えたら切り詰める。日本語のラベルで statusline の列がずれるのと、長い label で全行が押し出されるのを防ぐ
- probe のテスト経路の判定を `env | grep` から既知のキー名の直接参照に変更（改行を含む無関係な変数への誤マッチと、空文字設定時に本番経路へ落ちる従来挙動との食い違いを解消）

### refresh_token は使わない

Keychain の `refreshToken` でアクセストークンを更新すれば非 active アカウントの値も新鮮に保てるが、リフレッシュはトークンをローテートするため、Claude Code 本体が同じ refresh_token でリフレッシュしたときに無効化され、そのアカウントがログアウトしうる。使用量表示のために認証を壊すのは割に合わないので意図的に非対応とし、鮮度は statusline 側の経過時間表示で扱う。

## 2.1.0 — 2026-08-31: loops / longrun / lr の解散と契約の移設（#205）

`loops`・`longrun`・`lr` の 3 プラグインを解散し、中に埋まっていた契約だけを dev-workflow に移した（oratta/claude-harness#205、epic #208）。手順書としての層はモデルが自力でできるようになったので持たない。契約は他プラグインからも参照されるため、スキル配下ではなくプラグイン直下の `references/` に置く。

### install 済み環境でやること

marketplace から 3 エントリが消えるため、install 済みの環境ではキャッシュに残った旧プラグインを外す:

```
/plugin uninstall loops@oratta-claude-harness
/plugin uninstall longrun@oratta-claude-harness
/plugin uninstall lr@oratta-claude-harness
/reload-plugins
```

各プロジェクトの `.claude/settings.local.json` の `enabledPlugins` に `loops@oratta-claude-harness` / `longrun@oratta-claude-harness` / `lr@oratta-claude-harness` のキーが残っていれば外す（skill-pack の `enabledPlugins` 編集の規約に従う）。

### 契約の新旧パス

| 旧（loops / longrun / lr） | 新（dev-workflow 2.1.0） | 備考 |
|---|---|---|
| `plugins/loops/references/self-verification.md` | `plugins/dev-workflow/references/self-verification.md` | 自己検証の共通原則。6 スキルの `## 自己検証` 節が参照（旧 `longrun-plan` は対象から外れた） |
| `plugins/loops/references/pr-body-format.md` | `plugins/dev-workflow/references/pr-body-format.md` | PR / issue 本文の型。内容は同じ。`.github/PULL_REQUEST_TEMPLATE.md` と `roles/worker.md` の参照先も差し替え |
| `plugins/longrun/references/model-tiers.md` | `plugins/dev-workflow/references/model-tiers.md` | Workflow 実行のロール別ティア → `opts.model` エイリアス。longrun 固有の resolver・plan.md の割り当て節・`LONGRUN_AUTOMATED` は廃止。`rules/subagent-model-selection.md` の参照先も差し替え |
| `/loops:issueify`（`plugins/loops/skills/loops-issueify/SKILL.md`） | `plugins/dev-workflow/skills/issueify/SKILL.md`（スキル名 `issueify`） | `/develop` の issueify フォールバックは同プラグイン内を Read する。goalify・レシピへの参照は本文に取り込んで解消 |
| `/lr:e` / `/longrun:exec`（plan.md → Workflow スクリプト生成） | ネイティブ Workflow ツール。型は `plugins/dev-workflow/references/workflow-execution.md`、書き方は `workflow-authoring` スキル | 昇格トリップワイヤー 1 と develop SKILL.md の乗り換え先を差し替え。Build Contract レビュー・verifier のしきい値（品質 100% / 完成度 80%）・schema 付きレポートの知見はこの 1 ファイルに集約 |
| `/lr:p` / `/longrun:plan`（brain dump → plan.md） | `/opsx:explore`（openspec ネイティブ） | develop は上流の壁打ちを呼ばない方針のまま。トリップワイヤー 3 の構造的決定の逃がし先も `/opsx:explore` |
| `/loops:review-queue` | **廃止** | このリポに呼び出し元が無く、読み取り専用ビューのデータ源（GitHub Project「Review Queue」）は直接使える。人が捌く PR は `gh pr list --label human-merge --state open` |
| `plugins/loops/references/feature-list-format.md` | **廃止** | 唯一の利用者 `recipes/routine-long-build.md` が同時に消えた。外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ |
| `plugins/loops/templates/agent-loop-template.md`（憲法テンプレ） | **廃止**。各リポの `docs/agent-loop.md`（flatmate が保守）が正本 | harness からの再生成・逆同期はしない |
| `plugins/loops/tests/integration.bats` の S130 / S130b / S131 / S132 / S133 / S139 | `tests/marketplace-sync.bats`（リポ直下） | marketplace と `plugins/` の整合ガード。特定プラグインに属さないので loops と一緒に消さない |
| レシピ 10 本・`loops-design`・`goalify`・`dev-agent-start`・longrun の agents / schemas / scripts | **廃止**（git 履歴のみ） | 参照ゼロ。必要なら `git log --diff-filter=D -- plugins/loops plugins/longrun plugins/lr` から復元できる |

`openspec/specs/` の `loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（38 件）も削除した。生き残る契約の要件は `dev-workflow-shared-references`・`dev-workflow-issueify`・`marketplace-plugin-sync`・`loops-longrun-retirement` に引き継いだ。

### flatmate 側で追従が必要なもの

genetta-inc/flatmate#458 で追従する（https://github.com/genetta-inc/flatmate/issues/458）:

- `docs/agent-loop.md`（loop-dev-agent 憲法）: 正本宣言後は flatmate 側で自立。本文の `/loops:issueify`・`plugins/loops/references/pr-body-format.md`・`loops-dev-agent-install` の参照を新パスに
- `docs/burn-mode.md`: 「残り PR を人が捌く経路」の `/loops:review-queue` を `gh pr list --label human-merge` / Project 直接参照に
- issue テンプレート（`agent-task.md` 等）の書式の正本パスを `plugins/dev-workflow/references/pr-body-format.md` に
- リポジトリローカル pre-push フック（main 拒否込み）の雛形と挙動テスト（旧 `pre-push-merged-pr-guard.bats`）が harness から消えた。以後の正本は `new-resident` 側

### その他の変更

- `templates/escalation-tripwires.md`: unmanned の組み込み先を憲法（flatmate 保守）に、乗り換え先を `references/workflow-execution.md` と `/opsx:explore` に
- `skills/develop/SKILL.md`: 「longrun:plan を呼ばない理由」→「上流の壁打ち（`/opsx:explore`）を呼ばない理由」、参照節に憲法の正本宣言と Workflow 実行の型
- `skills/push-guard-setup/SKILL.md`: ローカル層の設置者を「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に
- 参照を直した他プラグインの patch bump: casting 0.4.1・experience-to-skill 0.3.2・skill-pack 0.2.1・infra 0.5.7・weekly-report 1.1.3・daily-report 0.3.5・worktree 2.12.3
