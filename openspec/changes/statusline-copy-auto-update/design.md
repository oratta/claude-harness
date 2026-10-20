## Context

`install.sh` は `plugins/statusline/scripts/statusline.sh` と `statusline-codex.py` を `<config>/`（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`）にコピーし、`settings.json` の `statusLine` をコピーに向ける。コピーを配るのは、marketplace dir が自動更新で再 clone され、cache dir は版ごとにパスが変わって `settings.json` から指せないため（`install.sh` 冒頭のコメント）。README は「コピーを直接編集してよい」としているので、毎回上書きすると利用者の調整が消える。

いま、プラグインを更新してもコピーは更新されず、更新に気づく手段も無い。

制約:
- 描画（`statusline.sh`）は数百ミリ秒ごとに走るので、描画のたびにハッシュを取らない
- SessionStart フックの標準出力は、JSON でなければ会話の文脈としてモデルに渡る。出すなら JSON だけにする
- フックは失敗してもセッションを止めてはいけない
- `tests/hook-python-isolation.bats` は hooks.json に登録したスクリプトの python3 起動を縛り、`CLAUDE_PLUGIN_ROOT` が空のときにルート直下を探さないことを検査する
- `tests/statusline-multi-account.bats` は `statusline.sh` と origin/main 版の出力のバイト一致を検査する
- 親エピックの注意書き: 表示の中身（名前・オフ・リセット権）には手を出さない

## Goals / Non-Goals

**Goals:**
- 手を入れていないコピーは、次のセッション開始時に黙ってプラグインの本体と同じ内容になる
- 手を入れたコピーは上書きされず、ステータスラインの 1 行目の末尾に `更新あり /statusline:setup` が出る
- この仕組みより前に入れたコピー（記録が無い）は手を入れたものとして扱い、上書きしない

**Non-Goals:**
- 表示の中身（名前・オフ・リセット権・バー・色）を変えること
- `settings.json` の `statusLine` の向き先をフックで直すこと（`/statusline:setup` の役目のまま）
- 手を入れたコピーと新しい本体を混ぜる（3-way マージする）こと
- `/statusline:setup --uninstall` の挙動を変えること

## Decisions

### 手を入れたかどうかは、install.sh が書いたハッシュとの比較で決める

`install.sh` はコピーを置いたあと（内容が既に一致して書き換えなかったときも）、2 つのコピーの SHA-256 を `<config>/.statusline-installed` に書く。形式は `sha256sum` の出力と同じ `<64 桁の16進数><空白2つ><ファイル名>` の行を 1 ファイル 1 行（ファイル名は `statusline.sh` と `statusline-codex.py`）。同じディレクトリ内で一時ファイルに書いてから `mv` で差し替える。

- 代替案: 更新日時で比べる → `cp -p` やエディタの保存で崩れ、内容を見ていないので採らない
- 代替案: 配った内容そのものを `<config>/` に控えて `cmp` する → 判定はできるが、利用者の目に触れる場所にスクリプトの複製がもう 1 本増える。ハッシュ 1 行で足りるので採らない
- ハッシュのコマンドは `shasum -a 256`、無ければ `sha256sum`。どちらも無い環境では `install.sh` は記録を書かずに警告を 1 行出し、フックは何もしない（記録が無いので「手を入れた」扱いになり、上書きは起きない側に倒れる）

### 判定と書き換えは SessionStart フックが行い、描画は印を読むだけ

`plugins/statusline/hooks/hooks.json` に SessionStart（matcher `startup|resume|clear`、timeout 10 秒）を登録し、`plugins/statusline/scripts/statusline-update-hook.sh` を呼ぶ。コマンドは他のプラグインと同じく `"\"${CLAUDE_PLUGIN_ROOT}/scripts/statusline-update-hook.sh\""` の形で書く（`tests/lint-plugin-validate.bats` の引用の検査）。`plugin.json` には何も足さない（`hooks/hooks.json` は既定の場所として自動で読まれ、このリポジトリの他のプラグインも `plugin.json` に hooks を書いていない。`description` を伸ばすと常時注入の予算に響く）。

フックは bash だけで書き、python3 を起動しない（`hook-python-isolation.bats` の対象を増やさない）。コピーごと（`statusline.sh` と `statusline-codex.py`）に、次の表で動く。「本体」は `$CLAUDE_PLUGIN_ROOT/scripts/` の同名ファイル。

| コピー | 本体と同じか | 記録のハッシュと同じか | 動き |
|---|---|---|---|
| 無い | – | – | 何もしない（導入していない） |
| ある | 同じ | – | 記録のその行を本体のハッシュに直す。印の対象にしない |
| ある | 違う | 同じ（手を入れていない） | 本体で原子的に置き換え（`statusline.sh` は 755、`statusline-codex.py` は 644。`install.sh` と同じ）、記録のその行を書き直す。バックアップは取らない（中身は過去に配った版そのもの） |
| ある | 違う | 違う／記録に行が無い／記録ファイルが無い | 上書きしない。印の対象にする |

判定のあと、印の対象が 1 つ以上あれば `<config>/.statusline-update-available` に対象のファイル名を 1 行 1 件で書き、1 つも無ければ印を消す。

- 代替案: 描画のたびに `statusline.sh` 自身がハッシュを取って比べる → 描画が重くなり、描画しているのが古いコピーでは比較のコード自体が無いので効かない。採らない
- 代替案: 毎回上書きする → 利用者の調整が消える。採らない

### 「更新あり」の表示は statusline.sh の 1 行目の末尾だけ

`statusline.sh` は 1 行目を出す直前に `[ -f "$CONFIG_DIR/.statusline-update-available" ]` だけを確かめ、あれば 1 行目の末尾に半角空白 2 つと `${YELLOW}更新あり /statusline:setup${RESET}` を足す。印が無いときの出力は今と 1 バイトも変えない（`statusline-multi-account.bats` のバイト一致が通る）。2 行目以降と 1 行目の既存部分（ディレクトリ・モデル・ブランチ）は変えない。

### 印を描けない古いコピーには、フックが開始時に案内を出す

この変更より前のコピーは印を読むコードを持たないので、印を置いても何も出ない。主の Mac の今のコピーがこれに当たり、何もしなければ受け入れ条件の実機確認（「最新版になるか『更新あり』が出る」）を満たせない。そこで、印を置いたときに `<config>/statusline.sh` のコピーに文字列 `.statusline-update-available` が含まれていなければ、フックは標準出力に `{"systemMessage":"ステータスラインのコピーに更新があります（手を入れたコピーなので自動では上書きしません）。/statusline:setup で更新できます"}` の 1 行だけを出す。コピーが印を読めるときは何も出さない（ステータスラインに出るので、毎セッションの案内は重ねない）。

- 代替案: 案内を出さず、README に「一度 `/statusline:setup` を打ち直す」とだけ書く → 打ち直しを覚えておく以外に気づく手段が無い、という元の問題が古いコピーについて残る。採らない
- 代替案: 印があるときは毎回案内を出す → 新しいコピーではステータスラインと二重になる。採らない

### 上書きしてよいのは、インストール済みのプラグインから起動されたときだけ

`$CLAUDE_PLUGIN_ROOT` を実体のパスに解決した値が `<config>/plugins/` の実体のパスの下にないとき、フックは何もしない（記録も印も触らない）。`CLAUDE_PLUGIN_ROOT` が空のときも何もしない（ルート直下の `/scripts/...` を組み立てない）。

harness の開発では `claude --plugin-dir <worktree>/plugins/statusline` で未マージの版を読み込むことがあり、そのセッションで本物の `~/.claude/statusline.sh` が未マージの版に置き換わると、並行して開いている他のセッションの表示まで変わる。また開発中の版と比べた「更新あり」は誤報になる。

- 代替案: 環境変数で止められるようにする → 開発者が毎回付け忘れる。場所で決めるほうが漏れない

### フックは常に exit 0

途中のどの失敗（コピー・記録の書き込み・ハッシュの取得）も、そのファイルの処理を飛ばすだけで exit 0 で終える。標準エラーにも何も出さない（SessionStart の 0 以外の終了は画面に出る）。

## Risks / Trade-offs

- [記録が無い既存の利用者は、一度 `/statusline:setup` を打ち直すまで自動にならない] → フックの案内と「更新あり」で気づける。打ち直せば以後は自動。手を入れたかどうかを後から推定する手段が無いので、上書きしない側に倒す
- [2 つのセッションが同時に開始すると、両方のフックが同じコピーを書き換える] → どちらも同じ本体を一時ファイル経由の `mv` で置くので、結果は同じ内容になる。記録も同じ値になる
- [異なる版の cache を指す古いセッションが resume で起動すると、コピーを古い版に戻しうる] → 記録どおりのコピーしか触らないので利用者の調整は消えない。次に新しい版のセッションが開始したときに戻る
- [`.statusline-update-available` が残ったまま、利用者が手で本体と同じ内容に戻した] → 次のセッション開始で「本体と同じ」の行に当たり、記録を直して印を消す
