## ADDED Requirements

### Requirement: epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、エピックの子を同時に動かす数の上限を次のとおり決めなければならない（MUST）。環境変数 `EPIC_DISPATCH_MAX_PARALLEL` が設定されていればその値を使う。値は 1 以上の整数でなければならず、空文字・0・数字以外のときは stderr に変数名と使い方を出して exit 1 で終わる（MUST）。設定されていなければ既定値を使う。既定値は物理メモリの GiB（バイト数を 1073741824 で割った値）を 4 で割って切り捨てた値で、1 未満なら 1 とする（MUST）。物理メモリは `sysctl -n hw.memsize`（バイト）で読み、読めなければ `/proc/meminfo` の `MemTotal`（kB）で読む。どちらも読めない・数字でないときは既定値を 2 とし、stderr に物理メモリを読めなかったことを出す（MUST）。

`epic-dispatch.sh` はサブコマンド `max-parallel` を持ち、上の規則で決めた上限を stdout に数字 1 行で出して exit 0 で終わらなければならない（MUST）。`max-parallel` は `orca` も `gh` も `git` も呼んではならない（MUST NOT）。`EPIC_DISPATCH_MAX_PARALLEL` の値が誤っているときは上と同じく exit 1 で終わる。

既定値の式と、その根拠にした実測値（2026-10-20 にオーナーの Mac（物理メモリ 32 GiB）で、同時に動いていた Claude Code のセッション 36 個の RSS が本体のプロセスのみで 146〜404 MB、子プロセスを含めて最大 564 MB だったこと）、子 1 件に 2 GiB を見込み物理メモリの半分を子に充てるという見込み（うちテスト・ビルドの山の 1.5 GiB は実測でないこと）は、develop の SKILL.md「エピックの扱い」→「回し方」に書かなければならない（MUST）。

この要件の入力は、`EPIC_DISPATCH_MAX_PARALLEL` の値と、`sysctl` と `/proc/meminfo` が返す物理メモリ量である。拾いたい誤りは、設定が無いときに上限が無くなること、値の打ち間違い（`two`・`0`・空文字）で上限が無くなるか 0 になって何も起動しなくなることである。次は通してよく、この要件では止めない: 非常に大きい値（上限なしと同じに動く）／物理メモリが実際より大きく報告される環境／コンテナで物理メモリと使えるメモリが違う環境。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は `sysctl` を PATH 上のスタブにして、次の Scenario を確かめなければならない（MUST）。既存の `launch` のテストは、上限に引っかからないよう `EPIC_DISPATCH_MAX_PARALLEL` を大きな値にして従来どおりの出力を確かめる（SHALL）。

#### Scenario: 設定が無いときは物理メモリから決めた既定値を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL` が未設定で、`sysctl -n hw.memsize` が `17179869184`（16 GiB）を返す環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `4` の 1 行で exit 0、`orca`・`gh`・`git` は呼ばれない

#### Scenario: 物理メモリが少なくても既定値は 1 を下回らない
- **WHEN** `sysctl -n hw.memsize` が `2147483648`（2 GiB）を返す環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `1`

#### Scenario: 物理メモリを読めなければ既定値は 2
- **WHEN** `sysctl` が失敗し `/proc/meminfo` も読めない環境で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `2`、stderr に物理メモリを読めなかったことが出る

#### Scenario: 環境変数が既定値より優先する
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=3` で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stdout は `3`

#### Scenario: 環境変数が 0 や数字以外なら使い方を出す
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=0` または `EPIC_DISPATCH_MAX_PARALLEL=two` で `epic-dispatch.sh max-parallel` を実行する
- **THEN** stderr に `EPIC_DISPATCH_MAX_PARALLEL` と使い方が出て exit 1

#### Scenario: SKILL.md に既定値と根拠の実測値が書かれている
- **WHEN** develop の SKILL.md「回し方」を読む
- **THEN** `EPIC_DISPATCH_MAX_PARALLEL`、既定値の式（物理メモリの GiB を 4 で割って切り捨て・最小 1・読めなければ 2）、根拠の実測値（1 セッションの RSS の範囲）が書かれている

### Requirement: epic-dispatch.sh launch は空いた枠の分だけ子を起動し、残りを deferred で出す
`epic-dispatch.sh launch` は、子を起動する前に「枠を使っている子」を数え、上限（要件「epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める」）から枠を使っている子の数を引いた空き枠（0 未満なら 0。例えば上限 2・使用中 3 なら 0）の分だけ子を起動しなければならない（MUST）。これは要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `launch` の呼び出し順と `launched` / `skipped` / `failed` の判定を書き換えず、出力の語に `deferred <N>` を加え、create を呼ぶ前の判定に空き枠を加えるものである。

