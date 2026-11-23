## 1. reply の自動判定

- [x] 1.1 `cmd_reply` で明示 --relaunch の有無を分け、指定なしでは子の記録の worktree・stop_uuid を使って既存 decide_relaunch の結果を渡す。自動判定用の閾値を wait --resolve と同じ規則で検査し、共通の送信処理の not-stopped 抑止は残す。bats の両送り手の 149999/150000/150001・短時間/3600 秒以上・計測不能・閾値上書き/不正値・明示 --relaunch・再開済みの fixture を追加して確認する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1069-1090（cmd_reply）、plugins/dev-workflow/scripts/epic-dispatch.sh:1295-1338（decide_relaunch、参照）、plugins/dev-workflow/scripts/epic-dispatch.sh:1913-1920（既存検査、参照）、plugins/dev-workflow/tests/epic-dispatch.bats:4550-4743（reply）、plugins/dev-workflow/tests/epic-dispatch.bats:5322-5470（put_transcript / resolve fixture）、plugins/dev-workflow/tests/epic-dispatch.bats:6818-6930（境界 fixture）
- [x] 1.2 reply-after-idle.md に両送り手の reply は --relaunch なしでも自動判定し、notify-closed は従来の手動分類のままと書く。script の先頭コメントと --help の relaunched の説明も更新し、既存の規則を確認する bats を自動判定の説明に合わせて通す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:1-5、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:49-75、plugins/dev-workflow/scripts/epic-dispatch.sh:140-150、plugins/dev-workflow/scripts/epic-dispatch.sh:222-228、plugins/dev-workflow/scripts/epic-dispatch.sh:304-310、plugins/dev-workflow/tests/epic-dispatch.bats:4371-4427

## 2. 完了だけを促す場面の手順

- [x] 2.1 epic-loop.md に「親だけで足りるのは既存の done または完了推定の条件を満たす子まで。停止中の子には足りない」と理由・既存経路の使い分けを記し、対象の子には終了だけの reply を省くと書く。文面を確認する bats を追加し、既存の notify-closed・完了推定・reap の条件のテストも通す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:71-75（通常進行 2〜4）、plugins/dev-workflow/tests/epic-dispatch.bats:5177-5224（notify-closed / inferred done の文面検査）
- [x] 2.2 変更記録に reply の自動判定と、やること 2 の「全対象には足りない」の理由・適用できる既存経路を記す。issue の仕様化判断コメント URL を示し、テスト結果と実機の費用削減の実証を区別して記載する。成果物の文面と issue の結論が一致することを確認する。触る範囲: plugins/dev-workflow/changes/1742.md（新規）

## 3. 統合確認

- [x] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `openspec validate auto-relaunch-epic-reply --type change --strict` を実行する。両送り手、Orca/tmux、wait --resolve、notify-closed、not-stopped、完了推定、reap の既存契約が通ることを確認し、コマンドと終了コードを記録する。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1-8997（実行）、openspec/changes/auto-relaunch-epic-reply/tasks.md:1-22（完了記録）

## Workflow follow-up

- R1 の APPROVE が記録先 #1742 に投稿されてから実装に進む。
- archive・PR の段では PR 本文に `Closes #1742` を書く。マージ・auto-merge はこの worker では行わない。
