# dev-workflow-memory-refresh（delta）

## ADDED Requirements

### Requirement: SessionStart でメモリ索引の閾値超過を通知する

`plugins/dev-workflow/scripts/session-tripwires.sh` は SessionStart ごとに `plugins/dev-workflow/scripts/memory-tripwire.sh` を呼び、その出力が空でなければ additionalContext の先頭に足さなければならない（SHALL）。出力が空のときは additionalContext に何も足してはならない（MUST NOT）。

`memory-tripwire.sh` は対象プロジェクトのメモリディレクトリについて次の 4 つを測る（SHALL）: 索引 `MEMORY.md` のバイト数、索引の行数、`MEMORY.md` 以外の `*.md` 1 件の最大バイト数、索引の最終更新時刻からの経過日数。閾値は環境変数 `DEV_WORKFLOW_MEMORY_INDEX_BYTES` / `DEV_WORKFLOW_MEMORY_INDEX_LINES` / `DEV_WORKFLOW_MEMORY_FILE_BYTES` / `DEV_WORKFLOW_MEMORY_STALE_DAYS` で上書きでき（SHALL）、未設定または非負整数でない値のときは既定値（4000 / 20 / 2500 / 30）を使わなければならない（SHALL）。

いずれかの値が閾値を超えたときは、`[memory] ` で始まる行を**超えた条件の数によらず 1 行だけ** stdout に出さなければならない（SHALL）。その行は超えた条件ごとに実測値と閾値を含み、本文の条件では最大のファイル名を含み、見直しの手段として `/memory-refresh` を示す（SHALL）。どの値も閾値以内なら何も出力してはならない（MUST NOT）。

このスクリプトは通知だけを行い、メモリディレクトリのファイルを作成・変更・削除してはならない（MUST NOT）。実行時に切り捨てない方針（エピック #257）による。

メモリディレクトリは次の順で決める（SHALL）: ① `DEV_WORKFLOW_MEMORY_DIR` ② `CLAUDE_PROJECT_DIR`（未設定なら作業ディレクトリ）が git 管理下なら、git の共通ディレクトリの親（worktree の場合は元のリポジトリ）の物理パス、そうでなければそのディレクトリの物理パスを取り、英数字以外の文字を `-` に置き換えた名前を `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/` の下で使い、その下の `memory/` を対象とする。Claude Code が worktree でも元のリポジトリのメモリを使うことに合わせるためである。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: メモリディレクトリが解決できない ／ 索引が無い・読めない ／ どの値も閾値以内。1 回の実行は 100ms 未満で終わらなければならない（MUST）。

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

### Requirement: memory-refresh スキルで承認と控えを取ってから整理する

`plugins/dev-workflow/skills/memory-refresh/SKILL.md` を見直しの手順の正本とし（SHALL）、`plugins/dev-workflow/commands/memory-refresh.md` はその SKILL.md を読んで実行するだけの薄いラッパーでなければならない（SHALL。手順を複製しない）。

手順は次を含まなければならない（SHALL）: ① 索引と全ファイルを読む ② 1 件ずつ削除・統合・短縮・維持のいずれかに分類し、「ファイル名 / 分類 / 理由」の一覧を主に出して、適用前に 1 回だけ承認を取る ③ 承認後、メモリディレクトリ丸ごとの控えを取り、控えの場所を報告してから適用する ④ 適用後、索引の項目行の数がファイル数（`MEMORY.md` を除く）と一致し、索引が指すファイルと実在するファイルに過不足が無いことを確かめる ⑤ 適用前後の件数・総バイト数・索引のバイト数と行数・本文 1 件の最大バイト数を報告する。

分類の基準は既存のメモリ規約（1 件 1 事実・repo が記録していることは保存しない・間違いは削除）を使い（SHALL）、「終わった事実か」「repo が持っているか」は issue / PR の状態や repo の記述を確かめてから決めなければならない（SHALL）。適用はスクリプトにせず一覧どおりに手で行う（SHALL）。変更が無かった場合も索引の更新時刻を新しくし、見直した時刻を残さなければならない（SHALL。検知側が最終更新からの日数を見るため）。

SKILL.md は、実際に行った初回整理の一覧を例として載せなければならない（SHALL）。

#### Scenario: 適用前に一覧を出して承認を待つ

- **WHEN** `/memory-refresh` を実行する
- **THEN** 適用の前に「ファイル名 / 分類 / 理由」の一覧が出て、主の承認を待つ

#### Scenario: 控えを取ってから適用し、一致と数字を報告する

- **WHEN** 一覧に承認が出る
- **THEN** 控えを取ってその場所を報告してから適用し、適用後に索引の項目行の数とファイル数の一致・過不足なし・前後の数字が報告される
