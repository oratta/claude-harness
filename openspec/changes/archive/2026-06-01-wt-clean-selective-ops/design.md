## Context

`wt-clean` は現状「Step 0 Sync → Step 1 全件診断 → Step 2 全件分類（🟢🟡🔴）→ Step 3 一括モード選択 → Step 4-7 カテゴリ一律処理 → Step 8 レポート」というフロー（`plugins/worktree/skills/wt-clean/SKILL.md`, version 1.3.0）。

既存仕様は 3 つの delta change で積み上げられている:
- `wt-clean-remote-sync`: Step 0 の `git fetch` + `git pull --ff-only` と `--no-sync`
- `wt-clean-merge-active`: 🔴 Active がある場合に Step 3 先頭へ「🔴 を main にマージ」選択肢を挿入する独立ルート（Step 5a/5b）
- `wt-clean-reuse`: `--keep` による 🟢 Safe 再利用化

本 change はこのコアフローを「選択ベース + 遅延診断 + 逐次対話」へ刷新する。スキルは `AskUserQuestion`（1 問あたり選択肢 2〜4・1 回最大 4 問・multiSelect 可）で対話する制約下で動く。実装対象は marketplace 配布されるスキル定義ファイルであり、`plugins/worktree/skills/wt-clean/SKILL.md` と `plugins/worktree/commands/wt-clean.md` の 2 ファイルが存在する（本文が既に乖離）。

## Goals / Non-Goals

**Goals:**
- パス／ブランチ名引数で対象 worktree を狙い撃ちし、他を完全に無視できる
- 引数なし時は「診断せずリストアップ → 対象を選ぶ → 選んだものだけ 1 個ずつ遅延診断＆対話」
- パス指定と対話選択を「TARGETS 確定 → 逐次処理」の単一パイプラインに統合
- 既存の安全機構（Sync / 🔴 マージの選択肢制御 / `--no-ff` / 競合ハンドリング / サニティチェック / LLM 退避 / `--keep` / `--no-sync`）の意味を保ったまま新フローへ移植

**Non-Goals:**
- `SKILL.md` と `commands/wt-clean.md` の完全な single-source 化（1 ファイル統合）は別 change とする。本 change では両者に同一フローを反映するか、薄い参照に寄せるところまで（D9）
- 選択をスキップして全自動で削除する `--yes` 系の無人実行モードは作らない（Open Question 送り）
- worktree の作成・セットアップ側（wt-setup）には触れない

## Decisions

### D1: 「TARGETS 確定 → 1 個ずつ遅延診断＆対話」の単一パイプライン

引数あり／なしのどちらも、以下の共通後段に合流させる:

```
Step 0  Sync（--no-sync で skip）
Step A  TARGETS 確定
          ├ 引数あり → 引数を解決して TARGETS に（D2）。リストアップ/選択は行わない
          └ 引数なし → リストアップ（D3）→ 対象選択（D4）→ TARGETS に
Step B  for i, wt in TARGETS:   # i/N 進捗表示
          診断（🟢🟡🔴 + dirty + LLM + 未マージコミット数）  ← 遅延診断
          カテゴリ別対話:
            🟢 → 削除（--keep 時は再利用化）の確認
            🟡 → LLM 退避 → 削除の確認
            🔴 → マージ/スキップ/破棄（D6）。マージ時は直後にサニティチェック（D7）
Step C  完了レポート（処理/スキップ/保留/残存件数）
```

**Rationale**: 「選択＝対象スコープの決定のみ。診断と操作決定は後段で 1 件ずつ」というユーザー意図に一致。パス指定は「Step A の選択を引数で前倒しした」だけと位置づけることで、①②を分岐ではなく入口違いに畳める。

**Alternative considered**: 現状の「全件先診断 → 一括選択」を残しパス指定だけ足す案。→ ②（個別選択）が別フローになり二重メンテになるため却下。

### D2: パス／ブランチ名引数の解決

複数引数を受け取り、各トークンを以下で解決する:

