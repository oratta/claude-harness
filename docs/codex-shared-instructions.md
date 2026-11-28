# Codex への共通ルール配布

公開 `rules/*.md`（README を除く）と harness の AGENTS 全文を機械的に連結する。readable の要点は正本の `rules/communication-style.md` を使う。harness 専用節は配布元リポジトリを変更するときだけ適用し、相対参照も供給元が基準となる。Claude 固有の hook や Agent の実行を代行するものではない。

## 公開生成と鮮度

開発 worktree で以下を実行する。公開生成は個人 overlay に依存しない。`generated/codex/AGENTS.md` は追跡対象であり、手編集せず正本の変更と一緒に再生成する。

```sh
python3 -B scripts/codex-shared-instructions.py generate
python3 -B scripts/codex-shared-instructions.py check
```

試すだけなら `generate --output "$TMPDIR/codex-public.md"` と `check --output "$TMPDIR/codex-public.md"` を使える。許可済み個人ルールは同期時だけローカルの管理区画に加わり、公開生成物には入らない。

## 明示同期

従来の同期では Codex を変更しない。Codex へ配るときだけ `--codex` を指定する。実ホームへ適用する前に、本体は対象一覧・AGENTS/config の具体差分・復旧方法を主に提示して適用権限を確認する。以下の同期例は使い捨て HOME 専用である。

```sh
task_home=$(mktemp -d)
mkdir -p "$task_home/registered"
HOME="$task_home" CLAUDE_CONFIG_DIR="$task_home/.claude" CODEX_HOME="$task_home/current" \
  sh scripts/sync.sh --no-pull --codex --account-home "current=$task_home/registered"
```

対象は `~/.codex`、現在の `CODEX_HOME`（設定時）、明示された登録先の和集合。実体パスで重複を除く。登録は `--account-home NAME=PATH` の反復、または `--account-home-file PATH` の平坦な JSON（例: `{"current":"/absolute/existing/home"}`）を使う。両形式の併用、重複名（JSON キーも含む）、空・非文字列・相対パス・存在しない登録先は拒否する。認証の有効性は配布時には検査しない。別台帳やホーム探索は行わない。

個人 rules の許可は既存の `$CLAUDE_CONFIG_DIR/harness-overlays`（既定 `~/.claude/harness-overlays`）と marketplace 直下の `.harness-overlay` を使う。許可取消は次回同期で管理区画からも除く。ファイル順・marketplace 順は安定している。

AGENTS の先頭に `<!-- BEGIN claude-harness shared instructions -->` から `<!-- END claude-harness shared instructions -->` までの管理区画を置く。区画外の既存バイト列は保持し、再同期は区画だけを置換する。破損・重複・逆順のマーカー、更新対象の symlink、非空の `AGENTS.override.md` は対象と原因を示して非0で拒否する。管理外指示の意味や正本への鮮度はこの入力検査の対象外。

config は `project_doc_max_bytes` の未設定・小さい値を131072へ引き上げ、大きい値は維持する。profile 等の容量値も対象。認証・MCP 等の設定とコメントは保持する。安全に編集できない TOML 表記は書き換えず拒否する。全対象の事前検査後に書き込むが、I/O障害時の全ホーム一括ロールバックは行わない。

## 復旧

適用前に各対象の `AGENTS.md` と `config.toml` をローカルの退避領域へコピーし、存在しなかったファイルも記録する。適用直後の復旧は退避したバイト列を戻し、元々無かったファイルだけを削除する。認証は変更しない。適用後に別の設定変更がある場合はファイル全体を戻さず、管理区画を除去し容量キーだけを元の値へ戻す。

拒否されたホームは自動修復しない。管理外 symlink の統合先、override の扱い、壊れたマーカーを人が確認してから同期を再実行する。

## worker と自動メモリ

worker は選択済み account home の管理区画だけを runtime CODEX_HOME へコピーする。区画外の一時指示や親 config/MCP はコピーしない。認証リンク、0700、隔離設定、親の TMPDIR/TMPPREFIX 継承を維持し、容量131072を毎回設定する。未配布・破損時は `shared_instructions_sync_required` を返し、turn/start 前に停止する。この場合は承認された同期で配布してから再実行する。配布本文の鮮度・意味は worker では検査しない。

Claude の `~/.claude/projects/*/memory/` は生成・配布・worker のいずれでも探索・コピー・リンクしない。別プロジェクトや住人の記憶の混入を防ぐためである。必要な知識は依頼文や明示された資料で渡せる。

## 容量の確認と実機証拠

```sh
python3 -B scripts/codex-shared-instructions.py capacity --fixture
python3 -B scripts/codex-shared-instructions.py capacity --cwd "$FLATMATE_DIR/workspace/ponta" --home "$CODEX_HOME"
```

固定入力は公開生成物・生成見出しと、manifest の実測サイズを再現する決定的UTF-8ダミー本文を合算する。非公開入力の相対パス・bytes・SHA-256・測定元は `tests/fixtures/codex-shared-instructions/manifest.json` に残す。本文は保存しない。ローカル検査は home と Git root から cwd までの各階層で、非空の AGENTS.override → AGENTS → config の fallback filenames の順で一つを選ぶ。CLAUDE は fallback に設定された場合だけ選ぶ。同階層の二重計上はしない。`--profile NAME` で使用 profile、`--limit N` で境界を指定できる。実物不在は非0で明示する。

容量内の判定は意味的一貫性やセッションの読込成功を保証しない。承認後の実機証拠は、(1) 新規セッションの破壊的 git・commit・主への聞き方の回答、(2) ponta の人格の最後の節の回答、(3) worker の日本語 commit の SHA・メッセージを、それぞれ正本や既存履歴と照合して issue #1853 に記録する。通信完走だけを合格としない。この実装工程では実ホーム適用と三つの実機検証は未実施である。
