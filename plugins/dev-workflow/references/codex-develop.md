# 手動Codex provider adapter

これは `skills/develop/SKILL.md` のprovider操作の差分。工程順、仕様化判断、レビュー回数、テスト、PR宣言、ゲート条件の正本はdevelopとrolesのまま。本体はClaudeで工程管理だけを行う。

## 起動

`/dev-workflow:develop --executor codex --account NAME --model MODEL <issue URLまたは依頼>`

既存登録accountを指定する。`docs/codex-develop.md` に導入方法を示す。人間の手動入口専用で、burn窓やcron/tickを要求しない。workerの認証・利用上限・権限拒否はそのまま停止理由とする。Codexが使えないときClaudeで代行しない。

## 本体が行う操作

1. develop入口0で記録先を確定し、対象repoのOrca等のルールで専用worktreeを用意する。CLIツール自身はworktreeを作らない。
2. `codex-develop.py --run-dir <private-run-dir> init --account NAME --model MODEL --cwd <worktree-root> --worker-state <private-worker-dir> --spec-path <仕様の相対path> --required-check '["実際の検証コマンド","引数"]' `。一度開始したrunのaccount/modelを変更しない。秘密情報を依頼ファイルへ入れない。
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

- spec-review前にWの仕様commitを確定し、review前に実装commitを確定する。本体がHEADを取得し入力に明示、回収時にも一致確認する。HEADが変われば承認を流用しない。
- read-only reviewerはGitHubコメントを書かない。本体が既存正本の書式で結果を代理投稿する。投稿成功前に後続実装/完了扱いしない。
- Gが通常経路の`codex exec`/companion/Claude reviewerを呼ぶ場面では、実行せず`needs-reviewer`を返す。本体が`review`で新threadを作り、その結果を新しいGへ渡す。ゲート正本の着手確認・同一PR/HEAD重複防止を先に実施する。
- opsx Skill操作は対象repoのopenspec CLI相当へ変換する。CLIがない/対応不明ならblocked。正本の仕様フォーマットを別テンプレートへ写さない。
- Claude hooksはCodexには自動適用されない。対象repoで必須の検査コマンドを本体が確認し、W/Gの指示と結果へ明記する。実行不能なら合格扱いしない。workerのread-only sandbox以外のhook保証をあるものと推定しない。
- worker completedは実行完了だけ。仕様APPROVE、テスト証拠、独立レビュー、ゲート合格を省略しない。merge/auto-mergeは禁止。途中停止は成果物とジョブ状態を記録する。

従来モードのexecレビューは維持するが、このモードの全委譲箇所は上表に集約する。burn接続・全account配分・使用量集計は別issue。

仕様レビュー結果は `仕様レビュー: APPROVE`、実装レビュー結果は `レビュー: APPROVE` を独立行で返すよう指示する。result→ackの後、`accept-review` がcompleted・レビューphase・固定HEAD・clean・仕様artifact hashを確認して承認を記録する。仕様の内容が変われば再レビューが必要。`--spec-path` は複数指定可でレビュー対象仕様を漏れなく指定する。実装前は仕様承認必須（初版は仕様省略経路なし）。

実装終了後は成果物をcommitし、`check` でinit時指定のrequired-checkを実行する。実コマンドのexit codeと出力を保存し、現在HEADで成功した証拠がなければfinish/gateを拒否する。required-checkは対象repoの必須検査を本体が選び、例示コマンドを無条件に流用しない。Codex sandboxでcommitできなければ本体が確認してcommitする。
