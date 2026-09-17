# 手動Codex開発を試す

#706 workerと#707入口を含むworktree版を使う。インストール済みプラグインは上書きしない。

```sh
claude --plugin-dir /absolute/path/to/harness-worktree/plugins/dev-workflow
```

利用するCodex認証profileは事前にログイン済みであること。認証を複製したり、通常profileを上書きしない。登録は既存のCODEX_HOMEを参照する。

```sh
python3 /absolute/path/to/harness-worktree/plugins/dev-workflow/scripts/codex-worker.py \
  --state-dir /absolute/private/worker register \
  --account spare --codex-home /absolute/path/to/codex-profile
```

Claudeの会話で実行する:

```text
/dev-workflow:develop --executor codex --account spare --model <利用可能なCodexモデルID> <issue URLまたは依頼>
```

Claudeが既存developの進め方でworktree/記録先を準備し、仕様→独立仕様レビュー→実装/テスト→PR→独立レビュー/ゲートを進める。差戻しもCodexへ委譲する。burnを有効化する必要はない。

## 操作の確認例

```sh
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 init \
  --account spare --model <model> --cwd /absolute/target-worktree --worker-state /absolute/private/worker
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 dispatch --phase spec --input /absolute/request.txt
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 status
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 result
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 ack
```

`request.txt` は担当工程の指示。本体は `references/codex-develop.md` の表でphaseを選ぶ。上記は送受信の例で、ackだけで仕様承認にはならない。review verdictと投稿を確認するのはClaude側。コマンド失敗はblockedで終了し、別providerへのfallbackはしない。run-dir/worker-stateには依頼・結果が残るため私有ディレクトリに置く。

初版は全工程fresh thread。read-only reviewerは投稿を本体に返す。実モデルによる一件完走は統合検証の証拠を参照し、fake testsだけで実運用検証済みとは扱わない。
