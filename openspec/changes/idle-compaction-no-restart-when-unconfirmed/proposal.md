## Why

develop の開始時、worktree の `.claude/settings.local.json` を `--apply` で false にした直後は、起動後の apply だけなので、そのセッションの live な idleCompaction が off かどうかを機械では確認できない。現行の手順はこの場合に新しいセッションでの再起動を求める（interactive は主に確認、unmanned は停止）。しかし起きうる実害は待機中のコンパクト 1 回で、手順書の読み直しの仕組み（compact 後の再読み込み hook）で戻せる。再起動を毎回求める費用のほうが大きい（#1497）。

## What Changes

- 起動後の apply だけなど、機械確認で live の off を確かめられないとき、interactive / unmanned とも再起動を求めず、止まらずに進む。確認できなかったことは「未確認」として記録する
- 残すもの: 実効値が on と判明した場合の再起動と、再起動してもなお off を確認できない場合の開始停止／check exit 1（壊れた設定・symlink 等）と apply 失敗での開始停止／機械確認の範囲を超えて「live で off」と報告しないこと／親の 60 分待ち後の再起動
- 変えないもの: `develop-idle-compaction.py` の `--check` / `--apply` の動作、ホーム・共有設定に書かないこと

## Impact

- 仕様: `dev-workflow-develop` の要件「idle compaction の設定を確かめられなければ成功にしない」
- 手順書: `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`「開始時の設定」
- テスト: `develop-idle-compaction.bats`、`develop-skill.bats`
- 変更記録: `plugins/dev-workflow/changes/1497.md`
