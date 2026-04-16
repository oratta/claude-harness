---
name: experience-to-skill
description: 作業完了時に LLM 駆動で自動コミットを実行する。**LLM（自分）が assistant 応答として作業完了を報告する時（「〜しました」「〜を追加しました」「〜完了です」「修正しました」「更新しました」等）は必ずその報告を書く直前にこのスキルを起動する。**ユーザーの完了フレーズ（「完了」「終わった」「動作確認して」「確認お願いします」「archive して」「commit して」「done」「finished」「完成」「ok」「OK」）、`longrun:archive` / `openspec:archive` 完了イベントでも自動起動。自セッション編集ファイルのみを安全にステージングし、Conventional Commits subject + Intent/Result/Prompted-by 構造化 body を持つコミットメッセージを生成、二重 secret filter で credentials 混入を防ぐ。Stop hook は使わないためマルチセッション並行実行時も衝突しない。単発コミットでは `/e2s:commit` を明示起動しても同じワークフローが走る。archive トリガー後は続いて `/e2s:ok` による verified タグ付与を提案する。作業終了・コミット作成・スキル化を狙った履歴構築・マルチセッション安全なコミット管理・LLM 応答境界でのコミットに言及があれば積極的に起動。
allowed-tools: Read, Bash, Glob, Grep
---

# experience-to-skill — LLM駆動の都度コミット・スキル

このスキルは Stop hook を使わず、LLM 自身（現在のセッション）が自分の作業履歴を元にコミットを実行する。マルチセッション race condition を構造的に回避し、セッション文脈を活かした高品質なコミットメッセージを生成する。

## 起動タイミング

**auto-trigger 条件（以下のいずれかに該当したら起動）:**

### Trigger 1: LLM（自分）の作業完了報告（★ 最優先・最頻出）

**自分が assistant 応答として次のパターンで作業完了を報告しようとしている時、その応答を書く前にこのスキルを起動する。**

報告パターンの例：

- 「〜を実装しました」「〜を追加しました」「〜を作成しました」
- 「〜を更新しました」「〜を修正しました」「〜を削除しました」
- 「〜完了です」「〜できました」「〜終わりました」
- 「実装が終わりました」「作業が完了しました」「反映しました」
- plan.md / tasks.md / openspec 系ファイルの更新完了を伝える報告
- `TodoWrite` でタスクを `completed` にマークした直後の総括報告
- ファイル作成・編集・削除を伴う tool call が1つ以上走った後、ユーザーへの応答本文を書こうとしている時

**運用ルール:**

- 応答を書き始める前に頭の中で「今、作業完了を伝えようとしているか？」を自問する
- YES なら**応答本文を出力する前に**本スキルを起動
- スキル実行（コミット）を終えてから、あらためてユーザーへの報告を書く
- ただし Precondition（差分ゼロ）にかかれば何もせず通常通り応答する
- 「調べました」「確認しました」のような読み取りだけの報告は対象外（差分ゼロで Precondition 通過）

これは Stop hook を使わずに **LLM 応答境界 ≈ コミット境界** を実現するための自己規律。Trigger 1 を無視して報告を書いてしまうと、ユーザー側からは「黙って編集→報告」の流れで変更が untracked のまま溜まっていくので、必ず優先する。

### Trigger 2: ユーザーメッセージの完了示唆フレーズ

ユーザーメッセージに次のいずれかが含まれる：`完了`, `終わった`, `動作確認して`, `確認お願いします`, `archive して`, `commit して`, `お願いします`, `done`, `finished`, `完成`, `ok`, `OK`

### Trigger 3: archive 系コマンド成功完了

`longrun:archive` / `openspec:archive` スラッシュコマンドの主要ワークフローが成功完了した直後。archive 側からこのスキルを明示起動する。

### Trigger 4: 明示起動

ユーザーが `/e2s:commit` を実行。

---

**どの trigger でも起動前に一度 git status を確認し、差分ゼロなら即座に終了する（Precondition 参照）。**

## Precondition: 差分ゼロ時は即座に終了

コミット実行フローに入る前に必ず：

