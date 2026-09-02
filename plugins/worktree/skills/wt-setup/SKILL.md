---
name: wt-setup
description: Git worktree の開発環境セットアップ。worktree 作成後に実行する。「worktreeセットアップ」「ワークツリー初期化」で起動。引数で後続作業指示を渡せる。`--with-pr` で Draft PR 常時バックアップ運用（プラグイン自体の repo 向け）。
version: 1.7.0
model: sonnet
context: fork
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# wt-setup — Worktree セットアップスキル

Git worktree作成後に実行し、開発に必要なファイル・設定を整えるスキル。

## 自動実行との関係（このスキルを手で呼ぶ必要がある場面）

このプラグインの hooks（`hooks/hooks.json`）が、**Step 1 に相当する部分は自動で済ませている**。

| 経路 | 何が起きるか |
| --- | --- |
| `--worktree` / Agent の `isolation:"worktree"` / background session | `WorktreeCreate` hook（`scripts/wt-create-hook.sh`）が worktree 作成を代行し、その場で `wt-setup.sh` まで実行する |
| 手動の `git worktree add` | `SessionStart` hook（`scripts/wt-setup-guard.sh`）が、その worktree の**初回セッションだけ** `wt-setup.sh` を実行し、残タスクを context に載せる |

どちらの経路でも `<gitdir>/wt-setup-done` に済みマーカーが置かれ、2 回目以降は無出力で何もしない。

したがってこのスキルを明示的に起動するのは、次のいずれかの場合になる:

- **`.worktreeinclude` の生成が必要**なとき（Step 2。hook は LLM 判断が要るこの処理をしない）
- **`--with-pr` で Draft PR を作りたい**とき（Step 4。hook は push/PR 作成のような外向き操作をしない）
- 依存インストールを含めてセットアップをやり直したいとき
- hook が無効な環境（プラグイン未インストール等）で手動セットアップするとき

`wt-setup.sh` は冪等なので、hook 実行後に改めてこのスキルを走らせても壊れない。

## 引数の扱い

コマンド引数（`$ARGUMENTS`）には以下を含めることができる:

1. **`--with-pr` フラグ**: worktree 作成と同時に空 commit → push → Draft PR を作る。Claude Code のプラグイン自動更新で marketplace 配下の worktree が吹き飛ぶ事故に備える用途。プラグイン自体のリポジトリ（marketplace dir 配下に置かれる前提）でのみ使う想定。
2. **後続作業指示**: セットアップ後に着手する作業の自然文。`--with-pr` と併用可。

例:

- `/wt-setup issue#3の対応`（後続作業のみ）
- `/wt-setup --with-pr`（PR ブートストラップのみ）
- `/wt-setup --with-pr issue#3の対応`（両方）

引数を以下の順で処理する:

1. `--with-pr` フラグが含まれていれば抽出して `WITH_PR=true` とする
2. 残った文字列を「後続作業指示」として保持する
3. Step 1〜3 で通常のセットアップを実行
4. `WITH_PR=true` なら Step 4 で Draft PR ブートストラップを実行
5. Step 5 で完了レポート
6. 後続作業指示があれば Step 6 で着手する

## 禁止事項

- `.claude/` ディレクトリに対する直接操作（削除、移動、リンク作成等）は絶対に実行しない
- `.claude/` の操作は全てスクリプト（wt-setup.sh）に委譲する
- スクリプトの処理を「効率化」「最適化」する目的で独自コマンドを実行しない。スクリプトが担当する処理はスクリプトに任せること

## 前提条件

- 現在のカレントディレクトリがworktree内であること
- メインリポジトリ（worktreeの親）が存在すること

## 実行フロー

### Step 1: セットアップスクリプトを実行

以下のスクリプトを実行する。

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/marketplaces/oratta-claude-harness/plugins/worktree}/scripts/wt-setup.sh"
```

スクリプトの出力を確認し、出力内容に基づいて後続ステップを判断する。

### Step 2: .worktreeinclude が存在しない場合のみ — 生成

スクリプト出力に「.worktreeinclude: なし」と表示された場合、以下の手順で生成する。
既に存在する場合はこのステップをスキップ。

1. メインリポの `.gitignore` を読む
2. 既定パターンをスクリプトから書き出す（テンプレを手で書き起こさない。文面はスクリプトが正本）:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/marketplaces/oratta-claude-harness/plugins/worktree}/scripts/wt-setup.sh" \
  --print-default-worktreeinclude > .worktreeinclude
```

