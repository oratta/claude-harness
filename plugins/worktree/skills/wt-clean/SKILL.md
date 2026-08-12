---
name: wt-clean
description: Git worktree の安全なクリーンアップ（自動処理 → 判断バッチのみ対話の 2 パス）。削除前に対象パス配下の devサーバープロセスを停止する。配下で claude 等の非シェルプロセスが稼働中／当日のセッションログがある／git worktree lock されている worktree は git がクリーンでも自動削除せず判断バッチに回す。`wt-clean [<path|branch>…] [--keep] [--no-sync] [--unattended] [--repo <path>]`、引数なしは全 worktree を対象。`--unattended` で Pass 2 を対話せず報告のみにして cron から無人実行、`--repo` で cwd 以外のリポジトリを対象にできる。「worktree整理」「ワークツリークリーン」「worktree削除」「worktree再利用」「PRマージ後の整理」「プルリク後の片付け」「未マージworktreeのマージ」「worktree消したのにdevサーバーが残っている」「worktreeが溜まっている」「worktreeの定期掃除」で起動。
version: 3.7.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# wt-clean — Worktree クリーンアップスキル

Git worktree を安全にクリーンアップするスキル。

**設計の核**: 「対話は判断が必要な分だけに絞り、走行中はブロックしない」。ユーザーとの対話は **Pass 2 の判断バッチ**（自動処理が全部終わった後）の 1 箇所だけに寄せる。**対象選択の質問はしない** ── 引数なしなら全 worktree を確認なしで対象にし、対象を絞りたいときだけ位置引数 `<path|branch>` を渡す。ほとんどのケース（🟢 Safe と LLM 退避だけで済む 🟡）は確認なしで自動処理されるため、「実行して放っておいたら作業が終わっている。判断が必要な分だけ最後に質問が残っている」という体験になる。最初に全件を診断（🟢🟡🔴 分類）せず、対象を確定してから 1 件ずつその場で診断する点は従来どおり。パス／ブランチ名引数は「対象を絞るショートカット」であり、引数あり／なしのどちらも `TARGETS を確定 → 2 パス処理` という共通パイプラインに合流する。

```
Step -1 対象リポジトリの解決（--repo、未指定なら cwd）→ MAIN_REPO 確定
   │
Step 0  Remote 同期（--no-sync で skip）
   │
Step A  TARGETS 確定（対話しない）
   ├ 位置引数あり <path|branch> … → 引数を解決して TARGETS に（リスト/選択はしない）
   └ 位置引数なし → 全 worktree をリストアップして表示 → そのまま全件を TARGETS に（質問なし）
   │
Step B  Pass 1: [i/N] 進捗で 1 個ずつ遅延診断 → ノンブロッキング自動処理
   │       🟢 → 根拠表示して即削除（--keep なら即再利用化）
   │       🟡 dirtyなし・稼働シグナルなし（LLMのみ）→ LLM退避 → 退避検証 → 即削除
   │       🔴 / dirtyあり / 稼働シグナルあり → DEFERRED に積んで次へ（この時点では触らない）
   │
Step B  Pass 2: 判断バッチ（DEFERRED が空ならスキップ） ←― 唯一の対話ポイント
   │       通常     : 状況をまとめて提示 → AskUserQuestion（1対象1問・最大4問/回）
   │                  回答後の別ターンで マージ/スキップ/破棄 を逐次実行
   │       --unattended: AskUserQuestion を呼ばず、一覧を出力して終了（破壊操作なし）
Step C  完了レポート
```

## オプションと引数

- **位置引数 `<path|branch> …`**（任意・複数可）: 処理対象を絞る。指定した worktree のみを対象にし、他は完全に無視する。位置引数があると全件対象化をスキップして、その worktree だけを対象にする
- **位置引数なし（オプションのみ・完全無指定を含む）**: 全 worktree を確認なしで対象にする。対象選択の質問（全て/個別/キャンセル）はしない
- **オプションなし（デフォルト）**: 削除モード。🟢 Safe はディレクトリごと削除する
- **`--keep`**: 再利用モード。🟢 Safe はディレクトリを残し、worktree 内のブランチを main に戻して元ブランチを削除する（`node_modules` / `.env` / 未追跡ファイルは保持）。🟡 は削除、🔴 はマージ後通常削除へフォールバック
- **`--no-sync`**: Step 0 の Remote 同期をスキップする。`--keep` や位置引数と併用可能（例: `wt-clean --keep --no-sync ~/wt/foo`）
- **`--unattended`**: 無人モード。Pass 1（🟢/🟡 の自動処理）は通常どおり実行し、**Pass 2 に到達した対象は `AskUserQuestion` を呼ばず一覧を出力して終了**する。cron から定期実行するためのモード（後述「無人モード」）
- **`--repo <path>`**: 対象リポジトリを外から指定する。未指定時は cwd（現行どおり）。worktree のパスを渡してもそのメインリポに正規化される（後述「対象リポジトリの解決」）

例:
- `wt-clean` → 全 worktree を確認なしで対象に診断・処理
- `wt-clean ~/wt/foo` → `foo` だけを対象に診断・処理
- `wt-clean feat-x` → `feat-x` をチェックアウト中の worktree を逆引きして対象に
- `wt-clean ~/wt/foo feat-y` → 2 件を対象に
- `wt-clean --unattended --repo ~/repos/flatmate` → cron 用。別リポの worktree を無人で掃除し、判断が要る分は報告だけする

## 前提条件

- **`--repo` 未指定時**: メインリポのルートで実行すること（worktree 内ではなく）。worktree 内で実行した場合は「メインリポで実行してください」と案内する（現行どおり）
- **`--repo <path>` 指定時**: cwd がどこであっても構わない。指定されたパスから**そのリポジトリのメイン worktree** を解決し、以降の git 操作はすべてそのメインリポに対して行う（cwd のリポジトリは一切触らない）

## コード片の実行シェルは zsh も含む（bash 専用構文を書かない）