「枠を使っている子」は、`orca worktree list --json` のワークツリーのうち、`repoId` が今のワークツリーと同じ・`parentWorktreeId` が今のワークツリーの id（`orca worktree current --json` の `.result.worktree.id`）・`isArchived` が true でない・`linkedIssue` があるもので、さらに次をすべて満たすものとする（MUST）: `workspaceStatus` が `completed` でない（完了の印が無い）／`comment` が `epic-stopped` でも `epic-stopped-seen` でもない（主の返事待ちで止まった印が無い）／`gh api repos/{owner}/{repo}/issues/<linkedIssue> --jq .state` が `closed` でない。`gh` が非 0 で終わったか出力が `open` / `closed` 以外のときは、その子を枠を使っている子として数え、stderr にその子を出す（MUST。メモリを守る側に倒す）。今のワークツリーの id が取れないときは枠を使っている子を 0 件とし、stderr にその旨を出す（SHALL）。

引数の子は先頭から順に処理し、同じ呼び出しで処理済みの番号と、一覧に同じ子のワークツリーがある子は、今までどおり `skipped <N>` を出して空き枠を減らさない（MUST）。それ以外の子は、空き枠が 1 以上なら `orca worktree create` 以降に進み、結果が `launched` でも `failed` でも空き枠を 1 減らす（MUST）。空き枠が 0 なら `orca worktree create` を呼ばず、注意書きも投稿せず、stdout に `deferred <N>` の 1 行を出す（MUST）。`deferred` は失敗ではなく、`failed` が 0 件なら exit 0 で終わる（MUST）。`launch` は stderr に、上限・その出どころ（`EPIC_DISPATCH_MAX_PARALLEL` か物理メモリか既定の 2 か）・枠を使っている子の番号を 1 行で出す（SHALL。全部が後回しになったときに、何が枠を塞いでいるかを主に示すため）。`EPIC_DISPATCH_MAX_PARALLEL` の値が誤っているときは、`orca` も `git` も呼ばず、子を 1 件も作らずに exit 1 で終わる（MUST）。

この要件の入力は、`orca worktree current --json` の `id` と `repoId`、`orca worktree list --json` の `repoId`・`parentWorktreeId`・`isArchived`・`linkedIssue`・`workspaceStatus`・`comment`、`gh` が返す子 issue の state、本体が渡す子の番号の並びである。拾いたい誤りは、上限を超えて子を起動すること、閉じた子・完了の印の子・止まった子が枠を塞いで後回しの子がいつまでも起動されないこと、後回しにした子が出力に出ずに親が見失うことである。次は通してよく、この要件では止めない: 主の返事待ちから戻った子（`epic-resumed`）の分だけ一時的に上限を超えること／`launch` が数えたあと、起動するまでのあいだに子が閉じること／別の親ワークツリーから同じリポジトリで起動された子は数えないこと／`failed` で create まで進まなかった子にも空き枠を使うこと。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh` のスタブで次の Scenario を確かめなければならない（MUST）。

#### Scenario: 上限 2 で着手できる子を 5 件渡すと 2 件だけ起動し 3 件を後回しにする
- **WHEN** 枠を使っている子が 0 件で、`EPIC_DISPATCH_MAX_PARALLEL=2` のスタブ環境で `epic-dispatch.sh launch 400 11 12 13 14 15` を実行する
- **THEN** stdout は `launched 11`・`launched 12`・`deferred 13`・`deferred 14`・`deferred 15` の 5 行で、`orca worktree create` は子 11 と子 12 についてだけ呼ばれ、exit 0

#### Scenario: 動いている子が 1 件閉じると後回しにした子のうち 1 件が起動される
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11 と子 12 のワークツリー（印なし）があり、`gh` が子 11 を `closed`、子 12 を `open` と返すスタブ環境で `epic-dispatch.sh launch 400 12 13 14 15` を実行する
- **THEN** stdout は `skipped 12`・`launched 13`・`deferred 14`・`deferred 15` の 4 行で、`orca worktree create` は子 13 についてだけ呼ばれる

#### Scenario: 完了の印と止まった印の子は枠を使わない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11（`workspaceStatus` が `completed`）と子 12（`comment` が `epic-stopped-seen`）のワークツリーがあり、`gh` がどちらも `open` と返すスタブ環境で `epic-dispatch.sh launch 400 13 14 15` を実行する
- **THEN** stdout は `launched 13`・`launched 14`・`deferred 15` の 3 行

#### Scenario: 戻った子は枠を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11（`comment` が `epic-resumed`）のワークツリーがあり、`gh` が `open` と返すスタブ環境で `epic-dispatch.sh launch 400 13 14` を実行する
- **THEN** stdout は `launched 13`・`deferred 14` の 2 行

#### Scenario: issue の state を読めない子は枠を使う側に数える
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、一覧に今のワークツリーから作られた子 11 のワークツリーがあり、`gh` が子 11 について失敗するスタブ環境で `epic-dispatch.sh launch 400 13` を実行する
- **THEN** stdout は `deferred 13` の 1 行、stderr に子 11 の state を読めなかったことが出て、exit 0

#### Scenario: 別の親から作られた子と archive された子は数えない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、一覧に `parentWorktreeId` が別のワークツリーの子 11 と、`isArchived` が true の子 12 のワークツリーがあるスタブ環境で `epic-dispatch.sh launch 400 13` を実行する
- **THEN** stdout は `launched 13`

#### Scenario: 使用中が上限より多ければすべて後回しにする
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、一覧に今のワークツリーから作られた子 11・12・13 のワークツリー（印なし）があり、`gh` がどれも `open` と返すスタブ環境で `epic-dispatch.sh launch 400 14 15` を実行する
- **THEN** stdout は `deferred 14`・`deferred 15` の 2 行で、`orca worktree create` は呼ばれず、exit 0

#### Scenario: 失敗した子も空き枠を使う
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、子 11 の `orca worktree create` が失敗するスタブ環境で `epic-dispatch.sh launch 400 11 12` を実行する
- **THEN** stdout は `failed 11`・`deferred 12` の 2 行で exit 1

#### Scenario: 後回しの子には注意書きを投稿しない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` のスタブ環境で `epic-dispatch.sh launch --note 注意 400 11 12` を実行する
- **THEN** `gh issue comment` は子 11 についてだけ呼ばれ、stdout は `launched 11`・`deferred 12`

