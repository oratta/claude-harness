規模の判断: 編集ファイルは 12 個前後で規模超過トリップワイヤーの閾値 5 個を超えるが、本体が承知済みで単一 change のまま進める（実装中にこれを理由に return しない）。

## 1. 実機で前提を確かめる

- [ ] 1.1 `plugins/dev-workflow/agents/worker.md` を `tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop`・`model: sonnet` の仮の定義で置き、`claude -p --plugin-dir plugins/dev-workflow` から名前付きで `dev-workflow:worker` を起こして、return が親に届くかを確かめる。届かなければ worker と gate-runner の `tools` に `SendMessage` を足すと決め、結果（Claude Code の版・届いたか）を PR 本文の `## 新種別の計測` に書く

## 2. 検査を先に書く（Red）

- [x] 2.1 `plugins/dev-workflow/tests/role-agent-types.bats` を新規に作る: worker.md / gate-runner.md の frontmatter（`name`・`model: sonnet`・`tools` の完全一致。worker は `Read, Edit, Write, Bash, Grep, Glob, TaskStop`、gate-runner は `Read, Bash, Grep, Glob, TaskStop`。1.1 で `SendMessage` を足すと決めたらそれを含む）／`tools` に `mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` が無い（gate-runner は加えて `Edit`・`Write` が無い）／`model` が `inherit` でない／本文が `skills/develop/references/roles/worker.md`（gate-runner は `gate-runner.md`）を指す／plugin.json の `agents` に 3 つの定義がある
- [x] 2.2 `plugins/dev-workflow/tests/agent-model-guard.bats` に足す: `dev-workflow:worker` + `model: fable` が deny、`dev-workflow:gate-runner` + `model: claude-fable-5-1` が deny、`dev-workflow:worker` の `sonnet`・`opus`・`model` 省略が許可
- [x] 2.3 develop の bats（`develop-roles.bats` か `develop-skill.bats`）に足す: SKILL.md の役割表の W 行に `dev-workflow:worker`、G 行に `dev-workflow:gate-runner`、V の行がある／(1) と (4) の spawn の行に種別がある／`worker.md` と `gate-runner.md` の冒頭に種別がある／`worker.md` に W が `/wt-setup` を呼ぶ記述が無く、SKILL.md の worktree の節に本体が `/wt-setup` を呼ぶ記述がある／`worker.md` に `openspec new change`・`openspec validate`・`openspec archive` があり、(3a) の節と (3b) の節に `/opsx:` の文字列が無く、`/opsx:` を含む行はどれも `本体` か `主` の語を含む（`grep '/opsx:' worker.md | grep -v -e 本体 -e 主` が空）／`worker.md` に `ls .claude/commands/opsx/` が無く `openspec --version` がある／SKILL.md の 1 ループの節に `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` が無く `openspec new change` がある／SKILL.md の前提の表の Agent の行に 2 つの種別があり、openspec の行に `openspec --version` がある／SKILL.md の役割表の R1 の行とレビュアーの行に `dev-workflow:worker` も `dev-workflow:gate-runner` も無い／`worker.md` の (3a) の return の節に `画面確認:` の書式がある／`screen-checker.md` があり、1 行目の書式 `画面確認結果: (合格|不合格|実行不能)` と、編集・commit・投稿をしないことが書かれている／`references/codex-develop.md` の Claude role の起動に `dev-workflow:worker`・`dev-workflow:gate-runner`・`dev-workflow:decider` があり、W / G を `general-purpose` で起こす記述が無い／`plugins/dev-workflow/README.md` の役割とモデルの説明に 2 つの種別がある
- [x] 2.4 既存の bats のうち W の `/opsx:*` を文字列で固定しているアサーションを CLI の形に直す: `plugins/dev-workflow/tests/develop-roles.bats` の「worker: spec path returns after /opsx:ff…」（`/opsx:ff`・`/opsx:apply` → `openspec new change`・`openspec validate`）と (3a)/(3b) の節の検査（(3a) の `/opsx:apply`・`/opsx:verify` → `openspec validate`、(3b) の `/opsx:archive` → `openspec archive`、(3a) に archive が無い否定は `openspec archive` で書く）、「openspec CLI だけある場合」の節を指す grep の見出し、`develop-skill.bats` の「loop: W does spec decision, split judgement and /opsx:ff…」と `spec-decision-and-review.bats` の「loop: R1 review sits between W's /opsx:ff and W's apply」（位置の基準を `/opsx:ff` から `openspec new change` に替える）。テスト名の `/opsx:ff` も直す
  - `develop-roles.bats` の「worker: does not re-run /opsx:ff…」は「既存 artifact が揃う場合に `openspec new change` を再実行しない」に改め、検査する本文も CLI の文言に合わせる。
  - 同ファイルの `:96` と `:154-167` にある「openspec CLI だけある場合」の箇条を awk で切り出す検査はやめる。CLI 経路の本文を対象に、(3a) の節に `openspec validate <change-name> --strict` があり、(3b) の節に `openspec archive <change-name>` があることを直接検査する。
- [x] 2.5 2.1〜2.4 を走らせて、落ちることを確かめる

## 3. 定義と本文を書く（Green）

