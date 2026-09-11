# rules/ — Claude Code グローバルルール集

全プロジェクト共通で Claude Code に読み込ませる行動ルール。`~/.claude/rules/*.md` として配置すると全セッションの冒頭に読み込まれる。

実運用で繰り返し起きた問題（認知負荷・事故・手戻り）から抽出したエッセンスだけを置く。事故の具体的経緯・個人向けの詳細な分析はローカルの `~/.claude/rules-archive/`（repo には含めない）に保存する方針。

## 導入・更新（scripts/sync.sh）

marketplace として install 済みなら、`scripts/sync.sh` を1回実行する:

```bash
~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh
```

pull（ff-only）→ `rules/*.md` を `~/.claude/rules/` へ、`output-styles/*.md` を
`~/.claude/output-styles/` へ symlink、まで冪等に行う。ファイルが増えても・rename されても
再実行するだけでよい（この harness を指す壊れた symlink は掃除される）。

- symlink 先は marketplace dir（plugin 更新で再 clone されても tracked ファイルなので復元される）
- **定期実行の足**: flatmate 住人が起動ルーティン（boot.sh）で毎世代実行するため、住人が稼働する
  PC は自動で最新に保たれる。鮮度の PC 横断可視化は flatmate の agent-status ハートビートが担う
  （flatmate#362。かつては手作業2点セット＝pull＋手動 symlink で、未実行の PC にはルールが
  一切届かないままドリフトしていた）
- ローカル限定のルールを追加したい場合は、symlink せず `~/.claude/rules/` に実ファイルとして置けばよい
  （共存可能。sync.sh は harness と無関係な実ファイル・symlink に触らない）
- Output Style の有効化（settings の `outputStyle`）は sync.sh では書き換えない。新しい PC では
  一度だけ `/output-style readable` で選ぶ

## ファイル一覧と移設先

常時注入される `rules/*.md` は「発火条件と要点」までに留め、手順・経緯・理由の説明は移設先に置く。移設先は**任意の cwd から解決できる形**（スキル名、または `~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`）で書く。`rules/*.md` は全プロジェクトのセッションに載るので、リポジトリ相対パスで書くと harness 以外の cwd では届かなくなる。この表が移設対応の正本。

| ファイル | 常時注入に残した要点 | 詳細の移設先 |
|---|---|---|
| `destructive-git-guard.md` | 破壊的 git 操作の事前承認必須と「戻すだけ」自己正当化への警戒。実行ではなく質問に変換するコマンド一覧 | なし（常時性を手放せないルール。全文を残す） |
| `dev-server.md` | 他プロジェクトのプロセス kill 禁止・ポート運用 | なし（常時性を手放せないルール。全文を残す） |
| `browser-infra-env-capture.md` | ダッシュボード操作で生成された認証情報の即時 env 保存・gitignore 確認 | 1Password / Actions secrets への昇格手順は `capability-registry:capability-registry` スキル |
| `communication-style.md` | 参照は中身で書く・比喩を作らない・判断依頼は背景から推奨まで・ヒアリングは1問ずつ（6原則の見出し）と、サブエージェントが書く場面で要る ✅/❌ 例・専門用語の言い換え・判断依頼の形式の見本・質問してよい例外 | 全文の正本は `~/.claude/plugins/marketplaces/oratta-claude-harness/output-styles/readable.md`（Output Style `readable`） |
| `git-commit-policy.md` | 細かい自律コミット・PR 運用 / ローカル main 運用の判定と自律実行の線引き・直接マージの禁止・ゲート通過後の取り直し（破壊的操作の一覧は `destructive-git-guard.md` に一本化） | PR 運用 / ローカル main 運用の判定と自律実行の線引きは `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/commit-and-pr-operations.md`。PR 作成後のゲートは `dev-workflow:pr-review-gate` スキル |
| `link-when-requesting-review.md` | 人間に確認を求めるときは必ずクリック可能なフル URL を添える・リンクを壊さない書式 | なし（要点のみで完結） |
| `perspective-casting.md` | 「観点の配役」返信前チェック5手順と各手順の判定（回復不能側に倒す・主へ上げる条件・全観点移譲時の相談・裁定の実行と事後報告）・フィードバックを受けたターンでの配役表更新 | 各手順の中身・配役表の作り方・判例の書き方・相談と仲裁の手順は `casting:casting` スキル |
| `one-off-no-script.md` | 一回限りの操作は操作一覧を作って手で実行・スクリプトは繰り返すか件数が多いときだけ・前提で起きない指摘は反証して閉じ、レビューは 2 周で打ち切る・汎用ツール化のサインで手を止める | 経緯（flatmate#599 / #608）と汎用ツール化の見分け方は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/one-off-operations.md` |
| `plugin-editing.md` | プラグイン編集は marketplace dir の外の開発用 clone で・ローカルコピー禁止・`CLAUDE_HARNESS_DEV_DIR` で場所を解決・worktree の前に fetch・`/wt-setup` で worktree を作らない・Draft PR まで作る・手動削除しない | `~/.claude/plugins/marketplaces/oratta-claude-harness/docs/worktree-recovery.md` |
| `subagent-model-selection.md` | サブエージェントの `model` 明示必須・役割ベースのティア対応表・最上位ティアの前に `FABLE_BUDGET_MODE` を確認 | 経緯・枠残量モード・強制層・適用範囲は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/model-tiers.md` |

`README.md` はこのディレクトリで唯一 symlink されず、常時注入の集計にも入らない。だから表が長くなっても固定分は増えない。
