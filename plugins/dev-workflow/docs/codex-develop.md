# 手動Codex開発を試す

#706 workerと#707入口を含むworktree版を使う。インストール済みプラグインは上書きしない。

```sh
claude --plugin-dir /absolute/path/to/harness-worktree/plugins/dev-workflow
```

利用するCodex認証profileは事前にログイン済みであること。認証を複製したり、通常profileを上書きしない。

前景実行は台帳を持たないので登録（`register`）は要らない。account名からCODEX_HOMEへの対応は、委譲のたびに引数で渡す。`--account-home NAME=PATH` の繰り返しか、account名をキー・CODEX_HOMEの絶対パスを値とする平らなJSON 1つを `--account-home-file PATH` で渡す。2つの与え方の併用は拒否し、合成も優先もしない。値が絶対パスでない、またはディレクトリとして存在しないときも拒否する。

台帳を持つ旧経路（`submit` / `status` / `result` / `ack` / `reap`）を使うときだけ、既存のCODEX_HOMEを登録する。`--state-dir` はサブコマンドの後ろに置く。

```sh
python3 /absolute/path/to/harness-worktree/plugins/dev-workflow/scripts/codex-worker.py \
  register --state-dir "$HOME/.local/state/claude-harness-codex/jobs" \
  --account spare --codex-home /absolute/path/to/codex-profile
```

Claudeの会話で実行する:

```text
/dev-workflow:develop --account spare --model <利用可能なCodexモデルID> --account-home spare=/absolute/path/to/codex-profile <issue URLまたは依頼>
/dev-workflow:develop --profile codex-standard --account-home-file /absolute/account-homes.json <issue URLまたは依頼>
/dev-workflow:develop --profile hybrid-standard --account-home current=/absolute/path/to/codex-profile <issue URLまたは依頼>
```

`--executor codex` は後方互換の別名として上の形式に追加できる。profile の Claude entry は `account=current`、model は `haiku|sonnet|opus|fable` のみとし、`fable` は `decider` role だけに指定できる。

Claudeが既存developの進め方でworktree/記録先を準備し、仕様化判断から進める。仕様不要なら理由を記録して実装へ、必要なら仕様と独立仕様レビューを経て実装/テスト・PR・レビュー/ゲートへ進む。profile で実行先を選んでもこの判断と工程は変わらない。差戻しも該当 role の実行先へ委譲する。burnを有効化する必要はない。

## 前景実行の呼び方

本体は委譲のたびに次の3手順を回す。台帳もrun-dirも作らないので、次の委譲へ引き継ぐ状態は残らない。

1. **指示をファイルに書く。** 担当工程に限定した指示（依頼・完了条件・記録先URL・対象artifact・固定HEAD）をUTF-8ファイルに書く。秘密情報は入れない。
2. **前景コマンドを背景実行で起動する。** `request` で役割別のexecutor/account/model/effortとCODEX_HOMEを解決した依頼ファイルを作り、そのファイルを渡して `run` をBashツールの背景実行で起こす。
3. **完了通知で結果を読む。** 標準出力の1行JSONを読む。成功はexit 0、失敗はexit 2。

```sh
python3 <plugin>/scripts/codex-develop.py request --phase spec --input /absolute/request.txt \
  --cwd /absolute/target-worktree --profile hybrid-standard [--profile-file /absolute/profiles.json] \
  --account-home current=/absolute/path/to/codex-profile --out /absolute/private/request.json
python3 <plugin>/scripts/codex-worker.py run --request /absolute/private/request.json
```

`--profile NAME` の代わりに旧形式の `--account NAME --model MODEL` も渡せる（どちらか一方だけ。併用・旧形式の片方欠落・どちらも無しは依頼ファイルを作らずに拒否する）。旧形式は role 別の effort を持たない。`request.txt` は担当工程の指示。`--phase` は役割指示を選ぶラベルで、本体は `references/codex-develop.md` の表から選ぶ。`request` はrun-dirもworker-stateも取らず、標準出力の1行JSONに書き出した依頼ファイルのパス・request_id・解決したrole/account/CODEX_HOME/model/effortを返す。依頼ファイルには指示文と実行先が入るため私有ディレクトリに置く。

