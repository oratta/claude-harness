## Context

squash マージの repo では、子の HEAD は main の祖先にならない。安全確認の要は「マージ済み PR の先端と HEAD の完全一致」（失われるコミットが無い保証）で、これは変えない。

## Decisions

1. **照合は 2 段にし、2 段目は 1 段目で一致が無いときだけ呼ぶ。** 普通の子は今と同じ `gh` 1 回で済む。2 段目は `gh pr list --state merged --search <HEAD sha> --json headRefOid`。GitHub の検索は、PR に含まれるコミットの SHA でも引ける。最終判定は `headRefOid` と HEAD の完全一致で、検索が余計な PR を返しても一致しなければ通らない。
   - 代案: 1 段目をやめて SHA 検索だけにする。検索の索引が遅れると、今通る子が通らなくなる退行になるので採らない。
   - 代案: 子の HEAD が main の祖先かで判定する。squash では効かない。
2. **1 段目に出力があるが一致しない場合も 2 段目へ進む。** 同じブランチ名を使い回した古い PR だけが 1 段目に出る場合でも、HEAD を持つ別名の PR を拾えるようにするため。最終的に一致が無ければ、両段とも空なら `no-merged-pr`、どちらかに出力があれば `head-mismatch`。
3. **端末の片付けの失敗は理由を分けるだけで、`--force` も再試行もしない。** `--force` は Orca の端末の確認だけでなく git の未コミット変更の保護も外す。失敗はアプリの再起動で直る見込みなので、親がエピックに「Orca を再起動してから reap をやり直す」と書けるよう、理由 `rm-failed-terminal-sweep` を返す。判定は rm の stderr を一時ファイルに取り、`terminal sweep failed` を含むかを `grep -F` で見る。stderr は取ったあと従来どおり親の stderr に流す。

## Risks

- 検索の索引の遅れ: マージ直後は 2 段目が空になりうるが、その場合は `kept` で残るだけで、あとで `reap` をやり直せる（消す側には倒れない）。
- `terminal sweep failed` の文言が Orca の更新で変わると、`rm-failed` に戻る。消す側には倒れない。
