# Design

## Context

- claude-harness の展開先 `.github/workflows/auto-merge.yml` の `SACRED`（`# >>> sacred-paths` マーカーの間）は、ディレクトリをプレフィックスで丸ごと聖域にする方針で書かれ、hook については `^plugins/[^/]+/hooks/` だけを持つ。hooks.json の `command` はどれも `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>"` の形で、本体は `plugins/<name>/scripts/` にある。
- 2026-11-10 時点で hooks.json が直接指すスクリプトは 5 プラグイン計 24 本（capability-registry 2・cost-ledger 3・dev-workflow 13・statusline 1・worktree 5。dev-workflow の `context-tripwire.sh` は 2 つのイベントから呼ばれるので 1 本と数える）。
- 許可を判定する hook のうち 3 本は判定の本体を別ファイルに置く: `git-destructive-guard.sh` と `rm-permission-guard.sh` が `git-guard-scratchpad.py` を実行し、`agent-model-guard.sh` が `usage_view.py` を import し、`secret-guard.sh` が `secret-guard.py` を実行する。
- `plugins/*/scripts/` には約 70 本あり、`epic-dispatch.sh`・`ci-watch.sh` など develop の中心のスクリプトは hook の経路に無い。
- `scripts/test-auto-merge-workflow.sh` は `SACRED` を workflow から抜き出し、代表パスに grep で当てて挙動を確かめる。CI（`ci.yml` のジョブ）で毎 PR 走る。展開先のこのファイルは原本からすでに分岐しており（リポ固有の代表パスを持つ）、原本と同一である必要は無い。
- `MERGE_CONDITION` は `SACRED` の部分集合で、親の判断の印でも `human-merge` を外せない範囲。

## Goals / Non-Goals

**Goals:**

- hooks.json が直接指すスクリプトと、許可の判定の本体である補助 3 本に触れた PR を `human-merge` で止める。
- hook を足して `SACRED` に書き忘れたとき、CI で気付けるようにする。

**Non-Goals:**

- 原本（`plugins/dev-workflow/templates/auto-merge/`）の正規表現・テスト・README の変更。
- `MERGE_CONDITION` の変更。
- 補助ファイルの自動収集（推移的な依存の追跡）。
- hook のスクリプト自体の変更、親が許可を書くスクリプトを hook から呼ぶ形に変えること。

## Decisions

### パスをファイル名ちょうどで列挙し、CI の検査で漏れを拾う

`SACRED` に、プラグインごとに `^plugins/<name>/scripts/(<a>\.sh|<b>\.sh|...)$` の形で 1 つの選択肢を置き、24 本＋補助 3 本をファイル名ちょうどで書く。`SACRED` の上のコメントの「個別ファイル名を列挙しない」という方針の例外として、列挙が許される理由（hooks.json との突き合わせを CI が検査する）をコメントに書く。

`scripts/test-auto-merge-workflow.sh` には次の検査を足す。

- `$ROOT/plugins/*/hooks/hooks.json` を順に読み、`"command":` の行から `${CLAUDE_PLUGIN_ROOT}/` に続く相対パスを取り出し、`plugins/<name>/<相対パス>` を `SACRED` に当てる。一致しなければそのパスを挙げて `ng`。
- `command` が `${CLAUDE_PLUGIN_ROOT}/` で始まる 1 本のパスの形で読めないときも `ng`（読めないものを通さない）。
- hooks.json が 1 つも見つからない、または `command` を 1 件も拾えないときも `ng`（検査が空振りして通るのを防ぐ）。
- jq には頼らず `grep` / `sed` で読む（既存の SACRED 検査と同じく、jq の無い環境でも必ず走らせる）。hooks.json の `command` は 1 行に 1 つという今の書き方を前提にする。

あわせて must-match に `git-destructive-guard.sh`・`git-guard-scratchpad.py`・`secret-guard.py`・`plugins/worktree/scripts/wt-create-hook.sh`、must-not-match に `ci-watch.sh`・`epic-dispatch.sh`、MERGE_CONDITION の must-not-match に `git-destructive-guard.sh` を足す。

採らなかった案:

- 自動マージの判定のときに hooks.json を読んで集める: ワークフローが PR とは別に base のファイルを読む処理を持つことになり、正規表現を実物で確かめている今のテストの形が崩れ、判定の経路も長くなる。CI の検査で同じ漏れを拾える。
- `plugins/*/scripts/` を丸ごと聖域にする: hook の経路に無い develop の中心のスクリプトまで主のマージ待ちになる。
- スクリプト中のファイル名を推移的に集める: コメントで名前が出ているだけのものまで拾い、48 本（`codex-develop.py` などを含む）に広がる。`headroom.py` が `codex_develop` を importlib で読むように、推移的に辿ると hook と無関係な範囲まで入る。
- 直さず「聖域ではない」と明記する: PR #1157・#1167 で実害が出ている。

### 補助ファイルは許可を判定する hook の直接の読み込み先だけを手で選ぶ

補助に入れるのは、PreToolUse / PermissionRequest の hook が判定の本体として直接実行・import するファイルに限る。許可・拒否の判定を変えられるのはここまでで、通知や記録の hook の補助は判定に関わらない。手で選ぶ分は CI の検査が拾わないので、残る限界として運用ガイドに書く。

### MERGE_CONDITION と原本は変えない

hook のスクリプトはマージ条件そのもの（判定ルール・合格を発行するゲート・マージロボットの原本）ではない。`plugins/*/hooks/` と同じく、親の判断の印で `human-merge` を外せる側に置く。原本の `SACRED` の既定はどのリポにも共通の 4 系統だけを持ち、hook の置き場はリポごとに違うので、展開先だけを変える。

## Risks / Trade-offs

- 補助ファイルが読み込む先（`usage_view.py` のさらに先など）と、hook が実行しない親が許可を書くスクリプトは聖域に入らない → 運用ガイドに残る限界として書く。必要になったら補助の一覧に手で足す。
- 新しい補助ファイルを足したとき CI は気付かない → 補助は手で選ぶことを `SACRED` のコメントと運用ガイドに書く。
- hooks.json の `command` を 1 行に 1 つでない形（複数行・シェルの式）で書くと検査が読めない → 読めない形は `ng` にして、書き方を直すか検査を直すかを PR で判断させる。
- 24 本＋3 本に触れる PR が `human-merge` で止まる件数が増える → 親の判断の印で外せる範囲なので、エピックの子は親が流せる。
- `SACRED` の正規表現が長くなる → プラグインごとにまとめ、`$` で終端してファイル名の前方一致による取り込み過ぎを防ぐ。
