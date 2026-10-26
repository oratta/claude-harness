# Proposal

## Why

親だけアイドル時のコンパクトを残しているが、比較すべき相手は長い会話の再読み込みではなく、issue の引き継ぎと develop 手順書を読む新しいセッションである。要約と手順書の再読み込みの両方を払う運用をやめ、親・子・単発の develop セッションで待機中のコンパクトを切る（#1385、OWNER の 2026-10-26 指示）。

## What Changes

- develop の開始で親・子を判定せず、その worktree の `.claude/settings.local.json` の `idleCompaction` だけを false にする。通常の自動コンパクトは維持し、ホームの設定に書かない。
- 専用の設定部品と入口の指示を追加する。既存設定を保ち、失敗を成功扱いしない。この PR の本文とリスク宣言で継続適用の範囲を示し、主のマージ承認（リスク宣言の許容）を一度受ける。承認後は新しい worktree も含む develop 開始で同じ操作を聞き直さず、範囲外の書き込みは従来どおり聖域承認を要する。
- `reply-after-idle.md` の親専用の閾値・compact 後なら続ける表・監視継続を根拠にする説明を置き換える。親も 60 分以上ならコメントから起動し直す。子の会話量・端末による既存の起動し直しは維持する。
- #1379 の wait 要件を変更し、60 分以上経過した親の起動し直しを timeout・通知・主の返事の処理より先に行う。60 分未満の timeout は子を調べず同じ wait を掛け直す。TTL による 3000 / 21600 秒の上限選択は維持し、待ちの費用の説明から idle compact 回避を現行の理由として取り除く。
- マージ後の実機確認を担当・時期・有効な観測条件付きで定義し、親・子の結果を #1385 に記録する。#1264 のアイドル閾値再集計は本変更の実機確認後に不要として閉じる提案を記録する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: develop 開始時の待機中コンパクトの無効化、親の再開規則、規則ファイルと epic の案内、実機検証記録。

## Impact

- 実装対象: `plugins/dev-workflow/scripts/develop-idle-compaction.py`（新規）、`skills/develop/SKILL.md`、`skills/develop/references/reply-after-idle.md` と `epic.md`（いずれも同 plugin 内）。対応する Bats と `plugins/dev-workflow/changes/1385.md` を追加・更新する。
- `epic-dispatch.sh` の子の `--settings '{"idleCompaction":false}'` は維持し、起動ロジックを変更しない。通常の compact 用の `develop-compact-reread.sh` と hooks の配線も維持する。
- Python 3、Bats、`idleCompaction` 対応の Claude Code が前提。途中の設定反映は実機で未確認であり、ファイルの書き込みだけで反映済みとは扱わない。
- 設定は worktree に残り、同じ worktree の他セッションにも効く。ユーザー設定・共有の `.claude/settings.json`・起動用シェルは変更しない。
- 単一 change: すべて develop の待機・再開という一つの capability に属し、適用方法の選択一つと既定済みの親の方針変更である。実機確認はマージ後の追跡であり、独立した capability の実装ではない。
- R1 差し戻し修正では dispatch HEAD `28b16803` に origin/main `1b203ef5`（#1379 を含む）を merge commit で取り込んだ。親の短い待ち直しと長時間後の再開の優先順位を同じ capability の MODIFIED 差分に記す。

## 継続適用の承認範囲（PR 本文・リスク宣言へ記載）

develop 開始時、現在の worktree の `.claude/settings.local.json` の `idleCompaction` だけを false にする。他の設定値は保持し、ホーム・共有設定には書かない。この操作は以後の develop 開始と新しい worktree にも継続適用する。設定が無ければ当該キーだけの local ファイルを作り、同じ worktree の他セッションにも残す。主のマージ承認（この範囲を明記したリスク宣言の許容）をこの範囲の承認として扱い、以後は聞かない。他キー・別ファイル・symlink 先への書き込みは承認に含まず、従来どおり聖域承認が必要である。現時点は承認待ちであり、仕様段階では実設定を変更しない。
