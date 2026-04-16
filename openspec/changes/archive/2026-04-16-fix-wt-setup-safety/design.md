## Context

wt-setup スキルは `context: fork` で Sonnet モデルにより実行される。SKILL.md は Step 1 でスクリプト実行を指示するが、LLM がスクリプトの前に独自に `.claude/` を `rm -rf` して丸ごとシンボリンクしようとする事象が発生した。スクリプト（wt-setup.sh）はサブディレクトリ単位でリンクする安全な設計だが、LLM の「最適化」でバイパスされた。

また `.worktreeinclude` 生成時に AskUserQuestion でパターン選択を毎回ユーザーに尋ねており、自明な判断で不要な対話が発生している。

## Goals / Non-Goals

**Goals:**
- LLM が `.claude/` を丸ごと削除するコマンドを実行しないようにする
- スクリプト側でも `.claude/` の無条件削除を防ぐガードを入れる
- `.worktreeinclude` 生成を AskUserQuestion なしで自動完結させる

**Non-Goals:**
- wt-setup.sh のロジック全体の書き直し
- wt-clean スキルの修正
- `.worktreeinclude` のパターン体系の再設計

## Decisions

### Decision 1: SKILL.md に禁止事項セクションを追加する

**選択:** SKILL.md の冒頭（実行フローの前）に `## 禁止事項` セクションを追加し、`.claude/` の直接操作を明示的に禁止する。

**理由:** `skill-script-separation` spec は「SKILL.md にスクリプト内部実装を記述しない」という原則だが、「LLM がスクリプト外で危険な操作をしない」という禁止ルールは含まれていなかった。LLM に対して「何をやるな」を明記するのが最も直接的な対策。

**代替案:**
- スクリプトだけにガードを入れる → LLM がスクリプトを呼ばずに直接操作する場合に効果なし
- allowed-tools から Bash を外す → スクリプト実行自体ができなくなる

### Decision 2: wt-setup.sh にガード処理を追加する（多層防御）

**選択:** スクリプトの `.claude/` 操作部分（Step 3）の前に、既存 `.claude/` がシンボリンクでない場合のチェックを追加する。

**理由:** SKILL.md の禁止ルールだけでは LLM が無視する可能性がある。スクリプト側でも防御し、多層防御とする。ただし、スクリプトは `rm -rf .claude` を元々実行しない設計なので、これは「LLM が別のコマンドで .claude を削除してからスクリプトが走った場合」の検知用。

### Decision 3: .worktreeinclude 生成を自動判定に変更する

**選択:** SKILL.md Step 2 の AskUserQuestion を削除し、以下の固定ルールで自動判定する：
- `.env`, `.env.*` → 常に含める
- `*.local.json`, `*.local.md` → 常に含める
- `*.pem`, `*.key` → `.gitignore` に含まれている場合は含める
- `node_modules`, `dist`, `out`, `*.log` 等 → 常に除外

**理由:** ユーザーのフィードバック。env 系ファイルのコピーは自明な判断であり、毎回確認する必要がない。

## Risks / Trade-offs

- **[LLM が禁止ルールを無視する可能性]** → スクリプト側ガードで多層防御。最悪の場合でもスクリプトが警告を出す。
- **[.worktreeinclude の自動判定が不適切なケース]** → 完了レポートに含めた/除外したパターンを表示し、ユーザーが事後修正可能にする。