```bash
git diff --cached --quiet && git diff --quiet
```

この両方が成功（exit 0）なら working tree が clean なので、**何もせず silently 終了**する。ユーザーに「コミットするものがありません」と一言だけ報告してよい。空コミットは絶対に作らない。

## Step 1: 自セッション編集ファイルの特定（context から）

**外部状態ファイルは使わない。** LLM 自身のこのセッションにおけるツール呼び出し履歴（Edit / Write / MultiEdit / Bash での `mv` / `rm` / `mkdir` / `cp` など）を context 内で確認し、編集・作成・削除したファイルのリストを頭の中で構築する。

- `memory/e2s/sessions/*` のようなファイルを読み書きしない
- `.git/e2s/*` のような git ref も使わない
- 純粋に「自分が今セッション中にどのツールでどのファイルを触ったか」を思い出す

**context 圧縮が起きている場合:**

- 圧縮要約レベルの記憶（どのファイルを編集したか）は通常残る
- 判断に迷うファイルがあれば後続ステップで `git diff <file>` を読んで内容から「自分の作業か」判定
- それでも分からなければユーザーに確認する

## Step 2: git status と照合してステージング集合を決定

```bash
git status --porcelain
```

出力行を解析し、変更のあるファイル（modified / added / deleted / renamed）を列挙する。Step 1 で構築した「自セッション編集ファイルリスト」と**交集合**を取り、それがステージング候補集合となる。

- リストにあるが git status に無い → 既にコミット済みか Step 1 の誤検出。除外
- git status にあるがリストに無い → 他セッション or ユーザー手動編集の可能性。**含めない**
- リネーム (`R  old -> new`) は new 側のパスで判定

## Step 3: Layer 1 ファイルパスベースの secret 除外

ステージング候補集合から、以下のパターンに一致するファイルを**無条件で除外**する：

- `.env` および `.env.*` (例: `.env.local`, `.env.production`)
- `*.key` (例: `private.key`, `rsa.key`)
- `*.pem`
- `credentials.*` (例: `credentials.json`, `credentials.yaml`)
- `*_secret*` / `*secret_*` / `secrets.*`
- `id_rsa*` / `id_ed25519*` / `id_ecdsa*`
- `.aws/credentials` / `.ssh/config` のような定番パス

除外したファイルがあればユーザーに報告する：`secret候補のため除外: .env.local, config.key`。

除外後にステージング集合が空になった場合は、「コミット可能な変更がありません」と報告して終了（空コミットは作らない）。

## Step 4: Layer 1 コンテンツベースの secret 正規表現スキャン

ステージング候補の差分内容に対して以下の正規表現を順に走らせる：

```
AWS access key:    AKIA[0-9A-Z]{16}
AWS secret key:    (?i)aws.{0,20}?(secret|private).{0,20}?[=:]\s*['"][0-9a-zA-Z/+]{40}['"]
OpenAI API key:    sk-[a-zA-Z0-9]{20,}
Anthropic API key: sk-ant-[a-zA-Z0-9_\-]{20,}
GitHub token:      ghp_[a-zA-Z0-9]{36}
GitHub PAT:        github_pat_[a-zA-Z0-9_]{82}
Slack token:       xox[baprs]-[0-9]{10,13}-[0-9a-zA-Z]{24,}
JWT:               eyJ[a-zA-Z0-9_=]+\.eyJ[a-zA-Z0-9_=]+\.[a-zA-Z0-9_.+/=\-]+
PEM block:         -----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----
Generic hex secret: (?i)(api[_-]?key|secret|token|password)['"]*\s*[:=]\s*['"][a-f0-9]{32,}['"]
```

**実装方法**: Bash でステージ予定ファイルの `git diff HEAD -- <file>` を取得し、内部で正規表現マッチをかける（grep -E を活用）。マッチしたら**即座にコミット中断**。

中断時のユーザー報告フォーマット：

```
❌ secret らしい値を検出しました。コミットを中断します。

ファイル: path/to/file.ts:42
パターン: OpenAI API key (sk-*)
該当行（先頭12文字のみ表示）: sk-abcd123456...

次の手順を取ってください:
1. 該当箇所を環境変数化する
2. .env ファイルに移動する（.env は自動で除外されます）
3. 修正後に再度コミット試行
```

