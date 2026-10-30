# Claude Harness

Claude Code用スキル・プラグインのマーケットプレイス

## クイックスタート

```bash
# マーケットプレイスを登録
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install dev-workflow@oratta-claude-harness
```

シークレットの値が画面に出る形の Bash と Read を実行前に止める `secret-guard` は `capability-registry` に入っている。`/plugin install capability-registry@oratta-claude-harness` で有効になり、`settings.json` の編集は要らない。

### Output Style `readable` を有効にする

`output-styles/readable.md`（読み手が前提を持たない状態で読める書き方のスタイル）と `rules/*.md` は、プラグインではないので `/plugin install` では届かない。クイックスタートの後に、marketplace dir の `scripts/sync.sh` を 1 回実行する（SessionStart hook などの自動実行は無い）。これが `readable.md` を `~/.claude/output-styles/` に、`rules/*.md` を `~/.claude/rules/claude-harness/` に symlink する。

```bash
~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh
```

初めて同期した場合は、Claude Code を再起動してスタイルファイルを読み込ませてから選ぶ。

`sync.sh` は settings の `outputStyle` を書き換えない（どのスタイルを使うかは PC ごとの設定に残すため）ので、届いたあとに自分で 1 手選ぶ。

```bash
# Claude Code の中で /output-style readable を実行する（/config のメニューからも選べる）
# または ~/.claude/settings.json に書く
{ "outputStyle": "readable" }
```

有効にしなくても、sync.sh を実行していれば `rules/communication-style.md`（`readable` から 6 原則の要点を抜いた短い版）は常に注入されるので、書き方の原則そのものは効く。sync.sh を実行していなければ、その短い版も効かない。有効にしない場合に効かないのは、短い版が省いた細部だけで、差はわずか。

- 判断を求める文章の 3 つの長い例、論点に含めないケースの説明、主に聞く理由を 3 つに絞る説明の詳細
- ヒアリングで選択肢を使わない 2 つの理由と、選択肢を出してよい場合の例
- 本題への回答に大半を使う、書き出すファイルも必要な分にする、といった長さの細かい指示

なお Output Style はメインの会話にしか効かないので、選んでもサブエージェントには全文が届かず、短い版だけで動く。

## プラグイン一覧

### dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。`develop` スキルは、コード・スキル・コマンド・規範文書を変える作業に入口（issue 番号/URL/自然文・会話・cron・エピックの子）を問わず発火する。本体はオーケストレータ専任で、作業者 W・仕様レビュアー R1・ゲート実行者 G を `model` 明示で spawn し、記録先（issue、無ければ Draft PR）の確定 → 仕様化判断の記録 → 仕様レビュー → TDD 実装 → pr-review-gate の 1 ループを回す。

```bash
/plugin install dev-workflow@oratta-claude-harness
```

**機能:**
- `/develop [issue番号|URL|自然文]`（`/work-issue` はエイリアス）— develop スキルを interactive モードで起動する。issue が無ければ issue を切らず Draft PR を記録先にする（issue を切るのは追跡・キュー・議論が要るときだけ）
- 本体は Edit でコードを書かず、レビューを代行しない。別コンテキストを要する工程（仕様レビュー・PR レビュー）はすべて本体が起こす
- エピック（独立してマージできる PR が 2 本以上・複数 capability・順序依存）は子 issue ごとに 1 ループを並列に回す（`orca` があり本体が Orca 管理のワークツリーにいれば Orca の子ワークツリーの独立セッション、それ以外と unmanned は `isolation: "worktree"` のサブエージェント。`plugins/dev-workflow/scripts/epic-dispatch.sh`）。Orca 経路では、子が「用が済んだ」の印を付けたワークツリーを親セッションが片付ける
- loop-dev-agent の無人サイクル（憲法は各リポの `docs/agent-loop.md`。flatmate が保守）では、憲法のメインが develop の本体を務める（`--unmanned`）
- 上流の壁打ち（`/opsx:explore`）は呼ばない（issue 化前の壁打ちとは切り分ける）
- `references/`（プラグイン直下）に他プラグインと共有する契約を置く: 自己検証の共通原則・PR / issue 本文の型・Workflow 実行のロール別ティア・Workflow 実行の型。`issueify` スキルはタスクメモを受け入れ条件付き issue に変換する

詳細は `plugins/dev-workflow/skills/develop/SKILL.md` を参照。

---

### product-handover

プロダクトをエージェントに引き渡すときにだけ必要になる固有部品を配るプラグイン。法務ドラフト・サポート窓口・教訓ログの雛形3種だけを持ち、オーケストレーターもスキルも持たない。

```bash
/plugin install product-handover@oratta-claude-harness
```

**機能:**
- `templates/legal/` — 利用規約・プライバシーポリシー・返金ポリシーのドラフト雛形（いずれも法務レビュー前である旨を明記した状態で配る）
- `templates/support-desk.md` — サポート窓口メールの設定雛形（`support-<slug>@<domain>` の命名規則、catch-all を使わない理由、一次対応の範囲）
- `templates/autonomy-lessons-skeleton.md` — 教訓ログの様式
- 引き渡しの順番（インフラ → dev-workflow の導入 → auto-merge の配線 → product-handover → SNS）は README に書くだけで、他プラグインの起動はしない
- リポ側と住人側の分担: 住人（workspace・cron・チャンネル）は flatmate の `new-resident` が担い、本プラグインはプロダクトのリポ側だけを扱う

