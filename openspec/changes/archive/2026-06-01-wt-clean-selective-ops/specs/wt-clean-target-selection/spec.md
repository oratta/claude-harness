## ADDED Requirements

### Requirement: wt-clean はパス／ブランチ名引数で対象 worktree をスコープする

`wt-clean` コマンドおよびスキルは、1 個以上のパスまたはブランチ名を引数として受け取り、指定された worktree のみを処理対象（TARGETS）とし、それ以外の worktree を完全に無視するものとする（SHALL）。引数が指定された場合、対話的なリストアップ・対象選択（後述）は行わず、解決された TARGETS をそのまま逐次処理ループに渡す。`--keep` / `--no-sync` フラグと引数は併用可能とする。

各引数トークンは次の順で解決するものとする（SHALL）:
1. realpath で正規化し、`git worktree list --porcelain` の `worktree` 行（絶対パス）と完全一致を試みる
2. 一致しない場合、ブランチ名とみなし、worktree のチェックアウト中ブランチ（`branch refs/heads/<name>`）から逆引きする

#### Scenario: 絶対／相対パス指定でその worktree だけが対象になる

- **WHEN** ユーザーが `wt-clean ~/wt/foo`（または相対パス `./foo`）を実行する
- **THEN** realpath 正規化したパスが `git worktree list` の worktree と完全一致し、その 1 件のみが TARGETS になる
- **AND** 他の worktree は診断も処理もされない

#### Scenario: ブランチ名指定で逆引きされる

- **WHEN** ユーザーが `wt-clean feat-x` を実行し、`feat-x` をチェックアウト中の worktree が一意に存在する
- **THEN** その worktree が TARGETS になる

#### Scenario: 複数指定で複数が対象になる

- **WHEN** ユーザーが `wt-clean ~/wt/foo feat-y` を実行する
- **THEN** 解決された 2 件が TARGETS になり、それ以外は無視される

#### Scenario: 引数指定時はリストアップと対象選択を行わない

- **WHEN** ユーザーが引数付きで `wt-clean <path>` を実行する
- **THEN** worktree 一覧のリストアップ表示および対象選択の AskUserQuestion は行われず、解決された TARGETS が直接逐次処理ループに渡される

### Requirement: 引数が解決できない場合は誤爆を避けて中断する

`wt-clean` は引数トークンが 0 件にも複数件にもマッチする場合、または解決結果がメインリポ自身を指す場合、自動選択せずエラーで中断するものとする（SHALL）。破壊操作（worktree 削除）の誤爆を防ぐため、曖昧なマッチを勝手に確定しない。

#### Scenario: マッチ 0 件で中断する

- **WHEN** ユーザーが `wt-clean nonexistent` を実行し、どの worktree パス・ブランチ名にも一致しない
- **THEN** 「`nonexistent` に一致する worktree がありません」と表示し、現存 worktree 一覧を提示して処理を行わず終了する

#### Scenario: マッチ複数件で中断する

- **WHEN** あるブランチ名が複数 worktree に一致する、もしくは曖昧な指定で複数候補が出る
- **THEN** 候補一覧を提示し、絶対パスでの再指定を促して処理を行わず終了する（自動選択しない）

#### Scenario: メインリポ自身を指した場合は中断する

- **WHEN** 引数の解決結果がメインリポ（worktree の親）自身を指す
- **THEN** 「メインリポは削除対象外です」と表示し、その対象を処理せず終了する

### Requirement: 引数なし時は遅延診断で worktree をリストアップする

引数なしで実行された場合、`wt-clean` は対象選択に先立って worktree を一覧表示するが、この時点では 🟢🟡🔴 のマージ済み判定（色分類）・dirty スキャン・LLM 検出・未マージコミット数の算出を**行わないものとする**（SHALL NOT）。リストには git 軽量コマンドで即取得できる情報（worktree パス、チェックアウト中ブランチ名、最終コミット日の相対表記）のみを表示する。診断はあくまで対象選択後に、選ばれた対象についてのみ行う。

#### Scenario: リストに色分類が出ない

- **WHEN** ユーザーが引数なしで `wt-clean` を実行する
- **THEN** worktree 一覧が表示され、各行にブランチ名と最終コミット日が含まれる
- **AND** 🟢🟡🔴 のマージ済み判定（色）はこの時点では表示されない

#### Scenario: リスト表示時に全件診断のコストを払わない

