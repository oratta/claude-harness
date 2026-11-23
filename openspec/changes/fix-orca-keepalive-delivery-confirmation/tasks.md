# Tasks

## 1. 送信前の待機解除と送信後の到達確認の分離

- [x] 1.1 古い待機→既知完了→送信文エコー→新しい前景スピナー（別ケースで `esc to interrupt`）＋空欄の送信後 fixture を追加する。send は exit 0 かつ turn_started 無しとし、期待する `sent` / exit 0 が現行では落ちることを確認してから、送信後だけ履歴の待機解除結果を到達条件から外す。送信前二度・送信後一度の read、send 一度、create/close/wait/再送/入力消去無しも検査する。`bats --filter 'keepalive orca' plugins/dev-workflow/tests/epic-dispatch.bats` で確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:111-230（keepalive_screen_reason）、plugins/dev-workflow/scripts/epic-launch-orca.sh:233-268（cmd_keepalive）、plugins/dev-workflow/tests/epic-dispatch.bats:8133-8246（履歴 fixture）、plugins/dev-workflow/tests/epic-dispatch.bats:8274-8403（到達確認テスト）
- [x] 1.2 同じ待機→完了→エコーを送信前に置いた場合は `skipped unknown-state` / send 0回を維持する回帰を追加する。送信後は、エコーだけ/背景待機だけ/前景実行あり＋通常文字・複数行・薄字入力/非空 draft/枠なし・複数枠・未知フッター/dialog/非screen source/不正shape を個別に用意し、すべて `failed send` / exit 1、再送無しを確認する。send 非ゼロと入れ子の turn_started の既存テストを維持する。`bats --filter 'keepalive orca|launch:.*turn_started|launch:.*nested stages' plugins/dev-workflow/tests/epic-dispatch.bats` を通す。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:111-268、plugins/dev-workflow/tests/epic-dispatch.bats:8149-8246（送信前の履歴制約）、plugins/dev-workflow/tests/epic-dispatch.bats:8274-8505（送信後の否定ケース）、plugins/dev-workflow/tests/epic-dispatch.bats:8880-9040（既存分類 matrix）

## 2. 実機確認手順と制限の明記

- [x] 2.1 親向け手順に、背景エージェント待機の `skipped busy` は正しい非送信であること、別の会話15万トークン未満・前景の入力待ち・通常の声かけ条件を満たす子を選ぶこと、候補が無ければ実機確認未完了とすることを明記する。#1728 / #1732 への実機送信・返事・cache 利用の記録方法、生ログを repo に置かない制約も記し、同じ文書を読む bats の手順テストを追加して `bats --filter 'keepalive.*verification' plugins/dev-workflow/tests/epic-dispatch.bats` を通す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:1-18、plugins/dev-workflow/tests/epic-dispatch.bats:8405-8505（近傍へ手順テスト追加）、plugins/dev-workflow/changes/1752.md（新規）
- [x] 2.2 P2-F2 の非bypass未知フッターについて design の実測制限（10件すべてbypass・非bypass未確認）を手順と変更記録へ残す。実装時に自然に該当する実画面を観測できるなら読み取りのみで形を確認し、版・取得方法・観測結果を記録する。今回は認識を拡張せず、観測できなくてもその制限を明記して完了とする（非bypass対応済みとはしない）。未知フッターの送信前 send 0回と送信後 failed send の回帰は1.2で検査し、合成画面を実測と称さない。触る範囲: plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:1-18、plugins/dev-workflow/changes/1752.md（新規）

## 3. 統合検証

- [ ] 3.1 `bash -n plugins/dev-workflow/scripts/epic-launch-orca.sh`、`shellcheck --severity=warning plugins/dev-workflow/scripts/epic-launch-orca.sh`、`bats plugins/dev-workflow/tests/epic-dispatch.bats`、`openspec validate fix-orca-keepalive-delivery-confirmation --type change --strict` を実行し、各 exit 0 を確認する。tmux・起動/reply・dispatch の既存の出力や結果記録を壊していないことも既存統合テストで確認する。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:111-268、plugins/dev-workflow/tests/epic-dispatch.bats:1-9706（統合検証のみ）、openspec/changes/fix-orca-keepalive-delivery-confirmation/（artifact 検証のみ）

## Workflow follow-up

- 実装開始には独立仕様レビューの APPROVE が必要。本工程は仕様作成までであり、上の実装タスクは未実行。
- 工程 (3b) で archive・Draft PR・仕様宣言を行う。マージとauto-merge有効化はこの worker の対象外。
- マージ後の実機 send / cache は未確認。背景待機中の子を避け、通常の声かけ条件を満たす会話15万トークン未満・前景が入力待ちの子を選ぶ。候補が無ければ未完了を維持する。実機の識別子・会話量・入力待ちの根拠・send 結果・予約文への返事・その後の request の cache_read_input_tokens と会話量の比較を #1728 と #1732 に記録し、fixture の成功で代替しない。ログを保存するなら LLM_LOG_DIR を用い、未設定なら保存先を確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:1-18（手順参照）、GitHub issues #1728 / #1732（実機証拠の記録先）
