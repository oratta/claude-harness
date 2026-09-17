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
  --account spare --model <model> --cwd /absolute/target-worktree --worker-state /absolute/private/worker --spec-path openspec/changes/<change> --required-check '["python3","-m","unittest"]'
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 dispatch --phase spec --input /absolute/request.txt
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 status
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 result
python3 <plugin>/scripts/codex-develop.py --run-dir /absolute/private/run-1 ack
```

`request.txt` は担当工程の指示。本体は `references/codex-develop.md` の表でphaseを選ぶ。上記は送受信の例で、ackだけで仕様承認にはならない。review verdictと投稿を確認するのはClaude側。コマンド失敗はblockedで終了し、別providerへのfallbackはしない。run-dir/worker-stateには依頼・結果が残るため私有ディレクトリに置く。

初版は全工程fresh thread。read-only reviewerは投稿を本体に返す。実モデルによる一件完走は統合検証の証拠を参照し、fake testsだけで実運用検証済みとは扱わない。

仕様レビュー結果は `仕様レビュー: APPROVE`、実装レビュー結果は `レビュー: APPROVE` を独立行で返すよう指示する。result→ackの後、`accept-review` がcompleted・レビューphase・固定HEAD・clean・仕様artifact hashを確認して承認を記録する。仕様の内容が変われば再レビューが必要。`--spec-path` は複数指定可でレビュー対象仕様を漏れなく指定する。実装前は仕様承認必須（初版は仕様省略経路なし）。

実装終了後は成果物をcommitし、`check` でinit時指定のrequired-checkを実行する。実コマンドのexit codeと出力を保存し、現在HEADで成功した証拠がなければfinish/gateを拒否する。required-checkは対象repoの必須検査を本体が選び、例示コマンドを無条件に流用しない。Codex sandboxでcommitできなければ本体が確認してcommitする。

archiveで移動した仕様は `relocate-spec --from-path openspec/changes/<change> --to-path openspec/changes/archive/<dated-change>` で承認対象を移せる（finish回収・ack・commit後）。ファイル名と内容のhashが承認時と完全一致する場合だけ受理する。変更が含まれる場合は新しいspec-reviewが必要。archive後は現在HEADでcheckを再実行してGへ進む。

workerはnetworkを使わないため、GitHub取得/投稿・push・PR作成はClaude本体が代理する。子から `needs-coordinator` が来たら本体が必要な操作を行い、証拠を次のfresh phaseへ渡す。子のsandboxがcommitを拒否したときも本体がcommitする。
