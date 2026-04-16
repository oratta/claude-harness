## 1. SKILL.md に禁止事項セクションを追加

- [x] 1.1 SKILL.md の実行フローの前に `## 禁止事項` セクションを追加し、`.claude/` の直接操作（`rm -rf .claude`, `rm -rf ./.claude`, `mv .claude`, `ln -s ... .claude`）を禁止する旨を明記する
- [x] 1.2 「スクリプトの処理を効率化・最適化する目的で独自コマンドを実行しない」旨を禁止事項に含める

## 2. wt-setup.sh にガード処理を追加

- [x] 2.1 Step 3（.claude/ の共有）の前に `.claude/` が既にシンボリンクかどうかのチェックを追加し、シンボリンクの場合はスキップ＋警告を出力する
- [x] 2.2 `.claude/` が通常ディレクトリとして存在する場合は削除せず、既存の `mkdir -p .claude` 処理をそのまま維持することを確認する

## 3. .worktreeinclude 自動判定ルールに変更

- [x] 3.1 SKILL.md Step 2 から AskUserQuestion の指示を削除する
- [x] 3.2 自動判定ルールを SKILL.md に記述する（`.env`, `.env.*` → 含める / `*.local.json`, `*.local.md` → 含める / `*.pem`, `*.key` → `.gitignore` にあれば含める / `node_modules`, `dist`, `out`, `*.log` → 除外）
- [x] 3.3 完了レポートに含めたパターンと除外したパターンの一覧を表示する指示を追加する

## 4. 検証

- [x] 4.1 SKILL.md に `symlink`, `ln -s`, `-sfn`, `git ls-files` の文字列が含まれないことを確認する（skill-script-separation spec 準拠）
- [x] 4.2 plugin.json のバージョンを更新する
