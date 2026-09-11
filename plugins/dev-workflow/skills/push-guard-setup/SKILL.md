---
name: push-guard-setup
description: マージ済み PR のブランチへの push を全リポジトリで拒否するグローバル pre-push ガードを導入する（`~/.githooks/pre-push` + `git config --global core.hooksPath`）。「push ガードを入れて」「マージ済みブランチへの push を止めたい」「グローバル git フックを設定して」で起動。人間の手打ち push と Claude の push の両方を同じ層で止める。
version: 1.0.2
allowed-tools: Read, Write, Edit, Bash
---

# push-guard-setup — グローバル push ガードの導入

マージ済み PR のブランチへ push しても変更はどこにも取り込まれない。それでも push は成功して見えるため、
気づくのが遅れるほど「どのコミットが宙に浮いたか」の調査と積み直しにコストがかかる。典型的な発生経路は
**マージ後に残った worktree での作業再開**である。

このスキルは、その事故を**リポジトリを問わず**止めるグローバル pre-push フックを導入する。git のフックは
コマンドの出所を問わないため、人間がターミナルで打つ push も、Claude が Bash で実行する push も、
同じ 1 枚で止まる（Claude 専用の PreToolUse deny では人間の手打ちが漏れる）。

## 層の構成（このスキルが担うのは上段だけ）

| 層 | 置き場所 | 内容 | 対象 |
|---|---|---|---|
| **グローバル**（このスキル） | `~/.githooks/pre-push` + `git config --global core.hooksPath` | マージ済み PR チェックのみ | 全リポジトリ |
| **リポジトリローカル** | `<repo>/.githooks/pre-push`（loop-dev-agent 導入済み repo。flatmate の `new-resident` が設置） | main/master 直 push 拒否。マージ済み PR チェックは、そのフックがグローバルの pre-push を呼ぶか同じチェックを内包したときだけ付く（`new-resident` が設置する既存のフックは main 拒否だけ） | 自律開発ループ導入 repo（ローカル設定が入っている clone だけ） |

**ローカルの `core.hooksPath` はグローバル設定より優先される**（git の設定優先順位）。ただしこれは
**その clone のローカル設定に `core.hooksPath` が入っているときだけ**成り立つ。git がフックを探すのは
`core.hooksPath` が指す 1 か所だけなので、リポジトリが `<repo>/.githooks/pre-push` を追跡していても、
ローカル設定の無い clone ではグローバル層だけが走り、ローカル層（main 拒否）は一度も実行されない。
ローカル設定は clone ごとの設定で、`git clone` では入らない（同じ clone のワークツリー間では共有される）。

したがって loop-dev-agent を導入済みのリポジトリでも、厳しい方（main 拒否込み）のローカル層が使われるのは
ローカル設定が入っている clone でだけである。入っている clone では、このスキルの導入によって緩くなることは
ない。設定の入れ方と、入れた clone でグローバル層を失わない書き方は、下の
「PR 運用リポジトリでリポジトリローカルのフックを有効にする」にある。

**グローバル層に main/master 直 push 拒否を入れない理由**: `~/.claude/rules/git-commit-policy.md` の
**ローカル main 運用**のリポジトリでは、承認後の `git push origin main` が正常系である。これを全
リポジトリで拒否すると正当な操作を壊す。main の封鎖は「PR 運用」と決めたリポジトリのローカル層に閉じる。

## Step 0: preflight

```bash
gh auth status                              # gh CLI が認証済みであること（未認証でも壊れないが、ガードは効かない）
git config --global --get core.hooksPath    # 既存値の確認（後述）
ls -la ~/.githooks 2>/dev/null              # 既存ディレクトリの確認
```

**`git config --global --get core.hooksPath` に既に別の値が入っている場合は、上書きする前に必ず
利用者へ確認する**（他のツールのフック集を無言で置き換えないため）。既存値を活かしたい場合は、
このスキルのフック本体を既存ディレクトリの `pre-push` にマージする方針を提案し、利用者の判断を仰ぐ。
既に `~/.githooks` が設定されている場合は再導入（上書き）でよい。

## Step 1: グローバルフックのテンプレート

`~/.githooks/pre-push` を以下の内容で作成する。

