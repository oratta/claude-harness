# 手動Codex開発を試す

#706 workerと#707入口を含むworktree版を使う。インストール済みプラグインは上書きしない。

```sh
claude --plugin-dir /absolute/path/to/harness-worktree/plugins/dev-workflow
```

利用するCodex認証profileは事前にログイン済みであること。認証を複製したり、通常profileを上書きしない。

account名からCODEX_HOMEへの対応は、委譲のたびに引数で渡す。`--account-home NAME=PATH` の繰り返しか、account名をキー・CODEX_HOMEの絶対パスを値とする平らなJSON 1つを `--account-home-file PATH` で渡す。2つの与え方の併用は拒否し、合成も優先もしない。値が絶対パスでない、またはディレクトリとして存在しないときも拒否する。profile・旧形式・対応表をすべて省略した自動選択だけは、既存の絶対ディレクトリである `CODEX_HOME`（未設定なら `~/.codex`）を `current` として評価する。候補が存在しなければ Codex は欠測になる。明示指定時に対応の無い名前をこの既定値へ倒さない。永続的な account registry は使わない。

Claudeの会話で実行する:

```text
/dev-workflow:develop --account spare --model <sol|luna|astra などの系統名、または完全なCodexモデルID> --account-home spare=/absolute/path/to/codex-profile <issue URLまたは依頼>
/dev-workflow:develop --profile codex-standard --account-home-file /absolute/account-homes.json <issue URLまたは依頼>
/dev-workflow:develop --profile hybrid-standard --account-home current=/absolute/path/to/codex-profile <issue URLまたは依頼>
/dev-workflow:develop --account-home-file /absolute/account-homes.json <issue URLまたは依頼>
```

`--executor codex` は後方互換の別名として上の形式に追加できる。profile の Claude entry は `account=current`、model は `haiku|sonnet|opus|fable` のみとし、`fable` は `decider` role だけに指定できる。

profile/旧 account/model を省略すると、各工程の開始時に Codex は fresh（age 300 秒以内）な週次使用量、Claude はセッション記録と snapshot の実効値（リセット前の値は経過時間によらず使う）から `週経過率 - 使用率` を比較する。両方に余裕があれば Claude が書き Codex が検査する `claude-write-codex-review`、Codex だけに余裕があれば `codex-standard`、それ以外は Claude 既定構成になる。工程途中では切り替えず、次工程で再評価する。標準出力の selection evidence（構成、reason、margin、fetched_at、代表 Codex account）は開始コメントと dispatch 記録へ残す。明示指定時はこの読込を行わない。

Claudeが既存developの進め方でworktree/記録先を準備し、仕様化判断から進める。仕様不要なら理由を記録して実装へ、必要なら仕様と独立仕様レビューを経て実装/テスト・PR・レビュー/ゲートへ進む。profile で実行先を選んでもこの判断と工程は変わらない。差戻しも該当 role の実行先へ委譲する。burnを有効化する必要はない。

## 前景実行の呼び方

本体は委譲のたびに次の3手順を回す。transport の永続状態は作らず、継続状態は記録先と worktree に置く。

1. **指示をファイルに書く。** 担当工程に限定した指示（依頼・完了条件・記録先URL・対象artifact・固定HEAD）をUTF-8ファイルに書く。秘密情報は入れない。
2. **前景コマンドを背景実行で起動する。** `request` で役割別のexecutor/account/model/effortとCODEX_HOMEを解決した依頼ファイルを作り、そのファイルを渡して `run` をBashツールの背景実行で起こす。
3. **完了通知で結果を読む。** 標準出力の1行JSONを読む。成功はexit 0、失敗はexit 2。

```sh
python3 <plugin>/scripts/codex-develop.py request --phase spec --input /absolute/request.txt \
  --cwd /absolute/target-worktree --profile hybrid-standard [--profile-file /absolute/profiles.json] \
  --account-home current=/absolute/path/to/codex-profile --out /absolute/private/request.json
python3 <plugin>/scripts/codex-worker.py run --request /absolute/private/request.json
```

