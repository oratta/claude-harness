## 1. wait の上限の既定（epic-dispatch.sh）

- [ ] 1.1 テストを先に書く。`epic-dispatch.bats` の wait の節に、design の契約どおりのトランスクリプトを `$CLAUDE_PROJECTS_DIR/-work-parent/` に置く helper を足し、spec の 6 つの Scenario（1 時間・5 分だけ・判定できない・上限を明示・書き込み 0 の行と古い行とサブエージェントの行・両方正の行）を足す。子は `closed` を返すスタブにして 1 回目のポーリングで終わらせる（`sleep` はスタブで経過時間が進まないので、上限は stderr の `wait limit` の行で確かめる）。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats:1852-1876`（`wait: EPIC_DISPATCH_TIMEOUT=0 alone times out` の前後）、トランスクリプトの置き方は `plugins/dev-workflow/tests/epic-dispatch.bats:2002-2030`（wait infer の節）を参考にする
- [ ] 1.2 関数 `cache_ttl_of` を足す（design の「順番 2 の change が使う関数の契約」のとおり。python3 は `last_activity` と同じく here-doc で呼ぶ）。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1018-1023`（`transcript_dir` のあと）
- [ ] 1.3 `cmd_wait` で、`--timeout` も空でない `EPIC_DISPATCH_TIMEOUT` も無いときだけ `cache_ttl_of "$(toplevel)"` で上限を 2700 / 21600 に決め、ポーリングの前に stderr へ `wait limit <秒> (parent cache <5m|1h|unknown>)` を出す。`is_num` の検査は決めたあとの値に掛ける。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1198-1222`（`cmd_wait` の冒頭と引数の解析）、`:1250-1252`（`SECONDS=0` の前）
- [ ] 1.4 冒頭の説明の「既定 300 / 21600」を書き換え、上限の既定の決め方と stderr の行を足す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:76-84`（`# wait:` の説明）

## 2. 親の手順（epic.md）

- [ ] 2.1 テストを先に書く。`develop-skill.bats` に、spec の Scenario「手順 5 は同じ wait を掛け直すだけにする」「子エピックの行で外す確認は closed のときだけ」「片付け待ちだけの待ちは長い上限を明示する」の検査を足す。`deleg_para` の終わりの行の照合（`^\`timeout\` と \`closed\` で起こされたときの確認では`）を 2.4 の書き換え後の行頭に合わせる。触る範囲: `plugins/dev-workflow/tests/develop-skill.bats:1007`、`:1387-1397`（`watch end: step 4 timeout, step 5 and step 8 point to the conditions` のあと）
- [ ] 2.2 手順 5 を書き換える（子 issue もエピックも読まず報告もせず、同じ引数の `wait` を `run_in_background: true` で 1 回起動してターンを終える・`--timeout` を足さない・発言は書かないか `主がすること: なし` の 1 行・子が印を付けずにタブで質問すると気づけない・**待ちをやめてよい条件** を指す）。発言の一覧から「手順 5 の `timeout` の報告」を外す。触る範囲: `plugins/dev-workflow/skills/develop/references/epic.md:54`（手順 5）、`:46`（ターンを終えるときの発言の一覧）
- [ ] 2.3 手順 4 の片付け待ちの子だけを待つ `wait` に `--timeout 21600` を付ける文を足す。手順 6 の「最長 6 時間待つ」の 2 か所を、親が気づかずに待ち続ける旨に直す。触る範囲: `plugins/dev-workflow/skills/develop/references/epic.md:53`（手順 4 の「`kept <N> not-done` の子だけを `--watch-done` に渡して」の文）、`:55`（手順 6）
- [ ] 2.4 子エピックの行で子を外す確認を `closed` で起こされたときだけにし、「最長 6 時間待つ」を直す。部品ごとの違いの表の「`timeout` と `closed` の確認」も合わせる。触る範囲: `plugins/dev-workflow/skills/develop/references/epic.md:79`、`:95`

## 3. 規則のファイルと記録

- [ ] 3.1 `reply-after-idle.md` に節「親の待ちの費用（#1324）」を「親への適用」と「根拠と、この数字の限り」の間に足す（design の D7。2700 と 21600・理由・掛け直すだけ・超過中に 5 分に縮むことと URL・有効期限を固定した人・PC が寝ている間）。閾値の表・そのまま送るか起動し直すかの表・「親への適用」の文は変えない。テストは `develop-skill.bats` に spec の Scenario「規則のファイルに親の待ちの費用と超過中の扱いがある」を足す。触る範囲: `plugins/dev-workflow/skills/develop/references/reply-after-idle.md:52-54`（節の境目）、`plugins/dev-workflow/tests/develop-skill.bats`（末尾）
- [ ] 3.2 変更の記録を書く（版は上げない）。触る範囲: `plugins/dev-workflow/changes/1324.md`（新規）

## 4. 確かめる

- [ ] 4.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-skill.bats` と `scripts/test.sh` が通ることを確かめる。`tests/injection-budget.bats` も通ること（常時注入の部品は触らない）
- [ ] 4.2 `openspec validate epic-wait-short-rewait --type change --strict` が通ることを確かめる
- [ ] 4.3 実機で、この worktree から `plugins/dev-workflow/scripts/epic-dispatch.sh wait <閉じた issue の番号>`（フラグなし。閉じた子なので 1 回目のポーリングで `closed` で終わる）を 1 回実行し、stderr の `wait limit` の行が、この worktree のトランスクリプトで最後にキャッシュを書いた行の有効期限（`jq` で `message.usage.cache_creation` を見る）と合うことを確かめる。触る範囲: なし（確認だけ）