1. realpath で正規化し、`git worktree list --porcelain` の `worktree` 行（絶対パス）と完全一致を試す
2. 一致しなければブランチ名とみなし、worktree list の checkout 中ブランチ（`branch refs/heads/<name>`）から逆引き
3. 0 件 → エラー: 「`<token>` に一致する worktree がありません」+ 現存 worktree 一覧を提示して中断
4. 複数件 → エラー: 候補一覧を提示し、絶対パスでの再指定を促して中断（誤爆防止のため自動選択しない）
5. メインリポ自身を指した場合 → エラー: 「メインリポは削除対象外」

**Rationale**: 絶対パス完全一致を最優先にすることで誤爆を最小化。ブランチ名はフォールバックとして直感性を確保。曖昧（複数ヒット）は安全側に倒して中断。

**Alternative considered**: 部分一致 fuzzy。→ 破壊操作（worktree 削除）で誤爆リスクが高く却下。

### D3: 遅延診断とリスト表示情報

引数なし時の Step A リストアップでは merged 判定（🟢🟡🔴 の色）を**行わない**。表示するのは git 軽量コマンドで即取れる:
- worktree パス（短縮表示可）
- checkout 中ブランチ名（`git worktree list` 由来）
- 最終コミット日（`git log -1 --format=%cr <branch>` 等の相対表記）

merged 判定・dirty スキャン・LLM 検出・未マージコミット数は **選択後の Step B で対象分だけ**実行する。

**Rationale**: worktree が多いとき全件診断のコストを払わない。ユーザーの「最初は何もチェックせずリストアップだけ」要望に一致。最終コミット日は「どれが古い／放置か」の選択手がかりとして安価かつ有用。

### D4: 選択 UI と AskUserQuestion 4 択制約への対処

`AskUserQuestion` は 1 問あたり選択肢最大 4 つ。worktree が多いと「全て + 個別」を 1 問に並べられない。2 段構成にする:

- **入口 1 問（single-select, 3 択）**: 「全て / 個別に選ぶ / キャンセル」
  - 「全て」→ 全 worktree を TARGETS に（＝廃止した一括モードの代替）
  - 「個別に選ぶ」→ 続く multiSelect へ
  - 「キャンセル」→ 何もせず終了
- **個別選択（multiSelect, 1 問 4 択まで）を worktree 4 件ずつのバッチに分割**:
  - 1 回の `AskUserQuestion` 呼び出しは最大 4 問 → 1 回で 4 件 × 4 問 = 16 件まで提示可能
  - worktree が 16 件を超える場合は `AskUserQuestion` を複数回に分け、各回で何件目〜何件目を提示しているか `log` で明示する（無音の打ち切りはしない）

**Rationale**: 入口で「全て」を独立させることで、件数に依存せず一括相当を 1 操作で表現できる。個別はバッチ分割で件数制約を吸収。

**Alternative considered**: フリーテキストで番号入力（"1,3,5"）。→ AskUserQuestion の UX 統一性を崩し、入力検証コストも増えるため却下。

### D5: 一括モード廃止（BREAKING）と「全て」での代替

現状 Step 3 の一括 4 択／5 択（`wt-clean-merge-active` が定義）は廃止する。代替は D4 入口の「全て」選択（全件を逐次処理）。

**Rationale**: 「選択 → 1 個ずつ対話」をデフォルトに統一することがユーザーの明示要望。一括選択を残すと入口が 2 系統になりフローが分岐する。CLAUDE.md の回帰防止方針は「意図せぬ破壊の防止」が趣旨であり、本件は**意図的・合意済みの仕様変更**なので BREAKING として明示記録する。

**Trade-off**: 「サクッと全削除（1 タップ完了）」体験は失われ、「全て」選択後も各件で対話が入る。冗長性の緩和（🟢 の確認一括承認など）は Open Question 送り。

### D6: 🔴 マージの per-target 統合

`wt-clean-merge-active` の「Step 3 先頭に独立ルートを挿入」要件は REMOVED。代わりに Step B の逐次ループ内で当該 worktree が 🔴 と診断された時、その場で「マージ / スキップ / 破棄」を提示する。per-🔴 の既存ロジックは保持して移植する:
- Dirty 同時 → マージ選択肢を除外（スキップ / 破棄の 2 択）+ 理由明示
- detached HEAD → マージ選択肢を除外（同 2 択）+ 理由明示
- マージは MAIN_BRANCH チェックアウト下で `git merge --no-ff`、merge in progress / 非 MAIN_BRANCH チェックアウト時は中断
- 競合時は `git merge --abort` を自動実行しない（保持）