## Step 5: Layer 2 LLM による意味的 secret チェック

Layer 1 通過後も、LLM（=自分）が**ステージング予定の diff 全体を一度レビュー**し、次を確認する：

- Layer 1 が取りこぼした独自形式トークン（社内 API token, カスタム認証 string, personal access token 相当）
- PII（メールアドレス、電話番号、住所、個人名と組み合わさった識別子）
- URL に埋め込まれた credentials（`https://user:password@...`）
- コメントとして書かれた TODO/FIXME の中に embed された「仮」の credentials（「後で直す」系）

疑わしい箇所があれば**コミット中断してユーザーに報告**。疑いが弱く、文脈上明らかに公開情報（例: ドキュメント内のダミー値）と判断できる場合は pass。判断に自信がない場合は必ずユーザーに確認する（安全側に倒す）。

## Step 6: コミットメッセージ生成

以下のフォーマットで生成する：

```
<type>(<scope>): <imperative subject, 50 chars max>

Intent: <ユーザーが達成したかったこと 1-2行>
Result: <何が起きたか・どう解決したか 1-3行>
Prompted-by: <session-id>#turn-<N>

🤖 via experience-to-skill
```

### Type の選び方

- `feat`: 新機能・新しい capability の追加
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの整形・空白・フォーマット（ロジック変更なし）
- `refactor`: 機能変更を伴わない内部構造の変更
- `test`: テストコードの追加・修正
- `chore`: ビルド・依存関係・設定ファイルの雑多な変更
- `perf`: パフォーマンス改善
- `build`: ビルドシステム・外部依存の変更
- `ci`: CI 設定の変更

### Scope

変更の焦点となるモジュール名・機能名・コンポーネント名。例: `feat(experience-to-skill): ...`, `fix(auth): ...`。複数モジュールにまたがる大きな変更の場合は scope を省略可能。

### Subject のルール

- **imperative mood**（命令形）: `add`, `fix`, `refactor`（`added`, `fixed` は NG）
- 50文字以内
- 文末にピリオドを打たない
- 英語 / 日本語どちらでもよいが、リポジトリの既存慣習に合わせる（`git log` で確認）

### Intent と Result の書き分け

- `Intent`: ユーザーが何を達成したかったか。ユーザーのプロンプトから抽象化。**プロンプト原文をそのまま転記しない**（sanitize する）
- `Result`: 何がコミットとして残ったか。差分から導出

### Prompted-by trailer

`<session-id>#turn-<N>` の形式で、プロンプト本文は**絶対に含めない**。これはローカルの session jsonl への後方参照ポインタであり、`/e2s:reflect` 実行時に jsonl を読み戻すために使う。

## Step 7: session-id の取得（フォールバック階段）

以下の順で試し、最初に成功したものを採用する：

1. **環境変数**: `echo "$CLAUDE_SESSION_ID"` が非空ならそれを使う
2. **jsonl パス推定**: `~/.claude/projects/<hash>/` 配下の最新 `*.jsonl` の basename（UUID 部分）から推定
   - `ls -t ~/.claude/projects/*/*.jsonl | head -1` で最新を取得し、basename から拡張子を除いた UUID を使う
3. **UUID 生成フォールバック**: 上記2つが両方失敗した場合、`uuidgen` または Python の `uuid.uuid4()` で新規生成。ただしこの場合 `<session-id>` は「推定値」扱いで後から jsonl にマップできない可能性があることを記録

取得した session-id と、現在のターン番号（このスキル起動が何回目のアシスタント応答か）を組み合わせて `Prompted-by` に入れる。ターン番号が取得困難な場合は `turn-unknown` と記す。

## Step 8: コミット実行

ステージング集合の最終リストを確定したら：

```bash
# 個別ファイルを明示的に add する（-A や . は使わない）
git add "path/to/file1.ts" "path/to/file2.md" "path/to/file3.json"

# コミット実行
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

Intent: <...>
Result: <...>
Prompted-by: <session-id>#turn-<N>

🤖 via experience-to-skill
EOF
)"
```

