# 初版契約

入口: `python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir <private-dir> <command>`。全stdoutはJSON。成功0、拒否2。

- register --account NAME --codex-home PATH: 既存profileを登録。tokenを複製せずパス・auth hash・identity hashを記録。account/readで起動時照合。メールclaimは署名検証ではなくprofile対応確認。
- submit --request FILE: request_id,origin=manual,account,cwd,model,role,promptを必須とする。戻りjob_id,status。request_idはジョブID。同一ID同一入力は再受付せず既存結果。同一ID異なる入力は拒否。
- status/result/cancel/ack --job ID。result.textは最終agentMessage。完了通知に無ければthread/readで回収。usage欠落はnull。
- send --job ID --request FILE: 初版unsupported。同thread context計測未確立のため、完了回収→ack→新IDで差戻しのfresh担当を作る。

SQLiteのBEGIN IMMEDIATEで受付とcwd/account排他を直列化。別state-dirにも共通所有台帳を適用し、前のjobが確認済terminalかつack済みになるまで引き継がない。台帳は0700ディレクトリ内0600。workerはstart_new_sessionで親から独立。親poller終了でworkerを終了しない。worker heartbeat消失はunknown、再投入・ack不可。terminalを観測し結果を回収後、呼び出し元のackでロックを解放。worker自動復活は行わずunknownを保持する。

cwdは所有者一致・git linked worktreeのroot・main/master以外の明示branchを要求。implement/spec-writeはworkspace-write、review/spec-review/impl-review/deciderはread-only。modelとapprovalPolicy=neverを明示。App Serverはprivate runtime CODEX_HOMEで起動し、auth.jsonだけ登録profileへのsymlinkを使う。既存brokerへ接続しない。元profileの外部MCP/app/plugin設定を継承せず、project/ancestor configは初版拒否。runtimeのauth symlinkまたはrefresh置換fileは終了時削除する。モデルの指示順守だけをread-only保証にしない。

既存companion 1.0.6はApp Serverとbrokerを既に持つ。しかし、要求するaccount/cwd排他・unknown保持・認証固定をそのまま保証できると未確認なので、初版は最小transportのみ実装する。#705で実証したinitialize/turn/interrupt/result回収契約を参照した。#705実験スクリプト自体を本番workerとして流用しない。

手動はバーンの開始時間を適用しない。fresh account/rateLimits/readでcodex枠の適用窓が欠落/不正/上限到達ならturnを開始しない。リセットチケットは消費しない。初版burnはunsupported。#706全体のburn共有予算・実行中steer・自動復旧は未完であり、本PRだけでissueを閉じない。

手動初期版の実行手順と制約: `plugins/dev-workflow/scripts/CODEX-WORKER.md`。基盤fake試験はモデルsandboxの実効性を実測した証拠ではない。実モデル・#707品質工程の統合確認は親作業で実施する。
