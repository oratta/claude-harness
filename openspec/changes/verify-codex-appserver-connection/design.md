# 接続PoCの設計と調査記録

## 状態と境界
仕様レビュー指摘反映後、承認を受け最小PoCを実施した。結果と未検証項目はRESULTS.mdを参照。認証切替、既存プロセスの中断は未実施。#705は接続成立と停止分類を確かめる小規模PoCまでで、#706の永続worker・排他・再起動復旧、#707の品質工程、#708のバーン判定は実装しない。手動・バーンは後続で同じApp Server入口を使い、execへの暗黙fallbackを持たない。

## 調査根拠（2026-09-17）
- Harness `plugins/dev-workflow/references/subagent-waiting.md` はexec直叩きとcompanion経由を区別。前景待ちは540000ms、3回上限で、companionは `waitTimedOut` と `job.status` による判定を要求する。exit codeだけで完了と扱わない。
- 同文書には2026-09-08のサブエージェント停止、09-09の完了マーカー誤認・companion待ち判定の過去記録がある。これはrepo内記録であり、今回報告された停止の生ログを再現・照合した証拠ではない。
- `_longruns/_archive/2026-05-13_codex-build-agent-eval/checkpoint.md` には165秒のexec完走記録がある。全CLI呼び出しが失敗するわけではない。
- ローカル配布物 `${CODEX_HOME}/plugins/cache/openai-codex/codex/1.0.6/scripts/codex-companion.mjs` は `runAppServerTurn` / `runAppServerReview` をimportする。`scripts/lib/codex.mjs` の `CodexAppServerClient.connect`、`scripts/lib/app-server.mjs` の `spawn("codex", ["app-server"])` とbroker接続から、**この版のcompanionは外側がCLIでも内部はApp Server**と確認した。Claude側が実際に解決する配布物の版・パスはPoC時に別途照合する。配布物は編集しない。
- `scripts/lib/codex.mjs` にはbroker unavailable/busy時にdirect App Server接続を試す経路がある。これはexec fallbackではないが、再利用・寿命・並列性が同じとは限らないためPoCの記録項目にする。
- ローカル `codex-cli 0.153.4` のhelpと生成schemaを確認。生成コマンドは `codex app-server generate-json-schema --out <一時ディレクトリ>`。生成はモデルを呼ばない。
- 公式資料: https://learn.chatgpt.com/docs/app-server 。実際に試す版の生成schemaを契約確認の基準とする。

**結論:** 「CLIだから止まる」「App Server化すれば直る」は未立証。exec直叩き、companion外側の待機、内部App Server、親エージェントの待機／再開を分けて評価する。今回の停止に対応する生ログは未特定で、原因確定はPoC実装後の採取または既存ログの同定を待つ。

## 小さく試す構成
専用の使い捨てfixtureと固定アカウント一つ、明示モデル一つ、同時turn一つで実施する。認証情報は既存の承認されたprofileから解決し、秘密値をログに保存しない。profile名だけで実アカウント一致を仮定しない。`account/read` のaccountはnull/API key/ChatGPTを区別し、ChatGPTのemailはnullableでstable account IDが常に返る契約ではない。本人性を確認できなければ実行を止め、#699/#706へ未解決として渡す。

比較対象はexec直叩き・現在実際に使用されるcompanion・最小の直接App Server client。既存companionで必要契約を満たせるなら再利用候補にし、新workerを先に必須としない。各経路に同じ小さい入力・model/effort・cwd・sandboxを使い、設定差は記録する。既存本番jobを中断せず、PoC所有のthread/turn/processだけを操作する。

## 接続契約
1. clientを立ち上げ `initialize` 応答後に `initialized`。初回はstdio接続を基準にし、broker比較では接続先と実際のtransportを記録する。
2. `thread/start` にcwd、model、sandbox、approvalPolicyを明示し、応答threadIdを保存する。PoCはread-only fixtureで開始し、書込み品質の検証は#707に渡す。
3. `turn/start` 応答は受付にすぎない。request IDとthreadId/turnIdを相関し、進捗notification、最終item、`turn/completed` のstatusを別に保存する。
4. `thread/tokenUsage/updated` をthreadId/turnIdに結合する。`turn/completed` にusageが必ずあるとは扱わない。通知欠落は0ではなく不明。
5. 待ち期限到達は「完了」「失敗」「needs_input」ではない。attention_requiredとして生存状態を確認し、同一仕事を再送しない。
6. 中断は `turn/interrupt` を指定threadId/turnIdへ送る。応答だけで停止確定とせず、terminal状態まで観測する。完了との競合では観測した最終状態を採用する。確認できなければunknown、再送なし。
7. 切断後に実行状態を確認できない場合はunknownとする。再接続・永続復旧を実装したことにはせず、#706への必要条件として報告する。

## 検証計画（実施状況はRESULTS.md）
| ケース | 操作 | 合格条件 |
|---|---|---|
| 一件完走 | 小さいfixtureの要約 | 受付・相関付き進捗・最終結果・terminalを区別して記録 |
| 中断 | 実行中turnを明示中断 | 非競合の所有turnでinterruptedを最低1回実測。completed競合・unknownは中断能力の合格に数えない |
| 待ち期限 | client待ちを短くする | 実行失敗と混同せず同じjobを追跡、重複送信0 |
| 親の待機終了 | polling側を終了、所有server側を観測 | 子が継続するか終了するかを実測。継続保証が無ければ#706の要件 |
| transport切断 | PoC接続だけを切断 | 不明を完了扱いしない、再送0 |
| 認証・quotaエラー | fixture/mockで応答を注入 | timeoutと区別、別アカウント・execに逃がさない |
| server request | approval/input要求fixture | 未対応要求を明示して中断確認、無限待機しない |
| broker比較 | 実使用companionと直接接続 | transport、寿命、再利用差を記録。既存機能の二重実装判断を保留できる |

観測には相対時刻、request/thread/turn相関、transport、model、終了status、exit/signal、stderrの非秘密部分を残す。prompt全文・token・emailは公開PRに貼らない。traceはローカル保管、公開版はマスキングとfixture入力で再現可能にする。

## issueを閉じる条件と後続判断
仕様レビュー通過だけでは#705を閉じない。上表を実施し、各項目のpass/fail/未確認と再現手順を報告する。受付・進捗・結果・中断が実測できれば接続候補としてGo。切断後の不明を隠さず、本番寿命の不足は#706へ渡す。既存障害の原因が未特定ならそのまま記し、「解消済み」としない。接続基本契約に欠落があればNo-Go/条件付きGoを根拠付きで記録する。

中断能力の必須合格条件は、自然完了と競合しない所有turnに対するinterruptで、最終statusがinterruptedとなることを最低1回実測すること。completed競合・unknownの分類だけではGoにしない。
