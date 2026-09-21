# 手動Codex provider adapter

これは `skills/develop/SKILL.md` のprovider操作の差分。工程順、仕様化判断、レビュー回数、テスト、PR宣言、ゲート条件の正本はdevelopとrolesのまま。本体はClaudeで工程管理だけを行う。

## 起動

`/dev-workflow:develop --executor codex --profile codex-standard <issue URLまたは依頼>`

外部設定は `--profile NAME --profile-file /absolute/profiles.json` とし、version 1、全canonical role、呼び出し側の対応表に載るaccountを必要とする。各roleの値は `{"executor":"codex","account":"spare","model":"MODEL","effort":"high"}` の形で、委譲のたびに解決して依頼ファイルへ固定する（runへのsnapshotは持たない）。

account名からCODEX_HOMEへの対応は呼び出し側の設定で与える。`--account-home NAME=PATH` の繰り返しか、account名をキー・CODEX_HOMEの絶対パスを値とする平らなJSON 1つを `--account-home-file PATH` で渡す。2つの与え方の併用は拒否し、合成も優先もしない。値が絶対パスでない、またはディレクトリとして存在しないときも拒否する。対応に無いaccount名は依頼ファイルを作らずに拒否し、既定や別のCODEX_HOMEへ倒さない。`docs/codex-develop.md` に導入方法を示す。人間の手動入口専用で、burn窓やcron/tickを要求しない。workerの認証・利用上限・権限拒否はそのまま停止理由とする。Codexが使えないときClaudeで代行しない。

## 本体が行う操作

develop入口0で記録先を確定し、対象repoのOrca等のルールで専用worktreeを用意する。CLIツール自身はworktreeを作らない。そのうえで、Claudeのサブエージェントと同じ3手順で委譲する。

1. **指示をファイルに書く。** 正本が次に呼ぶ役割と工程を決定し、その工程に限定した指示をUTF-8ファイルに書く。依頼・完了条件・記録先URL・対象artifact・固定HEADを渡す。実装者の会話履歴をレビューへ渡さない。秘密情報を依頼ファイルへ入れない。
2. **前景コマンドを背景実行で起動する。** 役割別のexecutor/account/model/effortとCODEX_HOMEを解決した依頼ファイルを作り、そのファイルを渡してworkerを起こす。2本目をBashツールの背景実行で走らせる。

   ```sh
   python3 <plugin>/scripts/codex-develop.py request --phase PHASE --input <指示ファイル> \
     --cwd <worktree-root> --profile NAME [--profile-file /absolute/profiles.json] \
     --account-home spare=/absolute/codex-home --out <依頼ファイル>
   python3 <plugin>/scripts/codex-worker.py run --request <依頼ファイル>
   ```

3. **完了通知で結果を読む。** 標準出力の1行JSON（`text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind`）を読む。成功はexit 0、失敗はexit 2。コマンドは1ターンで終わり、呼び出し元が消えれば自分も終わる。台帳もjob IDも残らないので、照会も受領も無い。同じ工程をもう一度やるときは、同じ手順を最初から繰り返す。

| 正本の委譲箇所 | phase | Codex role |
|---|---|---|
| W: 仕様化判断・仕様作成・仕様差戻し | spec | spec-write |
| R1: 独立仕様レビュー・再レビュー | spec-review | spec-review（read-only） |
| W: 実装・TDD・verify・修正 | implement | implement |
| W: archive・Draft PR・仕様宣言 | finish | implement |
| G: ゲートの照合・記録 | gate | implement |
| Gが必要とする独立PRレビュー | review | impl-review（read-only） |
| 判断側の修正方針・decider | decider | decider（read-only） |

毎回fresh thread。Claude専用`subagent-context.sh`や150K閾値は使わない。前工程の成果物と必要な要約だけを引き継ぐ。live steering/resumeは初版では使わない。書込担当が終わってから別担当を起こす。セッションをまたいで途中の委譲を引き継ぐ仕組みは持たないので、途切れたらその工程をやり直す。

## 品質とhook差分

- レビュー対象の固定と承認の有効範囲は既存の仕様レビュアー/ゲート正本に従う。本体が対象artifact・HEAD等の必要情報を指示に渡す。adapter自身に別の承認条件を設けない。
- read-only reviewerはGitHubコメントを書かない。本体が既存正本の書式で結果を代理投稿する。投稿成功前に後続実装/完了扱いしない。
- Gが通常経路の`codex exec`/companion/Claude reviewerを呼ぶ場面では、実行せず`needs-reviewer`を返す。本体が`review`で新threadを作り、その結果を新しいGへ渡す。ゲート正本の着手確認・同一PR/HEAD重複防止を先に実施する。
- 仕様化が必要と判断された場合のopsx Skill操作は対象repoのopenspec CLI相当へ変換する。CLI不在時の仕様化判断も既存develop正本に従う。正本の仕様フォーマットを別テンプレートへ写さない。
- Claude hooksはCodexには自動適用されない。対象repoで必須の検査コマンドを本体が確認し、W/Gの指示と結果へ明記する。実行不能なら合格扱いしない。read-only roleのreadOnly policy以外にsandboxによる保証は無い（書込担当は砂場なしで動く）ので、hook相当の保証があるものと推定しない。
- worker completedは実行完了だけ。既存developがその経路に要求する仕様承認・テスト証拠・独立レビュー・ゲート条件を省略しない。merge/auto-mergeは禁止。途中停止は成果物と結果JSONを記録する。

従来モードのexecレビューは維持するが、このモードの全委譲箇所は上表に集約する。burn接続・全account配分・使用量集計は別issue。

phaseは担当する役割の指示書を選ぶラベルであり、adapterは工程順序や品質承認を制御しない。`spec` は仕様化判断を含む。正本に従いWが「仕様化判断: しない」と理由を返した場合、本体は既存developの実装工程へ進む。Codex指定を理由に仕様を必須化しない。仕様が必要な場合は正本のR1承認条件を適用する。

仕様要否、レビュー判定、必須検査、archive、差戻し、次工程への進行はすべて既存developとrolesの正本で管理する。adapterに承認記録・検査実行・archive移動の独自コマンドは置かない。結果JSONは輸送結果の記録であり、品質台帳ではない。workerの最終回答とerror_kindを本体が確認し、失敗や途中commentaryを承認扱いしない。`completed` でもerror_kindがあれば実行成功ではない。

書込担当（implement / spec-write）は砂場なしで親の環境を引き継いで動くため、GitHub情報の取得・コメント・Draft PR作成・push・commitをworkerの中で自分で完了する。これらを `needs-coordinator` で本体へ回さない。本体が担うのは、read-only roleのレビュー結果の代理投稿と、揃えられなかった項目として記録済みの操作だけである。代理は運搬/記録の代理であり、仕様・コードの編集やレビュー判定を本体が代行するものではない。Gへは操作結果の証拠を渡して確認させる。

依頼ファイルには指示文と固定した実行先が入るため、私有ディレクトリに置く。workerは静的検証後、`thread/start`前に`model/list`の広告値でもmodel/effortを検証する。結果の公開`execution`は要求値と実効値・観測元を分けて載せ、実効値が未観測ならnullのままである（要求どおりだったと推測しない）。

台帳を持つ旧経路（`submit` / `status` / `result` / `reap`）の運用は `scripts/CODEX-WORKER.md` に残る。前景実行はその台帳を作らず読まないので、同時実行の枠管理も作業ディレクトリの排他も行わない。同じworktreeへ2本同時に投げないのは本体の責任である。
