## 1. テストを先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` の既存の `--command` の期待値（`cld --model 'opus'`・`cld --model 'opus[1m]'`・`cld-account b --model 'opus'`）を `EPIC_DISPATCH_PARENT_EPIC=<epic> ` の前置き付きに直す。スクリプトを走らせるテストで外の環境の `EPIC_DISPATCH_PARENT_EPIC` が漏れないよう、`setup` で `unset EPIC_DISPATCH_PARENT_EPIC` する
- [x] 1.2 launch のテストを足す: 端末を作れなかった子の stderr の作り直しのコマンドが `--command 'EPIC_DISPATCH_PARENT_EPIC=420 ` を含む（`grep -qF --` で開きの単一引用符ごと確かめる）
- [x] 1.3 route のテストを足す: `EPIC_DISPATCH_PARENT_EPIC=420` で Orca 管理下・子 2 件なら `nested` で exit 0 かつ orca が呼ばれない／同じ環境で `'#11'` は使い方を出して exit 1
- [x] 1.4 launch のテストを足す: `EPIC_DISPATCH_PARENT_EPIC=420` で `launch 460 11 12` は exit 1・stdout 空・`orca` と `git` の呼び出しが 0 件・stderr に `420` を含む
- [x] 1.5 SKILL.md のテストを足す: 「エピックの扱い」に `sub_issues_summary`・`後で別に起動するエピック:`・`nested` が書かれ、完了報告に載せる旨がある／`timeout` と `後で別に起動するエピック:` が同じ行にある（既存の「skill: Orca route reacts to closed, timeout and error」と同じ `grep -F … | grep -qF …` の形）／`launch` の拒否を `nested` と同じに扱い「親ワークツリーで開き直す」と報告しない旨がある
- [x] 1.6 `bats plugins/dev-workflow/tests/epic-dispatch.bats` で新しいテストと直したテストが落ちることを確かめる

## 2. 実装（Green）

- [x] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` の `cmd_route` で、子の番号の検査のあと `EPIC_DISPATCH_PARENT_EPIC` が空でなければ `nested` を出して exit 0（既存の判定より前）
- [x] 2.2 `cmd_launch` で、引数と環境変数の検査のあと・`orca` の有無の確認より前に、`EPIC_DISPATCH_PARENT_EPIC` が空でなければ stderr に理由を出して exit 1。`agent_cmd` を `EPIC_DISPATCH_PARENT_EPIC=$epic $claude_cmd --model <shq した model>` にする
- [x] 2.3 同ファイル先頭コメントの route / launch の説明に `nested`・前置き・拒否を足す（既存の行の並べ替えや言い回しの整理はしない）
- [x] 2.4 `bats plugins/dev-workflow/tests/epic-dispatch.bats` が全件通ることを確かめる

## 3. 文書と記録

- [x] 3.1 `plugins/dev-workflow/skills/develop/SKILL.md`「エピックの扱い」の回し方に、sub-issue を持つ子を外すこと（`sub_issues_summary.total` の `null` や空は 0 とみなす・コメントは `route` のあと・再開時も同じ）、`nested` を受けたセッションの止まり方（`launch` が展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない）、Orca 経路の `timeout` と `closed` の確認で `後で別に起動するエピック:` の子を外すこと、完了条件に完了報告へ番号を載せることと親エピックを閉じないことを足す。既存の文は書き換えず、足す文だけにする
- [x] 3.2 `plugins/dev-workflow/changes/460.md` に変更記録を書く（既存の changes/ の書式）
- [x] 3.3 `scripts/test.sh` と `scripts/lint.sh` を全件フォアグラウンドで流して通ることを確かめる

## 4. 実機確認

- [x] 4.1 `orca terminal create --command "EPIC_DISPATCH_PARENT_EPIC=<番号> cld --model 'haiku'"` で使い捨てのワークツリーに子セッションを起こし、そのセッションの Bash から `echo "${EPIC_DISPATCH_PARENT_EPIC:-unset}"` が番号を返すこと、そのセッションで `epic-dispatch.sh route 1 2` が `nested` を返すことを確かめる。作った端末とワークツリーは確かめてから片付ける（`launch` 本体は親ワークツリーの linkedIssue を書き換えるため実機では流さない）
