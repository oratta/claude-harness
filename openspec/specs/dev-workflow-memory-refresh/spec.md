# dev-workflow-memory-refresh Specification

## Purpose
リポジトリの外にあって注入予算のテストで測れないメモリ（`~/.claude/projects/<project>/memory/`）について、索引の肥大と放置を SessionStart で通知し（通知のみ・fail-open）、主の承認と控えを取ってから手で見直す手順（memory-refresh スキル）を定める。

## Requirements

### Requirement: SessionStart でメモリ索引の閾値超過を通知する

`plugins/dev-workflow/scripts/session-tripwires.sh` は SessionStart ごとに `plugins/dev-workflow/scripts/memory-tripwire.sh` を呼び、その出力が空でなければ additionalContext の先頭に足さなければならない（SHALL）。出力が空のときは additionalContext に何も足してはならない（MUST NOT）。テンプレートが無い・トリップワイヤー節が抽出できないときは、`dev-workflow-escalation-tripwires` の「SessionStart hook がトリップワイヤーを常駐注入する」要件に従って何も出力せず、通知も出さない（SHALL）。

`memory-tripwire.sh` は対象プロジェクトのメモリディレクトリについて次の 4 つを測る（SHALL）: 索引 `MEMORY.md` のバイト数、索引の行数、`MEMORY.md` 以外の `*.md` 1 件の最大バイト数、索引の最終更新時刻からの経過日数。閾値は環境変数 `DEV_WORKFLOW_MEMORY_INDEX_BYTES` / `DEV_WORKFLOW_MEMORY_INDEX_LINES` / `DEV_WORKFLOW_MEMORY_FILE_BYTES` / `DEV_WORKFLOW_MEMORY_STALE_DAYS` で上書きでき（SHALL）、未設定または非負整数でない値のときは既定値（4000 / 20 / 2500 / 30）を使わなければならない（SHALL）。

いずれかの値が閾値を超えたとき、または要件「閉じた issue を持つメモリを `[memory]` の 1 行で知らせる」の閉じた issue を持つメモリがあるときは、`[memory] ` で始まる行を**超えた条件・閉じた issue の数によらず 1 行だけ** stdout に出さなければならない（SHALL）。その行は超えた条件ごとに実測値と閾値を含み、本文の条件では最大のファイル名を含み、見直しの手段として `/memory-refresh` を示す（SHALL）。どの値も閾値以内で、閉じた issue を持つメモリも無いなら何も出力してはならない（MUST NOT）。

このスクリプトは通知だけを行い、メモリディレクトリのファイルを作成・変更・削除してはならない（MUST NOT）。書いてよいのは、メモリディレクトリの外にある `patches:` の issue の状態の控え（要件「`patches:` の issue の状態をメモリディレクトリの外の控えに持つ」）と、裏の確認が走っている間だけ控えの横に置く目印のディレクトリだけである。実行時に切り捨てない方針（エピック #257）による。

メモリディレクトリは次の順で決める（SHALL）: ① `DEV_WORKFLOW_MEMORY_DIR` ② `CLAUDE_PROJECT_DIR`（未設定なら作業ディレクトリ）が git 管理下なら、git の共通ディレクトリの親（worktree の場合は元のリポジトリ）の物理パス、そうでなければそのディレクトリの物理パスを取り、英数字以外の文字を `-` に置き換えた名前を `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/` の下で使い、その下の `memory/` を対象とする。Claude Code が worktree でも元のリポジトリのメモリを使うことに合わせるためである。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: メモリディレクトリが解決できない ／ 索引が無い・読めない ／ どの値も閾値以内で、閉じた issue を持つメモリも無い。1 回の実行（裏の確認を除いた開始の処理）は、`patches:` や控えの有無と `gh` の応答の速さによらず 0.5 秒未満で終わらなければならない（MUST）。

#### Scenario: 閾値以内なら何も足さない

- **WHEN** 索引が 3 行・本文が小さく・索引を今更新したメモリディレクトリで `memory-tripwire.sh` を実行する
- **THEN** stdout は空で exit 0。同じ状態で `session-tripwires.sh` を実行すると additionalContext に `[memory]` は含まれない