**Rationale**: 「🔴 があるかどうかで Step 3 の選択肢が増減する」分岐自体が、選択ベースフローでは不要になる（対象選択は色を見ずに行うため）。マージ判断を「その worktree を処理する番」に遅延させる方がフローが一貫する。

### D7: サニティチェックをマージ都度実行

従来「全マージ後にバッチ 1 回」だったテスト/ビルド検証を、各マージ直後にそのマージ分について実行する。PASS → 削除確定、FAIL → 当該 worktree と以降を保留。テストコマンド自動検出（package.json / Cargo.toml / pyproject / go.mod）と「見つからなければ skip」は維持。

**Rationale**: どのマージが壊したか即座に切り分けられる（ユーザー選択）。

**Trade-off**: マージ N 件 = テスト N 回で総時間は増える。緩和策は Risks 参照。

### D8: `--keep` / `--no-sync` の新フロー上の扱い

- `--no-sync`: Step 0 を skip。パス指定時も有効（D1 の Step 0 共通化）。
- `--keep`: Step B の 🟢 処理を「削除」ではなく「再利用化（main 切替＋元ブランチ削除、untracked 保持）」に切り替える。🟡 は従来通り削除、🔴 はマージ後 main 化のため再利用化はノーオペ → 通常削除にフォールバック（既存 reuse spec の思想を維持）。`--keep` の対象が 0 件でもエラーにしない。

### D9: SKILL.md と commands/wt-clean.md の二重管理

実装時にまず両ファイルの乖離実態を確認する（commands 版は version 表記がなく description も簡素で、remote-sync / merge-active が未反映の疑い）。本 change では:
- `SKILL.md` を正本として刷新フローを実装
- `commands/wt-clean.md` は同一本文に同期するか、`SKILL.md` を参照する薄いエントリに寄せる（commands 経由起動で旧フローが動く事故を防ぐ）

完全な single-source 化（1 ファイル化）は Non-Goal（別 change）。

## Risks / Trade-offs

- **[一括モード廃止で操作感が変わる]** → 入口「全て」で全件処理を 1 操作で開始できるよう担保。レポート冒頭に処理対象件数を明示。BREAKING を proposal/spec に記録。
- **[マージ都度サニティチェックで総時間増（テスト N 回）]** → マージ件数は通常少数。テスト未検出時は skip。重いテストへの `--no-verify` 系逃げ道は Open Question。
- **[worktree 多数時に選択 UI が複数 AskUserQuestion に分割されだれる]** → 入口「全て」で回避可能。分割時は提示範囲を log で明示し無音打ち切りを禁止。
- **[ブランチ名指定の誤爆（複数ヒットや別 worktree 削除）]** → 絶対パス完全一致を最優先、複数ヒット・0 件は自動選択せず中断して候補提示。
- **[commands/SKILL 乖離による旧フロー実行事故]** → D9 で両ファイルに反映 or 参照化。実装タスクに乖離調査を含める。
- **[遅延診断でリスト時に古い情報を見て選ぶ]** → 最終コミット日は表示するが、確定判断（merged/dirty）は選択後の対象分診断で行うため、誤って未マージを「全て」削除する事故は Step B の 🔴 対話（マージ/スキップ/破棄の明示確認）で食い止められる。

## Migration Plan

1. `SKILL.md` を新フローへ書き換え、`commands/wt-clean.md` を D9 方針で揃える
2. `plugin.json` のバージョンを更新（marketplace キャッシュ反映のため）
3. 既存 delta spec（merge-active / reuse / remote-sync）を本 change の delta で更新、新規 target-selection spec を追加
4. ロールバック: スキル定義ファイルの差し戻し（git revert）+ plugin.json バージョン戻しで即時復帰可能（データ移行を伴わない）

## Open Questions

- 🟢 の確認を一括承認できる高速化（例: 入口「全て（🟢 は確認省略）」）を将来オプションとして足すか
- マージ都度サニティチェックの `--no-verify` 系スキップを用意するか
- `commands/wt-clean.md` を将来 `SKILL.md` 単一ソース化する別 change を切るか