```sh
#!/bin/sh
# global push guard: マージ済み PR のブランチへの push を拒否する（全リポジトリ共通）
#
# main/master への直接 push は「ここでは」拒否しない。ローカル main 運用のリポジトリでは
# 承認後の main への push が正常系であり、全リポジトリで拒否すると正当な操作を壊すため。
# PR 運用のリポジトリでは、リポジトリローカルの .githooks/pre-push が main も拒否する。
zero="0000000000000000000000000000000000000000"

# gh を最大 3 秒で実行し "<merged件数> <open件数>" を返す。
# timeout(1) は macOS に無いため外部コマンドに依存せず、バックグラウンド + ポーリングで打ち切る。
# stdin はフック本体が push 対象の ref を読んでいるので、子プロセスには渡さない。
pr_counts() {
  _out=$(mktemp) || return 1
  gh pr list --head "$1" --state all --json state \
    --jq '"\([.[]|select(.state=="MERGED")]|length) \([.[]|select(.state=="OPEN")]|length)"' \
    >"$_out" 2>/dev/null </dev/null &
  _pid=$!
  _deadline=$(( $(date +%s) + 3 ))   # 壁時計で最大 3 秒（回数ベースだと sleep のプロセス生成コストで上限が保証されない）
  while kill -0 "$_pid" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$_deadline" ]; then
      kill "$_pid" 2>/dev/null
      rm -f "$_out"
      return 1
    fi
    sleep 0.1
  done
  wait "$_pid" 2>/dev/null || { rm -f "$_out"; return 1; }
  cat "$_out"
  rm -f "$_out"
}

while read local_ref local_sha remote_ref remote_sha; do
  # ブランチ削除 push は許可（マージ済みブランチの削除はむしろ望ましい）
  [ "$local_sha" = "$zero" ] && continue
  # 明示バイパス
  [ "${PREPUSH_ALLOW_MERGED:-0}" = "1" ] && continue

  branch=${remote_ref#refs/heads/}
  [ "$branch" = "$remote_ref" ] && continue   # refs/heads/ 以外（tag 等）は対象外

  # gh が使えない・失敗する・3 秒で応答しない場合は fail-open（オフラインや未認証で作業を止めない）
  counts=$(pr_counts "$branch") || continue
  set -- $counts
  merged=$1
  open=$2
  case "$merged" in ''|*[!0-9]*) continue ;; esac
  case "$open"   in ''|*[!0-9]*) continue ;; esac

  # マージ済み PR があり、open な PR が無い = 行き先の無いブランチ
  if [ "$merged" -gt 0 ] && [ "$open" -eq 0 ]; then
    echo "pre-push: $branch はマージ済み PR のブランチです（open な PR がありません）" >&2
    echo "pre-push: このまま push しても変更はどこにも取り込まれません。新しいブランチを切ってください:" >&2
    echo "pre-push:   git switch -c <new-branch> && git push -u origin <new-branch>" >&2
    echo "pre-push: 意図的に push する場合は PREPUSH_ALLOW_MERGED=1 git push ... で明示バイパスできます" >&2
    exit 1
  fi
done
exit 0
```

## Step 2: 設置と配線

```bash
mkdir -p ~/.githooks
# 上記テンプレートを ~/.githooks/pre-push として書き出す
chmod +x ~/.githooks/pre-push
git config --global core.hooksPath ~/.githooks
```

**この手順は冪等である**。フックファイルの上書きと設定の再設定しか行わないため、2 回以上実行しても壊れない。

## Step 3: 反映確認

```bash
git config --global --get core.hooksPath          # ~/.githooks が返ること
grep -q PREPUSH_ALLOW_MERGED ~/.githooks/pre-push && echo "hook installed"
```

実リポジトリでの確認は `--dry-run` で行える（pre-push フックは `--dry-run` でも実行されるため、
remote を一切変更せずに拒否を確認できる）:

```bash
# マージ済みブランチへの push が拒否されること
git push --dry-run origin HEAD:refs/heads/<マージ済みブランチ名>
# 通常のブランチへの push が通ること
git push --dry-run origin HEAD:refs/heads/<新しいブランチ名>
```

## 副作用と回避方法（導入前に利用者へ伝える）

グローバル `core.hooksPath` を設定すると、**自前で `core.hooksPath` を設定していないリポジトリの
`.git/hooks/` 直置きフックが無効化される**。git は hooksPath を「どちらか一方」としてしか見ないため。

- husky など、自分で `core.hooksPath` を設定するツールを使っているリポジトリは影響を受けない
- loop-dev-agent 導入済みのリポジトリも、その clone のローカル設定に `core.hooksPath` が入っていれば影響を受けない（入っていなければ `.githooks/` のフックも走らない。下の「PR 運用リポジトリでリポジトリローカルのフックを有効にする」）
- `.git/hooks/` に手書きのフックがあるリポジトリだけが影響を受ける。そのリポジトリで元に戻すには:

  ```bash
  git config core.hooksPath .git/hooks   # 当該リポジトリだけグローバル設定から離脱する
  ```

導入前に、影響を受けうるリポジトリを確認したい場合:

```bash
# 対象リポジトリで実行し、サンプル以外のフックが無いことを確認する
ls ~/path/to/repo/.git/hooks | grep -v '\.sample$'
```

## PR 運用リポジトリでリポジトリローカルのフックを有効にする

