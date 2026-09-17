# 手動Codex開発を試す

#706 workerと#707入口を含むworktree版を使う。インストール済みプラグインは上書きしない。

```sh
claude --plugin-dir /absolute/path/to/harness-worktree/plugins/dev-workflow
```

利用するCodex認証profileは事前にログイン済みであること。認証を複製したり、通常profileを上書きしない。登録は既存のCODEX_HOMEを参照する。

```sh
python3 /absolute/path/to/harness-worktree/plugins/dev-workflow/scripts/codex-worker.py \
  --state-dir "$HOME/.local/state/claude-harness-codex/jobs" register \
  --account spare --codex-home /absolute/path/to/codex-profile
```

Claudeの会話で実行する:

```text
/dev-workflow:develop --executor codex --account spare --model <利用可能なCodexモデルID> <issue URLまたは依頼>
```

Claudeが既存developの進め方でworktree/記録先を準備し、仕様化判断から進める。仕様不要なら理由を記録して実装へ、必要なら仕様と独立仕様レビューを経て実装/テスト・PR・レビュー/ゲートへ進む。実行先をCodexにしてもこの判断と工程は変わらない。差戻しもCodexへ委譲する。burnを有効化する必要はない。

## 台帳とrunの場所

`--worker-state DIR` 未指定なら `$HOME/.local/state/claude-harness-codex/jobs`。上のregisterと同じ台帳を参照する。別の台帳で登録した場合は `/develop ... --worker-state /absolute/private/worker` を明示する。

新規開始で `--run-dir` を省略すると、initが `$HOME/.local/state/claude-harness-codex/runs/<UUID>` を作り、JSONの`run_dir`を返す。Claudeはこの絶対pathを記録先に保存し、dispatch/status/result/ack等に必ず渡す。再開は `/develop ... --run-dir <保存したpath>` で既存runを読み、initを再実行しない。run内のaccount/model/worker_stateが指定と違えば再開せず不一致を報告する。台帳や最新runを探索して勝手に選ばない。

## 操作の確認例

```sh
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 init \
  --account spare --model <model> --cwd /absolute/target-worktree --worker-state "$HOME/.local/state/claude-harness-codex/jobs"
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 dispatch --phase spec --input /absolute/request.txt
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 status
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 result
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 ack
```

`request.txt` は担当工程の指示。本体は `references/codex-develop.md` の表でphaseを選ぶ。上記は送受信の例で、ackだけで仕様承認にはならない。review verdictと投稿を確認するのはClaude側。コマンド失敗はblockedで終了し、別providerへのfallbackはしない。run-dir/worker-stateには依頼・結果が残るため私有ディレクトリに置く。

初版は全工程fresh thread。read-only reviewerは投稿を本体に返す。実モデルによる一件完走は統合検証の証拠を参照し、fake testsだけで実運用検証済みとは扱わない。

phaseは役割指示の選択で、Codex独自の工程順序ではない。`spec` で既存の仕様化判断を依頼でき、仕様不要の結果なら本体は既存developどおり実装へ進む。仕様要否・レビュー・テスト・差戻し・archiveは既存の品質正本が管理し、adapterは起動・状態確認・結果回収・中断と実行先の固定に専念する。

旧版の `--spec-path` / `--required-check` / `accept-review` / `check` / `relocate-spec` は廃止した。検証コマンドとレビュー記録は、通常のdevelopと同じく担当役割と本体が既存手順で扱う。

workerはnetworkを使わないため、GitHub取得/投稿・push・PR作成はClaude本体が代理する。子から `needs-coordinator` が来たら本体が必要な操作を行い、証拠を次のfresh phaseへ渡す。子のsandboxがcommitを拒否したときも本体がcommitする。

旧版のrunも再開できるが、旧品質フィールドは無視する。pendingが残っている場合はresult→ackを済ませてから次のdispatchへ進み、変更したpromptで旧依頼を再submitしない。completedでもerror_kind付きは実行成功ではなく、ackも品質承認を意味しない。

### 送信到達が不明なpendingの復旧

結果が存在するpendingは `status` / `result` で回収し、terminal結果を受領して `ack` する。送信前の失敗や応答切断でworkerへ到達したか不明なら、同じrunに `retry` を実行する。`retry` は保存済みrequest.jsonのrequest_id/account/model/cwdとrunの一致を検証し、**元の依頼を変更せず**workerへidempotent submitする。promptを再生成せず、新しいrequest_idも作らない。不一致やファイル欠損なら拒否し、別account・別依頼へ差し替えない。

```sh
python3 <plugin>/scripts/codex-develop.py --run-dir <保存したrun-dir> retry
```

旧版の品質metadataは無視するが、pendingとownershipは引き継ぐ。retryは結果不明の仕事を別ジョブとしてやり直す機能ではなく、同一依頼の送信/照会を復旧するtransport操作である。