#### Scenario: 条件ごとに 1 行が出る

- **WHEN** 索引のバイト数・索引の行数・本文 1 件のバイト数・索引の最終更新からの日数のいずれか 1 つだけを閾値超にして実行する
- **THEN** `[memory] ` で始まる行がちょうど 1 行出て、超えた条件の実測値と閾値が含まれる（本文の条件ではファイル名も含まれる）

#### Scenario: 複数の条件が同時に超えても 1 行

- **WHEN** 索引の行数・本文 1 件のバイト数・最終更新からの日数を同時に閾値超にして実行する
- **THEN** 3 つの条件をすべて含む行がちょうど 1 行出る

#### Scenario: ディレクトリが無い・読めないときは無出力

- **WHEN** 存在しないメモリディレクトリ、または読めない索引を対象に実行する
- **THEN** stdout は空で exit 0

#### Scenario: 閾値を環境変数で上書きできる

- **WHEN** 閾値以内のメモリディレクトリで `DEV_WORKFLOW_MEMORY_INDEX_LINES=1` を与えて実行する
- **THEN** 索引の行数の条件で 1 行が出る。`DEV_WORKFLOW_MEMORY_INDEX_LINES=abc` のように整数でない値を与えたときは既定値で判定され、無出力で exit 0

#### Scenario: worktree からは元のリポジトリのメモリを見る

- **WHEN** リポジトリとその worktree を作り、メモリを元のリポジトリの名前の下にだけ置いて、`CLAUDE_PROJECT_DIR` を worktree にして実行する
- **THEN** 元のリポジトリのメモリが測られる

#### Scenario: 通知は SessionStart の注入文の先頭に載る

- **WHEN** 閾値超のメモリディレクトリを `DEV_WORKFLOW_MEMORY_DIR` で指して `session-tripwires.sh` を実行する
- **THEN** additionalContext は `[memory] ` で始まり、昇格トリップワイヤー節も従来どおり含まれる

#### Scenario: 閾値の超過と閉じた issue が同時でも 1 行

- **WHEN** 索引の行数を閾値超にし、閉じた issue を `patches:` に持つメモリを置いて実行し、裏の確認が終わってからもう一度実行する
- **THEN** `[memory] ` で始まる行がちょうど 1 行出て、索引の行数の条件と閉じた issue を持つメモリのファイル名の両方を含む

### Requirement: memory-refresh スキルで承認と控えを取ってから整理する

`plugins/dev-workflow/skills/memory-refresh/SKILL.md` を見直しの手順の正本とし（SHALL）、`plugins/dev-workflow/commands/memory-refresh.md` はその SKILL.md を読んで実行するだけの薄いラッパーでなければならない（SHALL。手順を複製しない）。

手順は次を含まなければならない（SHALL）: ① 索引と全ファイルを読む ② 1 件ずつ削除・統合・短縮・維持のいずれかに分類し、「ファイル名 / 分類 / 理由」の一覧を主に出して、適用前に 1 回だけ承認を取る ③ 承認後、メモリディレクトリ丸ごとの控えを毎回新しい場所に取り（既にある場所には取らない）、コピーの成功と元との一致を確かめ、控えの場所を報告してから適用する。控えの作成か照合に失敗したときは適用してはならない（MUST NOT） ④ 適用後、索引の項目行（`- [` で始まる行）の数がファイル数（`MEMORY.md` を除く）と一致し、索引が指すファイルと実在するファイルに過不足が無いことを確かめる ⑤ 適用前後の件数・総バイト数・索引のバイト数と行数・本文 1 件の最大バイト数を報告する。

