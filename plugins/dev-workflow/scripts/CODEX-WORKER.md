# Codex 前景 worker

`codex-worker.py` は private な依頼ファイルを受け取り、App Server の 1 turn を呼び出し元と同じ生存期間で実行する。

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py run --request /absolute/private/request.json
```

依頼は `request_id` / `origin=manual` / `account` / `cwd` / `model` / `role` / `prompt` / 任意の `effort` と、呼び出し側が解決した `codex_home` を持つ。account 名から CODEX_HOME への対応は `codex-develop.py request` が委譲ごとに解決する。worker は永続的な account registry、仕事の保存領域、所有権 DB を作成・参照しない。

## 検証と実行順

worker は依頼のフィールド、所有者、repo root、feature branch、linked worktree を静的検証する。その後、次の順序を変えない。

1. App Server を initialize する。
2. `account/read` と依頼された CODEX_HOME の認証情報を照合する。
3. 全ページの `model/list` で model と広告された effort の組合せを検証する。
4. `account/rateLimits/read` で 1 request 分と `quota_margin_pct`（既定 5）の余裕を確認する。
5. `thread/start`、`turn/start` の順に開始する。

model は両方の start に渡し、effort は `turn/start` だけへ渡す。effort 省略時は補完しない。一覧に無い model、非対応 effort、一覧取得失敗、利用枠の不明・不正・上限到達は turn 開始前に拒否し、別 model、account、provider へ切り替えない。サーバーが start を拒否した場合も自動再試行しない。

## role policy

`implement` / `spec-write` は Claude の書込担当と同じく `danger-full-access`、その他は `read-only`。全 role で `approvalPolicy=never` を維持する。read-only に writable roots を追加しない。`review` / `spec-review` / `impl-review` / `explore` / `summarize` は networkAccess=true、`decider` は false とする。

書込担当を OS sandbox なしにするのは、linked worktree の commit、push、GitHub 操作を担当自身が完了するためである。transport 完了は品質承認ではない。最終回答、テスト証拠、独立 review、gate は canonical develop workflow が判定する。

書込 role に sandbox を付けない根拠は実測にある。workspace-write では linked worktree の `$GIT_DIR` に `HEAD.lock` / `index.lock` を作れず git が exit 128 になり、`WorkspaceWriteSandboxPolicy` は `writableRoots` / `networkAccess` / `excludeTmpdirEnvVar` / `excludeSlashTmp` の4フィールドだけである。`danger-full-access` では commit、branch 作成、push、`gh`、PR 作成が通ることを確認している。

## 環境と認証

子プロセスは親環境を引き継ぐ。ただし worker が決める `CODEX_HOME`、別課金経路へ移し得る `OPENAI_API_KEY` / `CODEX_API_KEY` / `OPENAI_BASE_URL` / `CODEX_AUTH_JSON` / `OPENAI_ORGANIZATION` / `OPENAI_PROJECT`、別 checkout へ向け得る `GIT_DIR` / `GIT_WORK_TREE` / `GIT_COMMON_DIR` / `GIT_INDEX_FILE` は落とす。`TMPDIR` / `TMPPREFIX` は親の値を保ち、無ければ補わない。`GH_TOKEN`は渡る。`shell_environment_policy`は実測では絞らないので、runtime `config.toml`に引き継ぎ設定は書かない。worker 自身の git 呼び出しは固定 allowlist の最小環境を使う。

1 request ごとに 0700 の一時 runtime CODEX_HOME を作る。`auth.json` は指定 profile への symlink、`config.toml` は最小設定とし、元 profile の MCP / app / plugin 設定や履歴を継承しない。project または ancestor の `.codex/config.toml` は拒否する。終了時は認証 symlink と runtime directory を削除するが、指定された profile 本体は変更しない。同時に走る依頼の一時ファイルは同じ親の一時領域に混ざりうり、依頼が残した一時ファイルの出どころを worker は記録しない。この追跡が必要になったら Codex 側だけに戻さず、Claude のサブエージェント側にも同じ仕組みを入れて揃える。

ID token の email と `account/read` を照合する。実行中に元 `auth.json` の内容または runtime symlink が変われば停止を要求する。通常のtoken refreshでも止まる保守的制約がある。認証切替・設定書換えは行わない。これは署名検証や複数 workspace の完全識別を主張するものではない。

## 停止と結果

呼び出し元の祖先プロセス連鎖が変わるか、SIGTERM / SIGINT を受けると停止要求を立てる。signal handler から RPC は送らず、通常フローが `turn/interrupt` を 1 回送り、単一の 10 秒猶予内で終了する。終了時は App Server の子プロセスを残さない。

標準出力は `text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind` を持つ 1 行 JSON だけ。成功は exit 0、それ以外は exit 2。`thread/start` / `turn/start` がエラー応答を返した場合の `error_kind` は `server_rejected_start_<コード>`。要求値と実効値・観測元を分け、未観測値を要求値から補完しない。`effective.account` は App Server が返した実行中 account、`requested.account` は呼び出し側のラベルである。

品質判定に渡す `text` は一意な `phase=final_answer` だけ。途中 commentary、phase 欠測、複数 final、空 final を承認証拠にしない。結果 JSON を受け取れず終了した場合は、記録先と worktree を確認し、その工程を fresh phase としてやり直す。

テストは `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_codex_*.py'` で実行する。
