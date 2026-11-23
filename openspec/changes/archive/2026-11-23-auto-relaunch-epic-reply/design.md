## Context

動機は proposal.md を参照。`cmd_reply` は明示の `--relaunch` だけを `deliver_reply` に渡している。`resolve_stopped` は記録の worktree と止まりの uuid を `decide_relaunch` に渡してから同じ送り方を呼ぶ。判定は本体のログを 1 本選び、会話量または最後の assistant の時刻で決める。共通の送り方は再開済みの子を検出して送らない。

## Goals / Non-Goals

**Goals:** `reply` の両送り手で既存判定を再利用し、呼び手が指定を忘れても同じ基準を当てる。issue のやること 2 に、現在の状態遷移に基づく結論を残す。

**Non-Goals:** 閾値やログの選び方の変更、子の停止検知の変更（#1744）、launcher の変更、親から done を強制する操作の追加、notify-closed の自動判定化、reap の安全条件の緩和。

## Decisions

### reply の入口で既存の判定を再利用する

`--relaunch` が無いとき、親の状態の記録から子を一意に特定できれば worktree と stop_uuid を読み、`decide_relaunch` の結果を既存の `deliver_reply` に渡す。一意に決まらない・読めないときは判定だけで成功にせず、従来の送信処理が既存のエラーを返す。送信直前の not-stopped 判定は残す。

`deliver_reply` 自体で自動判定する案は、共有している notify-closed の挙動まで広げるため採らない。wait --resolve は今の経路のままとし、閾値・本体ログの選び方・計測失敗時の扱いは複製しない。

自動判定を行う reply では、wait --resolve と同じく FORCE_TOKENS と IDLE_SEC を非負整数として端末操作前に検査する。明示の `--relaunch` では自動判定と追加の閾値検査を行わず、従来の強制起動し直しの挙動を保つ。旧 MIN_TOKENS は読まない。

### 親だけの片付けは既存条件で可能な子に限る

issue に結論を記録済み: https://github.com/oratta/claude-harness/issues/1742#issuecomment-7087835723 。全対象を賄うには足りない。reap は status=done が必須で、完了推定は status=running かつ止まりの印なし・ログあり・completed で閉じた時刻と最後の活動が各 1800 秒以上前という条件を持つ。waiting または停止中の子は推定されない。mark は現在の worktree に対応する自分の記録だけを更新する。

そのため既に done の子は reap、完了推定の対象になる子は wait --watch-done → done → reap とし、「終えて」だけの返事は省く。停止中の子は既存 notify-closed で完了報告と mark done を促す。PR がマージ済みという事実だけで done を強制する案は、完了報告と片付けへの既存の承認条件を変えるため採らない。この結論と理由・使い分けを epic-loop.md に追記する。

## Risks / Trade-offs

- ログを決められない子は自動起動し直しを選べない → 既存と同じく条件を確認できないときは通常の送り方へ戻す。明示の --relaunch は残す。
- 判定後に子が再開することがある → deliver_reply の送信直前の抑止を維持する。
- 完了を促すためだけに止まった子を起こす費用は残る → 安全条件を緩めず、この制限を手順書に明記する。費用削減の実測は今回の fixture テストで実証したと報告しない。

## Migration Plan

既存記録の移行は不要。R1 の承認後にテスト・実装・手順書を同一 PR に入れる。問題があればその変更を revert し、従来の明示 --relaunch と手動判定へ戻せる。
