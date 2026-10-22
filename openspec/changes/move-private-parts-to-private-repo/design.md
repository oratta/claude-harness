## Context

#1128 の仕分けの表（`docs/public-private-split.md`）は、公開版の部品のうち次を「個人版」に決めた: `rules/plugin-editing.md`、プラグイン `weekly-report`・`daily-report`、`plugins/dev-workflow/docs/auto-merge-deployments.md`、capability-registry の `scripts/fmtoken.sh`・`skills/capability-registry/1password.md`・SKILL.md の「表記規約（生成文にも適用すること）」「資格情報の階層（どこに置くかはプロジェクトごとに決めない）」の 2 節。前半の change で保留の 5 行が公開版に確定し、移す範囲はこれで全部になった。

主の決定（https://github.com/oratta/claude-harness/issues/1129#issuecomment-6332494744 と https://github.com/oratta/claude-harness/issues/1129#issuecomment-6333407804 ）:

- 個人版のリポジトリは `oratta/claude-harness-oratta`（private）。位置づけは「公開版をベースに、その上に載せる追加分」
- `gh repo create --private` と、最初の 1 回だけ main に直接 push してよい。以後は Draft PR で回す
- 履歴は git filter-repo で運ばず、写して最初の commit に写し元の SHA を書く
- 切り替えの順番: 個人版を作って写す → オーナーが各 PC で切り替える → 公開版から消す PR をマージする

制約:

- サブエージェントからの main への push は hook に拒否される。個人版の最初の push は本体（主の確認画面が出るセッション）が行う
- `CLAUDE.md`・`AGENTS.md`・`tests/injection-budget.txt` は聖域で、変える PR は本文に理由を書き、マージは主の承認で行う
- 前半の PR #1213 は main（#1207 で固有名の検索が共有スクリプト `forbidden-words-check.sh` に変わった）と `openspec/specs/harness-public-private-split/spec.md`・`tests/public-private-split.bats` で衝突しており、その解消は #1213 の側で行う。この change のブランチは前半のブランチから切っている

## Goals / Non-Goals

**Goals:**

- 個人版に決めた部品を個人版のリポジトリに写し、オーナーの各 PC で個人版から読まれる状態にする
- 切り替えの後に公開版から部品を消し、公開版の作業ツリーに個人版の固有名が残っていないことを確かめる
- 消した後も公開版の検査（`scripts/test.sh`）と仕分けの文書が整合する

**Non-Goals:**

- 各 PC の切り替えを自動化すること（#1130）
- 公開版の過去の履歴から部品を消すこと（履歴は残し、写し元の SHA で辿れるようにする）
- 公開版の辞書（`tests/public-names/dict/`）に個人版の固有名を足すこと（要件「公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く」で禁じられている）
- 個人版に CI を置くこと

## Decisions

### 1. marketplace の名前はリポジトリ名と同じ `claude-harness-oratta`

install 先は `~/.claude/plugins/marketplaces/claude-harness-oratta/`、install ID は `<プラグイン>@claude-harness-oratta` になる。

- 選ばなかった案 `oratta-claude-harness-oratta`（公開版の `oratta-claude-harness` に揃える）: `oratta` が 2 回出る。公開版の名前 `oratta-claude-harness` で前方一致を取る処理（パスの判定・grep）に個人版も当たる
- 理由: 主の位置づけ「公開版の上に載せる追加分」がそのまま読め、install 先のディレクトリ名とリポジトリ名が一致する

### 2. 個人版の構成

| 個人版のパス | 中身 | 写し元 |
|---|---|---|
| `plugins/weekly-report/` | プラグイン丸ごと（`changes/`・`tests/` を含む） | `plugins/weekly-report/` |
| `plugins/daily-report/` | 同上 | `plugins/daily-report/` |
| `plugins/capability-registry-oratta/` | スキル `capability-registry-oratta`（SKILL.md に 2 節、`1password.md`）・`scripts/fmtoken.sh`・`tests/fmtoken.bats`・`.claude-plugin/plugin.json` | capability-registry の該当ファイルと節 |
| `rules/plugin-editing.md` | ルール | `rules/plugin-editing.md` |
| `docs/auto-merge-deployments.md` | 展開の記録 | `plugins/dev-workflow/docs/auto-merge-deployments.md` |
| `openspec/specs/<4 本>/spec.md` | 仕様 | `openspec/specs/` の同名 |
| `scripts/check-public-leak.sh`・`tests/private-names/dict/private-parts.txt` | 公開版の漏れの検査と辞書（新規） | なし |
| `.claude-plugin/marketplace.json`・`README.md` | marketplace の定義と使い方（新規） | なし |