このスキルは「SKILL.md を Read して、載っているコード片をそのまま **Bash ツールでインライン実行する**」設計であり、Claude Code の Bash ツールは macOS では既定で **zsh** を起動する。つまり ```bash と書かれたコードブロックも実際には zsh で走ることがある。**このファイルに載せるコード片は bash と zsh の両方で同じ結果になる書き方に限ること。**

zsh で実際に事故になった書き方（そのままコピーしないこと）:

| 書き方 | zsh での挙動 | 代わりに |
|---|---|---|
| `${var%%(*}` のようにパターンメタ文字（`(` `)` `[` `]` `#` `~`）を区切りに使う | `bad pattern: (*` の**パースエラーでシェルごと即終了**する。`\|\| true` / `set +e` でも救えない（コマンドの非ゼロ終了ではないため）。issue #66 | 区切りに `\|` や `/` などメタ文字でない文字を使う（`killed+=("$pid\|$comm")` → `${entry%%\|*}`） |
| `for x in $pids`（複数行の変数を単語分割で回す） | zsh は既定で単語分割しないため全行が 1 要素に潰れる | `while IFS= read -r x; do … done <<< "$pids"` |
| ループ本体で `local x` を毎周回宣言する | 2 周目以降の再宣言が `x=前回の値` を**標準出力に印字する**（bash は無言）。レポートにゴミ行が混ざる | 宣言は関数先頭にまとめる |
| 配列の添字を 0 始まりで直接参照する | zsh の配列は 1 始まり | 添字を直に書かず `"${arr[@]}"` で回す |

新しいコード片を足すときは、`bats plugins/worktree/tests/` に **bash と zsh の両方で実行して結果が一致することを確かめるテスト**を添えること（既存例: `classify_dirty: behaves identically under bash and zsh`）。

## 絶対禁則（最優先・データロス防止）

このスキルは `git worktree remove` / `git branch -D` という**取り消し不能な破壊操作**を含む。以下は他のどのルールよりも優先する。違反すると過去に「ユーザーが作業中の worktree（成果が LLM ログのみに残る設計議論セッション）を誤削除する」事故が発生している。

1. **破壊操作の実行条件を守る（最重要）**

   破壊操作は「自動実行してよいもの」と「AskUserQuestion 必須のもの」に区分される。この区分を勝手に拡大解釈してはならない。

   **自動実行してよい**（Step A で TARGETS に含めたことを承認とみなす）:
   - 🟢 Safe（マージ済み & dirty なし & LLM なし & 稼働シグナルなし）の削除・再利用化
   - 🟡 で dirty なし & 稼働シグナルなし（LLM のみ）の、**LLM 退避の実在検証成功後**の削除
   - いずれも削除直前に**診断根拠（マージ済み判定の根拠）を必ず表示**する。無音削除は禁止。

   **AskUserQuestion の回答後の別ターンでのみ実行してよい**（自動実行の絶対禁止）:
   - dirty な変更の破棄（🟡 dirty あり・🔴 dirty あり）
   - **稼働シグナルあり（禁則 3）の worktree の削除・再利用化**（マージ済み & クリーンでも同じ）
   - 🔴 Active の破棄削除（`git worktree remove --force` + `git branch -D`）
   - 🔴 Active の main へのマージ
   - AskUserQuestion ツール呼び出しと、これらを実行する Bash 呼び出しを**同一ターンの並列ツール呼び出しに含めてはならない**。並列にするとユーザーの回答が届く前に実行が走り、回答が「やめて」「対象が違う」でも手遅れになる。
   - 回答が届いたら、その回答が**どの worktree を指しているか**を文章で読み直し、対象を再確定してから実行する。曖昧な回答は「実行してよい」と解釈せず一度確認する。

   自動実行が許されるのは分類が厳格であることが前提である。禁則 2（LLM→🟡 強制）・禁則 3（稼働シグナル→自動処理禁止）・禁則 4（実ブランチ名判定）・squash 3 重検証を省略した状態での自動削除は、この区分に違反する。

   **`--unattended` はこの区分を緩めない。** 無人モードは「AskUserQuestion 必須」の側を自動実行に格下げするものでは**なく**、その分岐に**到達しないルート**である。無人モードでは Pass 2 の対象を報告して終了するだけで、dirty 破棄・🔴 破棄削除・🔴 マージは**一切実行しない**（実行したら禁則違反）。人間の目が入らない実行形態だからこそ、判断が要るものには手を触れない。

2. **「マージ済み & クリーン」でも LLM ログがある worktree は🟢 Safe にしない**
   - 独自 commit が無く working tree がクリーンでも、`LLM/` にログがある worktree は**現在進行中の作業セッション**の可能性が高い。Step B 診断で🟢 Safe に分類せず、必ず🟡 Recoverable 扱いとし、LLM を保全してから確認する（分類表を厳守）。
   - 設計議論・調査中心のセッションは git に commit が残らず、成果が `LLM/` ログにしか存在しないことがある。LLM ログの消失は復元困難なため保全を最優先する。

3. **配下にプロセスが稼働中／当日のセッションログがある／worktree がロックされている場合は自動処理しない（稼働シグナル）**

   2026-08-01 に flatmate リポで、壁打ち（設計議論）作業中の worktree を 🟢 Safe と誤判定して自動削除する事故が発生した。git 診断は完全にクリーン（マージ済み・dirty なし・`LLM/` なし）で、**稼働中の claude セッションのプロセスまで `kill_devserver_under` が停止した**。壁打ちセッションは commit も `LLM/` も残さないため、禁則 2 も git ベースの診断も効かない。

   そこで削除の可否は git 状態だけで決めず、**「今そこで誰かが作業しているか」を示す稼働シグナル**を必ず併せて見る:

   - **配下プロセス**: 削除対象パス配下で稼働中の**非シェルプロセス**（`claude` / `node` / `next` など）。判定は `lsof +D` と `kill_devserver_under` と**同一の除外基準**で行う（Step B-共通の `detect_active_procs_under`）。「`kill_devserver_under` が停止する対象が居るなら、それは自動削除してよい worktree ではない」という対応関係を崩さない。**ただし居残り（下記）は除く。**
   - **当日のセッションログ**: `~/.claude/projects/<worktree-path-slug>/` に 24 時間以内に更新された `.jsonl` がある。プロセスが一時的に落ちている壁打ちセッションもこれで拾える。
   - **worktree ロック**: `git worktree list --porcelain` が当該 worktree に `locked` を出している。ロックは「別のセッション／エージェントがこの worktree を所有している」という**最も強い所有権の表明**で、しかも git 側が既に持っている情報なので追加コストがゼロである。wt-setup の hooks が作る worktree（`--lock` 付き）や並列サブエージェントの worktree がこれに当たる。`git worktree remove --force`（`-f` 1 個）はロック済み worktree を拒否するため、ロックを無視して自動削除しようとすると Pass 1 が `fatal: cannot remove a locked working tree` で落ちる。**ロックの解除（`git worktree unlock`）は Pass 2 でユーザーが削除を選んだ場合にのみ行う**（SHALL NOT: Pass 1 での自動 unlock）。

   いずれか 1 つでも該当したら、マージ済み & クリーンでも **🟢 にせず 🟡 Recoverable とし、Pass 1 で自動処理せず `DEFERRED`（Pass 2 の判断バッチ）へ回す**。Pass 2 の提示には検出内容（PID・コマンド名／セッションログの更新時刻／ロックの有無と理由）を必ず含め、ユーザーが「作業中セッションかどうか」を判断できるようにする。稼働シグナルの検出は**削除しない方向にのみ働く**（🔴 を 🟡 に緩めることはしない）。

   **例外 — 居残り（leftover）は配下プロセスとして数えない（issue #98）**

   配下プロセスの存在は「作業中」の証拠にはならない。セッションを閉じてもプロセスがデタッチして
   残る運用（worktree ごとに codex / claude CLI を開く orca 等）では、シグナルが恒久的に立ちっぱなしになり、
   マージ済み・clean な worktree が**永久に Pass 2 送り**になる。2026-08-10 に flatmate で全件実行したとき、
   11 件中 Pass 1 で自動処理できたのは **0 件**だった（うち 5 件は squash マージ済み・clean）。実測した居残りは
   `PPID=1` のまま 7 日・3 日・1 日と生き続け、`lsof +D` は cwd が配下にあるだけの無関係プロセス
   （ChatGPT.app の `cua_node`、Pencil.app の MCP サーバー）まで巻き込んで拾っていた。

   そこで次の **3 条件をすべて満たす**プロセス群は、作業中ではなく残骸とみなして稼働シグナルから外す:

   1. 検出した PID 集合の外に生きた親がいない（集合のルートが `PPID=1` ＝ 起動元セッションが既に無い）
   2. worktree 配下に 24 時間以内に更新されたファイルが無い（`.git` 配下を除く）
   3. 対応する `~/.claude/projects/<slug>/` に 24 時間以内に更新された `.jsonl` が無い

   **AND を崩してはならない（SHALL NOT）。** 孤児であることだけを根拠にすると `launchd` 常駐の住人
   セッションを、活動痕跡が無いことだけを根拠にすると「開いたまま少し離席している対話セッション」を、
   それぞれ誤って削除対象にしてしまう。issue #77 で消してしまった壁打ちセッションは親プロセスが
   生きていたため、この 3 条件では引き続き守られる。判定できない場合（`ps` が引けない等）は
   居残りと見なさない側に倒す。

4. **削除判定は必ず実ブランチ名で行う（ディレクトリ名 ≠ ブランチ名）**
   - worktree のディレクトリ名と checkout 中ブランチ名は一致しないことがある（例: `setup-foo` ディレクトリで `ISSUE-129_xxx` ブランチを checkout）。マージ判定・`git branch -D` は `git worktree list` 由来の**実ブランチ名（`BRANCH_NAME`）**を使う。ディレクトリ名で判断しない。

5. **破壊操作の前に LLM 保全を済ませ、退避の実在を検証する**
   - `git worktree remove --force` は gitignore 対象（`LLM/`・`node_modules`・`.env`）も巻き込んで削除する。削除前に `LLM/` をメインリポへコピーする（Step B-🟡）。
   - **退避検証の成功が 🟡 自動削除の前提**。コピー後、退避先に元と同数のファイルが実在し空でないことを確認できるまで削除してはならない。検証に失敗したら削除せず HELD として保留する。
   - 万一保全前に削除してしまった場合、`~/.claude/projects/<worktree-path-slug>/<session>.jsonl` にセッション生ログが残っていれば LLM ログを再生成できる。worktree とブランチは `git worktree add <path> -b <branch> <last-sha>` で復旧できる。

加えて、本スキル固有の SHALL NOT:

- 引数の曖昧マッチ（複数件ヒット）を**自動選択しない**。必ず候補提示して中断する（Step A-1）
- 競合発生時に `git merge --abort` を**自動実行しない**（Step B Pass 2）
- Step B 再利用化（worktree 内）で `git reset --hard` / `git clean -fd` / worktree 内 `git pull` / `git fetch` を**実行しない**

## 実行フロー

### Step -1: 対象リポジトリの解決（`--repo`）

**すべての git 操作より先に `MAIN_REPO` を確定し、以降の git 呼び出しは例外なく `git -C "$MAIN_REPO"` を通す。** 素の `git ...`（= cwd 依存）を書いてはならない（SHALL NOT）。`--repo` の要点は「cwd のリポジトリを一切触らないこと」なので、1 箇所でも `-C` が漏れると別リポを掃除しに行く事故になる。

**パス正規化には `realpath -m` を使ってはならない（SHALL NOT）。** `-m` は GNU coreutils 専用オプションで、macOS 標準の BSD `realpath` では `illegal option -- m` となり**必ず失敗する**。2026-08-10 に flatmate で実走したとき、削除直前のプロセス残留チェックで `abs` が空文字に潰れ、`lsof +D ""` が何も返さないまま「配下に稼働中プロセスなし」と表示された（チェックしていないのにチェックしたと出る silent no-op）。以降のパス正規化は次の `abs_path` に統一する。

```bash
# BSD/GNU 両対応のパス正規化。
# 存在するディレクトリは cd -P + pwd -P で symlink まで解決する（`pwd` 既定の論理パスでは
# macOS の /var → /private/var のような symlink が解決されず、lsof +D の対象や
# worktree 一覧との突き合わせがずれる）。
# 存在しないパスは、最も近い親を物理パス化してから欠落部分を継ぎ足す。
# **解決できなければ空文字を返さず非 0 で失敗する**（呼び出し側が「空パスのまま検査した」
# ことに気づけるようにするため。旧実装は失敗を空文字で握り潰していた）。
abs_path() {
  local p="$1" parent leaf parent_abs

  if [ -z "$p" ]; then
    echo "abs_path: empty path" >&2
    return 1
  fi

  # root 以外の末尾スラッシュを除去
  while [ "$p" != "/" ] && [ "${p%/}" != "$p" ]; do
    p=${p%/}
  done

  if [ -d "$p" ]; then
    (cd -P -- "$p" 2>/dev/null && pwd -P) || {
      echo "abs_path: cannot resolve directory: $p" >&2
      return 1
    }
    return 0
  fi

  # 欠落パスは親を再帰的に正規化してから末尾要素を付ける
  case "$p" in
    */*) parent=${p%/*}; leaf=${p##*/}; [ -n "$parent" ] || parent="/" ;;
    *)   parent="."; leaf="$p" ;;
  esac

  # 欠落した . / .. を文字列操作だけで畳むと symlink の意味論が壊れるため拒否する
  case "$leaf" in
    ''|.|..) echo "abs_path: cannot resolve path: $1" >&2; return 1 ;;
  esac

  parent_abs=$(abs_path "$parent") || return 1
  printf '%s/%s\n' "${parent_abs%/}" "$leaf"
}
```

**呼び出し側は `abs_path` の失敗を必ず受け止める**（SHALL NOT: 失敗を無視して空の `abs` で `lsof +D` を撃つ）。稼働シグナル検出の中で失敗した場合は、**「検査不能」を稼働シグナルとして扱い Pass 2 へ送る**（削除しない側に倒す）。

```bash
# --repo 未指定なら cwd（現行どおりの後方互換）
REPO_ARG="${REPO_ARG:-$PWD}"

if ! git -C "$REPO_ARG" rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ $REPO_ARG は git リポジトリではありません"
  exit 1
fi

# worktree list の 1 行目は常にメイン worktree。
# --repo に worktree のパスを渡されてもここでメイン側へ正規化される。
MAIN_REPO=$(git -C "$REPO_ARG" worktree list --porcelain | awk '/^worktree /{print $2; exit}')

if [ -z "$MAIN_REPO" ]; then
  echo "❌ $REPO_ARG のメイン worktree を解決できませんでした"
  exit 1
fi
```

**前提条件チェックの出し分け**:

```bash
if [ -n "$REPO_OPT_GIVEN" ]; then
  # --repo 指定時: cwd がどこでも構わない。正規化した MAIN_REPO を使う
  echo "対象リポジトリ: $MAIN_REPO  (--repo $REPO_ARG)"
else
  # --repo 未指定時: 現行どおり「メインリポで実行すること」を要求する
  if [ "$(abs_path "$PWD")" != "$(abs_path "$MAIN_REPO")" ]; then
    echo "❌ worktree 内で実行されています。メインリポで実行してください: $MAIN_REPO"
    echo "  （または wt-clean --repo $MAIN_REPO で実行してください）"
    exit 1
  fi
fi
```

以降、本スキル内の `git worktree list` / `git branch` / `git log` / `git fetch` / `git pull` / `git merge` / `git worktree remove` / `git worktree prune` は**すべて `git -C "$MAIN_REPO"`** で実行する。worktree 内で実行するものだけが `git -C "$WT"` である（この 2 つを取り違えないこと）。

### Step 0: Remote 同期（Sync）

GitHub 側で PR がマージされた feature ブランチを後段のマージ済み判定（`git branch --merged`）で正しく Safe 判定するため、対象選択・診断に先立ってローカル `<main>` を `origin/<main>` に同期する。`--no-sync` 指定時はこの Step を完全にスキップする。**位置引数で対象を指定した場合も Step 0 は実行される**（単一対象のマージ済み判定を正確にするため。`--no-sync` で停止可能）。

> ⚠️ **この同期で救えるのは普通の merge / ff だけ**。**squash マージ**は元ブランチの SHA が main に残らないため、同期しても `git branch --merged` / `git log main..branch` は未マージと誤判定する。squash の検出は Step B の遅延診断（後述の「squash マージの罠」）で行う。Step 0 同期を怠ると squash 以前に**普通の merge すら**未マージ誤判定するので、`--no-sync` は「直前に手動同期済み」など確信がある場合のみ使う。

```bash
# --no-sync 指定時は即座にスキップ
if [ "$NO_SYNC" = "1" ]; then
  echo "Remote 同期: -- skipped (--no-sync)"
  # Step A へ進む
fi

# origin remote の存在確認
if ! git -C "$MAIN_REPO" remote get-url origin >/dev/null 2>&1; then
  echo "Remote 同期: -- skipped (no origin remote)"
  # Step A へ進む
fi

# main / master 検出
MAIN_BRANCH="main"
git -C "$MAIN_REPO" show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true

# fetch。⚠️ コメントで「失敗時は中断」と書いても終了コードは検査されない。
# 必ず if ! ... で囲むこと（本スキルは set -e を前提にできない）。
# ここで失敗したまま進むと、古い origin/<main> を基準に削除判定を行うことになる。
if ! git -C "$MAIN_REPO" fetch origin; then
  echo "❌ git fetch origin に失敗しました。ネットワーク・認証を確認して再実行するか、同期済みなら --no-sync を指定してください。" >&2
  exit 1
fi

# 進行差を測定（左=ローカル独自, 右=remote 独自）
read AHEAD BEHIND < <(git -C "$MAIN_REPO" rev-list --left-right --count "$MAIN_BRANCH"...origin/"$MAIN_BRANCH" | awk '{print $1, $2}')

if [ "$BEHIND" = "0" ]; then
  echo "Remote 同期: ✅ already up-to-date"
elif [ "$AHEAD" = "0" ]; then
  # メインリポが <main> 以外をチェックアウトしている場合、pull は「現在のブランチ」への
  # マージになるため ff できず fatal: Not possible to fast-forward で落ちる。
  # その場合は作業ツリーを触らず、ref だけを ff 更新する。
  CURRENT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)
  if [ "$CURRENT_BRANCH" = "$MAIN_BRANCH" ]; then
    if ! git -C "$MAIN_REPO" pull --ff-only origin "$MAIN_BRANCH"; then
      echo "❌ git pull --ff-only origin $MAIN_BRANCH に失敗しました。git status / git log で状態を確認してください。" >&2
      exit 1
    fi
  else
    # refs/heads/<main> を直接 ff 更新（非 ff なら git 側が拒否するので安全）
    if ! git -C "$MAIN_REPO" fetch origin "$MAIN_BRANCH:$MAIN_BRANCH"; then
      echo "❌ origin/$MAIN_BRANCH からローカル $MAIN_BRANCH ref の更新に失敗しました。git status / git log で状態を確認してください。" >&2
      exit 1
    fi
    echo "  （メインリポは $CURRENT_BRANCH をチェックアウト中のため、作業ツリーに触れず ref のみ更新）"
  fi
  # 成功分岐の後だけ表示する（失敗しても "✅ pulled" が出る事故を防ぐ）
  echo "Remote 同期: ✅ pulled $BEHIND commits (origin/$MAIN_BRANCH → $MAIN_BRANCH)"
else
  echo "⚠️ ローカル $MAIN_BRANCH が origin/$MAIN_BRANCH と diverge しています"
  echo "  AHEAD=$AHEAD, BEHIND=$BEHIND"
  echo "  git status / git log で状態を確認し、解消後に再実行してください"
  echo "  （または --no-sync で同期をスキップして実行）"
  exit 1
fi
```

**失敗時の扱い**:
- `git fetch origin` 失敗（ネットワーク到達不能等）→ エラー中断。再実行 or `--no-sync` を案内
- `git pull --ff-only` / `git fetch origin <main>:<main>` 失敗（diverge / force-push）→ エラー中断。`git status` で状態確認するよう案内
- 中断時、Step C 完了レポートは表示しない

**禁則**: 本 Step では `git pull --ff-only` 以外の pull 戦略（merge / rebase）を使ってはならない。`<main>` 以外がチェックアウトされているときに、同期のためだけに `git checkout` でブランチを切り替えてはならない（ユーザーの作業ツリーを勝手に動かさない。ref 更新の `fetch <main>:<main>` を使う）。

### Step A: TARGETS 確定

#### Step A-1: 位置引数あり → 引数を解決

位置引数（パス／ブランチ名）が 1 個以上ある場合、リストアップ・対象選択を**行わず**、各引数トークンを解決して `TARGETS` に格納する。

```bash
# 解決ロジック（各トークンごと）。MAIN_REPO は Step -1 で確定済み。
resolve_token() {
  local token="$1"
  # 1. realpath 正規化 → worktree list の絶対パスと完全一致
  local abs
  abs=$(abs_path "$token")
  local matches
  matches=$(git -C "$MAIN_REPO" worktree list --porcelain | awk '/^worktree /{print $2}' | grep -Fx "$abs")

  # 2. パス一致しなければブランチ名として逆引き
  if [ -z "$matches" ]; then
    matches=$(git -C "$MAIN_REPO" worktree list --porcelain | awk '
      /^worktree /{wt=$2}
      /^branch /{sub("refs/heads/","",$2); if($2=="'"$token"'") print wt}
    ')
  fi

  echo "$matches"
}
```

各トークンの解決結果に応じて分岐:

- **マッチ 1 件かつメインリポでない** → `TARGETS` に追加
- **マッチ 0 件** → エラー: 「`<token>` に一致する worktree がありません」+ 現存 worktree 一覧を提示して**中断**（処理しない）
- **マッチ複数件** → 候補一覧を提示し、絶対パスでの再指定を促して**中断**（自動選択しない）
- **メインリポ自身を指す** → 「メインリポは削除対象外です」と表示して**中断**

```
❌ 'foo' に一致する worktree がありません。
現存 worktree:
  /Users/oratta/wt/bar  (fix-y, 3週間前)
  /Users/oratta/wt/baz  (wip-z, 今日)
絶対パスまたは正確なブランチ名で再指定してください。
```

全トークンの解決に成功したら Step B へ。

#### Step A-2: 位置引数なし → 全 worktree を確認なしで TARGETS に

位置引数がない場合（`--keep` / `--no-sync` のみ、または完全無指定）は、**対象選択の質問をせず全 worktree を `TARGETS` にする**。以前は「全て/個別/キャンセル」を AskUserQuestion で聞いていたが、これは廃止した（対象選択で処理が止まる／途中で終わる事故を防ぐため）。対象を絞りたいときは位置引数 `<path|branch>` を渡す。

> ℹ️ ここで対象選択のために `AskUserQuestion` を呼んではならない（SHALL NOT）。破壊判断が必要な 🔴 / dirty は Pass 2 で確認されるため、全件を対象にしても🟢/🟡 の安全な自動処理と 🔴/dirty の Pass 2 対話に正しく振り分けられる。

**リストアップ（遅延診断: 色を出さない・表示のみ）**

`git worktree list` を並べるだけにする。この時点で 🟢🟡🔴 のマージ済み判定・dirty スキャン・LLM 検出・未マージコミット数算出は**行わない**（SHALL NOT）。表示する情報は git 軽量コマンドで即取れるものに限定する。表示は「これから全件を対象に処理する」ことの通知であり、選択を求めるものではない:

```bash
# メインリポ自身は対象外。各 worktree のブランチ名と最終コミット日（相対）を表示
git -C "$MAIN_REPO" worktree list --porcelain | awk '
  /^worktree /{wt=$2}
  /^branch /{sub("refs/heads/","",$2); print wt"\t"$2}
  /^detached/{print wt"\t(detached HEAD)"}
' | while IFS=$'\t' read -r WT BR; do
  [ "$WT" = "$MAIN_REPO" ] && continue
  LAST=$(git -C "$WT" log -1 --format='%cr' 2>/dev/null)
  echo "  $WT  ($BR, $LAST)"
done
```

```
Worktree 一覧（全件を対象に処理します）:
  /Users/oratta/wt/foo  (feat-x, 2日前)
  /Users/oratta/wt/bar  (fix-y, 3週間前)
  /Users/oratta/wt/baz  (wip-z, 今日)
```

リストアップした全 worktree（メインリポ自身を除く）を `TARGETS` に格納し、そのまま Step B へ進む。worktree が 0 件なら「対象の worktree がありません」と表示して終了する。

### Step B: 2 パス処理（Pass 1 自動処理 → Pass 2 判断バッチ）

確定した `TARGETS` を `git worktree list` の順に 1 件ずつ、`[i/N]` 進捗表示付きで遅延診断する。診断結果に応じて **Pass 1 で自動処理できるものは確認なしで処理**し、判断が必要なもの（🔴 / dirty）は `DEFERRED` に積んで **Pass 2 でまとめて対話**する。Pass 1 の走行中に AskUserQuestion を呼んではならない（SHALL NOT — ブロックすると「実行して放置」ができなくなる）。

> ⚠️ **絶対禁則 1 の再掲**: 🟢 と 🟡（LLM 退避検証済み・dirty なし）の削除は Step A の対象確定を承認として自動実行してよいが、診断根拠の表示を省略しない。dirty 破棄・🔴 破棄削除・🔴 マージは Pass 2 の AskUserQuestion 回答を**受け取った後の別ターン**でのみ実行する。AskUserQuestion ツール呼び出しとこれらの Bash を**同一ターンの並列ツール呼び出しに含めてはならない**。回答が届いたら対象を読み直して再確定してから実行する。

```bash
# 競合中断などで先行処理済みを確定扱いするためのカウンタ
PROCESSED=()   # 削除/再利用化が完了したもの
SKIPPED=()     # スキップ
HELD=()        # サニティ FAIL / 競合 / 退避検証失敗で保留・未処理
DEFERRED=()    # 🔴 / dirty あり → Pass 2 の判断バッチへ
N=${#TARGETS[@]}
i=0
```

各 `WT`（`BRANCH_NAME` は `git worktree list` 由来のチェックアウト中ブランチ名）について:

```bash
i=$((i+1))
echo "[$i/$N] $WT をチェック中…"
```

**遅延診断**（この対象についてのみ実行）:

> ℹ️ 以下で使う `classify_dirty` / `detect_active_procs_under` / `detect_recent_session_log` は後述の「Step B-共通」節で定義している（`kill_devserver_under` と同じ扱い）。**Pass 1 のループに入る前にまとめて定義しておくこと。**

```bash
# 1. マージ済みか（SHA ベース。普通の merge / ff のみ検出できる）
MERGED=$(git -C "$MAIN_REPO" branch --merged "$MAIN_BRANCH" | grep -E "[[:space:]]$BRANCH_NAME$" || true)
# 2. 未マージコミット数（SHA ベース）
AHEAD_COUNT=$(git -C "$MAIN_REPO" log --oneline "$MAIN_BRANCH".."$BRANCH_NAME" 2>/dev/null | wc -l | tr -d ' ')
# 3. dirty（表示用の生データ）と、無害パターンを除いた実効 dirty
DIRTY=$(git -C "$WT" status --porcelain)
HARMLESS_DIRTY=""              # 無害と判定できた場合に根拠を入れる
EFFECTIVE_DIRTY="$DIRTY"       # 分類に使うのはこちら
if [ -n "$DIRTY" ]; then
  OFFENDERS=$(classify_dirty "$DIRTY")
  if [ -z "$OFFENDERS" ]; then
    HARMLESS_DIRTY="dirty=lockfileのみ ($(printf '%s\n' "$DIRTY" | wc -l | tr -d ' ')件: $(printf '%s\n' "$DIRTY" | sed 's/^...//' | tr '\n' ' '))"
    EFFECTIVE_DIRTY=""
  fi
fi
# 4. LLM/
LLM=$(ls "$WT/LLM/" 2>/dev/null)
# 5. 稼働シグナル（絶対禁則 3）: 配下の非シェルプロセス / 当日のセッションログ / worktree ロック
#    ここでは検出のみ行い、プロセスの停止・ロック解除は一切しない
#    （停止は削除直前の kill_devserver_under、解除は Pass 2 でユーザーが削除を選んだ後）
ACTIVE_PROCS=$(detect_active_procs_under "$WT")      # 例: "48213(claude), 48310(node)"
RECENT_SESSION=$(detect_recent_session_log "$WT")    # 例: "~/.claude/projects/<slug>/ab12.jsonl (3時間前)"
WT_LOCKED=$(detect_worktree_lock "$WT")              # 例: "added with --lock (2026-08-07 21:41)"
# 居残りの除外（issue #98）: プロセスは居るが起動元セッションが無く活動痕跡も無いなら、
# それは作業中ではなく残骸なので稼働シグナルから外す。外した事実は無音にせず、
# 削除直前の根拠表示に必ず出す（LEFTOVER_NOTE）。
LEFTOVER_NOTE=""
if [ -n "$ACTIVE_PROCS" ] && is_leftover_under "$WT"; then
  LEFTOVER_NOTE="居残り除外: $ACTIVE_PROCS（起動元セッションなし / 24h以内の更新なし / セッションログなし）"
  ACTIVE_PROCS=""
fi
ACTIVE_SIGNAL=""
[ -n "$ACTIVE_PROCS" ] && ACTIVE_SIGNAL="稼働中プロセス: $ACTIVE_PROCS"
[ -n "$RECENT_SESSION" ] && ACTIVE_SIGNAL="${ACTIVE_SIGNAL:+$ACTIVE_SIGNAL / }直近セッションログ: $RECENT_SESSION"
[ -n "$WT_LOCKED" ] && ACTIVE_SIGNAL="${ACTIVE_SIGNAL:+$ACTIVE_SIGNAL / }worktree ロック: $WT_LOCKED"
```

**⚠️ squash マージの罠（最重要・必読）**: `git branch --merged` も `git log main..branch` も**コミット SHA の到達可能性**で判定する。**squash マージ**（GitHub の "Squash and merge"）では PR の全コミットが main 上で 1 個の**新しい SHA** に潰れるため、元ブランチの SHA はどれも main の祖先にならず、**実際にはマージ済みでも `AHEAD_COUNT > 0`（= 🔴 Active）と誤判定する**。Step 0 の remote 同期で救えるのは**普通の merge / ff だけ**で、squash は救えない。squash 運用のプロジェクト（PR を Squash merge で取り込む）ではほぼ全 PR がこの罠に該当する。

過去に同一セッションで 3 連続「マージ済みブランチを未マージ誤判定 → ユーザーに『ほんとに？マージ済みだと思ってる。ちゃんと確認して』と指摘される」事故が発生している。

そこで **`AHEAD_COUNT > 0` のときは即 🔴 と判定せず、squash マージ済みでないかを必ず追加検証する**:

> 🚨 **実ツリー差分にパスフィルタを掛けてはならない（SHALL NOT・データロス直結）。**
> かつて検証A は `-- 'src/**' 'app/**' 'lib/**' 'tests/**' 'e2e/**' '*.ts' '*.tsx' '*.js' '*.jsx'` という
> JS/TS 前提のパスフィルタを付けていた。この結果、**Markdown・シェル・Python 中心のリポジトリでは
> 対象ファイルが 1 つも一致せず差分が常に空になり、全ブランチが無条件で「squash 済み」と誤判定された**。
> 2026-08-10 に flatmate で実走したとき、PR が OPEN のままの未マージブランチ 6 本（うち 1 本は
> 106 ファイル・914 行の差分あり）が揃って「マージ済み」と判定された。このとき削除を実際に止めたのは
> git 自身の worktree ロックで、判定ロジックは 1 つも守っていない。
> 検証A は**全 tracked ファイルを対象**にする。「言語ごとの主要ソースだけ見れば十分」は成り立たない。

**判定の原則: 「マージ済み」と言うには、実際に成功した検査からの積極的な証拠を要求する（fail-closed）。** 検査が失敗したとき、その失敗が「マージ済み」を示す側に倒れてはならない。旧実装は `gh ... | grep -c` の形だったため、`gh` が未認証・通信断で失敗しても `grep -c` が 0 を返し、**OPEN PR の拒否権が黙って消えていた**（パイプの終了コードは末尾の `grep` のもので、`gh` の失敗は観測できない）。

```bash
SQUASHED=""            # squash マージ済みと判定できたら理由を入れる
NOT_MERGED_REASON=""   # 未マージと判定した根拠（Pass 2 の提示に使う）
if [ "$AHEAD_COUNT" != "0" ]; then
  # 検証A: 両 tip の tracked tree が完全一致するか。
  #   一致 = 内容保存の十分条件（branch の tracked 内容は全て main にある＝削除で失われない）。
  #   不一致は main 側が先行しただけでも起きるため、「branch 固有の内容がある」証拠にはならない
  #   （この非対称性が重要。不一致を単独で未マージ判定に使わない）。
  TREE_STATE="unknown"; TREE_DIFF=""
  if TREE_DIFF=$(git -C "$MAIN_REPO" diff "$MAIN_BRANCH" "$BRANCH_NAME" --stat 2>/dev/null); then
    if [ -z "$TREE_DIFF" ]; then TREE_STATE="equal"; else TREE_STATE="different"; fi
  fi

  # 検証B: git cherry は Pass 2 の診断表示のためだけに取る。単独では自動削除の根拠にしない
  #   （squash は patch-id が変わるため + が出る／失敗時も 0 に見えるため、両方向に信用できない）。
  CHERRY_STATE="unknown"; CHERRY_PLUS=""; CHERRY_OUTPUT=""
  if CHERRY_OUTPUT=$(git -C "$MAIN_REPO" cherry "$MAIN_BRANCH" "$BRANCH_NAME" 2>/dev/null); then
    CHERRY_PLUS=$(printf '%s\n' "$CHERRY_OUTPUT" | awk '$1=="+"{c++} END{print c+0}')
    CHERRY_STATE="known"
  fi

  # 検証C: PR 状態。gh をパイプに繋がず、変数代入の終了コードで成否を判定する。
  #   まず「そもそも PR 状態を取れて当然の環境か」を決める。GitHub リモートかつ gh がある
  #   場合のみ、取得失敗を異常（= fail-closed の対象）とみなす。非 GitHub / gh 不在の
  #   ローカル運用リポでは PR 検査は構造的に N/A で、失敗扱いにすると永久に自動削除できなくなる。
  GH_APPLICABLE=0
  if command -v gh >/dev/null 2>&1 &&
     git -C "$MAIN_REPO" remote get-url origin 2>/dev/null | grep -qi 'github\.com'; then
    GH_APPLICABLE=1
  fi

  PR_STATE="n/a"; PR_OPEN=""; PR_MERGED=""; PR_MERGED_AT_HEAD="0"; MERGED_PR_NUMBER=""
  if [ "$GH_APPLICABLE" = "1" ]; then
    PR_STATE="unknown"
    BRANCH_OID=""; PR_OPEN_RESULT=""; PR_MERGED_RESULT=""
    # gh はリポジトリを cwd から解決するため、--repo 指定時に cwd のリポを見に行かないよう
    # MAIN_REPO 側で実行する（-C を持たないので subshell で cd する）
    if BRANCH_OID=$(git -C "$MAIN_REPO" rev-parse "$BRANCH_NAME^{commit}" 2>/dev/null) &&
       PR_OPEN_RESULT=$( (cd "$MAIN_REPO" && gh pr list --head "$BRANCH_NAME" --state open --limit 1 --json number --jq 'length') 2>/dev/null) &&
       PR_MERGED_RESULT=$( (cd "$MAIN_REPO" && gh pr list --head "$BRANCH_NAME" --state merged --limit 100 --json number,headRefOid --jq '.[] | [.number, .headRefOid] | @tsv') 2>/dev/null); then
      case "$PR_OPEN_RESULT" in
        ''|*[!0-9]*) ;;   # 成功しても件数として解釈できなければ unknown のまま
        *)
          PR_STATE="known"
          PR_OPEN="$PR_OPEN_RESULT"
          PR_MERGED=$(printf '%s\n' "$PR_MERGED_RESULT" | awk 'NF{c++} END{print c+0}')
          # 「マージ済み PR が存在する」だけでは現在の tip が取り込まれた証明にならない
          # （マージ後に同じブランチへ追加コミットしても件数は 1 のまま）。
          # PR の headRefOid が現在の tip と一致することまで確認する。
          MERGED_PR_NUMBER=$(printf '%s\n' "$PR_MERGED_RESULT" | awk -F'\t' -v oid="$BRANCH_OID" '$2==oid{print $1; exit}')
          [ -n "$MERGED_PR_NUMBER" ] && PR_MERGED_AT_HEAD="1"
          ;;
      esac
    fi
  fi

  if [ "$PR_STATE" = "unknown" ]; then
    # GitHub リポなのに PR 状態を取れない = OPEN PR が無いことを確認できない
    NOT_MERGED_REASON="PR 状態を確認できない（gh 未認証・通信失敗等。OPEN PR の不在を確認できないため自動削除しない）"
  elif [ "$PR_STATE" = "known" ] && [ "$PR_OPEN" != "0" ]; then
    # OPEN な PR は「レビュー中の生きた作業」。ツリーが一致していても自動削除の対象にしない
    NOT_MERGED_REASON="PR が OPEN（レビュー中の作業）"
  elif [ "$TREE_STATE" = "equal" ]; then
    SQUASHED="squash済み (tracked tree が $MAIN_BRANCH と完全一致)"
  elif [ "$PR_MERGED_AT_HEAD" = "1" ]; then
    SQUASHED="squash済み (merged PR #$MERGED_PR_NUMBER の headRefOid が branch tip と一致)"
  else
    NOT_MERGED_REASON="自動削除の十分条件なし (tree=$TREE_STATE, cherry+=${CHERRY_PLUS:-unknown}, pr=$PR_STATE, merged_pr_at_head=$PR_MERGED_AT_HEAD)"
  fi
fi
```

判定規則（**「どれか 1 つでもマージ済みを示せば squash 済み」という旧規則は廃止した**）。上から順に評価し、最初に当たったものを採る:

| 順 | 状況 | 判定 | 根拠 |
|---|---|---|---|
| 1 | GitHub リポなのに PR 状態を取得できない | **未マージ** | OPEN PR の不在を確認できない。検査不能をマージ済み側に倒さない |
| 2 | OPEN な PR がある | **未マージ**（他の検証で覆さない） | レビュー中の作業を掃除対象にしない |
| 3 | tracked tree が main と完全一致 | squash 済み | ブランチの内容が全て main にある＝削除で内容を失わない |
| 4 | マージ済み PR の `headRefOid` が現在の tip と一致 | squash 済み | この tip 自体が取り込まれたことの直接証拠 |
| 5 | 上記いずれにも当たらない | **未マージ（🔴）** | マージ済みと言える積極的な証拠が無い |

- **ツリー差分の非対称性を守る**: 「差分が空」は削除して安全であることの十分条件だが、「差分がある」はブランチに未マージ内容があることを意味しない（main が先行しただけでも差分は出る）。したがって差分の有無を**未マージ判定の根拠には使わない**。
- **マージ済み PR の件数を根拠にしない**: 同名 head ブランチのマージ済み PR が 1 件あっても、そのマージ後に同じブランチへコミットを積んでいれば現在の tip は未マージである。必ず `headRefOid` と tip の一致まで確認する。
- **`cherry` を削除許可に使わない**: squash では patch-id が変わって `+` が出るため未マージの証明にならず、コマンド失敗時も 0 になるためマージ済みの証明にもならない。Pass 2 の表示にのみ使う。
- **非 GitHub / gh 不在のリポでは PR 検査を N/A とし、tracked tree の一致だけで判断する**。ここを「取得失敗」と同じ扱いにすると、ローカル運用リポで自動削除が永久に効かなくなるため区別する。

分類（color は対象ごとにその場で決める）:

| カテゴリ | 条件 |
|---|---|
| 🟢 Safe | マージ済み（`MERGED` or `SQUASHED`）& **実効 dirty なし（`EFFECTIVE_DIRTY` が空）** & LLM なし & **稼働シグナルなし（`ACTIVE_SIGNAL` が空）** |
| 🟡 Recoverable | マージ済み（`MERGED` or `SQUASHED`）だが LLM あり or **実効 dirty あり** or **稼働シグナルあり** |
| 🔴 Active | `AHEAD_COUNT > 0` **かつ** `SQUASHED` が空（squash でも普通 merge でもなく、本当に未マージの固有コミットがある） |

**squash 済み（`SQUASHED` が非空）の worktree は 🟢/🟡 として扱う**。`AHEAD_COUNT > 0` でも 🔴 にしない。ブランチ削除は元 SHA が main の祖先にならないため `git branch -D`（大文字）を使う。

Pass 1 では、カテゴリに応じて以下へ分岐する:

- 🟢 Safe → **Step B-🟢**（確認なしで自動削除／`--keep` 時は自動再利用化）
- 🟡 で実効 dirty なし & 稼働シグナルなし（LLM のみ）→ **Step B-🟡**（LLM 退避 → 検証 → 確認なしで自動削除）
- 🟡 で実効 dirty あり／**🟡 で稼働シグナルあり**／🔴 Active → **破壊操作はその場では一切行わない**。判断材料（dirty stat・未マージコミット一覧・LLM 有無・`ACTIVE_SIGNAL` の内訳）をこの時点で収集・表示し、LLM があれば非破壊の退避（コピー + 検証）だけ済ませて `DEFERRED+=("$WT")` し、次の対象へ進む。Pass 1 完了後に **Step B Pass 2** でまとめて対話する

> ⚠️ **稼働シグナルは 🟢/🟡 の自動処理を止めるためだけに使う**（絶対禁則 3）。`ACTIVE_SIGNAL` が非空なら、git 状態がどれだけクリーンでも Pass 1 の自動削除・自動再利用化の分岐に**入れてはならない**。`--keep` 指定時も同様（再利用化は元ブランチを `git branch -d` で消すため、作業中セッションにとっては同じく破壊的）。

#### Step B-共通: 無害な dirty の判定（`classify_dirty`）

`git status --porcelain` の各行を見て、**成果物でないと言い切れるファイル**（依存解決の副産物である lockfile）だけの汚れなら「無害な dirty」として扱い、分類上は clean と同じにする。

2026-08-07 に shukan-dev で実走したところ、dirty 判定された 9 本すべてが `package-lock.json` の同一の 11 行削除（`npm install` の副産物）だった。これを全部 Pass 2 に送ると、無人モードでは大半が保留に落ちて自動化の効果がほぼ消える（実測: 14 本中 🟢 が 3 本、うち 4 本が lockfile ノイズだけで Pass 2 行き）。

```bash
# 無害パターン（初期セット）。ここに無いファイルが 1 つでもあれば従来どおり dirty 扱い（安全側）。
# 追加するときは「消えても再生成できる」ことが機械的に保証できるものだけにする。
HARMLESS_DIRTY_FILES="package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock poetry.lock"

# porcelain 出力を受け取り、無害パターンに当てはまらないパスだけを出力する。
# 出力が空 = 全部無害。1 行でもあれば dirty 扱い。
classify_dirty() {
  local porcelain="$1" line path base
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path=${line:3}                 # "XY path" の path 部分
    path=${path##* -> }            # rename は新パス側を見る
    # 未追跡ディレクトリ（"?? dir/"）は中身が分からないため無害と見なさない
    case "$path" in
      */) echo "$path"; continue ;;
    esac
    # 外部 basename は使わない（最小 PATH の非対話シェルで command not found になる実績あり）
    base=${path##*/}
    base=${base%\"}                # core.quotePath による末尾のダブルクォートを落とす
    case " $HARMLESS_DIRTY_FILES " in
      *" $base "*) ;;              # 無害
      *) echo "$path" ;;           # 無害でない
    esac
  done <<< "$porcelain"
}
```

- 判定に使うのは `EFFECTIVE_DIRTY`（無害分を除いたもの）、**表示に使うのは `DIRTY`（生データ）**。無害と判断して削除するときは `HARMLESS_DIRTY` の根拠を必ず出す（無音削除の禁止は無害 dirty でも同じ）
- `core.quotePath` によりパスがダブルクォートで囲まれることがある。囲まれていても `basename` の一致には影響しないが、判定に迷ったら**無害と見なさない**（安全側）
- 無害 dirty はあくまで**分類上 clean と同じにする**だけで、禁則 2（LLM）・禁則 3（稼働シグナル）の判定には一切影響しない

#### Step B-共通: 稼働シグナルの検出（診断時・非破壊）

絶対禁則 3 の稼働シグナルを検出する 3 つのヘルパ。**遅延診断の中でのみ呼び、プロセスの停止・ロック解除・ファイルの変更は一切行わない**（破壊操作は削除直前の `kill_devserver_under` だけが行う）。

```bash
# 対象パス配下で稼働中のプロセス ID を列挙する（生の PID のみ・除外リスト適用前）。
# 検出範囲を 1 箇所に集約するためのヘルパで、detect_active_procs_under と
# is_leftover_under の両方がこれを使う（範囲がずれると両者の判定が食い違う）。
list_pids_under() {
  local abs="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof +D "$abs" 2>/dev/null | awk 'NR>1{print $2}' | sort -u
  else
    pgrep -f "$abs" 2>/dev/null | sort -u
  fi
}

# 検出した PID 集合の「外」に生きた親を持つプロセスがあるかを返す（0=ある）。
# 集合の外の親とは、そのプロセス群を起動した側（ターミナルのシェル・orca・エージェント
# ランナー等）のこと。それがまだ生きているなら、誰かがこの worktree でセッションを
# 開いたままにしているということで、居残りではない。
# 親が PID 1 なら起動元は既に終了して init/launchd に引き取られている＝孤児。
has_live_parent_outside() {
  local pids="$1" pid ppid
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')
    [ -n "$ppid" ] || continue                            # 引けない = 既に終了した短命プロセス
    [ "$ppid" = "1" ] && continue                         # init に引き取られた孤児
    printf '%s\n' "$pids" | grep -qx "$ppid" && continue  # 親も集合の中 = 同一セッションの子
    return 0
  done <<< "$pids"
  return 1
}

# worktree 配下に 24 時間以内に更新されたファイルがあれば、その 1 件目を返す。
# .git 配下を除外するのは、wt-clean 自身が診断で git を呼ぶと index 等が更新され、
# 「常に活動あり」になって判定が意味を失うため。
detect_recent_activity_under() {
  local abs="$1" hit
  [ -d "$abs" ] || { echo ""; return 0; }
  hit=$(find "$abs" -type f -mtime -1 -not -path '*/.git/*' -print -quit 2>/dev/null | head -1)
  if [ -n "$hit" ]; then
    echo "$hit ($(date -r "$hit" '+%Y-%m-%d %H:%M' 2>/dev/null))"
  else
    echo ""
  fi
}

# 配下で稼働中の非シェルプロセスを列挙する。
# 検出範囲と除外リストは kill_devserver_under と完全に同一に保つこと
# ——「kill_devserver_under が停止する対象が居るなら自動削除しない」という対応関係が本ガードの根拠。
detect_active_procs_under() {
  local target="$1" abs pids pid comm out=""
  # 正規化できないまま空パスで lsof を撃つと、何も返らないのに「プロセスなし」と
  # 表示される silent no-op になる。失敗は稼働シグナルとして扱う（削除しない側へ）。
  if ! abs=$(abs_path "$target"); then
    echo "プロセス検査不能: パスを解決できない（安全のため稼働扱い）"
    return 0
  fi

  pids=$(list_pids_under "$abs")

  # ⚠️ `for pid in $pids` と書いてはならない。zsh は未クォート変数を単語分割しないため
  #    複数行の $pids が 1 要素に潰れ、検出が黙って 1 件（実質ゼロ件）になる。
  #    while read + here-string なら bash / zsh のどちらでも行ごとに回る。
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | xargs -I{} basename {} 2>/dev/null)
    # comm が引けない = lsof と ps の間に終了した短命プロセス。既に居ないので稼働シグナルにしない。
    # （kill 側にこの分岐は無い。あちらは「消えた PID に空振りの kill を撃つ」だけで無害だが、
    #   こちらで拾うと全 worktree が毎回 Pass 2 送りになり、ガードが形骸化する）
    [ -n "$comm" ] || continue
    # kill_devserver_under と同じ除外リスト（対話用シェル/エディタは稼働シグナルにしない）
    case "$comm" in
      bash|zsh|sh|fish|tmux|ssh|vim|nvim|code|Cursor|login) continue ;;
    esac
    out="${out:+$out, }$pid($comm)"
  done <<< "$pids"
  echo "$out"
}

# 配下のプロセスが「作業中」ではなく残骸（居残り）かを返す（0=居残り）。issue #98。
# **3 条件の AND**で、ひとつでも欠けたら居残りと見なさない（＝従来どおり稼働シグナル扱い）。
# 孤児だけを根拠にすると launchd 常駐の住人セッションを、活動痕跡が無いことだけを根拠にすると
# 「開いたまま少し離席している対話セッション」を、それぞれ誤って削除対象にしてしまう。
# 判定不能（パス解決失敗・ps が引けない）も居残りと見なさない側に倒す。
is_leftover_under() {
  local target="$1" abs pids
  abs=$(abs_path "$target") || return 1
  pids=$(list_pids_under "$abs")
  [ -n "$pids" ] || return 1                                  # そもそもプロセスが居ない
  has_live_parent_outside "$pids" && return 1                 # 起動元セッションがまだ生きている
  [ -n "$(detect_recent_activity_under "$abs")" ] && return 1 # 配下に 24h 以内の更新がある
  [ -n "$(detect_recent_session_log "$target")" ] && return 1 # 24h 以内のセッションログがある
  return 0
}

# worktree に対応する Claude セッションログのうち、24 時間以内に更新された .jsonl を探す。
# プロセスが一時的に落ちている壁打ちセッションを拾うための補助判定。
#
# slug の候補を広く取る理由が 2 つある。どちらも**取りこぼし＝作業中 worktree の誤削除**に
# 直結するため、候補は多すぎるくらいでちょうどよい（誤検出の最悪は Pass 2 で 1 問増えるだけ）。
#   1. projects ディレクトリの slug 規則は Claude Code のバージョンで揺れる
#      （`.` を `-` に置換する版としない版が混在する）
#   2. **symlink 経由のパスと物理パスで slug が変わる**。abs_path は物理パスを返すが、
#      Claude Code 側の projects ディレクトリはセッションが見ていた論理パスで作られている
#      ことがある（macOS の /var → /private/var、Dropbox 配下の symlink 等）。
#      物理パスだけで探すと、そこに実在するログを取りこぼす。
detect_recent_session_log() {
  local target="$1" abs logical slug dir hit
  if ! abs=$(abs_path "$target"); then
    echo "セッションログ検査不能: パスを解決できない（安全のため稼働扱い）"
    return 0
  fi

  # 論理パス（symlink を解決しないまま絶対化したもの）も候補に含める
  case "$target" in
    /*) logical="$target" ;;
    *)  logical="$PWD/$target" ;;
  esac

  # 各ベースパスについて 候補A: `/` と空白のみ `-` に置換（旧形式・`.` を残す）
  #                   候補B: 候補A に加えて `.` も `-` に置換（新形式）
  local base slug_a slug_b slugs=""
  for base in "$abs" "$logical"; do
    [ -n "$base" ] || continue
    slug_a=$(printf '%s' "$base" | sed 's/[/ ]/-/g')
    slug_b=$(printf '%s' "$slug_a" | sed 's/\./-/g')
    slugs="$slugs$slug_a
$slug_b
"
  done

  # 重複を除いて順に探す
  for slug in $(printf '%s' "$slugs" | awk 'NF && !seen[$0]++'); do
    dir="$HOME/.claude/projects/$slug"
    [ -d "$dir" ] || continue
    # -mtime -1 = 24時間以内（BSD/GNU find 共通）
    hit=$(find "$dir" -maxdepth 1 -name '*.jsonl' -mtime -1 2>/dev/null | head -1)
    if [ -n "$hit" ]; then
      echo "$hit ($(date -r "$hit" '+%Y-%m-%d %H:%M' 2>/dev/null))"
      return 0
    fi
  done
  echo ""
}

# worktree が git worktree lock されているかを返す（ロック理由 + ロックファイルの更新時刻）。
# ロックは「別のセッション/エージェントがこの worktree を所有している」という最も強い信号で、
# git worktree list が既に持っている情報のため追加コストはゼロ。
# ロック時刻も併せて返すのは、Pass 2 で「今まさに作業中」と「PR マージ後の外し忘れ」を
# ユーザーが見分けられるようにするため（古いロックは後者の可能性が高い）。
# 対象 worktree 専用の管理ディレクトリから locked ファイルを直接検査する。
# ⚠️ `git worktree list --porcelain` を空白区切りで解析してはならない（SHALL NOT）。
#    porcelain の worktree 行はパス全体が入るため、`awk '{print $2}'` 系は
#    "/Users/x/my repo/foo" を "/Users/x/my" に切り落とし、ロックを取りこぼす。
# 検査に失敗した場合は空文字（＝ロックなし）を返さず、「ロック状態不明」という
# 非空の稼働シグナルを返して Pass 2 に送る（検査不能を安全側に倒す）。
detect_worktree_lock() {
  local target="$1" abs gitdir lockfile reason mtime

  if ! abs=$(abs_path "$target"); then
    echo "ロック状態不明: 対象パスを解決できない（安全のため稼働扱い）"
    return 0
  fi

  # worktree 管理情報そのものを読めない場合は「ロックなし」に倒さない
  if ! git -C "$MAIN_REPO" worktree list --porcelain >/dev/null 2>&1; then
    echo "ロック状態不明: git worktree list --porcelain 失敗（安全のため稼働扱い）"
    return 0
  fi

  # 対象 worktree 専用の gitdir を直接取得する
  # （linked worktree では <main-git-dir>/worktrees/<name> の絶対パスになる）
  if ! gitdir=$(git -C "$abs" rev-parse --absolute-git-dir 2>/dev/null); then
    echo "ロック状態不明: worktree の gitdir を解決できない（安全のため稼働扱い）"
    return 0
  fi

  lockfile="$gitdir/locked"
  if [ ! -e "$lockfile" ]; then
    echo ""
    return 0
  fi

  # locked ファイルの中身がロック理由。空ファイルも有効なロックとして扱う
  reason=""
  IFS= read -r reason < "$lockfile" || true

  if mtime=$(date -r "$lockfile" '+%Y-%m-%d %H:%M' 2>/dev/null); then
    echo "${reason:-locked} ($mtime)"
  else
    echo "${reason:-locked}"
  fi
}
```

**誤検出（false positive）は許容する**。稼働シグナルの誤検出が起こしうる最悪は「削除されず Pass 2 で 1 問聞かれる」だけであり、見逃し（false negative）の最悪は「作業中セッションの永久消失」である。判定は常に**検出する側に倒す**。

> ℹ️ **ロックは他の 2 つと性質が違う**。配下プロセスとセッションログは「今動いているか」の観測だが、ロックは**明示的な所有権の宣言**であり、放置されると古いまま残る（wt-setup の hooks が `--lock` 付きで作った worktree は、PR がマージされてもロックが自動で外れない）。そのため Pass 2 の提示ではロック時刻を必ず併記し、ユーザーが「作業中」と「外し忘れ」を区別できるようにする。**ロックが古いことを理由にスキル側で自動削除に格下げしてはならない**（SHALL NOT）。判断はユーザーに委ねる。

#### Step B-共通: 削除前のプロセス停止（devサーバー等）

`git worktree remove` を呼ぶ**全ての分岐**（🟢 / 🟡 / Pass 2 の 🔴 破棄削除・🟡 dirty 破棄・🔴 マージ後削除）は、実行前に必ず以下の `kill_devserver_under` を呼び、削除対象パス配下で稼働中のプロセスを停止する。`git worktree remove --force` は参照先ソースが消えた状態でプロセスだけ生き残ることがあり（issue #39: `next dev` プロセスツリーが worktree 削除後も2日以上残留し再ビルドループで CPU 165〜210%・swap 98% に達したインシデントの実例）、削除の**前に**必ず停止する。停止結果（PID・コマンド名、または「プロセスなし」）は無音にせず必ず表示する（無音削除の禁止と同じ思想）。

```bash
kill_devserver_under() {
  local target="$1"
  local abs
  abs=$(abs_path "$target")

  # 検出: lsof +D は対象パス配下に実際にオープンファイル/cwdを持つプロセスのみを返す
  # （pgrep -f はコマンドライン文字列の部分一致のため誤検出しうる。lsof 不在時のみフォールバック）
  local pids
  if command -v lsof >/dev/null 2>&1; then
    pids=$(lsof +D "$abs" 2>/dev/null | awk 'NR>1{print $2}' | sort -u)
  else
    echo "  ⚠️ lsof が見つかりません。pgrep -f にフォールバックします"
    pids=$(pgrep -f "$abs" 2>/dev/null | sort -u)
  fi

  if [ -z "$pids" ]; then
    echo "  プロセス残留チェック: $abs 配下に稼働中プロセスなし"
    return 0
  fi

  # ⚠️ comm はここで 1 回だけ宣言する。ループ本体に `local comm` を置くと、zsh では
  #    2 周目以降の再宣言が `comm=sleep` のように**変数の中身を標準出力に印字する**
  #    （bash は無言）。停止レポートの途中にゴミ行が混ざるため、宣言はループ外に出す。
  local killed=() skipped=() comm
  # ⚠️ `for pid in $pids` と書いてはならない（detect_active_procs_under と同じ理由）。
  #    zsh では複数行の $pids が 1 要素に潰れ、存在しない PID 1 個に kill を撃って
  #    「1件も止められないのに成功したように見える」状態になる。
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | xargs -I{} basename {} 2>/dev/null)
    # 対話用のシェル/エディタ（対象 worktree に cd しているだけのセッション）は誤 kill を避けるため除外。
    # 除外リストに無いコマンドは全て停止対象にする（false negative より false positive を避ける設計）。
    case "$comm" in
      bash|zsh|sh|fish|tmux|ssh|vim|nvim|code|Cursor|login)
        skipped+=("$pid($comm)")
        continue
        ;;
    esac
    kill -TERM "$pid" 2>/dev/null
    # ⚠️ 区切り文字に `(` を使ってはならない（issue #66）。`${entry%%(*}` は zsh で
    #    `bad pattern: (*` というパースエラーになり、`|| true` でも救えずシェルごと即死する。
    #    しかも死ぬのは killed が非空のとき、つまり kill -TERM 送信後・SIGKILL
    #    フォールバック前・git worktree remove 前という最悪の位置。パターンメタ文字では
    #    ない `|` を区切りにし、表示だけ "$pid($comm)" に組み立て直す。
    killed+=("$pid|$comm")
  done <<< "$pids"

  if [ ${#killed[@]} -gt 0 ]; then
    sleep 3
    for entry in "${killed[@]}"; do
      pid="${entry%%|*}"
      comm="${entry##*|}"
      if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null
        echo "  🔪 devサーバー(PID $pid($comm))を SIGKILL で停止しました（SIGTERM後も生存）" # 表示は $pid($comm) に戻す
      else
        echo "  🔪 devサーバー(PID $pid($comm))を停止しました"
      fi
    done
  fi
  if [ ${#skipped[@]} -gt 0 ]; then
    echo "  ⚠️ シェル/エディタと判定してスキップ: ${skipped[*]}"
  fi
}
```

検出範囲は削除対象パス（`$WT`）配下に厳密に限定される（`lsof +D`／`pgrep -f` とも `$abs` 配下のみを対象にする）ため、メインリポや他の worktree のプロセスを誤って止めることはない。

#### Step B-🟢: Safe → 確認なしで削除（`--keep` 時は再利用化）

AskUserQuestion は行わない。Step A で TARGETS に含めたことを承認とみなし、**診断根拠を 1 行表示してから**自動実行する（無音削除の禁止）。

`ACTIVE_SIGNAL` が非空の対象はここに来ない（絶対禁則 3 により Pass 1 の分岐で `DEFERRED` 行き）。

**削除モード（デフォルト）**:

```bash
# HARMLESS_DIRTY が非空なら「なぜ dirty なのに削除してよいのか」の根拠をここに必ず出す
echo "  🟢 Safe: merged=${MERGED:+branch--merged}${SQUASHED:+$SQUASHED} / ${HARMLESS_DIRTY:-clean} / LLMなし / 稼働シグナルなし${LEFTOVER_NOTE:+ / $LEFTOVER_NOTE} → 削除します"
kill_devserver_under "$WT"
git -C "$MAIN_REPO" worktree remove "$WT" --force
git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"    # SQUASHED のときは -D（元 SHA が main の祖先にならないため）
PROCESSED+=("$BRANCH_NAME (🟢 削除)")
```

**再利用モード（`--keep`、🟢 のみ）**: 処理前に main/master の重複チェックアウト競合を検査する。

```bash
# 他の worktree が既に MAIN_BRANCH をチェックアウトしているか
OTHER_CHECKOUT=$(git -C "$MAIN_REPO" worktree list | awk -v b="[$MAIN_BRANCH]" '$NF==b {print $1}' | grep -v "^$MAIN_REPO$" | head -1)

if [ -n "$OTHER_CHECKOUT" ]; then
  echo "⚠️ $MAIN_BRANCH は $OTHER_CHECKOUT で既にチェックアウト中 → $WT の再利用化をスキップ"
  HELD+=("$BRANCH_NAME (再利用化スキップ: main 使用中)")
else
  git -C "$WT" checkout "$MAIN_BRANCH"
  git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🟢 再利用化)")
  # worktree ディレクトリは残す。node_modules / .env / untracked は全て保持
fi
```

**禁則（worktree 内, SHALL NOT）**: `git -C "$WT" reset --hard` / `git -C "$WT" clean -fd` / `git -C "$WT" pull` / `git -C "$WT" fetch`。`<main>` の最新化は Step 0 がメインリポで実行済み。

マージを伴わない 🟢 再利用化・🟡 削除では**サニティチェックを走らせない**（既に main にマージ済みのため）。

#### Step B-🟡: Recoverable（実効 dirty なし・稼働シグナルなし・LLM のみ）→ LLM 退避 → 検証 → 確認なしで削除

実効 dirty がある 🟡（`EFFECTIVE_DIRTY` 非空）、および `ACTIVE_SIGNAL` が非空の 🟡 はここに来ない（Pass 1 の分岐で `DEFERRED` 行き）。無害 dirty のみの 🟡 はここに来る（削除時に `HARMLESS_DIRTY` の根拠を表示すること）。

```bash
# LLM ファイルをメインリポに退避（ファイル名にセッションIDが含まれ衝突しない）
mkdir -p "$MAIN_REPO/LLM"
cp "$WT/LLM/"* "$MAIN_REPO/LLM/" 2>/dev/null

# 退避検証（絶対禁則 5）: 元と同数のファイルが退避先に実在し、空でないこと
SRC_COUNT=$(ls "$WT/LLM/" | wc -l | tr -d ' ')
OK_COUNT=0
for f in "$WT/LLM/"*; do
  dst="$MAIN_REPO/LLM/$(basename "$f")"
  [ -s "$dst" ] && OK_COUNT=$((OK_COUNT+1))
done
```

- **検証成功（`OK_COUNT == SRC_COUNT`）** → 診断根拠と退避結果を表示して確認なしで削除:
  ```bash
  echo "  🟡 Recoverable: merged / ${HARMLESS_DIRTY:-clean} / 稼働シグナルなし / LLM ${SRC_COUNT}files → 退避検証OK → 削除します"
  kill_devserver_under "$WT"
  git -C "$MAIN_REPO" worktree remove "$WT" --force   # LLM/ は gitignore 対象のため --force が必要
  git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"        # SQUASHED のときは -D
  PROCESSED+=("$BRANCH_NAME (🟡 LLM退避→削除)")
  ```
- **検証失敗** → 削除しない。`HELD+=("$BRANCH_NAME (LLM退避検証失敗)")` として次の対象へ

#### Step B Pass 2: 判断バッチ（🔴 Active / dirty あり 🟡 / 稼働シグナルあり 🟡）

Pass 1 が全対象を処理し終えた後にのみ実行する。`DEFERRED` が空なら対話せず Step C へ。

> 🤖 **`--unattended` 指定時は、この節の状況表示までを行い `AskUserQuestion` を呼ばずに Step C へ抜ける**（後述「無人モード」）。以降の選択肢提示・回答待ち・選択ごとの分岐には**一切入らない**。

非空なら、各対象の状況を**まとめて**表示する。`ACTIVE_SIGNAL` が非空の対象は、検出内容（PID・コマンド名／セッションログの更新時刻／ロック理由と時刻）を必ず明示する（絶対禁則 3）。未マージと判定した対象は `NOT_MERGED_REASON` をそのまま出す。ユーザーが判断できる材料はこれだけなので省略・要約してはならない:

```
自動処理が完了しました（削除 3 / 保留 0）。残り 4 件は判断が必要です:

[1] baz (wip-z) — 🔴 未マージ
  判定根拠: ツリー差分あり / cherry+=3 / マージ済みPRなし
  未マージコミット: 3件
    abc1234 feat: ユーザー登録フォームの追加
    def5678 fix: バリデーションエラー
    ghi9012 chore: テスト整備
  Dirty: なし / LLM: なし

[2] qux (fix-q) — 🟡 dirty あり
  マージ済みだが未コミット変更あり:
    src/foo.ts | 12 ++++++++----
  LLM: あり（退避済み）

[3] business-idea (idea-x) — 🟡 稼働中の可能性
  git 上はマージ済み・clean・LLM なし（＝従来なら 🟢 Safe 判定）
  ⚠️ 稼働中プロセスあり: 48213(claude), 48310(node)
  ⚠️ 直近セッションログ: ~/.claude/projects/-Users-…-business-idea/ab12.jsonl (2026-08-07 14:32)
  → 壁打ち等の進行中セッションの可能性があります。削除するとプロセスも停止されます

[4] agent-a3ac2db (agent/issue-148-xxx) — 🔴 未マージ + ロック
  判定根拠: PR が OPEN（レビュー中の作業） — PR #289
  ⚠️ worktree ロック: added with --lock (2026-08-07 21:41)
  → 削除するには先に git worktree unlock が必要です（Pass 1 では自動解除しません）
```

**`--unattended` ならここで打ち切る**（`DEFERRED` を全件 `SKIPPED` として Step C の完了レポートへ。破壊操作は一切行わない）。以下は対話モード（`--unattended` なし）のみ。

続けて AskUserQuestion で **1 対象 1 問**として選択させる。1 回の呼び出しは最大 4 問なので、`DEFERRED` が 4 件を超える場合は複数回に分け、各回の提示範囲を明示する（無音での打ち切りを行わない）。

選択肢の出し分け（対象ごと）:

- **🔴 通常（Dirty なし & ブランチ名あり）**: 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択
- **🔴 Dirty 同時**: マージ選択肢を**除外**し「1) スキップ / 2) 破棄削除 (force)」の 2 択。理由明示「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」
- **🔴 detached HEAD（`BRANCH_NAME` 空）**: マージ選択肢を除外し同 2 択。理由明示「⚠️ detached HEAD のためマージできません（マージ対象のブランチ名がありません）」
- Dirty と detached が両方該当する場合も 2 択を提示し、両方の理由を併記する
- **🟡 dirty あり**: 「1) 変更を破棄して削除 / 2) スキップ」の 2 択（LLM は Pass 1 で退避・検証済みであることを前提とし、未退避なら実行前に退避する）
- **🟡 稼働シグナルあり（dirty なし）**: 「1) スキップ（推奨） / 2) 削除する（稼働中プロセスも停止される）」の 2 択。**推奨をスキップ側に置く**（絶対禁則 3 — 判断がつかないまま削除する方が損失が大きい）。稼働中プロセスの PID・コマンド名を選択肢の説明に含める

