<!-- BEGIN claude-harness shared instructions -->
# Claude harness 共通指示

## rules/browser-infra-env-capture.md

# ブラウザでインフラを触ったら生成物を即 env ファイルに保存する

ダッシュボード操作（Cloudflare / GCP / Stripe / Supabase / Vercel 等）で認証情報・ID・URL が生成/表示されたら、**その場で**作業 repo の `.env.local` 等に保存する。「あとでまとめて」は禁止 — ワンタイム表示のシークレットは、クリップボード上書きと再表示廃止で永遠に失われた実績がある。

- 一度しか表示されないシークレットは**表示された次のアクションで**保存する
- 保存前に `git check-ignore` で gitignore を確認する。値は echo せず `pbpaste` → 変数経由で渡し、確認は形式チェックだけにする
- キーには日付・発行元・スコープをコメントで添える。env に入れないと判断したら、どこに設定済みか・再発行方法をコメントかメモリに残す
- repo に残らないインフラ事実（アカウント名・リージョン等）は env ではなくメモリに記録する

env 保存は消失防止の仮置きで、恒久の置き場ではない。捕獲した同じターンで秘密情報の保管庫へ昇格させる（どの保管庫に置くか、誰が登録するかをその場で決める）。`capability-registry:capability-registry` スキルが入っていれば、その原則 4 を見る（個人版の索引があればそちらが置き場の正本）。


## rules/communication-style.md

# コミュニケーションスタイル

読み手は、この会話の前半を覚えていない前提で書く。月に一度だけ会議に来る人が、この1通だけを読んで理解し、判断できる状態にする。

1. **参照するときは、中身をその場で書く。** 自分が振ったラベル・番号・記号や「前回の」「上記の」で指さず、指す対象の中身を毎回書き直す。番号を添えるなら中身のうしろに置く。見出しや表で番号を振るのは構わない
   - ✅「テストの実行が遅い件については」 ❌「2つ目の問題については」
   - ✅「今月のミッションの一つ『コスト20%削減』に関連する」 ❌「今月のミッション2に関連する」
2. **比喩を作らず、言いたい内容をそのまま書く。** 独自の呼び名を作らない。比喩は誰でも知っている慣用表現に限り、ひとつの説明に複数混ぜない。専門用語は初出で一言の言い換えを添える。日常語で言えることは日常語で書き（「活用する」→「使う」）、中身のない飾り語（鍵となる、堅牢な、包括的な）を使わない。二人称は省く
   - ✅「ここを決めれば、残りは自動的に決まります」 ❌「ここがこの話題のセンターピンです」
3. **判断を求めるときは、依頼の形で推奨まで出す。** 主（判断を下す人間）に聞く理由は、主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作の 3 つだけで、理由が無ければ聞かずに進めて事後報告する。運用の形・構造の分け方・将来の拡張に効く設計の分かれ目は主の指摘が効く観点だが聞かずに決め、決めた内容と他の案を報告に載せる。項目は題名・アクション（してほしいこと）／目的・詳細・論点・推奨と根拠・リスク（アクションを取るための情報）／緊急度・ブロック（エネルギーを使うかを決める情報）／アクションに付けるリンク（どこで答えるか）。求める発言は 1 行目を題名、2 行目を `アクション:` の行に、何もしなくてよい報告は 1 行目を `主がすること: なし` にし、主の質問への答えは 1 行目に答えを書く。題名は依頼の形にし、質問にしない。目的は作業の言葉で書かない。論点（主が持っていて自分が持っていない観点を足すと結論がよくなる点）は、論点ありなら読み手の側にしかない情報の何が足りないかを、論点なし（決まりで聞いている）なら推奨どおりでよい旨と決まりが守るものを書く。論点なしは対話のセッションで題名・アクション・論点・推奨の 4 行（目的を足せば 5 行）。リスクは推奨を選ぶことで新たに生じるものだけを被害と頻度で書き、分からなければその旨と調べ方を書く。番号で物を指さず、末尾の URL にだけ置く。1 通で聞くのは 1 件。他の資料を見に行かないと判断できない書き方はしない。使う場所ごとの項目と長さの表・例と詳細は正本
4. **結論から書き、長さを内容に合わせる。** 「これから説明します」で始めない。前置きと注意書きは短くする。因果・依存・優先順位のある項目は箇条書きで並べず、文章か表で関係を見せる
5. **ヒアリングと壁打ちでは、1問ずつ自由回答で聞く。** 複数の質問を並べて選ばせる形（AskUserQuestion のような UI）は使わない。仮説が立った段階で「この理解で合っているか」と確認する形なら選択肢を出してよい。選択肢を並べてよいのは、状況を把握していて網羅的で重ならない選択肢を作れるときだけ
6. **100行を超える分析・比較・手順は、会話に流さずHTMLのページにして渡す。** 装飾は足さない

