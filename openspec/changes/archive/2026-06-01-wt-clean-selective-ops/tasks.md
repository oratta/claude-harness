## 1. 準備・現状調査

- [x] 1.1 `plugins/worktree/skills/wt-clean/SKILL.md` と `plugins/worktree/commands/wt-clean.md` の乖離内容を diff で洗い出し、どちらが正本か（remote-sync / merge-active / reuse が両方に反映されているか）を確認する（design D9）→ 本文ロジックはほぼ同一。差は frontmatter（commands は version 無し・description 簡素）とコメント数行のみ。両方に新機能反映済み。**SKILL.md を正本**とする
- [x] 1.2 正本を `SKILL.md` に定め、`commands/wt-clean.md` を同期 or 参照化する方針を確定する（commands 経由起動で旧フローが動く事故の防止）→ **本文同期**を選択（参照化は slash command 単独起動で動かない懸念）
- [x] 1.3 既存 Step 構造（Step 0〜8、Step 5a/5b/6d）のうち、逐次フローへ移植するロジック断片（per-🔴 確認・`git merge --no-ff`・競合ハンドリング・サニティ検出・LLM 退避・再利用化・重複チェックアウト検知）を棚卸しする → 全断片を SKILL.md 既存記述から把握済み、Step B 逐次ループへ再配置

## 2. 引数パースとスコープ解決（wt-clean-target-selection）

- [x] 2.1 `--keep` / `--no-sync` フラグと位置引数（パス／ブランチ名、複数可）を分離してパースする処理を定義する
- [x] 2.2 各引数トークンを realpath 正規化 → `git worktree list --porcelain` の `worktree` 行と完全一致で解決する
- [x] 2.3 パス一致しない場合にブランチ名（`branch refs/heads/<name>`）から逆引きするフォールバックを定義する
- [x] 2.4 マッチ 0 件 → 現存 worktree 一覧を提示して中断、複数件 → 候補提示し絶対パス再指定を促して中断（自動選択しない）、メインリポ指定 → 「削除対象外」で中断、を定義する
- [x] 2.5 引数指定時はリストアップ・対象選択をスキップし、解決した TARGETS を直接逐次処理ループに渡すことを明記する

## 3. 遅延診断リストアップ（引数なし時, wt-clean-target-selection）

- [x] 3.1 リストアップ時に 🟢🟡🔴 判定・dirty スキャン・LLM 検出・未マージコミット数算出を**行わない**ことを明記する（SHALL NOT）
- [x] 3.2 表示情報を worktree パス・チェックアウト中ブランチ名・最終コミット日（`git log -1 --format=%cr`）のみに限定する処理を定義する

## 4. 対象選択 UI（引数なし時, wt-clean-target-selection）

- [x] 4.1 入口 AskUserQuestion（single-select 3 択: 全て / 個別に選ぶ / キャンセル）を定義する
- [x] 4.2 「全て」→ 全 worktree を TARGETS、「キャンセル」→ 無処理終了、の分岐を定義する
- [x] 4.3 「個別に選ぶ」→ worktree を 4 件ずつのバッチに分けた multiSelect 質問（1 回最大 4 問 × 4 件 = 16 件）を定義する
- [x] 4.4 worktree が 16 件超のとき AskUserQuestion を複数回に分け、各回の提示範囲を `log` で明示する（無音打ち切り禁止）

## 5. 逐次処理ループ（wt-clean-target-selection）

- [x] 5.1 TARGETS を `git worktree list` 順に `[i/N]` 進捗表示付きで 1 件ずつ処理するループ骨格を定義する
- [x] 5.2 各対象の処理開始時にその場で診断（🟢🟡🔴 + dirty + LLM + 未マージコミット数）を行う遅延診断を組み込む
- [x] 5.3 🟢 → 削除（`--keep` 時は再利用化）の確認対話を定義する
- [x] 5.4 🟡 → LLM 退避 → 削除の確認対話を定義する（既存 LLM 退避ロジックを移植）
- [x] 5.5 🔴 → マージ／スキップ／破棄の対話へ分岐させる（§6 へ接続）