回答を受け取ったら、**別ターンで**回答がどの worktree を指すか読み直して再確定し、選択ごとに逐次実行する（絶対禁則 1）。

> ℹ️ **ロック済み worktree の削除にはロック解除が要る**。`git worktree remove --force`（`-f` 1 個）はロック済み worktree を `fatal: cannot remove a locked working tree` で拒否する。ユーザーが Pass 2 で削除を選んだ対象がロックされている場合に限り、削除の直前に `git -C "$MAIN_REPO" worktree unlock "$WT"` を実行してよい。**Pass 1 での自動 unlock は禁止**（SHALL NOT）。以下の削除分岐はいずれも次の `unlock_if_locked` を通す。

```bash
# Pass 2 でユーザーが削除を選んだ対象にのみ使う。ロックされていなければ何もしない。
# ロック状態を確認できない場合・解除に失敗した場合は非 0 を返し、呼び出し側で削除を中断する
# （確認できないまま remove に進むのは、ロックガードを無効化するのと同じ）。
unlock_if_locked() {
  local wt="$1" lock_state
  lock_state=$(detect_worktree_lock "$wt")

  case "$lock_state" in
    "")
      return 0
      ;;
    ロック状態不明:*)
      echo "❌ $lock_state。削除を中断します: $wt" >&2
      return 1
      ;;
    *)
      echo "  🔓 worktree のロックを解除します（ユーザーが削除を承認済み）: $wt"
      if ! git -C "$MAIN_REPO" worktree unlock "$wt"; then
        echo "❌ worktree のロック解除に失敗したため、削除を中断します: $wt" >&2
        return 1
      fi
      ;;
  esac
}
```