分類の基準は既存のメモリ規約（1 件 1 事実・repo が記録していることは保存しない・間違いは削除）を使い（SHALL）、frontmatter の `patches:` の issue が完了（`COMPLETED`）で閉じたメモリは削除に分類しなければならない（SHALL。直し先が直ったので、その場しのぎの記憶は要らない）。完了以外（`NOT_PLANNED`・`DUPLICATE` など）で閉じたものは削除に決め打ちせず、メモリが補っていたプラグインの動きが直ったかを確かめてから分類し、直っていなければ維持して `patches:` を新しい直し先の issue に書き換えるか消さなければならない（SHALL）。「終わった事実か」「repo が持っているか」は issue / PR の状態や repo の記述を確かめてから決めなければならない（SHALL）。適用はスクリプトにせず一覧どおりに手で行う（SHALL）。変更が無かった場合も索引の更新時刻を新しくし、見直した時刻を残さなければならない（SHALL。検知側が最終更新からの日数を見るため）。

SKILL.md は、実際に行った初回整理の一覧を例として載せなければならない（SHALL）。SKILL.md は `patches:` の書き方の正本を持たなければならない（SHALL）: 置き場所（frontmatter の `metadata:` の下、またはトップレベル）、値（直し先の GitHub の issue の URL 1 本）、検知側（`memory-tripwire.sh`）がセッションの開始時に issue の状態を裏で確かめて控え、閉じていればその次のセッションの `[memory]` で知らせること。

#### Scenario: 適用前に一覧を出して承認を待つ

- **WHEN** `/memory-refresh` を実行する
- **THEN** 適用の前に「ファイル名 / 分類 / 理由」の一覧が出て、主の承認を待つ

#### Scenario: 控えを取ってから適用し、一致と数字を報告する

- **WHEN** 一覧に承認が出る
- **THEN** 新しい場所に控えを取り、元との一致を確かめてその場所を報告してから適用し、適用後に索引の項目行の数とファイル数の一致・過不足なし・前後の数字が報告される

#### Scenario: 控えが取れなければ適用しない

- **WHEN** 控えの場所が既に存在する、またはコピーか照合に失敗する
- **THEN** 削除・短縮を適用せずに止まる

`patches:` による分類の守備範囲は次のとおり。入力の出どころはメモリの frontmatter と `gh` が返す issue の状態・閉じ方で、敵対的な入力は想定しない。拾う誤りは、完了で閉じたものを削除にしないこと・完了以外で閉じたものを確かめずに削除にすること。通してよい具体例は、動きが直ったかの判断の誤り（主が一覧の承認で見る）。見つかる穴をすべて塞ぐことは完了条件にしない（MUST NOT）。

#### Scenario: patches: の issue が完了で閉じたメモリは削除に分類される

- **WHEN** `patches:` の issue が `COMPLETED` で閉じたメモリと、`NOT_PLANNED` で閉じたメモリがあるメモリディレクトリで `/memory-refresh` を実行する
- **THEN** 前者は削除に分類され、後者はプラグインの動きが直ったかを確かめた結果で分類され、直っていなければ維持と `patches:` の書き換えか削除が一覧に出る

#### Scenario: SKILL.md に patches: の書き方がある

- **WHEN** `plugins/dev-workflow/skills/memory-refresh/SKILL.md` を読む
- **THEN** `patches:` の置き場所（`metadata:` の下とトップレベル）・値（issue の URL 1 本）・検知側が開始時に裏で確かめて次のセッションで知らせることが書かれている

### Requirement: memory-tripwire.sh はメモリの frontmatter の `patches:` を読む

`memory-tripwire.sh` は、メモリディレクトリの `MEMORY.md` 以外の `*.md` について、ファイル先頭の frontmatter（最初の `---` の行から次の `---` の行まで）にある `patches:` の値を読まなければならない（SHALL）。読む位置はトップレベルの `patches:` と、`metadata:` の下に字下げされた `patches:` の両方である（SHALL）。値が `https://github.com/<owner>/<repo>/issues/<番号>` の形でないものと、frontmatter の外の `patches:` は無視しなければならない（MUST）。

#### Scenario: 2 つの置き場所のどちらも読む

- **WHEN** `metadata:` の下に `patches:` を持つメモリと、トップレベルに `patches:` を持つメモリを置き、`gh` が両方の issue を閉じていると返す状態で実行し、裏の確認が終わってからもう一度実行する
- **THEN** `[memory] ` で始まる行がちょうど 1 行出て、2 件のファイル名と issue の URL を含む

#### Scenario: frontmatter の外と URL でない値は無視する