#### Scenario: 上限の値が誤っていれば何も呼ばない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=abc` で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca` も `git` も呼ばれず、stderr に使い方が出て exit 1

### Requirement: 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる
develop の SKILL.md「エピックの扱い」→「回し方」は、次を書かなければならない（MUST）。これは要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方を書き換えず、上限と後回しの子の扱いを足すものである（「解けた子を件数にかかわらず `launch` する」は、`launch` に渡す子の選び方として今までどおりで、件数を抑えるのは `launch` である）。

**Orca 経路**: 手順 1 に、`launch` の出力に `deferred <N>`（上限に達したので起動しなかった子。後回しの子）があること、上限は `EPIC_DISPATCH_MAX_PARALLEL`（無ければ物理メモリから決める既定値）であることを書く。手順 2 に、後回しの子は `wait` の位置引数（動いている子）にも `--watch-done`（片付け待ちの子）にも入れないことを書く。手順 3（`done` を処理したあと）と手順 8（`stopped` を処理したあと）に、後回しの子が残っていれば、2 に戻る前に依存の解けた開いた子を `launch` に渡し直す（起動済みの子は `skipped`、枠がまだ無ければまた `deferred`）ことを書く。手順 4 の依存グラフを読み直して解けた子を `launch` する処理が後回しの子も含むことを書く。`launch` のあと動いている子も片付け待ちの子も 0 件なのに後回しの子が残るときは、`wait` を呼ばずに主に報告し、報告に `launch` の stderr の枠を使っている子の行を添えることを書く。後回しの子の一覧はどこにも保存せず、起動し直した親（手順 7）は依存の解けた開いた子を `launch` に渡した出力で後回しの子を知ることを書く。

**サブエージェント方式**: 開始時に `scripts/epic-dispatch.sh max-parallel` を 1 回呼んでその値を上限にし、エピックの全部の子をまたいで、枠を使っている W の総数をその上限までに抑えることを書く（MUST）。W 1 体（名前付きで起こし SendMessage で再開する 1 系列）は、起こしてから、その W が担う change のループが終わる（PR がマージされる・記録先が閉じる）か、主の返事待ちで保留に入るまで、1 枠を使う。1 つの子の中で change ごとに W を並列に起こすときは、その W ごとに 1 枠を使う。本体は、新しい子の最初の W を起こす前・同じ子の中で別の change の W を起こす前・保留から戻る W を再開する前に、そのつど空き枠（上限から枠を使っている W の数を引き、0 未満なら 0）を確かめ、空き枠が 0 なら起こさず再開もせずに待ちに回すことを書く（MUST）。枠が空いたら、待ちに回したもののうち、保留から戻る W の再開を先に、そのあと同じ子の中の別の change の W、そのあと依存の解けた新しい子の最初の W の順で起こすことを書く（SHALL。主の返事を受けた件と始まっている子を先に進めるため）。