**選択ごとの分岐**:

- **スキップ** → 状態維持。`SKIPPED+=("$BRANCH_NAME")`
- **破棄削除 (force)**（🔴） →
  ```bash
  kill_devserver_under "$WT"
  unlock_if_locked "$WT" || exit 1
  git -C "$MAIN_REPO" worktree remove --force "$WT"
  git -C "$MAIN_REPO" branch -D "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🔴 破棄削除)")
  ```
- **変更を破棄して削除**（🟡 dirty あり） →
  ```bash
  kill_devserver_under "$WT"
  unlock_if_locked "$WT" || exit 1
  git -C "$MAIN_REPO" worktree remove --force "$WT"
  git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"    # SQUASHED のときは -D
  PROCESSED+=("$BRANCH_NAME (🟡 dirty破棄→削除)")
  ```
- **削除する**（🟡 稼働シグナルあり・dirty なし） →
  ```bash
  kill_devserver_under "$WT"        # ここで初めて稼働中プロセスを停止する（ユーザーが承認済み）
  unlock_if_locked "$WT" || exit 1   # 状態確認・解除に失敗したら remove に進まない
  git -C "$MAIN_REPO" worktree remove "$WT" --force
  git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"      # SQUASHED のときは -D
  PROCESSED+=("$BRANCH_NAME (🟡 稼働シグナルあり→ユーザー承認で削除)")
  ```
