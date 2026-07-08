# longrun-openspec-preflight Specification

## Purpose
TBD - created by archiving change openspec-degradation. Update Purpose after archive.
## Requirements
### Requirement: exec は Step 0 で OpenSpec 前提条件チェックを実行する

`/longrun:exec`（`/lr:e`）は、ランディレクトリ特定後・Setup フェーズ本体の開始前（Step 0）に、(a) `npx openspec` が解決可能であること、(b) カレント repo が openspec init 済み（git root 直下に `openspec/` ディレクトリが存在）であることの 2 条件を実コマンド実行で検査し、結果を checkpoint.md に記録しなければならない（SHALL）。コマンドを実行せずに「インストールされていない」と推測判断してはならない（MUST NOT）。

#### Scenario: 前提条件を満たす repo では従来どおり起動する

- **WHEN** `npx openspec` が解決可能で `openspec/` が存在する repo でユーザーが `/lr:e` を実行し、Step 0 の動作モード確認（通常モードがデフォルト・縮退選択肢を常時含む AskUserQuestion）で通常モードを選択する
- **THEN** 従来どおり通常モード（OpenSpec あり）で Setup フェーズが開始され、checkpoint.md に前提条件チェックの実行結果（コマンド出力）が記録される

#### Scenario: npx openspec が解決できない環境で縮退モードを提案する

- **WHEN** `npx openspec` が解決できない環境でユーザーが `/lr:e` を実行する
- **THEN** AskUserQuestion で「OpenSpec CLI が解決できないため縮退モード（spec 類を `_longruns/<run>/` 内に自己完結生成）で実行するか、中断して OpenSpec をセットアップするか」の選択肢が提示される

#### Scenario: openspec 未 init の repo で縮退モードを提案する

- **WHEN** `npx openspec` は解決できるが `openspec/` ディレクトリが存在しない repo でユーザーが `/lr:e` を実行する
- **THEN** AskUserQuestion で「openspec init して通常モードで続行する」「縮退モードで実行する」「中断する」の選択肢が提示される

### Requirement: ユーザーの選択で run の動作モードが確定する

Step 0 の AskUserQuestion に対するユーザーの回答に従って run の動作モードを確定し、縮退モードを選択した場合はランディレクトリに縮退マーカー（`_longruns/<run>/.degraded-mode`）を作成しなければならない（SHALL）。ユーザーが中断を選択した場合は run を開始せず、OpenSpec のセットアップ手順を案内して終了する（SHALL）。「OpenSpec 不要」の明示的 opt-out の入力手段として、preflight が OK の場合も Step 0 の動作モード確認 AskUserQuestion に縮退モードの選択肢を常時含めなければならない（SHALL。デフォルト選択肢は通常モード、専用の引数は追加しない）。

#### Scenario: 縮退モードを承諾すると縮退 run が開始される

- **WHEN** 縮退モード提案に対してユーザーが「縮退モードで実行する」を選択する
- **THEN** `_longruns/<run>/.degraded-mode` マーカーが作成され、OpenSpec CLI を一切呼び出さない縮退モードで Setup フェーズが開始される

#### Scenario: 中断を選択するとセットアップ案内が表示される

- **WHEN** 縮退モード提案に対してユーザーが「中断する」を選択する
- **THEN** run は開始されず、OpenSpec のインストール / init 手順の案内が表示されて exec が終了する

#### Scenario: ユーザーが OpenSpec 不要と明示して縮退モードで実行する

- **WHEN** 前提条件を満たす repo（preflight 結果 `OK`）でユーザーが `/lr:e` を実行し、Step 0 の動作モード確認 AskUserQuestion で「縮退モード（OpenSpec を使わない）」を選択する
- **THEN** 縮退マーカーが作成され、縮退モードで run が開始される

### Requirement: 既存の openspec あり repo の従来挙動は変わらない

前提条件を満たす repo（既存の openspec/ あり repo）において、Step 0 で通常モードを選択した後の実行フロー・成果物のパス・成果物の形式は従来から一切変化してはならない（MUST NOT）。Step 0 で追加されるユーザー対話は動作モード確認の 1 問のみとする（SHALL）。また `/longrun:status` には縮退分岐を実装しない（change-2 で廃止されるため）（SHALL NOT）。

#### Scenario: 通常モードの run は従来と同一の成果物を生成する

- **WHEN** openspec init 済みの repo でユーザーが `/lr:e` を実行し、Step 0 で通常モードを選択して run を完走させる
- **THEN** OpenSpec change（`openspec/changes/<name>/`）・checkpoint.md・verification-guide.md が従来バージョン（5.2.0）と同一のパス・形式で生成され、縮退マーカーは作成されない