3. `.gitignore` の内容を以下の分類ルールで自動判定し、パターンを追加する（ユーザーに確認しない）:
   - **含める**: `.env*` 系、`*.pem`, `*.key` 系、`config/secrets*` 系（開発に必要な環境・秘密鍵ファイル）
   - **除外する**: `node_modules`, `out`, `dist`, `build`, `.next`, `*.log` 系（ビルド成果物・一時ファイル。再生成可能）
   - **既定では入れない（オプトインのみ）**: `.vercel`。`vercel link` / `vercel env pull` が
     `.vercel/.env.production.local` を作ると本番環境変数一式が全 worktree に複製されるため（issue #55）。
     その repo で本当に必要な場合だけ、既定テンプレのコメント行を有効化する。
4. repo 固有の除外は `!<pattern>` 行で書ける（例: `!.env.production`）。バックアップ・エディタ残骸は
   スクリプト側の既定除外に入っているので書く必要はない
5. worktree内に `.worktreeinclude` を作成（作業コミットに含めてマージする。以降のworktreeではチェックアウト時に存在するため再生成不要）
6. 作成後、再度スクリプトを実行してファイルをコピーする

**コピー対象は gitignore されたファイルだけ**（issue #80）。`.env.*` のような glob は
`.env.local.example` のような**追跡済み**ファイルにも一致するが、スクリプトはコピー直前に
メインリポ側で `git check-ignore` / `git ls-files` を確認し、git が管理しているファイルは
`skipped (tracked): <path>` と出して飛ばす。メインリポの checkout が古いと、その古い内容が
worktree の追跡ファイルを上書きして「誰も触っていないのに行が消えた」差分になるため。
`.worktreeinclude` にパターンを足すときも、この「gitignore されたものだけ運ぶ」契約は変わらない
（追跡済みファイルを持ち込みたい場合は、そもそも worktree のチェックアウトに入っている）。

#### 配布しないもの: バックアップ・エディタ残骸（issue #55）

`.env.*` のようなワイルドカードは `.env.local.bak-stripe-migration` のような**バックアップ**にも一致する。
実際にローテート前の本番値が worktree に焼き付いていた（Uranai で実証）ため、スクリプトは
`*.bak` / `*.bak-*` / `*.backup` / `*.old` / `*.orig` / `*.save` / `*.rej` / `*~` / `*.swp` / `*.tmp` /
8 桁日付サフィックス（`.env.local.20260101`）を**常に除外**し、`skipped (excluded): <path>` と出す。

この除外はスクリプト側の既定として持つ（各 repo の `.worktreeinclude` の明示列挙に置き換えない）。
理由は 2 つ:

- 既に `.env.*` を配っている repo の `.worktreeinclude` を 1 つも書き換えなくても巻き込みが止まる
- `.env.development.local` のような正当な派生ファイルは repo ごとに増えるので、列挙し続ける運用は破綻する

repo 固有の除外は `.worktreeinclude` に `!<pattern>` 行を書く（ベース名・パスのどちらにも照合）。

#### 本番値ガード: 警告して続行（issue #55）

コピー対象の中身に本番クレデンシャルらしきパターン（Stripe の `sk_live_`/`rk_live_`、
Supabase の service_role キー、本番 DB ホスト、AWS アクセスキー）を見つけると、
スクリプトは `WARNING: 本番値の疑い: <path> — <種別>` を出す。

**挙動はスキップではなく「警告して続行」**。本番データの調査や移行スクリプトの検証など、
開発中に本番キーを意図して置く正当な用途があり、そこで黙ってファイルが配られない方が
（気付かないまま動かないという形で）危険なため。配りたくない場合は `!<pattern>` 行で除外する。

警告は**種別だけを出し、検出した値は出力しない**（セッションログに秘密が残るのを防ぐ）。
`SUPABASE_SERVICE_ROLE_KEY` のような変数名にも反応するので、dev プロジェクトのキーでも警告は出る
（誤検出を許して見落としを減らす側に倒している）。

### Step 3: 依存インストール（任意）