- **マージ** → 下記マージ実行へ

**マージ実行**（メインリポで `MAIN_BRANCH` チェックアウト下、`--no-ff` 必須）:

事前確認（いずれか該当ならマージ処理を中断し案内）:

```bash
CURRENT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  echo "⚠️ メインリポが $MAIN_BRANCH 以外をチェックアウト中（現在: $CURRENT_BRANCH）。マージ処理を中断します。"
  echo "  対応: cd $MAIN_REPO && git checkout $MAIN_BRANCH してから wt-clean を再実行してください。"
  # この対象は HELD、ループ中断
fi
if [ -f "$MAIN_REPO/.git/MERGE_HEAD" ]; then
  echo "⚠️ メインリポで前回のマージが進行中（.git/MERGE_HEAD 検出）。マージ処理を中断します。"
  echo "  対応: cd $MAIN_REPO で git status を確認し、競合解決→commit、または git merge --abort してから再実行してください。"
  # この対象は HELD、ループ中断
fi
```

マージ:

```bash
git -C "$MAIN_REPO" merge "$BRANCH_NAME" --no-ff \
  -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"
```

- **成功** → そのまま Step B-サニティ（マージ都度）へ
- **競合（exit 非 0）** → `git merge --abort` は**自動実行しない**（SHALL NOT）。`.git/MERGE_HEAD` を保持したまま中断する。
  - 競合より前に処理が完了したもの（Pass 1 の自動処理分と、Pass 2 で先に処理した分。いずれも `PROCESSED`）は**確定済みとして扱い巻き戻さない**
  - 競合した worktree（`HELD`）以降の未処理 `DEFERRED` は処理しない
  - ループを抜けて Step C（競合中断レポート）へ