`.githooks/pre-push`（main/master への直接 push 拒否など）を追跡している PR 運用のリポジトリでは、
**各 clone で 1 回**、ローカル設定を入れないとそのフックは走らない（上の「層の構成」）。実例は
[kg-recruit#126](https://github.com/oratta/kg-recruit/issues/126): ローカル設定が住人の clone にしか無く、
人間のメインチェックアウトと全ワークツリーで main を守るフックが死んでいた。

```bash
# 対象リポジトリの clone で 1 回実行する（ワークツリーは clone の設定を共有するので、ワークツリーごとには不要）
git config --local core.hooksPath .githooks

# 設定の有無を確認する（何も出ずに exit 1 なら未設定で、.githooks/ のフックは走っていない）
git config --local --get core.hooksPath
```

worktree プラグインの wt-setup は、`.githooks/` を追跡していてローカル側に値が無いリポジトリでワークツリーを
作ると、この設定を自動で入れる。ローカル側（`config.worktree` や include 経由を含む）に既存の値があれば
上書きせず、`.git/hooks/` に `.sample` 以外の既存のフック（Git LFS の pre-push など）があれば切り替えずに
その旨を知らせる。どちらの場合も、入れるなら上のコマンドで入れる。ワークツリーを一度も作らない clone でも
入らないので、同じく上のコマンドで入れる。

**有効にすると、その clone ではグローバルのフック（マージ済み PR のブランチへの push 拒否）が走らなくなる**。
失わないためには、ローカルの pre-push からグローバルの pre-push を呼ぶか、同じチェックを内包する。

### ローカルの pre-push からグローバルの pre-push を呼ぶ例

kg-recruit#127 で使った書き方。git は push 対象の ref を標準入力で 1 回だけ渡すので、変数に保持して、
自分の判定とグローバルのフックの両方に同じ内容を渡す。グローバルの設定がこのフック自身のディレクトリを
指しているときに呼ぶと自分自身を呼び続けるので、`pwd -P` で解決して比べ、違うときだけ呼ぶ。

```sh
#!/bin/sh
# <repo>/.githooks/pre-push: main/master への直接 push を拒否し、そのあとグローバルの pre-push を呼ぶ
input=$(cat)

protected="main master"
while read -r local_ref local_sha remote_ref remote_sha; do
  for b in $protected; do
    if [ "$remote_ref" = "refs/heads/$b" ]; then
      echo "pre-push: $b への直接 push は禁止です。feature ブランチに push して PR を作成してください" >&2
      exit 1
    fi
  done
done <<EOF
$input
EOF

# グローバルのフックへ同じ引数と標準入力を渡す。未設定・自分自身を指す場合は呼ばない
global_dir=$(git config --global --type=path --get core.hooksPath 2>/dev/null)
if [ -n "$global_dir" ] && [ -x "$global_dir/pre-push" ] &&
   [ "$(cd "$global_dir" 2>/dev/null && pwd -P)" != "$(cd "$(dirname "$0")" && pwd -P)" ]; then
  printf '%s\n' "$input" | "$global_dir/pre-push" "$@"
  exit $?
fi
exit 0
```

## 設計方針

- **拒否するのは「merged な PR が 1 件以上 ∧ open な PR が 0 件」のときだけ**。初回 push（PR 未作成）や、
  同名ブランチで意図的に PR を開き直したケースは通す
- **`gh` の失敗時は fail-open**。ガードのために日常の push が止まると `--no-verify` が常用され、
  ガード全体が形骸化する
- **3 秒で打ち切る**。fail-open は「最終的には通す」保証でしかなく、回線が死んでいると `gh` の接続
  タイムアウトまでフックが固まる。全リポジトリ・全 push に効かせる層では致命的なので、外部コマンドに
  依存しないポーリングで打ち切る
- **`gh` の呼び出しは 1 回**（`--state all` で取得して merged / open を jq で数える）。実測で 2 回呼びは
  +約 1.0 秒、1 回なら約 0.5 秒
- closed（マージされず閉じた）PR のブランチは対象外。意図的な作り直し運用があり誤検知率が高いため
- 見逃した分は第 2 層（GitHub の「Automatically delete head branches」）と第 3 層（マージ後の
  `/wt-clean`）で回収する

## してはならないこと

- 既存の `git config --global core.hooksPath` を確認せずに上書きしない
- グローバル層に main/master 直 push 拒否を追加しない（ローカル main 運用のリポジトリを壊す）
- 常駐プロセスや cron を作らない（このスキルが作るのはフック 1 ファイルと git 設定 1 行だけ）

## 自己検証

導入後、以下がすべて成立することを確認して初めて「導入できた」と報告する:

1. `git config --global --get core.hooksPath` が `~/.githooks` を返す
2. `~/.githooks/pre-push` が実行可能（`test -x`）である
3. マージ済みブランチへの `git push --dry-run` が exit 1 で拒否される
4. 通常のブランチへの `git push --dry-run` が exit 0 で通る

3 と 4 の実行結果（コマンドと exit code）をターン内に表示すること。自己申告のみの完了宣言は禁止。