詳細は `plugins/product-handover/README.md` を参照。このプラグインは 2026-08-29 に旧名のプラグインを作り直したもので、入れ替え手順は `plugins/product-handover/CHANGELOG.md` にある。

---

### その他のプラグイン

いずれも `/plugin install <プラグイン名>@oratta-claude-harness` でインストールする。

| プラグイン | 説明 |
|-----------|------|
| `worktree` | Git worktree のセットアップ（`/wt-setup`。`--with-pr` で Draft PR まで作成）とクリーンアップ（`/wt-clean`） |
| `infra` | Vercel + Supabase + GitHub Actions で local/staging/prod の環境を一括セットアップする（`/infra-setup`） |
| `capability-registry` | 外部サービスを操作する前に CLI とトークンの在処を教える発見層。シークレットの値が画面に出る形の Bash と Read を止める `secret-guard` の hook も入る（無効化は環境変数 `CAPABILITY_REGISTRY_SECRET_GUARD=off`） |
| `statusline` | 使用量ステータスライン。クォータ消化率と窓の日程消化率を1本のバーに重ね、`25%/29%` の形で「今のペースでリセットまで持つか」を示す（`/statusline:setup`） |

---

## バンドル

複数のプラグインを一括でインストールできます。

```bash
# 全プラグインをインストール
/plugin install bundle:all@oratta-claude-harness
```

---

## overlay（別の harness を重ねる）

`scripts/sync.sh` は、この harness の rules と output-styles を `~/.claude/` に symlink で配る。別の harness（別の marketplace）の rules と output-styles も、同じ仕組みで重ねられる。重ねる側は次の 3 つを用意する。

1. **許可ファイル**: `~/.claude/harness-overlays` に、重ねたい marketplace のディレクトリ名（`~/.claude/plugins/marketplaces/` 直下の名前）を 1 行に 1 つ書く。空行と `#` で始まる行は無視される。
2. **印**: 重ねられる側の marketplace の直下に `.harness-overlay` を置く。1 行目がサブディレクトリ名（`[a-z0-9][a-z0-9-]*`）で、その marketplace の `rules/*.md` が `~/.claude/rules/claude-harness/<名前>/` に配られる。`output-styles/*.md` は `~/.claude/output-styles/` に配られ、公開側と同名のときは公開側が優先される（重なる側が警告される）。
3. **再実行**: 許可ファイルを書いたら `scripts/sync.sh` を実行する。許可ファイルから行を外して再実行すると、その overlay の symlink は消える。

```bash
echo "my-harness" >> ~/.claude/harness-overlays
~/.claude/plugins/marketplaces/oratta-claude-harness/scripts/sync.sh
```

### 許可が要る理由

marketplace を入れただけの第三者が、`.harness-overlay` を置くだけで常時効く指示（rules や output-styles）をあなたの環境に張れないようにするため。`.harness-overlay` があっても、許可ファイルに書かれていない marketplace は張られず、pull もされない。許可ファイルが無いか、空行とコメントだけなら新しい overlay は張られず、以前張った overlay の symlink は削除される（何も表示されない）。公開版の同期は続く。

### 飛ばされたときの警告

許可した overlay の構成検査に失敗すると、`sync.sh` は標準エラーに `[harness-sync]` で始まる警告を出してその overlay を飛ばす。ファイル単位の衝突（公開側と同名の output style など）では該当ファイルだけを飛ばし、rules などは配線される。いずれも終了コードは非 0 になるが、可能な配線は続く。

| 警告 | 原因と直し方 |
|------|-------------|
| `許可した overlay のディレクトリがありません。飛ばします: <名前>` | 許可ファイルに書いた marketplace が見つからない。`~/.claude/plugins/marketplaces/` 直下の名前と綴りを確かめるか、marketplace を入れる |
| `許可した <名前> の直下に .harness-overlay がありません。飛ばします` | 印が無い。その marketplace の直下に `.harness-overlay` を置く |
| `overlay の名前が空か不正のため飛ばします` | `.harness-overlay` の 1 行目を `[a-z0-9][a-z0-9-]*` に直す |
| `overlay の名前 <名前> が重複しているため飛ばします` | 許可ファイル内の同じ marketplace の重複行を削除する。異なる marketplace 同士が同じ名前なら、片方の `.harness-overlay` の 1 行目を変える（marketplace 名の辞書順で先のものが採られる） |
| `<配布先>/<名前> が実ファイルか symlink のため overlay を飛ばします` | `~/.claude/rules/claude-harness/<名前>` に同名の実ファイルなどがある。移すか消す |
| `許可ファイルの行が不正のため飛ばします` | 行に `/` を含むか、`.` で始まっている。ディレクトリ名だけを書く |

---

## ローカル開発

