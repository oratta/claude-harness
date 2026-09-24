# プラグイン編集の詳細と、旧運用からの移行

`rules/plugin-editing.md`（常時注入される要点）から詳細を移した先。プラグインのコマンド・スキル・エージェント・ルールを編集するとき、マージ前の動作確認をするとき、worktree や plugin の状態が壊れたときに読む。

## 編集してはいけない 2 か所

- `~/.claude/plugins/marketplaces/...`（marketplace dir）— Claude Code が自動更新するインストール成果物。ここで feature ブランチを checkout すると、自動更新や `scripts/sync.sh` の pull がそのブランチ上で走り、`~/.claude/plugins/cache/` にもマージ前の内容が入る
- `~/.claude/commands/` や `~/.claude/skills/` へのローカルコピー — marketplace 版より優先されて更新が反映されなくなる事故が過去に繰り返し発生した

Claude Code が実行時に読むのは `~/.claude/plugins/cache/<marketplace>/<plugin>/<版>/` で、marketplace dir はそのコピー元にすぎない。版は `plugin.json`（または `marketplace.json` のエントリ）の `version` で決まり、`version` が無ければ marketplace dir の HEAD の commit SHA が版になる。版が同じ間は cache は更新されないので、`version` を書くとその値を変えない限り push しても利用者に届かない。marketplace dir を feature ブランチにしていると、Claude Code の自動更新や `scripts/sync.sh` の `git pull --ff-only` がそのブランチ上で走り、cache にもマージ前の内容が入る。

`~/.claude/rules/*.md` は marketplace dir 配下のファイルを指す symlink（`scripts/sync.sh` が張る）。ルールを直すときも symlink の実体ではなく開発用 clone 側の `rules/*.md` を編集し、マージしてから **marketplace dir 側の** `scripts/sync.sh`（`~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh`）で追随させる。

開発用 clone や worktree の `scripts/sync.sh` は実行しない。sync.sh は自分自身の位置からリポジトリを決めるので、symlink が既にある PC では「harness 外を指す symlink」として rc=1 で失敗し、まだ無い PC ではマージ前の feature ブランチの rules が全セッションのグローバルルールとして張られる。

## 開発用 clone の場所（他プロジェクトで作業中に harness を直したくなったとき）

**別のプロジェクトで作業していて harness の修正が必要になったら、その作業リポジトリの中で直さない。** 作業中のリポジトリに harness のファイルを作ったり書き換えたりすると、そのリポジトリの git 履歴に混ざり、harness 側には永久に届かない。marketplace dir で直すのも同じく禁止（上の理由）。

開発用 clone の場所は環境変数 **`CLAUDE_HARNESS_DEV_DIR`** で解決する。PC ごとに置き場所が違うので、パスをこのリポジトリの文書やスクリプトに固定で書かない（`LLM_LOG_DIR` と同じ扱い）。

```bash
# 開発用 clone の場所を確認する
echo "${CLAUDE_HARNESS_DEV_DIR:?未設定}"
```

未設定なら **主に置き場所を聞く**。デフォルトパスを勝手に決めない。`find ~ -name claude-harness` のような探索で当てにいくのも禁止（marketplace dir や過去の残骸を拾う）。

解決できたら、そこから worktree を切って直す。作業中のプロジェクトのセッションから直接 harness を編集しにいかず、worktree を作ってそこで別セッションを立てるか、その worktree を作業ディレクトリに指定したサブエージェントに任せる。

```bash
# 開発用 clone は marketplace dir と違って自動更新されないので、origin/main は古いままになり得る
git -C "$CLAUDE_HARNESS_DEV_DIR" fetch origin
git -C "$CLAUDE_HARNESS_DEV_DIR" worktree add <worktree のパス> -b <ブランチ名> origin/main
```

`/wt-setup` は worktree を作るスキルではないので、worktree の作成に使わない（作成後に worktree の中で走らせるもので、カレントが worktree でなければ止まるが、**作業中のプロジェクトの worktree にいると判定が通り、そちらのリポジトリに Draft PR が作られる**）。harness の worktree で立てたセッションの中でなら、`/wt-setup --with-pr` で Draft PR まで用意できる。

元のプロジェクトの作業に戻る前に、harness 側は commit して push する（PR 運用のリポジトリなので Draft PR まで作る）。作業ツリーに置きっぱなしにしない。

## 版と変更の記録、反映

- 版は上げない。`plugin.json` と `marketplace.json` に `version` を書かなければ commit SHA が版になり、main に入るたびに利用者へ更新が届く。`version` があるとその値で版が固定されるので、`tests/marketplace-sync.bats` の S130・S131 が `version` の存在を CI で落とす
- 変更の記録は `plugins/<name>/changes/<番号>.md` に 1 PR 1 ファイルで書く。番号は記録先の issue 番号、無ければ PR 番号（同じ issue の 2 本目の PR は PR 番号）。`CHANGELOG.md` は凍結しているので追記しない
- `known_marketplaces.json` でリポジトリ URL を確認して commit & push
- マージ前の動作確認は `claude --plugin-dir <worktree のパス>/plugins/<プラグイン名>` でそのセッションだけ読み込ませる。`--plugin-dir` はプラグイン 1 個のディレクトリ（`.claude-plugin/plugin.json` を持つもの）を取る。リポジトリのルート（`.claude-plugin/marketplace.json` を持つ marketplace）を渡しても警告なしに何も読み込まれない。複数見るなら繰り返し指定する
- マージ後の反映は `/plugin marketplace update oratta-claude-harness`（または新規セッション起動時の自動更新）→ `/reload-plugins` か新規セッション。`/plugin update` というスラッシュコマンドは存在しない
- 状態がおかしくなったら手動削除せず `/plugin uninstall` → `/reload-plugins` → `/plugin install` → `/reload-plugins`

## 旧運用からの移行と、marketplace dir に残った worktree の扱い

以前は marketplace dir 自体で feature ブランチを checkout し、そこから worktree を生やしていた。この形の worktree は、管理情報が再 clone されうる `.git` の中にあるため、プラグイン自動更新で失われることがある。開発を marketplace dir の外に出すのはこの構造を避けるため。残っている場合も、失われた場合も、開発用 clone 側で作り直す:

```bash
# 1. 開発用 clone（marketplace dir の外に置いたもの）で branch を取得する
git -C <dev-clone> fetch origin <branch-name>

# 2. 開発用 clone から worktree を作り直す
git -C <dev-clone> worktree add <worktree-path> <branch-name>

# 3. wt-setup で開発環境を整える
cd <worktree-path>
# Claude Code を立ち上げて /wt-setup
```

marketplace dir 側に古い worktree の登録が残っている場合の掃除（`git worktree prune` や worktree dir の削除）は破壊的操作なので、主の承認を得てから行う。

commit して push 済みの内容は remote から復元できる。session.jsonl のような ephemeral ファイルは **復元対象外**。
