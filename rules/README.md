# rules/ — Claude Code グローバルルール集

全プロジェクト共通で Claude Code に読み込ませる行動ルール。`~/.claude/rules/*.md` として配置すると全セッションの冒頭に読み込まれる。

実運用で繰り返し起きた問題（認知負荷・事故・手戻り）から抽出したエッセンスだけを置く。事故の具体的経緯・個人向けの詳細な分析はローカルの保存先（repo には含めない）に置く方針（`destructive-git-guard.md` の本文はこのパスを書かず「ローカルに保存」とだけ書く）。

## 導入・更新（scripts/sync.sh）

marketplace として install 済みなら、`scripts/sync.sh` を1回実行する:

```bash
~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh
```

pull（ff-only）→ `rules/*.md` を `~/.claude/rules/claude-harness/` へ、`output-styles/*.md` を
`~/.claude/output-styles/` へ symlink、まで冪等に行う。rules は出どころごとのサブディレクトリに張るので、
`~/.claude` を見れば、どの Harness が置いたファイルか分かる。以前 `~/.claude/rules/` 直下に張っていた
この harness の symlink は、新しい位置に張ったあとで消える。ファイルが増えても・rename されても
再実行するだけでよい（この harness を指す壊れた symlink は掃除される）。

- symlink 先は marketplace dir（plugin 更新で再 clone されても tracked ファイルなので復元される）
- **定期実行の足**: 定期実行は利用者の環境が担う（cron など）。鮮度の PC 横断可視化も利用者の環境の見張りに任せる
  （かつては手作業2点セット＝pull＋手動 symlink で、未実行の PC にはルールが
  一切届かないままドリフトしていた）
- **別の Harness を重ねる（overlay）**: `~/.claude/plugins/marketplaces/<名前>/` の直下に `.harness-overlay`
  （1 行目がサブディレクトリ名。`[a-z0-9][a-z0-9-]*`）を置いた marketplace があれば、同じ sync.sh が見つけて、
  その `rules/*.md` を `~/.claude/rules/claude-harness/<サブディレクトリ名>/` に、`output-styles/*.md` を
  `~/.claude/output-styles/` に張る。overlay が無い環境では何も出さず、この harness だけを張る。
  名前が不正・重複・同名の実ファイルとぶつかる overlay は警告して飛ばし、終了コードを 0 にしない
- **同名のルール**: この harness と overlay が同じファイル名のルールを持っても、張り先のディレクトリが別なので
  ぶつからず、両方が読まれる（上書きも優先順位もない）。内容が食い違うルールを作らないのは overlay を書く側の責任
- **同名の output style**: `outputStyle` は名前で選ぶので、直下に 1 階層のまま張り、同名ならこの harness を優先して
  overlay 側を警告する
- ローカル限定のルールを追加したい場合は、symlink せず `~/.claude/rules/` に実ファイルとして置けばよい
  （共存可能。sync.sh は harness と無関係な実ファイル・symlink に触らない）
- Output Style の有効化（settings の `outputStyle`）は sync.sh では書き換えない。新しい PC では
  一度だけ `/output-style readable` で選ぶ

## ファイル一覧と移設先

常時注入される `rules/*.md` は「発火条件と要点」までに留め、手順・経緯・理由の説明は移設先に置く。移設先は**任意の cwd から解決できる形**（スキル名、`~/.claude/plugins/marketplaces/oratta-claude-harness/<path>`、または Output Style が正本の場合の `~/.claude/output-styles/<name>.md`）で書く。`rules/*.md` は全プロジェクトのセッションに載るので、リポジトリ相対パスで書くと harness 以外の cwd では届かなくなる。この表が移設対応の正本。

