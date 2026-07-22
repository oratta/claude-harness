## REMOVED Requirements

### Requirement: 引数なし時は対象選択 UI で TARGETS を選ばせる

**Reason**: 引数なし時の対象選択（`AskUserQuestion` の「全て / 個別に選ぶ / キャンセル」3 択 + multiSelect バッチ）は、実運用でほぼ常に「全て」を選ぶだけの形式的な 1 クリックであり、この対話でセッションが停止して処理が途中で終わる事故が発生していた。`wt-clean-auto-flow` で per-target 確認を廃止して「実行して放置で終わる」体験に寄せた方針と一貫させるため、入口の対象選択 UI も廃止する。

**Migration**: 引数なし時は全 worktree をデフォルト対象にする（本 delta の ADDED「引数なし時は全 worktree をデフォルト対象にする（対象選択 UI なし）」を参照）。対象を絞りたい場合は既存の位置引数 `wt-clean <path|branch>` を使う。破壊判断が必要な 🔴 / dirty は Pass 2 の判断バッチで引き続き確認される。

## ADDED Requirements

### Requirement: 引数なし時は全 worktree をデフォルト対象にする（対象選択 UI なし）

引数なし（位置引数がなく、`--keep` / `--no-sync` のみ、または完全無指定）で実行された場合、`wt-clean` はリストアップした全 worktree（メインリポ自身を除く）を確認なしで `TARGETS` にし、そのまま Pass 1 に進むものとする（SHALL）。対象選択のための `AskUserQuestion`（「全て / 個別に選ぶ / キャンセル」および multiSelect）を呼んではならない（SHALL NOT）。

全件をデフォルト対象にしても安全性は損なわれない。🟢 Safe と 🟡（LLM のみ・退避検証済み）は確認なしで自動処理され、破壊判断が必要な 🔴 Active / dirty は Pass 1 で `DEFERRED` に積まれ、Pass 2 の判断バッチで明示確認される（`wt-clean-merge-active` 仕様に従う）。対象を絞りたい場合はユーザーが位置引数を指定する。

#### Scenario: 引数なしで全 worktree が確認なしで TARGETS になる

- **WHEN** ユーザーが引数なし `wt-clean` を実行する
- **THEN** メインリポを除く全 worktree がそのまま TARGETS になり Pass 1 に渡される
- **AND** 対象選択の AskUserQuestion（全て / 個別 / キャンセル）は一切表示されない

#### Scenario: オプションのみでも対象選択を聞かない

- **WHEN** ユーザーが `wt-clean --keep` や `wt-clean --no-sync`（位置引数なし）を実行する
- **THEN** 全 worktree が確認なしで TARGETS になり、対象選択の質問は表示されない

#### Scenario: worktree が存在しない場合は何もせず終了する

- **WHEN** メインリポ以外の worktree が 1 件も存在しない状態で引数なし `wt-clean` を実行する
- **THEN** 「対象の worktree がありません」と表示し、診断・削除・再利用化を行わず終了する

#### Scenario: 全件対象でも破壊判断は Pass 2 で確認される

- **GIVEN** 引数なし実行で全 worktree が TARGETS になっている
- **AND** その中に 🔴 Active または dirty な worktree が含まれる
- **THEN** それらは Pass 1 で自動削除されず `DEFERRED` に積まれ、Pass 2 の判断バッチで明示確認される

## MODIFIED Requirements

### Requirement: 引数なし時は遅延診断で worktree をリストアップする

引数なしで実行された場合、`wt-clean` は全件確定に先立って worktree を一覧表示するが、この時点では 🟢🟡🔴 のマージ済み判定（色分類）・dirty スキャン・LLM 検出・未マージコミット数の算出を**行わないものとする**（SHALL NOT）。リストには git 軽量コマンドで即取得できる情報（worktree パス、チェックアウト中ブランチ名、最終コミット日の相対表記）のみを表示する。この一覧は「これから全件を対象に処理する」ことの通知であり、選択を求めるものではない。診断はあくまで全件確定後の Pass 1 で、対象になった番になって初めて行う。

#### Scenario: リストに色分類が出ない

- **WHEN** ユーザーが引数なしで `wt-clean` を実行する
- **THEN** worktree 一覧が表示され、各行にブランチ名と最終コミット日が含まれる
- **AND** 🟢🟡🔴 のマージ済み判定（色）はこの時点では表示されない

#### Scenario: リスト表示時に全件診断のコストを払わない

- **WHEN** worktree が多数存在する状態で引数なし `wt-clean` を実行する
- **THEN** リストアップのために全 worktree の `git branch --merged` / dirty スキャン / LLM 検出は実行されない