スクリプト出力に `NEEDS_NPM_INSTALL=true` と表示された場合、`npm install` を実行するか確認する。
`Gemfile` がある場合は `bundle install` を提案。

### Step 4: Draft PR ブートストラップ（`--with-pr` フラグがある場合のみ）

`$ARGUMENTS` に `--with-pr` が含まれている場合のみ実行する。それ以外はスキップ。

事前チェック:

1. `git remote get-url origin` が成功すること（origin remote が存在）
2. `git branch --show-current` の結果が `main` / `master` ではないこと（feature branch であること）
3. `gh pr list --head <branch>` で既に PR が無いこと（既存なら URL を報告してスキップ）

ブートストラップ手順:

```bash
BRANCH=$(git branch --show-current)
BASE=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)

# 1. 空 commit
git commit --allow-empty -m "chore: init draft PR for ${BRANCH}"

# 2. push（-u で upstream 設定。失敗しても続行できるよう || true は付けない）
git push -u origin "${BRANCH}"

# 3. Draft PR 作成（--head を明示することで upstream tracking 問題を回避）
gh pr create --draft \
  --head "${BRANCH}" \
  --base "${BASE}" \
  --title "${BRANCH}" \
  --body "$(cat <<EOF
## Draft PR

これは作業中の Draft PR です。worktree 作業内容を remote にバックアップする目的で自動作成されました。
（Claude Code のプラグイン自動更新で marketplace 配下の worktree が吹き飛ぶ事故に備えるため）

## CI Status

Draft の間 CI は skip 想定（\`if: github.event_name == 'push' || github.event.pull_request.draft == false\`）。
Ready for Review に変えると CI 起動。Preview deploy 系は Draft でも走らせて OK。

## 復元手順（worktree が消えたとき）

\\\`\\\`\\\`bash
git fetch origin ${BRANCH}
git worktree add ~/.superset/worktrees/<uuid>/${BRANCH} ${BRANCH}
cd ~/.superset/worktrees/<uuid>/${BRANCH}
# Claude Code を立ち上げて /wt-setup で開発環境復元
\\\`\\\`\\\`

session.jsonl のような ephemeral ファイルは復元対象外。

🤖 Generated by /wt-setup --with-pr
EOF
)"
```

エラー時:

- `gh pr create` が「既に PR が存在」と返したら、その URL をユーザーに報告してスキップする
- `git push` が失敗したら、原因をユーザーに報告して以降のステップを中止する
- `gh` コマンドが見つからない場合は、その旨を報告してスキップ（後続作業には進む）

### Step 5: 完了レポート

スクリプトの出力結果を元に、セットアップ結果をまとめてユーザーに報告する。
`.worktreeinclude` を新規生成した場合は、含めたパターンと除外したパターンの一覧もレポートに含める。
`--with-pr` で Draft PR を作った場合は PR URL もレポートに含める。

### Step 6: 後続作業の実行（後続作業指示がある場合のみ）

`$ARGUMENTS` から `--with-pr` を取り除いた残りに作業指示が含まれている場合、完了レポートに続けてその作業に着手する。

- 引数を新規ユーザー指示として扱い、通常通りタスク分解・実装を進める
- 完了レポートと作業着手は明確に区切る（例: 「セットアップ完了。続けて『issue#3の対応』に着手します。」）
- 残り引数が空の場合はこのステップをスキップして終了

## エラーハンドリング

- スクリプトがエラー終了した場合: エラー出力をそのままユーザーに報告する
- セットアップでエラーが発生した場合、引数で指定された後続作業には着手しない（先にエラー解消が必要）
- Step 4 の Draft PR ブートストラップで `gh` 由来のエラーが出た場合: Step 5・Step 6 は通常通り続行する（PR は手動で作り直せるため）

## 自己検証

完了宣言の前に、成果物の evidence を確認する（原則: `plugins/dev-workflow/references/self-verification.md`）。

- 作成した worktree が登録されていることを確認する: `git worktree list` に対象パスが現れる。
- `--with-pr` 実行時は Draft PR が作成されたことを確認する: `gh pr view --json isDraft,url` で `isDraft` が true。
- カレントディレクトリが作成した worktree 内であり、後続作業指示に着手できる状態が整っていることを確認する。