| ファイル | 常時注入に残した要点 | 詳細の移設先 |
|---|---|---|
| `destructive-git-guard.md` | 破壊的 git 操作の事前承認必須と「戻すだけ」自己正当化への警戒。実行ではなく質問に変換するコマンド一覧（`git-commit-policy.md` から外した禁止一覧を項目単位で覆う。main/master への直接 push は remote 名を問わない）。dev-workflow の hook（`git-destructive-guard.sh`）との分担（本文は「hook が入っていれば」の条件つきで、入っていない環境では一覧の操作もこのルールだけが止める）: 一覧の操作は hook が実行前に止め（対話セッションでは確認画面）、拒否されたら承認後も主が実行する。サブエージェントから呼ばれたときは確認画面を出さずに拒否され、子は打ち直さず親に返る。画面を見ている人のいないセッション（起動時に無人の印を付けたもの）でも確認画面を出さずに拒否され、チャンネルで主に承認を求める。hook で止まらないもの（push 済みの `--amend`・`rebase -i`・ブランチ名を書かない push・スクリプト経由）はこのルールだけが止める | なし（常時性を手放せないルール。全文を残す） |
| `dev-server.md` | 他プロジェクトのプロセス kill 禁止・ポート運用 | なし（常時性を手放せないルール。全文を残す） |
| `browser-infra-env-capture.md` | ダッシュボード操作で生成された認証情報の即時 env 保存・gitignore 確認 | 保管庫（秘密情報を置く場所）への昇格手順は `capability-registry:capability-registry` スキル。本文ではスキルを「入っていれば」の条件つきで書き、製品名は書かない |
| `communication-style.md` | 参照は中身で書く・比喩を作らない・判断依頼は質問から推奨まで・ヒアリングは1問ずつ（6原則の見出し）と、サブエージェントが書く場面で要る ✅/❌ 例・専門用語の言い換え・判断依頼の 6 段の順と聞く理由の 3 つ・質問してよい例外 | 全文の正本は `~/.claude/output-styles/readable.md`（Output Style `readable`。sync.sh が symlink する先で、clone の実体は `~/.claude/plugins/marketplaces/oratta-claude-harness/output-styles/readable.md`）。`~/.claude/output-styles/` への配布（sync.sh の symlink・定期実行）はこの README の「導入・更新」節 |
| `git-commit-policy.md` | 細かい自律コミット・PR 運用 / ローカル main 運用の判定と自律実行の線引き（PR 運用は archive 完了後の push と PR 作成まで）・直接マージの禁止・ゲート通過後の取り直し（破壊的操作の一覧は `destructive-git-guard.md` に一本化） | PR 運用 / ローカル main 運用の判定と自律実行の線引きは `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/commit-and-pr-operations.md`。PR 作成後のゲートは `dev-workflow:pr-review-gate` スキル |
| `link-when-requesting-review.md` | 人間に確認を求めるときは必ずクリック可能なフル URL を添える・リンクを壊さない書式と、括弧で囲むと 404 になる理由 | なし（見出しを外しただけで全文を残す） |
| `perspective-casting.md` | 「観点の配役」返信前チェック5手順と各手順の判定（回復不能側に倒す・主へ上げる条件・全観点移譲時の相談・裁定の実行と事後報告）・フィードバックを受けたターンでの配役表更新 | 各手順の中身・配役表の作り方・判例の書き方・相談と仲裁の手順は `casting:casting` スキル |
| `one-off-no-script.md` | 一回限りの操作は操作一覧を作って手で実行・スクリプトは繰り返すか件数が多いときだけ・前提で起きない指摘は反証して閉じ、レビューは 2 周で打ち切る・汎用ツール化のサインで手を止める | 経緯（flatmate#599 / #608）と汎用ツール化の見分け方は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/one-off-operations.md` |
| `plugin-editing.md` | プラグインは自動更新されるインストール先やローカルコピーを直接編集せず、持つリポジトリの開発用 clone で直す・ルールの symlink も同じ・手動削除しない | `~/.claude/plugins/marketplaces/oratta-claude-harness/docs/worktree-recovery.md` |
| `subagent-model-selection.md` | サブエージェントの `model` 明示必須・役割ベースのティア対応表・最上位ティアの前に `FABLE_BUDGET_MODE` を確認 | 経緯・枠残量モード・強制層・適用範囲・対応表の保守は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/model-tiers.md` |

`README.md` はこのディレクトリで唯一 symlink されず、常時注入の集計にも入らない。だから表が長くなっても固定分は増えない。
