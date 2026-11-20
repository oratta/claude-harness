# Tasks

## 1. 現行の画面構造と入力欄の観測

- [x] 1.1 `result.terminal` の構造検査と任意の draft の扱いを直し、source が画面でない場合は unknown-state、構造が不正なら既存 stdout と stderr の `failed observe shape` を返す。read の欠落・型違い・不正 JSON・stream / screen-unavailable・任意の draft を網羅する回帰テストを同時に追加し、`bats --filter 'keepalive orca' plugins/dev-workflow/tests/epic-dispatch.bats` で確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:111-181（keepalive_screen_reason）、plugins/dev-workflow/scripts/epic-launch-orca.sh:186-204（観測の失敗処理）、plugins/dev-workflow/tests/epic-dispatch.bats:7834-7937（fixture と観測テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:8377-8492（分類 matrix）
- [x] 1.2 Orca fixture のヘルパー・直接書かれた応答・matrix を現行構造に統一する。`orca --version` と取得コマンドを添え、実際の `orca terminal read --terminal <handle> --screen --json` の出力を匿名化してテスト内へ貼った fixture を 1 件追加する。実測の bypass-permissions フッターと複数 statusline の入力枠を認識し、空欄・同一行/複数行/薄字の入力・busy・dialog・古いフッターの後のシェル・複数枠をテストする。`bats --filter 'keepalive orca' plugins/dev-workflow/tests/epic-dispatch.bats` が通り、実測例で空欄が ready、入力済みが input-not-empty、実行中が busy になることを確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:133-179（画面と入力領域の分類）、plugins/dev-workflow/tests/epic-dispatch.bats:7834-7949（実測 fixture と回帰テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:8290-8301（wait の直接 fixture）、plugins/dev-workflow/tests/epic-dispatch.bats:8377-8492（分類 matrix）

## 2. 送信の到達確認

- [x] 2.1 send 応答の現行構造を CLI ヘルプと実機確認の receipt に照合し、turn_started の検出が入れ子でも通ることをテストする。既存の検出で十分なら関数は変更しない。未確認時の見直しは現行 read を 1 回だけ使い、新しい前景の busy と入力枠全体 / 任意の draft の空欄の両方を必要とする。busy だけ、非空の入力/ draft、idle のまま、不正な送信後 read、send 非ゼロの各失敗、および再送・create/close/wait/入力消去をしないことをテストし、`bats --filter 'keepalive orca|launch:.*turn_started|launch:.*nested stages' plugins/dev-workflow/tests/epic-dispatch.bats` で確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:87-90（turn_started）、plugins/dev-workflow/scripts/epic-launch-orca.sh:111-217（空欄観測と cmd_keepalive）、plugins/dev-workflow/tests/epic-dispatch.bats:1296-1311（既存の stages テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:7846-7949（送信確認テスト）

## 3. 統合と実際の子への到達確認

- [x] 3.1 `bash -n plugins/dev-workflow/scripts/epic-launch-orca.sh`、`bats plugins/dev-workflow/tests/epic-dispatch.bats`、`openspec validate fix-orca-keepalive-observation --type change --strict` を実行し、全て exit 0 を確認する。送信失敗や形の不一致の診断が wait の従来の stdout / 終了理由を変えず、既存の tmux / 起動 / reply のテストも通ることを確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:87-217、plugins/dev-workflow/tests/epic-dispatch.bats:1-8932（統合検証のみ）
- [ ] 3.2 実際のエピックの会話 15 万トークン未満で停止中の子 1 件について、共通定義の固定文が一度届き、会話ログに固定文と `[child-cache-keepalive]` の予約された返事があり、次の request の `cache_read_input_tokens` が会話量とほぼ同じになることを検証する。子の識別子、時刻、read/send の構造、送信結果、ログの該当 uuid、input/cache_read/cache_creation の数値と比較対象の会話量を #1728 のコメントに記録する。実測した send receipt も匿名化して回帰テストへ反映し、`bats --filter 'keepalive orca' plugins/dev-workflow/tests/epic-dispatch.bats` が通ることを確認する。条件を満たす子やログが無ければ未完了のまま blockers として報告し、stub の成功で代えない。ログはリポジトリに保存しない。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:7846-7949（実測 send の回帰ケース）、openspec/changes/fix-orca-keepalive-observation/tasks.md（新規、検証結果のチェック更新。実機の証拠は issue #1728）

## Workflow follow-up

- 本体が別コンテキストの R1 を起こし、#1728 に仕様レビューの APPROVE が記録されてから実装する。
- 全工程では仕様 artifact 5 ファイルに加え実装 2 ファイルを予定する。実装段で追加のファイル変更や範囲拡大が必要なら、その段で本体へ報告する。
- archive・PR・仕様宣言は本体が指示する次の工程で行う。この仕様段では実装・merge を行わない。

## 実装段の検証範囲

- 1.1 / 1.2 / 2.1: 対象 bats の Red（exit 1、18/20 失敗）→ Green（exit 0、20/20 成功）を確認。1.2 の入力済み / busy は実測 read fixture からの派生ケースでも検証した。実機の自然な状態の観測結果は別途報告し、未観測の状態を実機確認済みとはしない。
- 2.1 の CLI ヘルプと入れ子 receipt の回帰テストは確認済み。実機 send receipt の採取・照合は送信禁止の指示に従い 3.2 とともにマージ後へ残す。
- 3.2 はマージ後に要確認。実装段では他の端末への send を行わない。

- 3.1: `bats plugins/dev-workflow/tests/epic-dispatch.bats tests/public-private-split.bats tests/injection-budget.bats` — exit 0、772/772 成功（epic-dispatch 636、public-private-split 50、injection-budget 86）。
- `bash -n plugins/dev-workflow/scripts/epic-launch-orca.sh` / `shellcheck --severity=warning plugins/dev-workflow/scripts/epic-launch-orca.sh` / `scripts/test-auto-merge-workflow.sh` / `openspec validate fix-orca-keepalive-observation --type change --strict` — 各 exit 0。不変条件は 145 件成功、actionlint も成功。
- CI の収集対象: ci.yml の lint（scripts/lint.sh、scripts/test-auto-merge-workflow.sh）と test（scripts/test.sh）。shellcheck は変更ファイルへ適用。全体 bats は CI の test matrix に委ねる。claude plugin validate は導入済みだが、この工程の Claude 起動禁止に従い未実行（成功とはしない）。
- 関係するテストの探索: `git grep -l -F -e plugins/dev-workflow/scripts/epic-launch-orca.sh -e epic-launch-orca.sh -e epic-dispatch.bats -e openspec/changes/fix-orca-keepalive-observation/tasks.md -- '*.bats'`。epic-dispatch.bats と public-private-split.bats が該当し、注入予算検査も加えて実行した。
- 実機: Orca 1.4.263、2026-11-21、`orca terminal read --terminal <handle> --screen --json` の実出力を同じ分類関数で読み取りのみ検査。term_1f430bf4-9e62-4302-b80c-4c803488562a（issue-1728）で read / 分類 exit 0、ready。ほかの既存端末も ready または unknown-state で、自然な入力済み / busy は観測できず未確認。状態を作るための入力・送信はしていない。