```
⚠️ マージで競合が発生しました:
  Branch: wip-z → main
  Conflict files:
    src/foo.ts
対応手順:
  1. cd <main-repo>
  2. 競合を解決して `git add` + `git commit`
  3. wt-clean を再実行
※ wip-z worktree は削除されていません（競合状態を保持）。
※ 以降の未処理対象も処理を中断しました。
※ `git merge --abort` で main を戻したい場合は手動で実行してください（自動 abort はしません）。
```

**Step B-サニティ（マージ都度）**:

マージ成功直後に、そのマージ分についてメインリポでテスト/ビルドを実行する。

```bash
cd "$MAIN_REPO"
# テストコマンド自動検出（最初に見つかったスタックを使用）
# Node.js : package.json の scripts から test/lint/typecheck/build
#   例: npm test, npm run lint, npm run typecheck, npm run build
# Rust    : Cargo.toml → cargo test, cargo clippy, cargo build
# Python  : pyproject.toml / setup.py → pytest
# Go      : go.mod → go test ./..., go vet ./...
# 見つからなければスキップして削除へ
```

- **全 PASS（またはテスト未検出）** → 通常削除（`--keep` 指定でもマージを伴うため**通常削除**にフォールバック）:
  ```bash
  kill_devserver_under "$WT"
  git -C "$MAIN_REPO" worktree remove "$WT" --force
  git -C "$MAIN_REPO" branch -d "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🔴 マージ→削除, N commits)")
  ```
