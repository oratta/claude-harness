# 手動Codex provider adapter

これは `skills/develop/SKILL.md` のprovider操作の差分。工程順、仕様化判断、レビュー回数、テスト、PR宣言、ゲート条件の正本はdevelopとrolesのまま。本体はClaudeで工程管理だけを行う。

## 起動

`/dev-workflow:develop --executor codex --account NAME --model MODEL <issue URLまたは依頼>`

既存登録accountを指定する。`docs/codex-develop.md` に導入方法を示す。人間の手動入口専用で、burn窓やcron/tickを要求しない。workerの認証・利用上限・権限拒否はそのまま停止理由とする。Codexが使えないときClaudeで代行しない。

## 本体が行う操作

1. develop入口0で記録先を確定し、対象repoのOrca等のルールで専用worktreeを用意する。CLIツール自身はworktreeを作らない。
2. `codex-develop.py --run-dir <private-run-dir> init --account NAME --model MODEL --cwd <worktree-root> --worker-state <private-worker-dir>`。一度開始したrunのaccount/modelを変更しない。秘密情報を依頼ファイルへ入れない。
3. 正本が次に呼ぶ役割と工程を決定し、その工程に限定した指示をUTF-8ファイルに書く。依頼・完了条件・記録先URL・対象artifact・固定HEADを渡す。実装者の会話履歴をレビューへ渡さない。
4. `... dispatch --phase PHASE --input <file>`。戻りのjob_idを記録し、`... status` / `... result` で回収。コマンド待機を終えてもworkerは動き続ける。不明な結果は再実行せず同じrunで照会する。
5. terminal結果を読み、`... ack` でworkerのcwd lockを解放する。ackは品質承認ではない。正本の判断記録・APPROVE・verify・ゲート条件を確認して次のphaseへ進む。unknownはack不可。cancel後も終了確認する。

| 正本の委譲箇所 | phase | Codex role |
|---|---|---|
| W: 仕様化判断・仕様作成・仕様差戻し | spec | spec-write |
| R1: 独立仕様レビュー・再レビュー | spec-review | spec-review（read-only） |
| W: 実装・TDD・verify・修正 | implement | implement |
| W: archive・Draft PR・仕様宣言 | finish | implement |
| G: ゲートの照合・記録 | gate | implement |
| Gが必要とする独立PRレビュー | review | impl-review（read-only） |
| 判断側の修正方針・decider | decider | decider（read-only） |

毎回fresh thread。Claude専用`subagent-context.sh`や150K閾値は使わない。前工程の成果物と必要な要約だけを引き継ぐ。live steering/resumeは初版では使わない。書込担当が終了・ack済みになってから別担当を起こす。

## 品質とhook差分

- レビュー対象の固定と承認の有効範囲は既存の仕様レビュアー/ゲート正本に従う。本体が対象artifact・HEAD等の必要情報を指示に渡す。adapter自身に別の承認条件を設けない。
- read-only reviewerはGitHubコメントを書かない。本体が既存正本の書式で結果を代理投稿する。投稿成功前に後続実装/完了扱いしない。
- Gが通常経路の`codex exec`/companion/Claude reviewerを呼ぶ場面では、実行せず`needs-reviewer`を返す。本体が`review`で新threadを作り、その結果を新しいGへ渡す。ゲート正本の着手確認・同一PR/HEAD重複防止を先に実施する。
- 仕様化が必要と判断された場合のopsx Skill操作は対象repoのopenspec CLI相当へ変換する。CLI不在時の仕様化判断も既存develop正本に従う。正本の仕様フォーマットを別テンプレートへ写さない。
- Claude hooksはCodexには自動適用されない。対象repoで必須の検査コマンドを本体が確認し、W/Gの指示と結果へ明記する。実行不能なら合格扱いしない。workerのread-only sandbox以外のhook保証をあるものと推定しない。
- worker completedは実行完了だけ。既存developがその経路に要求する仕様承認・テスト証拠・独立レビュー・ゲート条件を省略しない。merge/auto-mergeは禁止。途中停止は成果物とジョブ状態を記録する。

従来モードのexecレビューは維持するが、このモードの全委譲箇所は上表に集約する。burn接続・全account配分・使用量集計は別issue。

phaseは担当する役割の指示書を選ぶラベルであり、adapterは工程順序や品質承認を制御しない。`spec` は仕様化判断を含む。正本に従いWが「仕様化判断: しない」と理由を返した場合、本体は既存developの実装工程へ進む。Codex指定を理由に仕様を必須化しない。仕様が必要な場合は正本のR1承認条件を適用する。

仕様要否、レビュー判定、必須検査、archive、差戻し、次工程への進行はすべて既存developとrolesの正本で管理する。adapterに承認記録・検査実行・archive移動の独自コマンドは置かない。run履歴は輸送結果の記録であり、品質台帳ではない。workerの最終回答とerror_kindを本体が確認し、失敗や途中commentaryを承認扱いしない。

共通workerはnetwork無効。W/Gが必要とするGitHub情報の取得・コメント/ラベル・Draft PR作成・pushは `needs-coordinator` と具体的な操作/内容を返し、本体が既存の認可範囲で代理実行する。sandboxがgit commitを拒否した場合も本体が差分を確認してcommitする。これは運搬/記録の代理であり、仕様・コードの編集やレビュー判定を本体が代行するものではない。Gへは操作結果の証拠を渡して確認させる。

worker-state既定値は `$HOME/.local/state/claude-harness-codex/jobs`（registerと共通）。`--worker-state DIR` 指定時はその台帳だけを使う。新規run-dir省略時はinitが `$HOME/.local/state/claude-harness-codex/runs/<UUID>` を作成しJSONで返す。本体がこのpathを記録して全後続操作に渡す。既存`--run-dir`の再開時はinitせずrun.jsonのaccount/model/worker_stateとの一致を確認する。不一致や不明なrunを別accountで継続しない。

旧版run.jsonの `spec_paths` / `checks` / `approvals` は再開時に品質判断として使わない。旧pendingがあれば新promptで再submitせずresult→ackで受領を終えてから新dispatchする。`completed` でもerror_kindがあれば実行成功ではない。ackは結果受領とownership解放であり、品質承認ではない。

### 送信到達が不明なpendingの復旧

結果が存在するpendingは `status` / `result` で回収し、terminal結果を受領して `ack` する。送信前の失敗や応答切断でworkerへ到達したか不明なら、同じrunに `retry` を実行する。`retry` は保存済みrequest.jsonのrequest_id/account/model/cwdとrunの一致を検証し、**元の依頼を変更せず**workerへidempotent submitする。promptを再生成せず、新しいrequest_idも作らない。不一致やファイル欠損なら拒否し、別account・別依頼へ差し替えない。

```sh
python3 <plugin>/scripts/codex-develop.py --run-dir <保存したrun-dir> retry
```

旧版の品質metadataは無視するが、pendingとownershipは引き継ぐ。retryは結果不明の仕事を別ジョブとしてやり直す機能ではなく、同一依頼の送信/照会を復旧するtransport操作である。