- [ ] 3.1 `plugins/dev-workflow/agents/worker.md` と `agents/gate-runner.md` を書く（`decider.md` の形に倣う。description は 1 文。本文は指示書を指すだけで手順を写さない）
- [ ] 3.2 `plugins/dev-workflow/.claude-plugin/plugin.json` の `agents` 配列と description、`.claude-plugin/marketplace.json` の dev-workflow の description を更新する
- [ ] 3.3 `skills/develop/references/roles/worker.md`: 冒頭に種別を書く。「W がしないこと」から `/wt-setup` の例外を消す。仕様化判断の 3 段の検出を `openspec --version` だけにし、opsx コマンドがあっても CLI が無ければ理由を「openspec 不在」とすると書く。仕様化・(3a)・(3b) を openspec CLI の経路だけで書き換える（`/opsx:` は、本体や主が先に `/opsx:ff` で change を作っていた場合を述べる行にだけ残し、その行に `本体` か `主` を含める）。(3a) の return に `画面確認:` の行と書式・決め方を足す。(3b) に V の return（合格なら証拠の入力、実行不能なら証拠を書かない）の扱いを足す。「全経路共通の大原則」から opsx 経路の語を除き、CLI 経路と直行の 2 経路にする。(3a) の return の `/opsx:verify` の合否を `openspec validate --strict` の exit code に替える
- [ ] 3.4 `skills/develop/references/roles/screen-checker.md` を新規に書く: 入力（W の `画面確認:` の行・worktree のパス・起動手順）、`isolation` 無しで W の作業ツリーを見ること、dev server は `rules/dev-server.md` に従い二重起動せず起動したポートを return に書くこと、拡張の接続確認、観測の手順、return の 1 行目の書式と 3 つの値ごとに書くこと、しないこと（編集・commit・投稿・主への直接依頼・待ち）
- [ ] 3.5 `skills/develop/SKILL.md`: 役割表に W / G の種別と V の行（`general-purpose`・`sonnet`・上げない）を足す。(1)・(3)・(4) の spawn に種別を書く。1 ループの (1)・(3a)・(3b) と工程図から `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` を除き、`openspec new change`・`openspec validate --strict`・`openspec archive` に替える。(3a) と (3b) の間に V の分岐（要る／不要、合格／不合格／実行不能）を足し、V に W の worktree のパスを渡して `isolation` を付けずに起こすこと、同じ `画面確認:` の行の 2 回目の `不合格` を本体が数えて失敗ループとして扱うことを書く。worktree を用意する節に `.worktreeinclude` が無いとき本体が `/wt-setup` を呼ぶことを足す。前提の表の Agent の行に種別を書き、「opsx コマンドまたは openspec CLI」の行を、W は openspec CLI だけで進め経路の有無を `openspec --version` で決める（opsx コマンドは本体や主が対話で使う道具）形に直す。役割表の W の行の `/opsx:ff` を `openspec new change` に替える
- [ ] 3.6 `skills/develop/references/roles/gate-runner.md` の冒頭と、`references/codex-develop.md` の Claude role の起動（「`decider` role は `dev-workflow:decider`、他の role は `general-purpose`」の文）に種別を書く。`plugins/dev-workflow/README.md` の役割とモデルの説明に種別を書き、1 ループの行の `/opsx:ff` を `openspec new change` に替える
- [ ] 3.7 `scripts/agent-model-guard.sh` のコメントに新種別の扱い（`DECIDER_TYPES` に入れない・定義に model を持つ）を足すかを決め、足すなら 1 行にする（判定ロジックは変えない）
- [ ] 3.8 `plugins/dev-workflow/changes/330.md` に変更の記録を書く

## 4. 検査を通す

- [ ] 4.1 `.github/workflows/*.yml` の `pull_request` / `push` の `run:` から検査コマンドを集めて全部実行し、exit code を記録する（`./scripts/test.sh` を含む）
- [ ] 4.2 `tests/injection-budget.bats` が落ちたら、まず新しい description を削る。それでも足りなければ `tests/injection-budget.txt` を動かし、PR 本文に何を削ろうとしてなぜその値にしたかを書く
- [ ] 4.3 `openspec validate role-scoped-agent-types --strict` が exit 0

## 5. 計測を記録する（合否の閾値は決め打ちしない）

- [ ] 5.1 同じ Claude Code の版・同じモデル・同じ短い指示文で、`general-purpose` と `dev-workflow:worker`、`general-purpose` と `dev-workflow:gate-runner` を `claude -p --plugin-dir plugins/dev-workflow` から起こし、各トランスクリプト（`~/.claude/projects/<proj>/<session>/subagents/agent-a*.jsonl`）の最初の `message.usage` の `input_tokens`・`cache_creation_input_tokens`・`cache_read_input_tokens` を分けて PR 本文の `## 新種別の計測` に書く（版の番号も書く）
- [ ] 5.2 5.1 の新種別の値を、issue #330 本文の 2026-09-20 の実測（W / G の初回 43,208〜50,577）と並べて書く
- [ ] 5.3 Chrome 拡張が繋がる環境で `general-purpose`・`model: sonnet` の V を起こして 1 ページを開かせ、`mcp__claude-in-chrome__*` が呼べたことと return の 1 行目を記録する。繋がらない環境なら `画面確認結果: 実行不能` が返ることを記録し、主の環境での確認を PR 本文の動作確認ポイントに残す。起動できた V の最初の usage も 3 つに分けて書く
- [ ] 5.4 (3b) で follow-up issue を作る（中身: マージ後に新種別で最初に develop を 1 本通した記録先で、全エージェント合計の `cache_creation_input_tokens` と `cache_read_input_tokens`、上限による強制停止の回数と手渡しの回数を分けて集計する。担い手はその 1 本を通した本体で、記録先の PR がマージされたあとに行う）。PR 本文の `## 新種別の計測` に、この項目が未計測であることと follow-up issue の URL と測る記録先の決め方を書く（集計そのものはこの change の範囲外）