`run` の結果JSONは `text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind`。実効model/effortやIDが未観測ならnullであり、成功値を推測しない。完了は実行terminalであって品質承認ではなく、`completed` でも `error_kind` が非空なら実行成功として扱わない。review verdictと投稿を確認するのはClaude側。コマンド失敗はそこで停止し、別providerへfallbackしない。

`run` は呼び出し元のプロセス連鎖が切れれば自分も終わり、SIGTERM / SIGINT でも止まる。job IDも受領（`ack`）も無いので、途中で切れた委譲を後から照会・復旧する手段は無い。同じ工程をやり直すときは、3手順を最初から繰り返す。台帳を読み書きしないため、同時実行の枠管理も作業ディレクトリの排他も行わない。同じworktreeへ2本同時に投げないのは本体の責任である。

外部profileはversion 1の`profiles.<name>.roles`に全canonical roleを持ち、各entryでexecutor/account/model/effortを指定する。profileと旧`--account/--model`は併用不可。profileが指すaccount名が `--account-home` / `--account-home-file` の対応表に無ければ、依頼ファイルを作らずに拒否し、既定や別のCODEX_HOMEへ倒さない。workerは静的検証と`model/list`広告値による開始前検証を行う。

初版は全工程fresh thread。read-only reviewerは投稿を本体に返す。実モデルによる一件完走は統合検証の証拠を参照し、fake testsだけで実運用検証済みとは扱わない。

公開 PR の finish/G までの実測は sandbox 外のため未実施である。追加依頼を含む実測時は、実行コマンド、exit code、対象 HEAD、executor/account/model/CODEX_HOME/cwd、finish/G 結果と証跡 URL をこの記録へ追記する。

phaseは役割指示の選択で、Codex独自の工程順序ではない。`spec` で既存の仕様化判断を依頼でき、仕様不要の結果なら本体は既存developどおり実装へ進む。仕様要否・レビュー・テスト・差戻し・archiveは既存の品質正本が管理し、adapterは起動・結果回収・中断と実行先の固定に専念する。

旧版の `--spec-path` / `--required-check` / `accept-review` / `check` / `relocate-spec` は廃止した。検証コマンドとレビュー記録は、通常のdevelopと同じく担当役割と本体が既存手順で扱う。

書込担当（implement / spec-write）は砂場なしで親の環境を引き継ぐため、GitHub取得/投稿・push・PR作成・commitをworkerの中で自分で完了する。本体が代理するのは、read-only roleのレビュー結果の投稿と、揃えられなかった項目として記録済みの操作だけである。子から `needs-coordinator` が来た場合は、その操作が記録済みの項目に当たるかを確認してから本体が行い、証拠を次のfresh phaseへ渡す。

## 台帳を持つ旧経路

`init` / `dispatch` / `status` / `result` / `ack` / `retry` と run-dir・worker-state を使う経路は残っている。前景実行と混ぜず、どちらか一方で1つの委譲を完結させる。

`--worker-state DIR` 未指定なら `$HOME/.local/state/claude-harness-codex/jobs` で、上のregisterと同じ台帳を参照する。別の台帳で登録した場合は `/develop ... --worker-state /absolute/private/worker` を明示する。`--run-dir` を省略すると `init` が `$HOME/.local/state/claude-harness-codex/runs/<UUID>` を作り、JSONの`run_dir`を返す。

```sh
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 init \
  --account spare --model <model> --cwd /absolute/target-worktree --worker-state "$HOME/.local/state/claude-harness-codex/jobs"
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 dispatch --phase spec --input /absolute/request.txt
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 status
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 result
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 ack
```

この経路だけが、記録先へ `<!-- codex-develop-continuation:v1 ... -->` / `:v2 ...` の継続記録を残し、送信到達が不明なpendingを同じrunの `retry` で復旧する（元の依頼を変更せずidempotent submitし、promptも request_id も作り直さない）。dispatchはrole別設定とpayload hashをsubmit前にpendingへ保存し、retryは保存依頼を変更しない。pendingが残っている場合はresult→ackを済ませてから次のdispatchへ進む。ackだけで仕様承認にはならない。run-dir/worker-stateには依頼・結果が残るため私有ディレクトリに置く。

台帳・スロット・cwd排他・拒否理由の詳細は `scripts/CODEX-WORKER.md`。継続記録の形式と検証は `commands/develop.md`。前景実行にはこれらのいずれも現れない。