**Orca 経路と両経路に共通の数え方**: 「枠を使っている子」に、完了の印の子・閉じた子・主の返事待ちで止まった子を数えないこと、その理由（止まった子はアイドルで、数えると主の返事が遅れるあいだ全体が止まる）を書く。Orca 経路では止まった子が戻るのは子のセッションの中なので親が止められず、戻った子の分だけ一時的に上限を超えうることを書く。サブエージェント方式では再開を本体が行うので、上の手順で再開前に空きを確かめ、上限を超えないことを書く。

`plugins/dev-workflow/tests/epic-dispatch.bats`（または `tests/develop-skill.bats`）は、SKILL.md のこれらの記述があることを確かめなければならない（MUST）。

この要件の入力は SKILL.md の本文である。拾いたい誤りは、親が `deferred` の子を動いている子として `wait` に渡して最長 6 時間待つこと、枠が空いても後回しの子を起動しないこと、サブエージェント方式で上限を超えて W を起こすことである。次は通してよく、この要件では止めない: `timeout` で起こされたときに後回しの子を `launch` に渡し直さないこと（枠は変わっていない）／サブエージェント方式で R1・G・決める役など W 以外の役割を枠に数えないこと（上限が抑えるのは W の数）／W が R1 や G の結果を待って動いていないあいだも 1 枠を使い続けること。手順書の読み方の揺れ（すり抜ける入力）が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: Orca 経路の手順に後回しの子の扱いが書かれている
- **WHEN** SKILL.md の Orca 経路の手順 1〜4・8 を読む
- **THEN** `deferred <N>` の意味、後回しの子を `wait` に渡さないこと、手順 3 と手順 8 のあとで後回しの子があれば `launch` に渡し直すこと、手順 4 の `launch` が後回しの子を含むことが書かれている

#### Scenario: 後回しの子だけが残ったら主に報告する
- **WHEN** SKILL.md の Orca 経路の手順を読む
- **THEN** 動いている子も片付け待ちの子も 0 件で後回しの子が残るとき、`wait` を呼ばずに `launch` の stderr を添えて主に報告することが書かれている

#### Scenario: サブエージェント方式に同じ上限が書かれている
- **WHEN** SKILL.md のサブエージェント方式の段落を読む
- **THEN** `epic-dispatch.sh max-parallel` の値を上限に、子をまたいだ W の総数を抑えること、W 1 体が枠を使う期間、新しい子の W・同じ子の別の change の W・保留から戻る W のどれも起こす前に空き枠を確かめること、待ちに回したものを起こす順（再開 → 同じ子の別の change → 新しい子）が書かれている

#### Scenario: 保留から戻る W は枠が空くまで再開しない
- **WHEN** 上限 2 のサブエージェント方式で、子 A と子 B の W を起こし、A が主の返事待ちで保留に入ったので子 C の W を起こしたあと、主が A に返事をした（B・C の W はまだ動いている）場面を、SKILL.md の手順に当てはめる
- **THEN** 手順からは、A の W を再開せずに待ちに回し、B か C の W が枠を返したら（ループが終わるか保留に入ったら）A を新しい子より先に再開する、と読める。同時に枠を使う W は 2 体を超えない

#### Scenario: 子の中で change ごとに W を起こすときも枠を使う
- **WHEN** 上限 2 のサブエージェント方式で、子 A の W と子 B の W が動いているあいだに、子 A が 2 つの change に割れて 2 つめの change の W を起こそうとする場面を、SKILL.md の手順に当てはめる
- **THEN** 手順からは、空き枠が 0 なので 2 つめの change の W を起こさずに待ちに回し、枠が空いたら新しい子より先に起こす、と読める

#### Scenario: Orca 経路で戻った子の扱いが書かれている
- **WHEN** SKILL.md の枠の数え方を読む
- **THEN** Orca 経路では戻った子の分だけ一時的に上限を超えうること、サブエージェント方式では再開前に空きを確かめるので超えないことが書かれている

#### Scenario: 枠を使っている子の数え方が書かれている
- **WHEN** SKILL.md の回し方を読む
- **THEN** 完了の印の子・閉じた子・主の返事待ちで止まった子を数えないことと、戻った子の分だけ一時的に上限を超えうることが書かれている