- `weekly-report`・`daily-report` は同じ名前で写す。定期実行と手での呼び出しがコマンド名 `/weekly-report`・`/daily-report` を使っているので、名前を変えると呼び出し側を直す範囲が広がる
- capability-registry の個人版の部品は、公開版と同じ名前のプラグインにせず別名 `capability-registry-oratta` にまとめる。同じ名前にすると公開版の capability-registry と同時に入れられず、公開版に残る仕組み（browser-guard・索引）を失う。スキルの description だけは新しく書く（公開版の capability-registry が発火した後に、保管庫とトークンの取り出しを調べるときに読まれる、という発火条件）
- `auto-merge-deployments.md` はプラグインの部品ではなく記録なので、個人版のルート直下の `docs/` に置く
- 写すときに中身を直してよいのは 2 点だけにする: install ID の `@oratta-claude-harness` を `@claude-harness-oratta` にすること、`plugins/dev-workflow/references/self-verification.md` への参照を「公開版の dev-workflow の `references/self-verification.md`」と書くこと。それ以外を直すと、写し元の SHA との突き合わせで差分の理由が説明できなくなる
- 個人版に CI は最初は置かず、README に `bats plugins/*/tests` での確かめ方を書く。private のリポジトリの Actions は無料枠の分数を使うため。R1 もこの案でよいと判断した（https://github.com/oratta/claude-harness/issues/1129#issuecomment-6333651952 ）

### 3. 移した部品の記録は、仕分けの表から外して新しい節に置く

`docs/public-private-split.md` の仕分けの表から移した部品の行（`rules/plugin-editing.md`・`weekly-report`・`daily-report`・`plugins/dev-workflow/docs/auto-merge-deployments.md`・`fmtoken.sh`・`1password.md`・SKILL.md の 2 節）を外し、新しい節「個人版に移した部品」の表（列は 部品・移した先・写し元の commit）に移す。

- 理由: `tests/public-private-split.bats` は表にあるのに部品の無い行を「表の行が部品に当たらない」で落とす。行を残して分類を「移した」にする案は、分類の値を増やし、要件「各行は決めた分類と理由を持つ」と前半の検査を広く直すことになる
- dev-workflow と capability-registry の行は「分割」のまま残す。dev-workflow は前半の Scenario「確定した 5 行はすべて公開版である」が部品の行を前提にしており、capability-registry は要件「capability-registry の扱いを選ばなかった案と後続の割り当てとともに残す」が部品ごとの行き先を文書に求めている。どちらも公開版の部品の行だけが残る
- capability-registry の SKILL.md は 2 節を消した後も節の行で覆う（残る節「原則」「索引（1 サービス 1 行）」「CLI が無いサービス（ネガティブエントリ）」「新サービスの追加」と冒頭の行）

### 4. 公開版から消えたことと固有名の検査

消えたことは公開版の bats が確かめる: 移した部品のパスについて `git ls-files` が 0 件、`.claude-plugin/marketplace.json` の `plugins[]` と bundle `all` に `weekly-report`・`daily-report` が無い、`rules/` に `plugin-editing.md` が無い、capability-registry の SKILL.md に 2 節の見出しが無い。パスと見出しは新しい節「個人版に移した部品」の表から読み、表と検査の両方に同じ部品が出るようにする。

固有名は個人版で確かめる。個人版の `scripts/check-public-leak.sh <公開版の作業ツリー>` が、個人版の辞書 `tests/private-names/dict/private-parts.txt`（`fmtoken`・`weekly-report`・`daily-report`・`auto-merge-deployments`・`1password.md`・`Fieldy`）を公開版の `plugins/dev-workflow/scripts/forbidden-words-check.sh --dict` に絶対パスで渡す。

- 検索の範囲: `git ls-files` のうち公開版の部品（`rules/`・`output-styles/`・`scripts/`・`plugins/`）とルート直下の `README.md`・`CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md`。`openspec/`・`docs/public-private-split.md`・`_longruns/`・各所の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は除く（経緯の記録と、消えたことを確かめる検査は語を持ってよい）
- 結果は公開版の消す PR の本文に載せる
- 選ばなかった案（公開版の辞書に足す）: 要件「公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く」が新しい固有名を公開側の辞書に足すことを禁じている

### 5. 仕様の差分

