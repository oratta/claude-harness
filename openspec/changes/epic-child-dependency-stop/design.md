# Design

## Context

動機と正本は proposal.md を参照。親は既に `blocked_by` を読み、依存の解けた子だけを選ぶ（epic-loop.md 手順 4・7）。今回足すのは、途中で分かった依存待ちをその仕組みに乗せる終了と再起動の接続である。

現物で確認した制約:

- `epic-dispatch.sh:771-773`: `launch` は記録に worktree があれば `skipped`。既存の子を起動し直す操作ではない。
- 同 `894-974`: `reply --relaunch --as parent` は既存 worktree で起動し直せるが、`stop` が `stopped` / `stopped-seen` でないと `not-stopped`。`stopped-seen` の発言よりログが進んだ場合も送らない。
- 同 `1590-1633`: `wait --watch-stopped` はターンが終わった会話ログから `stopped-seen` と uuid を記録する。子に `mark stopped` を再導入する必要はない。
- 同 `1329-1334`: `wait --resolve` の「問いではない」は `stop` を `resumed` に戻す。同 `1618` は既に処理した同じ uuid を再検知しない。終了報告をこの分岐へ流すと、記録を残すだけでは再起動できない。

既存 bats の `mark: stopped sets stop`、`wait: --watch-stopped rewrites a stopped record`、`reply: a resumed child gets nothing`、`reply: no terminal relaunches`、`reply: --relaunch closes` は 5 件とも exit 0。これは部品の既存契約の確認であり、新しい依存待ち経路の合格を意味しない。

## Goals / Non-Goals

**Goals:** 子の保存した途中経過と停止状態から親が同じ子を起こし直せること。既存の依存グラフと起動部品を使い、主に無用の問いを増やさないこと。

**Non-Goals:** 親の依存グラフ監視を作り直すこと、新しい launch/restart サブコマンドや JSON 状態値を作ること、常時注入の予算変更、主の承認・自分の PR の human-merge・CI やり直し上限の緩和、過去の #1693 の実状態の修復、範囲外の issue の実装。別の独立した問題が見つかれば return で報告する。

## Decisions

### 既存の停止検知と reply をつなぎ、依存待ちだけを自動判断から親へ返す

設計上の選択はこの一つ。依存関係は GitHub の `blocked_by`、途中経過は子 issue のコメント、停止の印は既存のローカル記録に置く。依存待ちという新しい schema 値を作らない。