## 6. 🔴 マージの逐次統合（wt-clean-merge-active delta）

- [x] 6.1 旧 Step 3 一括選択肢（🔴 マージ先頭挿入 / 🟢🟡処理 等の 4・5 択）と「回帰防止」要件を撤去する（REMOVED）
- [x] 6.2 逐次ループ内 🔴 で「マージ / スキップ / 破棄」3 択、Dirty 同時・detached HEAD 時はマージ除外 2 択 + 理由明示を定義する
- [x] 6.3 マージ実行を MAIN_BRANCH チェックアウト下の `git merge --no-ff -m "merge: integrate <branch> (wt-clean active merge)"` で行う処理を移植する
- [x] 6.4 MAIN_BRANCH 以外チェックアウト中 / `.git/MERGE_HEAD` 存在時はマージ処理を中断し案内する事前確認を移植する
- [x] 6.5 競合時は `git merge --abort` を自動実行せず中断、先行処理済み（削除確定）は巻き戻さず、以降の TARGETS は未処理とする挙動を定義する

## 7. マージ都度サニティチェック（wt-clean-merge-active delta）

- [x] 7.1 テストコマンド自動検出（package.json / Cargo.toml / pyproject / go.mod、未検出は skip）を移植する
- [x] 7.2 マージ成功直後にそのマージ分のサニティチェックを実行し、PASS → 通常削除、FAIL → 当該保留＋失敗コマンド/エラー抜粋表示、とする（バッチ実行・`MERGED_BRANCHES` 方式は廃止）
- [x] 7.3 `--keep` 指定でもマージを伴う処理は通常削除側に流し、レポートに理由併記する

## 8. --keep / --no-sync の統合（wt-clean-reuse / wt-clean-remote-sync delta）

- [x] 8.1 Step 0 Sync を「対象選択・遅延診断より前」に位置づけ、パス指定時も実行（`--no-sync` で停止）するよう接続する
- [x] 8.2 `--keep` の 🟢 Safe 再利用化（main 切替＋元ブランチ削除、untracked 保持、重複チェックアウト競合検知）を逐次ループ 5.3 に移植する
- [x] 8.3 マージを伴わない 🟢 再利用化・🟡 削除ではサニティチェックを走らせないことを明記する
- [x] 8.4 再利用化対象 0 件でもエラーにせず継続することを維持する

## 9. 完了レポート

- [x] 9.1 レポート冒頭に Step 0 同期結果 1 行（pulled / up-to-date / skipped 各表記）を表示する
- [x] 9.2 処理（削除/再利用化）・スキップ・保留・残存 worktree 件数を区別表示する
- [x] 9.3 🔴 マージ結果（通常成功 / --keep マージ後通常削除 / サニティ FAIL 保留 / 競合中断 + 未処理）の各表記を定義する

## 10. 配布反映

- [x] 10.1 §1.2 の方針に従い `commands/wt-clean.md` を同期 or 参照化する
- [x] 10.2 `SKILL.md` frontmatter の version と plugin.json のバージョンを更新する（marketplace キャッシュ反映のため）
- [x] 10.3 SKILL.md description / オプション節を新フロー（パス指定・選択ベース・一括モード廃止）に合わせて更新する

## 11. 検証

- [x] 11.1 `openspec validate wt-clean-selective-ops --strict` が通ることを確認する
- [x] 11.2 各 spec の Scenario（パス指定 / ブランチ逆引き / 0・複数件エラー / 遅延リスト / 入口 3 択 / 個別バッチ / i/N 逐次 / 🔴 都度マージ→サニティ / 競合中断 / --keep 再利用化 / Step 0 同期）を SKILL.md 記述と突き合わせ、抜けがないか確認する
- [x] 11.3 BREAKING（一括モード廃止）が CLAUDE.md / README など利用者向けドキュメントの記述と矛盾しないか確認し、必要なら追記する