`--profile NAME` の代わりに旧形式の `--account NAME --model MODEL` も渡せる（明示形式どうしはどちらか一方だけ。併用・旧形式の片方欠落は拒否する）。model は系統名（worker が呼ぶ直前に model/list の最新版へ解決する）か完全なモデル ID のどちらでも書ける。どちらも無い場合は自動選択になる。旧形式は role 別の effort を持たない。`request.txt` は担当工程の指示。`--phase` は役割指示を選ぶラベルで、本体は `references/codex-develop.md` の表から選ぶ。`request` は標準出力の1行JSONに書き出した依頼ファイルのパス・request_id・解決したrole/account/CODEX_HOME/model/effortと selection evidence を返す。依頼ファイルには指示文と実行先が入るため私有ディレクトリに置く。

`run` の結果JSONは `text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind`。実効model/effortやIDが未観測ならnullであり、成功値を推測しない。完了は実行terminalであって品質承認ではなく、`completed` でも `error_kind` が非空なら実行成功として扱わない。review verdictと投稿を確認するのはClaude側。コマンド失敗はそこで停止し、別providerへfallbackしない。

`run` は呼び出し元のプロセス連鎖が切れれば自分も終わり、SIGTERM / SIGINT でも止まる。途中で切れた委譲を後から照会・復旧する手段は無い。同じ工程をやり直すときは、記録先と worktree を確認して3手順を最初から繰り返す。同時実行の枠管理も作業ディレクトリの排他も行わない。同じworktreeへ2本同時に投げないのは本体の責任である。

外部profileはversion 1の`profiles.<name>.roles`に全canonical roleを持ち、各entryでexecutor/account/model/effortを指定する。profileと旧`--account/--model`は併用不可。profileが指すaccount名が `--account-home` / `--account-home-file` の対応表に無ければ、依頼ファイルを作らずに拒否し、既定や別のCODEX_HOMEへ倒さない。workerは静的検証と`model/list`広告値による開始前検証を行う。

初版は全工程fresh thread。read-only reviewerは投稿を本体に返す。実モデルによる一件完走は統合検証の証拠を参照し、fake testsだけで実運用検証済みとは扱わない。

公開 PR の finish/G までの実測は sandbox 外のため未実施である。追加依頼を含む実測時は、実行コマンド、exit code、対象 HEAD、executor/account/model/CODEX_HOME/cwd、finish/G 結果と証跡 URL をこの記録へ追記する。

phaseは役割指示の選択で、Codex独自の工程順序ではない。`spec` で既存の仕様化判断を依頼でき、仕様不要の結果なら本体は既存developどおり実装へ進む。仕様要否・レビュー・テスト・差戻し・archiveは既存の品質正本が管理し、adapterは起動・結果回収・中断と実行先の固定に専念する。

旧版の `--spec-path` / `--required-check` / `accept-review` / `check` / `relocate-spec` は廃止した。検証コマンドとレビュー記録は、通常のdevelopと同じく担当役割と本体が既存手順で扱う。

書込担当（implement / spec-write）は砂場なしで親の環境を引き継ぐため、GitHub取得/投稿・push・PR作成・commitをworkerの中で自分で完了する。本体が代理するのは、read-only roleのレビュー結果の投稿と、揃えられなかった項目として記録済みの操作だけである。子から `needs-coordinator` が来た場合は、その操作が記録済みの項目に当たるかを確認してから本体が行い、証拠を次のfresh phaseへ渡す。

## 2.13.14 以前の状態を手動で片付ける

既存の `$HOME/.local/state/claude-harness-codex/` は inert data であり、コードは起動時にこのディレクトリを見ない。自動削除もしない。

削除してよいのは、次の3条件をすべて確認した後だけである。

1. `pgrep -fl 'codex-worker.py'` が何も返さない。
2. 回収が必要だった旧 job の結果を 2.13.14 で回収済み、または不要と判断済みである。
3. dev-workflow 2.13.14 以前の session が残っていない。

確認後、利用者が次を実行する。

```sh
rm -rf -- "$HOME/.local/state/claude-harness-codex"
```

`runtimes/` 内の `auth.json` は認証元へのリンクである。上のコマンドはリンクを消すだけで、リンク先の認証情報は消えない。