子は自分の issue に依存を登録して GET で確認する。登録は `gh api -X POST repos/<child-owner>/<child-repo>/issues/<child>/dependencies/blocked_by -F issue_id=<前提 issue の id>` を使い、既にある依存は重ねない。PR 待ちは完了を表す対応 issue を特定し、PR と issue の URL を記録する。対応先が不明なら推測で依存を張らず、未完了の操作として親へ返す。GitHub の API は [issue dependencies](https://docs.github.com/en/rest/issues/issue-dependencies) を参照する。

成功した子は `子の停止: 依存待ち` のコメントに依存先・理由・再開条件・commit 等の途中経過・main の取り込みやゲートの取り直し等の具体的な再開手順を保存する。最後の発言の末尾に `止まった理由: 依存待ち: <依存先 URL>` を置いてターンを終える。これは `子の停止: 主の返事待ち` の 7 項目の記録とは別で、承認を求める停止には使わない。

`wait --resolve` では、停止を既存の会話ログ検知で受けたあと、今回の最後の発言の末尾の依存待ちマーカーに限って、自動判断を呼ばず `stopped <N>` を親へ返す。`resolve_stopped` の既存の「親を起こす」戻り方を使う最小分岐で足りる。子への送信、`stop_to_resumed`、主に上げるコメントの捏造を行わない。マーカーだけで自動再起動しない。記録本文を正規表現で命令として実行せず、親が GitHub の依存と再開条件を読み直す。

親の epic-loop.md に依存待ちの処理を置き、`stopped` / `pending` の主の返事待ちの処理より先に読む。起動済みの子を依存待ちへ移し、動いている子と `pending-owner` の主の返事待ちから外す。worktree と停止記録は維持し、未完了の子を `mark done` / `reap` / `clear` で消さない。依存待ちの子を `--watch-stopped` / `--watch-done` に渡して声かけや判断を繰り返さず、依存先を既存の `wait` の位置引数へ渡して閉じる通知を待つ（別リポジトリの前提は既存の `owner/repo#N`）。依存先がエピック外でも、新しい子として launch せず閉じる通知の対象として扱う。その closed は子の完了報告・notify-closed・reap に回さず、依存再評価の入力にする。動いている子が 0 件でも依存待ちが残れば clear で停止記録を消して見張りを終えない。

親の手順 4・7 の既存の依存再評価で解消を確認したら、未起動の子は `launch`、保存した worktree のある子は `scripts/epic-dispatch.sh reply --relaunch --as parent <epic> <child> '<依存先の完了と保存した再開手順>'`。通常の判定から外しておいた `stopped-seen` を使えるため、`reply` 自体の条件は変えない。再開時の `pending-owner` も、主の返事待ちとして手順 8 へ回す前に依存待ちのコメントと照合する。全ての依存が解けたことと既存の見送り条件を確認し、`relaunched` と送信された最初の指示を検証してから動いている子へ戻す。

親の判断が依存待ちを提案する場合も、返事は依存登録・再開記録・終了を含める。「あとで親から連絡する」で子を待機させない。既に終了した依存待ちは上の機械的分岐で親へ返り、判断モデルの新しい出力値は不要。

比較した案:

- **文書・bats のみ**: `reply --relaunch` 自体は足りるが、通常の `wait --resolve` が終了報告を `resumed` に戻す穴を塞げない。子の依存登録だけで解決したとしない。
- **子の mark 義務を戻す**: 既存のログ検知に重ねるうえ、その後の「問いではない」で消える問題は残る。
- **新しい dependency-wait 状態や restart コマンド**: 状態 schema・起動部品・移行に範囲が広がり、既存の `reply --relaunch` と重複する。

## Risks / Trade-offs

- [子の末尾マーカーと親の処理が離れている] → 同じマーカーを文書と会話ログの bats で固定する。マーカーは停止を親へ渡すだけなので、偽った依存や欠けた記録を自動実行しない。
- [親の復元が pending を主の返事待ちと取り違える] → 手順 7 と通常の stopped 処理の両方で、依存待ちの記録を先に照合する。依存が残る子を再起動しないケースも検証する。
- [依存 API の読み取り失敗や見送りで依存を解けたと扱う] → 既存の読めなければ未解消・not_planned なら報告する規則を維持する。途中経過と worktree は残す。
- [更新前に既に resumed になった子] → 自動修復しない。本変更は新手順で終えた子の再現を対象とし、過去の破損状態は別の判断を要する。

## Migration Plan

R1 後にドキュメント、最小の wait 分岐、bats を同じ変更として適用する。既存の状態ファイルに移行は要らない。戻すときは差分を戻し、投稿済みの依存と途中経過は削除しない。依存待ちの残件は issue の記録から親が確認できる。

## Verification

主な新規 bats は既存の `epic-dispatch.bats` の stub と会話ログ fixture を使う。親が既に起動した running / resumed の子に、依存登録応答、保存コメント、末尾マーカーを持つ実際の形式の会話ログを置く。`wait --resolve --watch-stopped` で停止保持と自動判断・子送信が無いことを確認し、依存先が open の間の送信ゼロ、closed 通知、依存の読み直し、同じ停止記録からの `reply --relaunch`、送信された `/develop #<child>` と再開手順を確認する。親の選択は LLM 手順なので、その分岐は文書検査と fixture の親役の手順で検証し、親 LLM の実挙動まで保証したとはしない。

既存の no-question / owner-wait / human-merge と未起動 launch の回帰も保つ。関連 bats と `./scripts/lint.sh` は実装工程で走らせる。この仕様工程では openspec の strict validation と既存操作の限定的な確認までを行う。