### 実行後の報告

成功したらユーザーに報告：

```
✅ コミット完了
SHA: a1b2c3d
Subject: feat(experience-to-skill): add main skill implementation
Files: 3 files, +245 -0

次のアクション:
- 動作確認済みならタグを打ちますか？ → `/e2s:ok`
- 別の作業を継続 → このまま続行
```

失敗した場合（pre-commit hook 失敗など）はエラー内容を**ありのまま**報告し、`--no-verify` を**使わずに**ユーザーに指示を仰ぐ。

## Step 9: archive トリガー経由の場合は verified タグ提案

`longrun:archive` または `openspec:archive` から本スキルが起動された場合、Step 8 のコミット成功後に続けて：

```
コミットが完了しました。archive 系コマンド完了に伴うコミットなので
verified タグを提案します：

  verified/<YYYYMMDD-HHMMSS>-<label>

ラベル候補: <LLM が commit 群から生成>

このまま `/e2s:ok <label>` を実行しますか？
（yes / no / 別ラベルを指定）
```

ユーザー同意を得たら `/e2s:ok` の処理に委譲する。同意が得られなければタグを作らず終了する。

## Guardrails（絶対に auto-execute しない操作）

以下の操作は、本スキルから**ユーザーの明示承認なしに絶対実行しない**：

- `git push` / `git push --force` / `git push --tags`
- `git commit --amend`
- `git reset --hard` / `git reset --soft HEAD^` など履歴改変
- `git rebase` / `git rebase -i`
- `git checkout -- <file>` / `git restore <file>`（作業破棄）
- `git clean -f` / `git clean -fd`
- `git tag --force` / `git tag -d`（`/e2s:ok` コマンドで通常の付与はOK、削除や強制上書きは NG）
- `git branch -D`
- `--no-verify` / `--no-gpg-sign` フラグの使用
- main / master ブランチへの force push

エラーや pre-commit hook 失敗でこれらを使いたくなっても、**必ず根本原因の修正を優先**すること。

## Notes: Context 圧縮時のフォールバック

長時間セッションで context 圧縮が起きた場合：

- 圧縮は要約を残す動作なので、「どのファイルを編集したか」というレベルの記憶は通常失われない
- ただし「何行目をどう変えたか」といった細部は summarize されている可能性がある
- **判定に迷ったら**:
  1. `git diff <file>` を読む。変更内容が現在の会話の目的と一致していれば「自分の作業」と判断
  2. 不明瞭なファイルはステージング集合から除外してユーザーに確認
  3. 安全側に倒す：確信が持てないファイルは含めない
- 圧縮前後で commit 方針がブレないよう、**自分のツール呼び出しの事実のみを根拠とする**（推測でステージングしない）

## Notes: マルチセッション並行実行時の挙動

同じリポジトリで複数 Claude セッションが並行動作している場合、各セッションの context は独立しているため：

- Session A の context は Session A が呼び出した Edit/Write/Bash のみを持つ
- Session A のスキル実行時、Step 1 で列挙されるのは Session A の編集分のみ
- `git status` には両セッションの変更が見えるが、Step 2 の交集合演算で自セッション分だけが残る
- Session B の変更は unstaged のまま残り、Session B 側でコミットされる

つまり設計上 race condition が発生しない。ただし**両セッションが同じファイルを同時編集した場合**は通常の git 衝突と同じなので、後にコミットする側が前の変更を巻き込むことは受容する（それが git の通常動作）。

## Notes: 失敗時のリトライ方針

- Layer 1/2 の secret filter で中断 → ユーザーに修正を促し、修正完了後にスキル再起動で OK
- pre-commit hook 失敗 → `--no-verify` を絶対に使わず、hook が求める修正を実施してから再 commit
- `git commit` が何らかの理由で exit non-zero → エラーメッセージ全文をユーザーに見せて指示を仰ぐ

**自動リトライは行わない。**失敗の原因を理解せず再実行することは禁止。