- **WHEN** worktree が多数存在する状態で引数なし `wt-clean` を実行する
- **THEN** リストアップのために全 worktree の `git branch --merged` / dirty スキャン / LLM 検出は実行されない

### Requirement: 引数なし時は対象選択 UI で TARGETS を選ばせる

引数なし時、`wt-clean` はリストアップ後に `AskUserQuestion` で対象を選ばせるものとする（SHALL）。AskUserQuestion の 1 問あたり選択肢上限（4 つ）に対応するため、選択は次の 2 段構成とする:

1. 入口（single-select, 3 択）: 「全て / 個別に選ぶ / キャンセル」
2. 「個別に選ぶ」選択時は、worktree を 4 件ずつのバッチに分けた multiSelect 質問で対象を選ばせる。worktree が 1 回の AskUserQuestion 提示上限（最大 4 問 × 4 件 = 16 件）を超える場合は AskUserQuestion を複数回に分け、各回の提示範囲を `log` で明示する（無音での打ち切りを行わない）。

「全て」を選んだ場合は全 worktree を TARGETS にする。「キャンセル」を選んだ場合は何も処理せず終了する。

#### Scenario: 「全て」で全 worktree が TARGETS になる

- **WHEN** ユーザーが引数なし `wt-clean` の入口で「全て」を選ぶ
- **THEN** 全 worktree が TARGETS になり逐次処理ループに渡される

#### Scenario: 「個別に選ぶ」で選択した worktree のみ TARGETS になる

- **WHEN** ユーザーが入口で「個別に選ぶ」を選び、multiSelect で一部の worktree にチェックを入れる
- **THEN** チェックされた worktree のみが TARGETS になる

#### Scenario: 「キャンセル」で何も処理されない

- **WHEN** ユーザーが入口で「キャンセル」を選ぶ
- **THEN** どの worktree も診断・削除・再利用化されず終了する

#### Scenario: worktree が 16 件を超える場合は分割提示し範囲を明示する

- **GIVEN** worktree が 1 回の AskUserQuestion 提示上限を超える件数存在する
- **WHEN** ユーザーが「個別に選ぶ」を選ぶ
- **THEN** AskUserQuestion が複数回に分けて提示され、各回で何件目から何件目を提示しているかが `log` で明示される

### Requirement: TARGETS を 1 個ずつ遅延診断しカテゴリ別に対話処理する

`wt-clean` は確定した TARGETS を `git worktree list` の順で 1 件ずつ、`i/N` 形式の進捗表示とともに処理するものとする（SHALL）。各対象についてその場で診断（マージ済み判定 🟢🟡🔴・dirty・LLM・未マージコミット数）を行い、診断カテゴリに応じた対話を行う:
- 🟢 Safe → 削除（`--keep` 指定時は再利用化）の確認
- 🟡 Recoverable → LLM 退避 → 削除の確認
- 🔴 Active → マージ／スキップ／破棄の対話（`wt-clean-merge-active` 仕様に従う）

#### Scenario: 進捗表示付きで 1 件ずつ処理される

- **GIVEN** TARGETS が 4 件確定している
- **WHEN** 逐次処理ループが走る
- **THEN** 各対象の処理開始時に `[1/4]`〜`[4/4]` の進捗が表示される
- **AND** その対象の診断（🟢🟡🔴）は処理する番になって初めて実行される

#### Scenario: 🟡 と診断された対象は LLM 退避後に削除される

- **WHEN** 逐次処理中の対象が 🟡 Recoverable と診断される
- **THEN** LLM ファイルをメインリポへ退避してから削除の確認が行われる

#### Scenario: 🔴 と診断された対象はマージ／スキップ／破棄を対話する

- **WHEN** 逐次処理中の対象が 🔴 Active と診断される
- **THEN** その場で「マージ / スキップ / 破棄」の対話が行われる（独立した一括ルートを経由しない）

### Requirement: 完了レポートに処理結果と残存件数を表示する

`wt-clean` は逐次処理の完了後、処理した対象・スキップした対象・保留した対象・残存 worktree 件数を含む完了レポートを表示するものとする（SHALL）。`wt-clean-remote-sync` 仕様に従い、レポート冒頭には Step 0 の同期結果を 1 行で含める。

#### Scenario: 処理対象件数とスキップが区別表示される

- **WHEN** 逐次処理が完了する
- **THEN** 削除／再利用化された対象、スキップした対象、保留した対象、残存 worktree 件数がレポートに表示される
