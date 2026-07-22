## Context

`wt-clean` は `git worktree remove --force` を 5 箇所（Step B-🟢 自動削除 / Step B-🟡 LLM退避後削除 / Pass 2 の 🔴 破棄削除・🟡 dirty 破棄・🔴 マージ後削除）で呼ぶ。いずれも worktree ディレクトリを丸ごと消すが、その配下で稼働中のプロセス（`next dev` 等の dev サーバー）を止めるステップが無い。ソースが消えた状態で dev サーバーが再ビルドを試行し続けるループに陥り、CPU/メモリを圧迫するインシデントが実際に発生した（issue #39）。

利用側の `.claude/rules/dev-server.md` には既に「他プロジェクトのプロセスを誤って kill しない」ための cwd 判別の考え方があり、同じ思想を wt-clean 側にも実装する。

## Goals / Non-Goals

**Goals:**
- `git worktree remove` を呼ぶ全ての箇所で、その直前に削除対象パス配下で稼働中のプロセスを検出し停止する。
- 停止対象を削除対象 worktree のパス配下に厳密に限定し、メインリポや他 worktree のプロセスを誤って止めない。
- 停止結果（PID・コマンド名、または「プロセスなし」）を必ずログ表示する（無音実行にしない）。
- ユーザーが対象 worktree に `cd` して作業しているだけのシェル/エディタセッションを誤って kill しない。

**Non-Goals:**
- dev サーバーのアプリケーション固有の graceful shutdown フック呼び出し（OS シグナルのみを扱う）。
- wt-clean 以外の場面（例: 通常の開発中）でのプロセス監視・管理。
- 対象パス外のプロセスに対する一切の操作。

## Decisions

### 検出方式: `lsof +D` を採用（`pgrep -f` はフォールバック）

- `lsof +D "$WT"` は対象パス配下に実際にオープンファイル/cwd を持つプロセスだけを返す。`pgrep -f "$WT"` はコマンドライン文字列の部分一致のため、パス文字列がたまたま別の意味で引数に混入したプロセスまで誤検出しうる。
- macOS/Linux とも `lsof` は標準搭載のため、これを主手段にする。`lsof` が使えない環境（一部の最小コンテナ等）向けに `pgrep -f "$WT"` をフォールバックとして併記し、フォールバック使用時はログにその旨を明示する。

### シグナル手順: SIGTERM → 3秒待機 → 生存確認 → SIGKILL フォールバック

- まず SIGTERM で graceful shutdown の機会を与え、3秒待って `kill -0` で生存確認し、まだ生きていれば SIGKILL する。
- 3秒は「dev サーバーの通常の shutdown を待つ」と「wt-clean 全体の体感速度を落としすぎない」のバランスで選んだ初期値。プロセスが見つからない worktree では待機自体をスキップするため、大半のケースでは体感速度に影響しない。

### シェル/エディタの除外リスト（コマンド名ベースの簡易ヒューリスティック）

- 検出した PID のコマンド名が `bash` / `zsh` / `sh` / `fish` / `tmux` / `ssh` / `vim` / `nvim` / `code` / `Cursor` 等の対話用プロセスに一致する場合はスキップし、ログに「シェル/エディタと判定してスキップ」と明示する。
- これは「対象 worktree に `cd` しているだけの対話セッション」を dev サーバーと誤認して kill しないための保険。除外リストは網羅的ではないが、`next-server` / `node` / `npm` / `yarn` / `pnpm` / `vite` 等の実際の dev サーバー系プロセス名は通常このリストに含まれないため、除外漏れによる実害（＝本来止めるべきプロセスを誤って除外リストに含めてしまうこと）は小さい。
- **設計判断として false negative（本来止めるべきプロセスを見逃す）より false positive（対話セッションを誤って止める可能性）を避ける側に倒す**。除外リストに無いコマンドは全て停止対象にする（default-allow ではなく default-kill）。将来除外漏れが見つかれば都度リストに追加する。

### 適用箇所: 5 つの `git worktree remove` 呼び出し全てに共通ヘルパーとして適用

`kill_devserver_under "$WT"` という 1 つの手順として SKILL.md 内に一度だけ定義し、5 箇所（🟢 / 🟡 / 🔴破棄削除 / 🟡dirty破棄 / 🔴マージ後削除）はいずれも「`kill_devserver_under "$WT"` → `git worktree remove ...`」の順で呼び出す形にする（実装をコピペで重複させない）。

## Risks / Trade-offs

- [Risk] `lsof` が使えない環境では検出できない → Mitigation: `pgrep -f` にフォールバックし、フォールバック使用をログに明示する。
- [Risk] 除外リストが不完全で対話セッションを誤って kill する可能性が残る → Mitigation: リストは保守的に運用し、SIGTERM を最初に送ることで大半のシェル/エディタは実害なく生存し続ける（シェルは SIGTERM で終了しないことが多い）。実害が確認されたら除外リストに追加する。
- [Risk] SIGTERM 後の 3 秒待機が全 worktree 処理の体感速度を落とす → Mitigation: プロセスが見つからない worktree（大半のケース）では待機自体をスキップする。
- [Risk] 本 change と無関係の既存 bats テスト失敗が 2 件ある（`plugin.json` バージョン期待値の古さ、文言チェックの古さ）→ Mitigation: 本 change のスコープ外として触れない。既存の pre-existing failure であることをタスク側に明記する。

## Migration Plan

ユーザー側の移行作業は不要（marketplace dir 配下の skill 文書・テスト更新のみ）。`plugins/worktree/.claude-plugin/plugin.json` の version を bump する（`plugin-editing.md` ルールに従う）。