- **WHEN** 本文の中にだけ `patches:` の行があるメモリと、`patches:` の値が issue の URL でないメモリを置いて実行する
- **THEN** `gh` は呼ばれず、控えにも書かれない

### Requirement: `patches:` の読み取りの守備範囲を限る

要件「memory-tripwire.sh はメモリの frontmatter の `patches:` を読む」の守備範囲は次のとおりでなければならない（MUST）。入力の出どころはエージェントか主が書いたメモリのファイルで、敵対的な入力は想定しない。拾う誤りは、2 つの置き場所の片方を読まないこと・frontmatter の外や URL でない値を確かめに行くこと。通してよい具体例は、YAML として不正な frontmatter の読み違い・引用符や複数行で書いた値を読めないこと（人のレビューが見る）。見つかる穴をすべて塞ぐことは完了条件にしない（MUST NOT）。

#### Scenario: 守備範囲の外の書き方でもセッション開始を止めない

- **WHEN** `patches:` の値を引用符で囲んだメモリを置いて実行する
- **THEN** exit 0 で終わり、セッションの開始は止まらない（その値を読めるかどうかは、この要件の拾う誤りに入らない）

### Requirement: `patches:` の issue の状態をメモリディレクトリの外の控えに持つ

issue の状態は、`patches:` の URL ごとに、確かめた日（ローカルの日付）・状態・閉じ方を控えに書いて持たなければならない（SHALL）。控えは全プロジェクト共通の 1 ファイルで、既定は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.memory-patches-cache.tsv`、`DEV_WORKFLOW_MEMORY_PATCHES_CACHE` で変えられる（SHALL）。メモリディレクトリの中に置いてはならず（MUST NOT）、別のファイルに書いてから置き換えなければならない（SHALL）。

#### Scenario: 控えをメモリディレクトリに置かない

- **WHEN** `patches:` を持つメモリを置いて実行する
- **THEN** 実行の前後でメモリディレクトリのファイルの一覧と中身が変わらない

### Requirement: 開始は控えだけを読み、`patches:` の issue は裏で確かめ直す

開始の処理は控えだけを読んで知らせ、`gh` の応答を待ってはならない（MUST NOT）。GitHub への照会は 1 回 0.3〜0.7 秒かかり、開始の 0.5 秒未満と両立しないためである（主の決定: https://github.com/oratta/claude-harness/pull/1655#issuecomment-6941172238 ）。当日に閉じたと控えた URL を除くすべての `patches:` の URL（控えの無いもの・当日に開いているか「不明」と控えたもの・前の日の控え）は、標準入力・標準出力・標準エラーを閉じた裏のプロセスで `gh` に確かめ直し、控えを書き換えなければならない（SHALL）。当日に閉じたと控えた URL について `gh` を呼んではならない（MUST NOT）。閉じたことは、裏の確認が控えに書いたあとのセッションで知らせる（SHALL。閉じたあと 2 回目のセッションになってよい）。

#### Scenario: 開始は控えだけを読み、0.5 秒未満で終わる

- **WHEN** 当日に閉じたと控えた URL と当日に開いていると控えた URL を持つメモリを置き、呼ばれたら記録を残す `gh` を置いて実行する
- **THEN** 開始の処理は 0.5 秒未満で終わり、閉じたと控えたメモリだけが `[memory]` の行に出る。裏の確認では、開いていると控えた URL についてだけ `gh` が呼ばれる

#### Scenario: 閉じたことは裏の確認が控えに書いた次のセッションで知らせる

- **WHEN** 1 回目の実行で開いていると控えたあと、`gh` が閉じていると返すように替えて 2 回目を実行し、裏の確認が終わってから 3 回目を実行する
- **THEN** 2 回目の stdout は空で、裏の確認が控えをその日の日付で閉じていると書き換え、3 回目の `[memory]` の行にそのメモリが出る

#### Scenario: 前の日の控えは確かめ直す

- **WHEN** 開いていると書かれた前の日の控えがあり、`gh` がその issue を閉じていると返す状態で実行する
- **THEN** 裏の確認で `gh` が呼ばれ、控えがその日の日付で閉じていると書き換わり、次の実行の `[memory]` の行にそのメモリが出る

### Requirement: `patches:` の issue の裏の確認を 2 つ同時に走らせない

裏の確認が走っている間は、控えのパスに `.lock` を付けた目印のディレクトリを置き（SHALL）、目印があるあいだは新しい裏の確認を起こしてはならない（MUST NOT）。打ち切りの時間より 60 秒以上古い目印は、途中で止まった確認の残りとして取り直す（SHALL）。

#### Scenario: 裏の確認を 2 つ同時に走らせない

- **WHEN** 新しい目印のディレクトリがある状態で実行し、次に目印の更新時刻を古くして実行する
- **THEN** 1 回目は `gh` が呼ばれず、2 回目は目印を取り直して裏の確認が走り、控えが書かれる

### Requirement: `patches:` の issue を確かめる処理は時間で打ち切り、失敗しても止めない

裏の確認は、`DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT` の秒数（既定 3。非負整数でなければ既定。0 なら `gh` を呼ばず、裏の確認も起こさない）で打ち切らなければならない（MUST）。控えの置き場所が無く目印を置けないときは、裏の確認を起こさない（SHALL）。`gh` が無い・認証切れ・オフライン・時間切れ・控えの読み書きの失敗でも、セッションの開始を止めてはならず（MUST NOT）、失敗そのものを表示してはならない（MUST NOT）。閾値の超過と、確かめられた別の URL の閉鎖は、失敗があっても知らせる（SHALL）。確かめられなかった URL は、`gh` が無いときを除き、その日の日付で状態「不明」と控え（SHALL）、次のセッションの裏の確認で確かめ直す（SHALL）。「不明」は閉じたとして扱わない（MUST NOT）。

#### Scenario: gh が使えなくても止めない

- **WHEN** `gh` が無い、`gh` が失敗を返す、または `gh` が打ち切りの時間より長く返らない状態で、閾値以内のメモリディレクトリに `patches:` を持つメモリを置いて実行する
- **THEN** stdout は空で exit 0、開始の処理は 0.5 秒未満で終わり、裏の確認は打ち切りの時間と 1 秒の和より前に終わる。`gh` が無いときは控えが書かれず、それ以外では状態「不明」がその日の日付で書かれ、次の実行の裏の確認で `gh` がもう一度呼ばれる

#### Scenario: 取得の失敗があっても閾値の超過と別の URL の閉鎖は知らせる

- **WHEN** 索引の行数を閾値超にし、`gh` が失敗を返す URL を持つメモリと、`gh` が閉じていると返す URL を持つメモリを置いて実行し、裏の確認が終わってからもう一度実行する
- **THEN** `[memory] ` の行がちょうど 1 行出て、索引の行数の条件と閉じた URL のメモリを含み、失敗した URL のメモリと失敗の内容は含まない

#### Scenario: 打ち切りの時間を 0 にすると gh を呼ばない

- **WHEN** `DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT=0` で、控えの無い `patches:` を持つメモリを置いて実行する
- **THEN** `gh` は呼ばれず、控えも書かれない

### Requirement: 閉じた issue を持つメモリを `[memory]` の 1 行で知らせる

控えの状態が閉じている URL を持つメモリが 1 件以上あるときは、`[memory] ` の 1 行（要件「SessionStart でメモリ索引の閾値超過を通知する」の 1 行）に、閉じた issue を持つメモリの件数と、ファイル名と issue の URL の組を含めなければならない（SHALL）。閉じ方（完了かそれ以外か）は通知では分けない（SHALL。分類は memory-refresh で行う）。

#### Scenario: 開いている issue だけなら何も出さない

- **WHEN** 閾値以内のメモリディレクトリで、`patches:` の issue がすべて開いていると `gh` が返す
- **THEN** stdout は空で exit 0

#### Scenario: 閉じた issue は閉じ方によらず知らせる

- **WHEN** `patches:` の issue が `NOT_PLANNED` で閉じたメモリを置いて実行し、裏の確認が終わってからもう一度実行する
- **THEN** `[memory]` の行にそのメモリのファイル名と issue の URL が出る