- **FAIL** → 当該 worktree は削除せず保留:
  ```
  ⚠️ マージ後チェックで問題が検出されました:
    失敗コマンド: npm test
    エラー出力: [抜粋]
    このマージ（wip-z）が原因の可能性があります。
  → この worktree は削除せず保持します。
  ```
  `HELD+=("$BRANCH_NAME (サニティ FAIL 保留)")`。FAIL 後は安全側に倒し、ユーザーに「以降の処理を続けるか中断するか」を AskUserQuestion で確認する。**`--unattended` ではこの確認も行わず、その場で中断して Step C へ抜ける**（無人モードではそもそもマージが起きないためここには到達しないが、到達した場合も対話しない）。

### Step C: 完了レポート

`--repo` を指定した場合は、先頭に対象リポジトリを 1 行で表示する（`対象リポジトリ: $MAIN_REPO`）。cwd と対象がずれる実行形態なので、どのリポを掃除したのかがレポートだけで分かるようにする。

続けて Step 0 の同期結果を 1 行で表示する:
- `Remote 同期: ✅ pulled N commits (origin/<main> → <main>)`
- `Remote 同期: ✅ already up-to-date`
- `Remote 同期: -- skipped (--no-sync)`
- `Remote 同期: -- skipped (no origin remote)`

