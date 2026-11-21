# Tasks

実装予定は `plugins/dev-workflow/` 配下の次の5ファイルに限定する: `scripts/epic-child-state.sh`（新規）、`hooks/hooks.json`、`tests/epic-child-state.bats`（新規）、`skills/develop/references/epic-child-stop.md`、`scripts/epic-dispatch.sh`。ターン固有の処理は新規スクリプトに置き、`epic-state.sh` の汎用関数と `owner-message-number-check.sh` は変更せず再利用する。行番号は修正時の HEAD `9c8b841d` の案内であり、編集前に該当範囲を読み直す。既存テストの期待値は変えない。6ファイル目が必要なら実装を増やさず本体へ返す。

## 1. 入力受付と任意拡張

- [x] 1.1 `turn_input` / `turn_state` の子側用の型検査と、ロック内で再読して世代・入力・未終了状態を一括保存する処理を新規スクリプトに作る。`epic-state.sh` を source して既存の検索・読み取り・排他更新関数を再利用し、同ファイルは編集しない。既存の記録検証は拡張の有無や不正で失敗させない。新規 bats の `input` 系ケースで初回・連続入力・同秒・新セッション・未知項目保持・旧記録互換を検証する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 1.2 新規入口に UserPromptSubmit の対象限定と送り手分類を実装する。予約文は既存 `child-log-read.py --keepalive-text` を読み取りで再利用し、初回の起動形・別repo・再起動時の埋込返事・親経由の主の返事・引用を区別する。`input` / `scope` / `keepalive` 系 bats で3送り手・受付時刻・対象外の無出力と無変更を確かめる。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 1.3 入力受付の契約を子の文書に記し、通常入力で旧状態が無効になること、送り手は権限の証明でないこと、予約文では元の入力と時刻を保つことを説明する。`input` / `keepalive` 系 bats に文書の契約の確認も含める。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:1-35（読む場面・声かけ・親から届いた返事）、plugins/dev-workflow/tests/epic-child-state.bats（新規）

## 2. Stop の検査と世代の照合

- [x] 2.1 状態行を最終非空行から検査し、3値・中身・時刻を同一世代で保存する。欠落・不正・空の中身・引用/コード内の例・後続文を block し、`stop_hook_active=true` でも再検査する。`stop` 系 bats で欠落・不正が修正要求となること、未修正の再停止も拒否すること、修正後と3値の保存を確かめる。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 2.2 payload のログと入力時のバイト境界で現在の発言を対応付け、保存時にセッション・世代・境界を再照合する。`generation` 系 bats に Stop の読み取りと保存の間の新入力、読み取り前に届いた新入力、同文の過去発言、前セッションからの遅い Stop を含め、新世代を上書きしないことを確かめる。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 2.3 対象の子の入力未記録・拡張不正・読めないログ・複数一致・ロック/保存失敗を、入力受付は exit 2、現在ターンの Stop は block の理由付きで扱う。`failure` 系 bats で元の JSON・親の停止情報と残留ロックを保持し、通常入力の送り直しの案内を検証する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 2.4 声かけの入力に対応する Stop を検査・保存の対象外にし、正常一行と逸脱応答の両方で元のターン情報を保つ。`keepalive` 系 bats で予約文の完全一致、主が同文を送った場合、1文字違う通常入力を確認する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 2.5 子の文書を毎ターンの状態行の形へ書き換え、定型の `止まった理由:` と見込み3行のあとに状態行を置く。依存待ちの成功を作業報告、主の操作が必要な失敗を主の返事待ちとして例示し、声かけの一行の例外・既存の停止コメントの条件・本文での質問を保つ。新規 bats の `docs` 系と既存 `epic-child-no-ask-tool` で確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:1-57（子の通常ターン・依存待ち・定型の止まり・記録の形）、plugins/dev-workflow/tests/epic-child-state.bats（新規）

- [x] 2.6 Stop の共通入口から既存 `owner-message-number-check.sh` を同じ payload で1回呼び、block の結果を保存前に反映する。通常ターンの拒否では現在の世代・セッション・境界をロック内で照合し、同じ入力の状態を `null` に戻す。`stop-owner` 系 bats に実物の既存スクリプトとの組み合わせを含め、`#1670 の対応を進めますか？` と正しい状態行でも block・未終了となること、番号と URL を修正した新発言の再停止で同じ世代にだけ保存されること、状態行不正の再停止は免除されないことを確認する。既存状態の無効化、無効化失敗時の block と理由、拒否処理中の新入力を上書きしないことも検証する。既存 Stop の1回限定・解除設定・fail-soft、対象外セッションの既存出力・終了コード、予約文の旧状態維持も比較する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh（新規）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 2.7 `resolve_stopped` の依存待ちの末尾判定だけを変更する。旧形式の最後の非空行、または有効な最終状態行の直前の非空行がマーカーなら既存どおり停止を保つ。状態行の構文は Stop と同じ条件にし、本文検索や状態記録による判定は足さない。新規 bats の `dependency-wait` 系で実際の `wait --watch-stopped --resolve` を通し、旧形式・新形式・末尾空白/CR のいずれも自動判断未呼出・送信なし・`stopped <N>`・exit 0・停止記録維持となることを確認する。マーカー無しの通常報告と、マーカー後に別文章・不正な状態行・複数の状態行がある例は従来の自動判断経路に渡ることも確認する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1418-1427（依存待ちマーカーの判定）、plugins/dev-workflow/tests/epic-child-state.bats（新規）

## 3. フックの接続と全体確認

- [x] 3.1 UserPromptSubmit に新規スクリプトを追加し、Stop の既存登録を新規スクリプトの共通入口に置き換え、timeout を30秒にする。既存 Stop を別 hook として重複登録しない。SubagentStop と SessionStart は対象に追加しない。`hooks` 系 bats で登録コマンドとイベント経路を通して、一般セッションでは既存 Stop の振る舞いを保ちターン情報に触れないこと、既存 Stop が1回だけ呼ばれること、対象の子では状態行の欠落が block になることを確認する。触る範囲: plugins/dev-workflow/hooks/hooks.json:32-49（入力フック）・149-158（Stop）、plugins/dev-workflow/tests/epic-child-state.bats（新規）
- [x] 3.2 `scripts/test.sh epic-child-state epic-child-no-ask-tool epic-stop-from-log-scenario epic-dispatch` と `openspec validate epic-child-turn-state --type change --strict` を実行し exit 0 を確認する。bats の HOME・EPIC_STATE_ROOT・会話ログは一時領域に隔離し、実際のセッションやホームに書かない。既存の親テストの期待値を変更せず、親への送信や端末操作の新規呼び出しが無いこと、`epic-state.sh` と既存 Stop が無変更であることを確認する。入力検査の守備範囲で通してよい「意味は実作業と不一致だが形式は正しい状態行」「主が直接送った予約文」も fixture に含める。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats（新規。結合確認の対象は実装予定5ファイル全体）

## Workflow follow-up

- この spec 工程で実装しない。artifact の commit・push 後は本体が R1 の仕様レビューを依頼する。APPROVE が記録先にあることを確認してから実装工程に進む。
- 実装後の verify・archive・PR の遷移は本体の canonical develop 手順に従う。依存待ち判定の互換変更を越える親側の #1744 と、時間による知らせの #1745 はこの tasks に追加しない。