- `harness-public-private-split`: ADDED「個人版に移した部品は移した記録に載せ、公開版に残さない」。MODIFIED「dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない」「dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない」（個人版のファイルと節を除く決まりを外す）
- `always-on-injection-scope`: MODIFIED「常時性を手放してはいけないルールを縮約対象から外す」（plugin-editing の項目を外す）
- `plugin-release-convention`: MODIFIED「プラグインを変更しても版を上げない」
- `dev-workflow-shared-references`: MODIFIED「自己検証の共通原則は解散プラグインの記述を除いて引き継ぐ」
- `skill-verification-sections`: MODIFIED「対象スキルの SKILL.md は「## 自己検証」節を持つ」
- 個人版に移る 4 本の仕様は delta で消さず、archive の直前に `git rm -r` する（全要件を REMOVED にすると archive が止まる。前例 `openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/tasks.md`）

`harness-public-private-split` の 2 つの MODIFIED の本文は、#1207 で変わった main の版に前半の変更を重ねた形で書いた。#1213 のマージ後に main の正本と突き合わせ、食い違えば archive の前に合わせ直す。

### 6. 切り替えの順番と凍結

1. 個人版のリポジトリに部品を写す。最初の commit のメッセージに写し元の公開版の commit SHA を書く。`gh repo create` と main への push は本体が行う
2. 公開版の消す PR を Draft で作る（この時点でマージしない）
3. オーナーが各 PC で: `/plugin marketplace add oratta/claude-harness-oratta` → 個人版の `weekly-report`・`daily-report`・`capability-registry-oratta` を install → 公開版の `weekly-report@oratta-claude-harness`・`daily-report@oratta-claude-harness` を uninstall → `~/.claude/rules/plugin-editing.md` を `~/.claude/plugins/marketplaces/claude-harness-oratta/rules/plugin-editing.md` への symlink に張り替える → `/reload-plugins`
4. 全 PC が済んだら、公開版の消す PR を Ready にしてマージする（主の承認）

- 写した後は公開版の移す部品を凍結する。マージの前に `git log <写し元SHA>..origin/main -- <移す部品のパス>` が空であることを確かめ、空でなければその commit を個人版に写してから進む
- 順番の理由: 先に公開版から消すと、`/weekly-report` の定期実行が止まり、`scripts/sync.sh` が「この harness を指す壊れた symlink」として `~/.claude/rules/plugin-editing.md` を消す（`scripts/sync.sh` の `link_dir`）
- 入れてから外す順にするのは、外してから入れる順だと間に定期実行が来たときに呼べるコマンドが無くなるため

## Risks / Trade-offs

- [張り替えてからマージするまでの間、公開版の `scripts/sync.sh` が `rules/plugin-editing.md` を「harness 外を指す symlink」として触らず、rc=1 で終わる（`link_dir` の harness 外の分岐）] → 毎回の sync で警告が出るだけで、他の配線は進む。マージを全 PC の切り替えの直後にして期間を短くする。マージ後は公開版の `rules/` にファイルが無いので警告は消え、個人版を指す symlink は掃除の対象（harness を指す壊れた symlink）に当たらない
- [切り替えの途中で同じ名前の `weekly-report` が 2 つの marketplace から入っている時間がある] → install と uninstall を続けて行い、間に `/weekly-report` を呼ばない。定期実行は週 1 回で、手順は数分で終わる
- [写した後に公開版の部品が直され、個人版に届かない] → 凍結と、マージ前の `git log <写し元SHA>..origin/main` の確認で拾う
- [公開版を使う第三者の `weekly-report`・`daily-report` が消える] → オーナーの業務専用の部品で、他の利用者を想定していない。README の一覧から外し、変更の記録に書く
- [個人版に CI が無いので、個人版の部品の検査が走らない] → README に手で回す `bats` の手順を書く（R1 の判断で確定）
- [`harness-public-private-split` の MODIFIED の本文が #1213 の衝突の解き方と食い違う] → #1213 のマージ後、archive の前に main の正本と突き合わせる（tasks に入れる）

## Migration Plan

上の「切り替えの順番と凍結」のとおり。戻すとき: 公開版の消す PR をマージする前なら、PR を閉じ、各 PC で個人版のプラグインを uninstall して公開版のものを入れ直し、symlink を公開版の marketplace dir に戻す。マージした後なら、公開版で revert の PR を作る（個人版のリポジトリは残してよい）。

## Open Questions

なし（個人版に CI を置くかは、置かずに README に手で回す `bats` の手順を書く案で R1 の判断により閉じた）