続けて `PROCESSED` / `SKIPPED` / `HELD` と残存 worktree 件数を区別表示する。自動処理分（Pass 1）と判断バッチ分（Pass 2）が区別できるよう表示する。

```
wt-clean 完了:
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  対象: 4 worktrees（全件・確認なし）
  自動処理（確認なし）: feat-x (🟢 削除), bar (🟡 LLM退避→削除)
  再利用化: -
  判断バッチ: wip-z (🔴 マージ→削除, 3 commits merged)
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: fix-q (🟡 dirty, ユーザー選択), idea-x (🟡 稼働シグナル, ユーザー選択)
  LLMコピー: 2 files → LLM/（退避検証 OK）
  残存worktrees: 1
```

稼働シグナルで判断バッチに回った対象は、選択結果にかかわらず検出内容をレポートにも 1 行残す:

```
  ⚠️ 稼働シグナルで自動処理を保留: idea-x — 稼働中プロセス 48213(claude) / セッションログ 2026-08-07 14:32
```

**再利用モード（`--keep`）** のレポートには、再利用化した worktree ごとにディレクトリパスと次作業コマンドを含める:

```
  再利用化: feat-x
    ディレクトリ: /Users/oratta/repo/.worktrees/feat-x
    現在ブランチ: main（元 feat-x は削除済み）
    次の作業: cd /Users/oratta/repo/.worktrees/feat-x && git checkout -b <new-branch>
注意:
  - package.json / Gemfile 等が更新されていれば、再作業前に依存を再インストールしてください
  - 必ず git checkout -b <new-branch> で新ブランチを切ってから作業を開始してください
```

**サニティ FAIL 保留時**:
```
  ⚠️ チェック失敗で保留: fix-y — npm test FAIL
      → 削除も再利用化も行われていません
```

**競合中断時**:
```
wt-clean 中断:
  Remote 同期: ✅ already up-to-date
  対象: 3 worktrees（中断）
  削除確定: feat-a (🔴 マージ→削除, 確定済み)
  ⚠️ マージ競合で中断: feat-b (src/foo.ts)
      → 競合解決後に wt-clean を再実行してください
  未処理: feat-c
  残存worktrees: 2
```

## 無人モード（`--unattended`）

cron から定期実行するためのモード。**「危ないものだけを対話に送る」という既存の 2 パス設計をそのまま使い、その対話を報告に置き換えるだけ**である。禁則を緩めるのではなく、禁則対象（dirty 破棄・🔴 破棄・🔴 マージ）の分岐に**入らないルート**を足している。

### 挙動

| Step | `--unattended` での挙動 |
|---|---|
| Step -1 / Step 0 / Step A | 通常どおり（`--repo` と併用されることが多い） |
| Pass 1（🟢・🟡 の自動処理） | **通常どおり実行する**。ここは元々確認なしの分岐であり、無人でも判定基準は 1 ミリも変えない |
| Pass 2 | 状況を表示したら **`AskUserQuestion` を呼ばずに終了**。`DEFERRED` は全件 `SKIPPED` 扱い |
| Step C | 通常のレポート + 「判断が必要な残件」の一覧 |

### SHALL NOT（無人モード固有）

- `--unattended` 実行中に **`AskUserQuestion` を呼んではならない**（Pass 2 の判断バッチ・サニティ FAIL 後の継続確認を含め、例外なく）
- Pass 2 の破壊分岐（dirty 破棄・🔴 破棄削除・🔴 マージ）を**実行してはならない**。「無人だから自動で判断する」は絶対禁則 1 の違反
- 禁則 3（稼働シグナル）のガードを**無人だからといって緩めてはならない**。むしろ人間の目が入らない実行形態なので、このガードが最後の砦になる
- Pass 1 の判定基準（squash 3 重検証・LLM 退避検証・無害 dirty の判定）を**無人だからといって甘くしてはならない**

### 完了レポート（無人モード）

Pass 2 送りになった対象を、**番号・パス・ブランチ名・分類・理由**付きで列挙する。cron のログをあとから人間が読んで判断できることが唯一の出口なので、件数だけの要約で済ませてはならない。

```
wt-clean 完了（無人モード）:
  対象リポジトリ: /Users/oratta/repos/flatmate
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  対象: 14 worktrees（全件・確認なし）
  自動処理（確認なし）: 7 件
    feat-a (🟢 削除), feat-b (🟢 削除, dirty=lockfileのみ), feat-c (🟡 LLM退避→削除) …
  残存worktrees: 7

判断が必要な残件（無人モードのため未処理・4 件）:
  [1] /Users/oratta/wt/wip-z   ブランチ: wip-z    分類: 🔴 未マージ
      理由: 未マージコミット 3 件（squash 検証も未マージと判定）
  [2] /Users/oratta/wt/fix-q   ブランチ: fix-q    分類: 🟡 dirty
      理由: src/foo.ts ほか 2 ファイルに未コミット変更（lockfile 以外を含む）
  [3] /Users/oratta/wt/idea-x  ブランチ: idea-x   分類: 🟡 稼働シグナル
      理由: 稼働中プロセス 48213(claude) / セッションログ 2026-08-07 14:32
  [4] /Users/oratta/wt/det-h   (detached HEAD)    分類: 🔴 未マージ
      理由: detached HEAD のためマージ判定不能

→ 対話モードで処理するには: wt-clean --repo /Users/oratta/repos/flatmate
```

### cron への載せ方（参考）

各住人の `cron-jobs.md` に週 1 の反応型ジョブとして登録する運用を想定している（本スキルの範囲外）。ジョブ側は次を守ること:

- `--repo` を必ず指定する（住人の作業ディレクトリと対象リポジトリを分離するため）
- 出力は破棄せずログに残す。残件一覧は人間が後で読む前提の成果物である

## 🔴 Active worktree の強制破棄（破棄削除選択時）

Step B Pass 2 で「破棄削除 (force)」を選んだ場合のみ:

1. 未マージコミットのログ・未コミット変更の diff は判断バッチの提示時点で表示済みであること（未表示なら実行前に表示する）
2. LLM ファイルがあればコピーし、退避検証（絶対禁則 5）を行う
3. `kill_devserver_under "$WT"` で削除対象パス配下の稼働中プロセス（devサーバー等）を停止する
4. `git worktree remove --force` + `git branch -D`（大文字 D = 強制削除）

判断バッチでの「破棄削除」回答がユーザーの最終確認である。追加の「本当に削除しますか？」は挟まない（判断材料は回答前に提示済みであることが前提）。ただし回答が曖昧（どの対象か特定できない・選択肢外の自由入力）な場合は実行せず確認し直す。

## エッジケース

- メインリポ自体が worktree の場合: スキップ（削除対象外）
- detached HEAD の worktree: ブランチ削除はスキップ。🔴 判定時はマージ選択肢を除外（Step B Pass 2）
- worktree のパスが存在しない（既に手動削除済み）: `git -C "$MAIN_REPO" worktree prune` で整理
- `--repo` に worktree のパスを渡された: エラーにせず、`git worktree list` の 1 行目からメイン worktree に正規化して続行する（Step -1）
- `--repo` に git リポジトリでないパスを渡された: エラー中断（Step -1）。Step C 完了レポートは表示しない
- `--unattended` で `DEFERRED` が 0 件: 残件一覧の節は出さず、通常の完了レポートのみ表示する
- Superset 作成の worktree: 削除後「Superset UI 上でも not found になるので UI から削除してください」と案内

## 自己検証

完了宣言の前に成果物の evidence を確認する（原則: `plugins/loops/references/self-verification.md`、詳細手順: `plugins/worktree/references/wt-clean-verification.md`）。

- 削除した worktree が `git worktree list` に現れないことを確認する。
- 🟡 判定で LLM 退避を行った場合、退避先ファイルが実在し空でないことを**削除前に**検証済みであることを確認する（検証失敗のまま削除していないこと）。
- 🟢/🟡 の自動削除について、削除直前に診断根拠を表示したことを確認する（無音削除をしていないこと）。
- 稼働シグナル（配下の非シェルプロセス／24時間以内のセッションログ）を検出した worktree を Pass 1 で自動削除・自動再利用化していないこと、および Pass 2 の提示に検出内容（PID・コマンド名／セッションログ更新時刻）を含めたことを確認する（絶対禁則 3）。
- **検査の失敗が「マージ済み」側に倒れていないこと**（パスフィルタなしの実ツリー差分・`headRefOid` 一致・`gh` の終了コード・ロック検出・Step 0 の同期）。個別項目は `plugins/worktree/references/wt-clean-verification.md` の「判定が『マージ済み』側に倒れていないことの確認」を参照する。
- worktree ロックを検出した対象を Pass 1 で自動処理せず、Pass 1 で `git worktree unlock` を実行していないことを確認する（解除は Pass 2 で削除を選んだ対象のみ）。
- dirty 破棄・🔴 破棄削除・🔴 マージを行った場合、それぞれ Pass 2 の AskUserQuestion 回答後の別ターンで実行したことを確認する。
- `git worktree remove` の直前に `kill_devserver_under` を実行し、削除対象パス配下にプロセス残留が無いことを確認したこと（停止した PID または「プロセスなし」がログに表示されていること）。
- 無害 dirty（lockfile のみ）として自動処理した場合、削除直前の表示に `dirty=lockfileのみ` と対象ファイル名が含まれていることを確認する。lockfile 以外を 1 つでも含む worktree が自動処理されていないことも確認する。
- `--unattended` で実行した場合、`AskUserQuestion` を**一度も呼んでいない**こと、Pass 2 の破壊分岐を実行していないこと、残件が番号・パス・ブランチ名・分類・理由付きでレポートに列挙されていることを確認する。
- `--repo` を指定した場合、操作対象が指定リポジトリのメイン worktree に解決されており、cwd 側のリポジトリの worktree・ブランチが一切変更されていないことを確認する（`git -C <cwd-repo> worktree list` が実行前後で不変）。