開発用の clone は **marketplace dir（`~/.claude/plugins/marketplaces/oratta-claude-harness/`）の外**に置く。marketplace dir は Claude Code が自動更新するインストール成果物なので、そこで feature ブランチを checkout しない（`CLAUDE.md` の「開発場所」を参照）。

```bash
# リポジトリをクローン（置き場所は marketplace dir の外なら任意）
git clone https://github.com/oratta/claude-harness
cd claude-harness

# マージ前の動作確認は、そのセッションだけこの clone を読み込ませる
# --plugin-dir はプラグイン 1 個のディレクトリを取る（リポジトリのルートを渡しても何も読み込まれない）
claude --plugin-dir ./plugins/<変更したプラグイン>
```

### 開発用 clone の場所（`CLAUDE_HARNESS_DEV_DIR`）

環境変数 `CLAUDE_HARNESS_DEV_DIR` は、上の開発用 clone の場所を指す。harness を直すときに worktree をその clone から生やすので、未設定だとその手順が止まる。未設定のまま harness のリポジトリでセッションを始めると、`worktree` プラグインを入れていれば 1 行の警告を出す（`/plugin install worktree@oratta-claude-harness`）（セッションは止まらない。harness を直さない人には何も出ない）。

`~/.claude/settings.json` の `env` に、自分の clone の絶対パスを入れる。既に `env` がある場合は、他の値を消さずに 1 行足す。

```json
{
  "env": {
    "CLAUDE_HARNESS_DEV_DIR": "/path/to/claude-harness"
  }
}
```

### 新しいプラグインを追加

```bash
# プラグインディレクトリを作成
mkdir -p plugins/new-plugin/{.claude-plugin,skills,commands}

# plugin.json を作成
cat > plugins/new-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "new-plugin",
  "description": "...",
  "skills": [],
  "commands": []
}
EOF

# marketplace.json を更新
# plugins 配列に追加
```

---

## ライセンス

MIT License

## Author

Oratta

---

### 解散済みプラグイン

ループレシピ集・自律実行ハーネス・その短縮コマンド集の 3 プラグインは 2026-08 に解散した（[#205](https://github.com/oratta/claude-harness/issues/205)）。手順書としての層をやめ、中に埋まっていた契約（自己検証の共通原則・PR / issue 本文の型・issueify・ロール別モデルティア）だけを `dev-workflow` に移した。install 済みの環境での `/plugin uninstall` 手順と新旧パスの対応表は `plugins/dev-workflow/CHANGELOG.md` にある。

Discord 改造版（公式プラグインの fork で、主のリアクションをセッションへ push 配送するもの）は 2026-09 に flatmate へ移し、flatmate 自身が marketplace として配っている（[genetta-inc/flatmate#851](https://github.com/genetta-inc/flatmate/issues/851)）。harness からは外した（[#314](https://github.com/oratta/claude-harness/issues/314)）。`discord@oratta-claude-harness` を入れている環境は次のとおり切り替える。flatmate の marketplace の登録手順は flatmate#851 を正本とする。

1. `claude plugin uninstall discord@oratta-claude-harness` を実行する
2. flatmate の marketplace を登録し（手順は flatmate#851）、`settings.json` の `enabledPlugins` に `discord@flatmate` を入れる。手順 1 の uninstall で消えずに `discord@oratta-claude-harness` が残っていれば、そのエントリを消す
3. 住人の `CHANNEL_PLUGINS` を `plugin:discord@flatmate` にして、住人を再起動する

`skill-pack`・`telegram`・`experience-to-skill` の 3 プラグインは 2026-10 に解散した（[PR #841](https://github.com/oratta/claude-harness/pull/841)）。`bundles` の `all` からも外した（telegram は元から `all` に入っていなかった）。理由と代替は次のとおり。

| プラグイン | 解散の理由 | 代替 |
|-----------|-----------|------|
| `skill-pack` | Claude Code 本体でプロジェクト単位の ON/OFF ができるようになった | `/skills` 画面と `skillOverrides`（個人スキル）、`/plugin` または `claude plugin enable\|disable --scope`（プラグイン単位） |
| `telegram` | 公式プラグインで代替できる。fork の目的だった「利用者のリアクションをセッションへ届ける」機能は不要と判断した | 公式 `telegram@claude-plugins-official` |
| `experience-to-skill` | 公式のスキルで足り、使われていなかった | 公式の `skill-creator` スキル |

install 済みの環境では、入れていたプラグインについて次を行う。

1. `claude plugin uninstall skill-pack@oratta-claude-harness`・`claude plugin uninstall telegram@oratta-claude-harness`・`claude plugin uninstall experience-to-skill@oratta-claude-harness` のうち、入れていたものを実行する
2. uninstall で消えずに `settings.json` / `settings.local.json` の `enabledPlugins` に `<name>@oratta-claude-harness` が残っていれば、そのエントリを消す
3. telegram を使っていた環境は、公式の `telegram@claude-plugins-official` を入れる（設定は公式側の手順に従う）

`~/.claude/skills/distilled/` と `<repo>/.claude/skills/distilled/` にある蒸留スキル（名前が `e2s-` か `distilled-` で始まるもの）は uninstall では消えない。
