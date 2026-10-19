## 1. 上限の値（epic-dispatch.sh）

- [ ] 1.1 上限を決める関数を足す（`EPIC_DISPATCH_MAX_PARALLEL` の検査、未設定なら `sysctl -n hw.memsize` → `/proc/meminfo` の `MemTotal` で物理メモリを読み `floor(GiB/4)`・最小 1、読めなければ 2 と stderr。値と出どころを変数に残す）。`agent_setup` の近くに置く。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:239-253（agent_setup の前後）
- [ ] 1.2 サブコマンド `max-parallel` を足す（orca / gh / git を呼ばず、数字 1 行を出して exit 0。値の誤りは使い方を出して exit 1）。usage とディスパッチの case に足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:147-160（usage）、plugins/dev-workflow/scripts/epic-dispatch.sh:1093-1103（case）
- [ ] 1.3 テスト: `sysctl` のスタブを足し（`make_stub` に sysctl を加えるか、テストごとに置く）、`max-parallel` の Scenario 5 件（16 GiB → 4、2 GiB → 1、読めない → 2 と stderr、環境変数 3 → 3、0 / two → exit 1）を書く。既定値のテストでは `EPIC_DISPATCH_MAX_PARALLEL` を unset する。Linux の CI で実物の `/proc/meminfo` が読まれないよう、読むファイルはテスト用の内部変数 `EPIC_DISPATCH_MEMINFO_FILE`（既定 `/proc/meminfo`。冒頭の説明に「テスト用」と書き、SKILL.md には書かない）で差し替えられるようにし、テストでは存在しないパスを渡す。sysctl は PATH 上のスタブだけを使う（スクリプトが `/usr/sbin/sysctl` を絶対パスで呼ぶと、スタブが効かず実機のメモリ量が読まれるので、PATH で引く。macOS の通常のシェルの PATH には `/usr/sbin` が入っている）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:33-51（setup）、plugins/dev-workflow/tests/epic-dispatch.bats:54-260（make_stub）、テストは launch のテスト群の後ろに新規

## 2. launch の枠と deferred（epic-dispatch.sh）

- [ ] 2.1 `cmd_launch` で、引数の検査の直後（orca を呼ぶ前）に上限を決め、値が誤っていれば使い方を出して exit 1。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:323-341
- [ ] 2.2 `orca worktree list --json` を読んだあと、今のワークツリーの id（`.result.worktree.id`）と repoId から枠を使っている子を数える（parentWorktreeId 一致・archive でない・linkedIssue あり・workspaceStatus が completed でない・comment が epic-stopped / epic-stopped-seen でない・`gh api repos/{owner}/{repo}/issues/<N> --jq .state` が closed でない。gh の失敗は数える側で stderr）。id が無ければ 0 件で stderr。上限・出どころ・数えた子を stderr に 1 行。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:346-366
- [ ] 2.3 空き枠を `max(0, 上限 − 使用中)` で求める。子ごとのループで、skipped の判定のあと、空き枠が 0 なら create も注意書きの投稿も行わずに `deferred <N>`。create に進んだ子は結果にかかわらず空き枠を 1 減らす。exit code は従来どおり failed の有無だけで決める。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:367-437
- [ ] 2.4 冒頭の説明（launch の段落）と、設計の正本の要件名の一覧に、上限・枠の数え方・`deferred`・`max-parallel` を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-144
- [ ] 2.5 テスト: 既存の launch のテストが上限に当たらないよう `setup` で `EPIC_DISPATCH_MAX_PARALLEL` を大きな値（例 99）にし、上限のテストだけで上書きする。spec の launch の Scenario 10 件（5 件渡して 2 件起動、使用中が上限より多ければ全部後回し、1 件閉じると 1 件起動、印のある子は数えない、戻った子は数える、gh 失敗は数える、別の親・archive は数えない、failed も枠を使う、後回しの子に注意書きを投稿しない、値の誤りで何も呼ばない）を書く。current_json に id を持たせるのはこれらのテストだけでよい。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:33-51（setup）、plugins/dev-workflow/tests/epic-dispatch.bats:898-960（launch の skipped 系テストの近く。新規テストを足す）

## 3. 回し方の手順（SKILL.md）

- [ ] 3.1 Orca 経路の手順 1 に `deferred <N>` と上限、手順 2 に後回しの子を wait に渡さないこと、手順 3 と手順 8 の終わりに後回しの子が残っていれば `launch` に渡し直すこと、手順 4 の `launch` が後回しの子を含むこと、後回しの子だけが残ったら `launch` の stderr を添えて主に報告すること（1 行目は `主がすること:` の規定どおり）、手順 7 で後回しの子を `launch` の出力で知ることを書く。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:429-436
- [ ] 3.2 子セッションの起動の段落（`EPIC_DISPATCH_MODEL` などを説明している段落）の近くに、上限の環境変数・既定値の式・根拠の実測値と見込み・枠を使っている子の数え方（完了の印・閉じた子・止まった子を数えない理由と、戻った子の分だけ一時的に超えうること）を書く。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:442-446
- [ ] 3.3 サブエージェント方式の段落に、開始時に `scripts/epic-dispatch.sh max-parallel` で上限を得て、子をまたいだ W の総数をその数までに抑えること、W 1 体が枠を使う期間（起こしてから change のループが終わるか保留に入るまで。子の中の change ごとの W もそれぞれ 1 枠）、新しい子の W・同じ子の別の change の W・保留から戻る W の再開の前に毎回空き枠（`max(0, 上限 − 使用中)`）を確かめて 0 なら待ちに回すこと、枠が空いたら再開 → 同じ子の別の change → 新しい子の順で起こすことを書く。Orca 経路では戻った子の分だけ一時的に超えうるが、サブエージェント方式では超えないことも書く。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:448、plugins/dev-workflow/skills/develop/SKILL.md:200（change ごとに W を並列に起こす記述。エピックの子のときは枠に従うことを 1 文足す）
- [ ] 3.4 テスト: SKILL.md の記述（spec の SKILL の Scenario: 既定値と実測値、Orca 経路の手順、後回しだけが残ったときの報告、サブエージェント方式の上限と起こす前の空きの確認と起こす順、保留から戻る W は枠が空くまで再開しないこと、子の中の change ごとの W も枠を使うこと、Orca 経路で戻った子の扱い）を確かめるテストを足す（文の有無を grep で確かめる）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2192-2280（`skill:` のテスト群の後ろに新規）

## 4. 記録と確認

- [ ] 4.1 変更記録を書く（何を変えたか・既定値と実測値・客の Mac の値の置き場は flatmate 側で配線すること）。触る範囲: plugins/dev-workflow/changes/1106.md（新規）
- [ ] 4.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `bats plugins/dev-workflow/tests/develop-skill.bats` を通す（この Mac には GNU parallel が無いので `-j` を付けない）。`openspec validate epic-dispatch-max-parallel --type change --strict` を通す