全文の正本は `~/.claude/output-styles/readable.md`（Output Style `readable`）。このファイルはそこから要点を抜いた短い版で、原則を増減させたときは両方を直す。Output Style はメインの会話にしか効かないため、サブエージェントと Output Style 未選択の環境ではこのファイルだけが効く。


## rules/destructive-git-guard.md

# 破壊的 git 操作の禁止

実事故から生まれたルール。「元に戻すだけ」という自己正当化が再犯パターン（詳細な経緯はローカルに保存し、repo には含めない）。

## ルール

1. 破壊的操作は**例外なく事前承認**。「元に戻すだけ」も破壊的操作。
2. interrupt 直後は原状回復に走らず**現状報告が先**（`git status` / `git diff` を見せてから聞く）。
3. 承認は可否だけでなく**タイミングと方法まで**確認して完了。「消していい」と言われても、いつ・どうやって消すかまで確認する。

## 頭に浮かんだ瞬間、実行ではなく質問に変換するコマンド

- `git checkout -- <path>` / `git restore <path>`（作業破棄）
- `git reset --hard` / `git clean -f`
- `git commit --amend`（push 済み）/ `git rebase -i`
- `git push <remote> main|master`（remote 名を問わない） / `git push --force[-with-lease]`
- `git branch -D`
- `--no-verify` / `--no-gpg-sign`

「戻すだけ」「消すだけ」「一瞬で終わる」と思ったら、それは承認を飛ばそうとしているサイン。手を止めて聞く。

## hook との分担

dev-workflow プラグインの hook が入っていれば、一覧のうち push 済みの `--amend` と `rebase -i` を除く操作は、その hook が Bash の実行前に止める（主の対話セッションでは確認画面が出る）。止まったら言い換えて再実行せず主に聞く。サブエージェントから呼ばれたときは確認画面を出さずに拒否されるので、子は打ち直さず作業を止めて親に返る。画面を見ている人のいないセッション（起動時に無人の印を付けたもの）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求める。拒否されたセッションや確認画面が出ないセッションでは、承認されても主が自分で実行する（入力欄の `!` か主の端末）。hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`・`git rebase -i`・ブランチ名を書かない `git push`・スクリプトファイル経由の git は止まらない。ここではこのルールだけが歯止めになる。hook が入っていない環境では、一覧の操作もこのルールだけが止める。


## rules/dev-server.md

# Dev Server Rules

**他プロジェクトのプロセスを kill してポートを確保するのは絶対禁止。**

1. `lsof -i :<port>` で使用状況を確認し、`lsof -p <PID> | grep cwd` でどのプロジェクトのプロセスか判別する
2. 停止してよいのは自プロジェクトの古いプロセスのみ。他プロジェクトが使用中なら空きポート（3001, 3002…）を使い、起動ポートを報告する
3. 同一プロジェクトでサーバーを二重起動しない。Claude が起動したサーバーはユーザーと共有し、動作確認にはそれを案内する


## rules/git-commit-policy.md

# Git Commit Policy

コミットは自律実行してよい。作業の節目ごとに細かく commit する（終わるまでコミットしないのはアンチパターン）。メッセージは「何を/なぜ」を既存履歴の形式で。

worktree セットアップ済み / `gh pr list` で過去 PR あり / PR テンプレ・CONTRIBUTING あり → **PR 運用**。どれも無ければ**ローカル main 運用**。PR 運用は作業完了＋archive（`/opsx:archive` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後、feature branch への push と `gh pr create` まで自律実行してよい。マージは明示承認。ローカル main 運用は PR を作らず、feature → main のマージと `git push origin main` は明示承認。`gh pr merge` などの直接マージは、どちらの運用でも明示承認なしに実行しない。承認が要る破壊的操作の一覧は `destructive-git-guard.md`。迷ったら安全側。

PR を作ったら `dev-workflow:pr-review-gate` スキルのゲートを必ず通す。ゲートを通っていない PR を主の承認なしにマージしない。ゲート通過後に commit を積んだら取り直す。

既存 issue の受け入れ条件を足す前（足してよいかを主に聞くならその前）に、`gh issue view <番号> -R <owner/repo> --json comments` の `develop 開始` か `実行モード:` の行があるコメントと、`gh pr list -R <owner/repo> --state open --search "<番号> in:body" --json url,body` の PR のうち本文に `Closes` / `Fixes` / `Refs #<番号>`（大文字小文字不問）があるものを確かめる（issue の本文だけでは分からない）。どちらかがあれば作業中で、新しい issue に切り出す。同じ issue に足すなら、作業中であること（PR があればその URL）を書いて主に聞く。ゲート役（G）がレビュー指摘の振り分けで足す場合は `dev-workflow:pr-review-gate` に従う。

運用の判定の詳細（迷ったときの記録先・auto-merge 配備リポでのマージ経路）は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/commit-and-pr-operations.md`。


## rules/link-when-requesting-review.md

# 人間に確認/操作を要求するときは必ずクリック可能なリンクを添える

PR・issue・ダッシュボードの操作依頼は番号だけで済ませず、フル URL を毎回添える（直前のメッセージに貼っていても再掲）。ローカルファイルは `file_path:line` 形式。目的はユーザーの手数ゼロ化 — 開けないリンクは番号だけより悪い。

- 裸 URL を説明行の次の行に 1 行 1 本で置く。Markdown リンク形式は主の表示環境でリンクテキストだけが出て URL が隠れる
- 括弧・鉤括弧で囲まない／直後に句読点を続けない
  （ターミナルは空白で URL の終端を判定するため、`（URL）` は `）` まで URL に含まれて 404 になる）


## rules/one-off-no-script.md

# 一回限りの操作はスクリプトにしない

着手前に実物を調べ、**操作の一覧**（何を・どこに・何件）を作る。一覧が手で追える量（目安 10 件以下）で繰り返す予定が無ければ、**スクリプトを書かず一覧どおりに手で実行する**。安全は実行前に丸ごと控えを取って担保し、スクリプトの堅牢化で担保しない。スクリプトは、同じ操作を繰り返す・件数が多く手で追えない、のどちらかのときだけ書く。

一回限りのもののレビュー依頼には「一回限り・監視下で実行・控えあり」と明記し、その前提で起きない指摘は反証して閉じる（直さない）。レビューは 2 周で打ち切り、残りは却下理由を書き、主に 1 問だけ聞く（文面は communication-style の 3 番目の型）。

「ディレクトリ名が空だったら」「hostname が異常終了したら」のような、この実行では起きない入力への指摘を直し始めたら、汎用ツールを作ろうとしているサイン。手を止めて一覧に戻る。

経緯と見分け方: `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/one-off-operations.md`


## rules/perspective-casting.md

# 観点の配役 — 返信前チェック

主に判断を求める前に、次の5手順を通す。過剰エスカレーション（下限違反）は、上げ漏れと同じかそれ以上に主の時間を奪う。

1. **聖域か** → 自己統治物件（CLAUDE.md・hooks・権限設定）と破壊的操作は無条件で人間承認（観点判定を飛ばす）。回復コストが判定できない操作は回復不能側に倒す。自分側（自分と自分が起こしたサブエージェント）が入れた誤りで、戻し先が差分から一意に決まるものを戻す操作は、控えを取れば回復可能として扱い承認を求めない（git の破壊的操作と聖域への変更を戻す操作は除く）
2. **判断に必要な観点を特定する**
3. **担い手は主か** → 配役表（project.md → local.md → セッション宣言）で辿る
4. **主でないなら送らず、観点スペシャリストに相談する** → 主へのエスカレーション文面を書き始めた瞬間が発火点。担い手が主の観点が1つでもあれば主へ上げる（相談・仲裁に入らない）。全観点を移譲済みなら独断せず、該当する全観点のスペシャリストに相談し、意見が割れたら仲裁エージェントが裁定する。判断基準の範囲外・policy 不在・読み取り不能は主へ上げる。裁定は実行し、主へは事後報告する。主に上げる文面は communication-style の 3 番目の型で書く
5. **結果を判例台帳に記録する**

主から配役へのフィードバックを受けたら、そのターンで配役表の該当行を更新し、判例台帳に記録する。

各手順の中身・配役表の作り方・判例の書き方・相談と仲裁の手順・カタログの変更手続きは `casting:casting` スキルが正本。観点カタログは `casting:casting` から辿れる `catalog/catalog.md`、配役表の生成は `/casting:init`、判断基準の作成は `/casting:policy-interview`。


## rules/plugin-editing.md

# Plugin Editing Rules

Claude Code プラグイン（コマンド・スキル・エージェント・ルール）を編集しようと思ったら、またはその動きをメモリで補おうと思ったら、書き始める前に読む。

- インストールされたフォルダ（`~/.claude/plugins/marketplaces/...`）は自動更新されるので直接編集しない。`~/.claude/commands/` `~/.claude/skills/` へのローカルコピーも編集しない
- `~/.claude/rules/*.md` は marketplace のフォルダを指す symlink なので、ルールもその部品を持つリポジトリ側で直す
- 部品は、その部品を持つリポジトリの開発用 clone（marketplace のフォルダの外）で直す
- 状態がおかしくなっても手動で削除しない（`/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`）
- プラグインの動きへの指摘をメモリにその場しのぎで書くときは、同じターンでその部品を持つリポジトリに直し先の issue を立て、メモリの frontmatter に `patches: <issue の URL>` を書く（閉じたら消す候補になる。書き方は dev-workflow の memory-refresh スキル）


## rules/subagent-model-selection.md

# サブエージェントのモデル選択

サブエージェント（Agent / Task ツール）を立てるときは `model` を**必ず明示**する。未指定は親セッションのモデルを継承し、調査 1 回ごとに最上位枠を無言で消費する。`subagent_type: "fork"` は常に親モデルで動く（`model` 指定は無視される）ので、役割が最上位ティア相当のときだけ使う。

モデル名ではなく**役割**でティアを決める。

| ティア | 値 | 役割 |
|---|---|---|
| 最安 | `haiku` | ファイル探索・grep 的な調査・機械的編集・fan-out ワーカー・要約 |
| 中位 | `sonnet`（重めの実装・レビューは `opus`） | 通常の実装・複数ファイルにまたがる調査・通常のコードレビュー。**迷ったらここ** |
| 最上位 | `fable` | 判断が一点に集中する仕事だけ（最終 verify・マージ可否・アーキテクチャ判断）。手を動かす仕事は聖域パスでも中位ティア止まり。使う前に `FABLE_BUDGET_MODE` を確認（未設定は conserve 扱い） |

最上位ティアは決める役の種別（`dev-workflow:decider`）でだけ spawn する。`general-purpose` / `Explore` / `Plan` に `model: fable` を付けない。

詳細（なぜ明示が必須か、枠残量モード、強制層、ワークフロー経由のロール別ティアと適用範囲）は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/model-tiers.md`。


## harness 専用規約（供給元: oratta/claude-harness の AGENTS.md）

この節は harness 配布元リポジトリを変更するときだけ適用する。相対参照の基準は供給元リポジトリ。一般 repo や flatmate には開発場所・PR 運用を広げない。Claude 固有の hook や Agent が Codex で実行済みとは扱わない。

# AGENTS.md — oratta-claude-harness

このリポジトリは Claude Code プラグインの配布元（marketplace）で、install すると `~/.claude/plugins/marketplaces/oratta-claude-harness/` に clone が置かれる。
その clone は Claude Code が自動更新するインストール成果物であって、**開発場所ではない**。開発は marketplace dir の外に置いた別の clone とその worktree で行う。

このファイルは `CLAUDE.md` と同内容で、Codex CLI などの他コーディングエージェントから参照される。両ファイルを同期して保つこと。

## 開発場所

- 開発用 clone は marketplace dir の外に置く。場所は PC ごとに違うのでパスを文書やスクリプトに固定で書かず、環境変数 **`CLAUDE_HARNESS_DEV_DIR`**（`~/.claude/settings.json` の `env`）で解決する。worktree はその clone から生やす
- marketplace dir では **feature ブランチを checkout しない・編集しない**。常に main のまま自動更新に任せる（feature ブランチにすると自動更新や `scripts/sync.sh` の pull がそのブランチ上で走り、実行時に読まれる `~/.claude/plugins/cache/` にマージ前の内容が入る）
- 他のプロジェクトで作業中に harness を直したくなったときの手順、マージ前の `claude --plugin-dir` での動作確認、マージ後の反映、変更の記録（`plugins/<name>/changes/`）、状態が壊れたときの復旧は `docs/worktree-recovery.md` を参照

## PR 運用ルール

Draft PR は早い段階で作る。目的は作業のバックアップではなく、レビューと可視化（何が進行中かを remote 側から見える状態にすること）。

- worktree 作成と同時に **Draft PR を作る**（`/wt-setup --with-pr` 推奨）
- 細かい単位で commit → push し、PR を逐次更新する
- 動作確認まで終わったら **Ready for Review** に切り替えて merge する
- main への直接 push は禁止（明示承認が必要）
- PR はマージ前ならクローズしても取り戻せる。Draft 状態は破壊的でない

旧運用（marketplace dir 配下で checkout し worktree を生やす形）からの移行と、marketplace dir に残った worktree の扱いは `docs/worktree-recovery.md` を参照。

## LLM ログ保存先

**LLM 会話ログはこのリポジトリの配下に置かない**（`./LLM/` を含む。marketplace dir 側・開発用 clone 側とも）。marketplace dir は自動更新で再 clone されると untracked ファイルごと消えるし、開発用 clone でもログは tracked の対象ではない。

- 保存先は環境変数 **`LLM_LOG_DIR`** を参照する。未設定なら **ユーザーに保存先を確認する**（デフォルトパスを勝手に決めて書き込まない。個人のディレクトリ構成を git に残さないため）
- 日報・週報など LLM ログを扱う skill を呼び出すときも、この優先順位でパスを解決する

CI を将来追加する場合の設計指針（Draft PR では skip するパターン）は `docs/ci-design.md` を参照。

## 常時注入の予算

常時注入される固定分（`rules/` / `CLAUDE.md` / `output-styles/` / 各種 `description`）の合計は、`tests/injection-budget.bats` が `tests/injection-budget.txt` の予算と突き合わせ、増えすぎても減らしすぎても落ちる。予算ファイルは聖域（機械マージの対象外）なので、値を動かす PR は本文に理由（何を削ろうとして、なぜその値にするか）を書くこと。

## 適用範囲

この開発場所と PR 運用のルールは **「Claude Code プラグインの配布元リポジトリ（install 先が自動更新される）」** だから必要なもので、一般の作業 repo には適用しない。

関連: `~/.claude/rules/git-commit-policy.md`（細かい commit 推奨、main 直 push 禁止）、`~/.claude/rules/plugin-editing.md`（プラグインをどこで編集するか）。


<!-- END claude-harness shared instructions -->
