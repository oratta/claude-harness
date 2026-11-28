# Codex 前景 worker

`codex-worker.py` は private な依頼ファイルを受け取り、App Server の 1 turn を呼び出し元と同じ生存期間で実行する。

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py run --request /absolute/private/request.json
```

依頼は `request_id` / `origin=manual` / `account` / `cwd` / `model` / `role` / `prompt` / 任意の `effort` と、呼び出し側が解決した `codex_home` を持つ。account 名から CODEX_HOME への対応は `codex-develop.py request` が委譲ごとに解決する。worker は永続的な account registry、仕事の保存領域、所有権 DB を作成・参照しない。

## 検証と実行順

worker は依頼のフィールド、所有者、repo root、feature branch、linked worktree を静的検証する。その後、hook の依存・source を検証して一時 runtime に配布し、次の順序を変えない。

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

子プロセスは親環境を引き継ぐ。例外として `DEV_WORKFLOW_CODEX_GUARD_DIR` / `DEV_WORKFLOW_CODEX_GIT_GUARD` / `DEV_WORKFLOW_CODEX_SECRET_GUARD` / `DEV_WORKFLOW_CODEX_ASK_GUARD` は helper 実体から求めた配布元の絶対パスへ固定する。さらに worker が決める `CODEX_HOME`、別課金経路へ移し得る `OPENAI_API_KEY` / `CODEX_API_KEY` / `OPENAI_BASE_URL` / `CODEX_AUTH_JSON` / `OPENAI_ORGANIZATION` / `OPENAI_PROJECT`、別 checkout へ向け得る `GIT_DIR` / `GIT_WORK_TREE` / `GIT_COMMON_DIR` / `GIT_INDEX_FILE` は落とす。`TMPDIR` / `TMPPREFIX` は親の値を保ち、無ければ補わない。`GH_TOKEN`は渡る。`shell_environment_policy`は実測では絞らないので、runtime `config.toml`に引き継ぎ設定は書かない。worker 自身の git 呼び出しは固定 allowlist の最小環境を使う。

1 request ごとに 0700 の一時 runtime CODEX_HOME を作る。`auth.json` は指定 profile への symlink、`config.toml` は最小設定とし、検証済み `hooks.json` と実行系リンクを加える。元 profile の MCP / app / plugin 設定や履歴を継承しない。project または ancestor の `.codex/config.toml` と `.codex/hooks.json` は拒否する。終了時は認証 symlink と runtime directory を削除するが、指定された profile 本体は変更しない。同時に走る依頼の一時ファイルは同じ親の一時領域に混ざりうり、依頼が残した一時ファイルの出どころを worker は記録しない。この追跡が必要になったら Codex 側だけに戻さず、Claude のサブエージェント側にも同じ仕組みを入れて揃える。

ID token の email と `account/read` を照合する。ターン開始前は元 `auth.json` の email と account_id を比べ、読めなければその場で止める。ターンの待機中は、runtime symlink が差し替えられるか、元 `auth.json` の email か account_id が開始時と違えば `auth_profile_changed` で停止を要求する。email と account_id が同じまま中身だけ変わった（token 更新）ときは、その変化ごとに `account/read` を 1 回呼び、email が同じなら続け、違うか取得できなければ停止を要求する。ただし取得の途中で app-server との接続が切れたときはアカウントの変化とみなさず、`transport_disconnected` で終わる。書き換え途中などで `auth.json` が読めないときは読み直し、読めない状態が 5 秒を超えて続いたら停止を要求する。一度停止を決めた後と停止の合図の後は照合し直さず、理由を保つ。認証切替・設定書換えは行わない。これは署名検証や複数 workspace の完全識別を主張するものではない。

## 停止と結果

呼び出し元の祖先プロセス連鎖が変わるか、SIGTERM / SIGINT を受けると停止要求を立てる。signal handler から RPC は送らず、通常フローが `turn/interrupt` を 1 回送り、単一の 10 秒猶予内で終了する。終了時は App Server の子プロセスを残さない。

標準出力は `text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind` / `started_at` / `ended_at` を持つ 1 行 JSON だけ（`started_at` / `ended_at` は実行の開始と終了の時刻で、UTC の ISO8601・秒まで・末尾 `Z`。成功・失敗を問わず入る）。成功は exit 0、それ以外は exit 2。`thread/start` / `turn/start` がエラー応答を返した場合の `error_kind` は `server_rejected_start_<コード>`。要求値と実効値・観測元を分け、未観測値を要求値から補完しない。`effective.account` は App Server が返した実行中 account、`requested.account` は呼び出し側のラベルである。

品質判定に渡す `text` は一意な `phase=final_answer` だけ。途中 commentary、phase 欠測、複数 final、空 final を承認証拠にしない。結果 JSON を受け取れず終了した場合は、記録先と worktree を確認し、その工程を fresh phase としてやり直す。

テストは `scripts/test.sh python-suites` で実行する。`plugins/*/tests/test_*.py` をファイル名で絞らずに全件走らせるので、同じ値を別のファイルで検査しているテストも一緒に走る。`scripts/test.sh dev-workflow` のようにプラグイン名で絞った実行では Python のテストは走らないので、一緒に走らせたいときは `scripts/test.sh dev-workflow python-suites` と並べる。

## hook runtime と本体向け導入手順

worker は全 role の runtime に `codex-hook-runtime.py` で既存 PreToolUse 定義を配布し、`codex app-server` で起動し、配布済み一時 runtime の `thread/start` params に `"config": {"bypass_hook_trust": true}` を渡す。helper は実体のある checkout から adapter/git/secret/ask と secret の Python sibling・git 共通判定を解決し、bash/python3 の存在も検査する。hook 内の実行系は一時 `.hook-bin` の絶対リンクへ固定する。親の guard パス4変数も子環境で配布元へ固定する。`DEV_WORKFLOW_UNATTENDED` と git/secret の off、TMPDIR/TMPPREFIX、その他の継承契約は保つ。依存欠落なら server/turn を起こさず失敗 JSON と exit 2、準備中の失敗を含め runtime は削除する。既存 guard の動的失敗・timeout の fail-open は変わらない。

[app-server 追試（codex-cli 0.163.0）](https://github.com/oratta/claude-harness/issues/1863#issuecomment-7236723402) では、最上位の `--dangerously-bypass-hook-trust` と `-c bypass_hook_trust=true` のいずれでも reset が実行され snapshot が変化した。同じ配布済み一時 CODEX_HOME を使う `codex exec --dangerously-bypass-hook-trust` は拒否し、app-server は `thread/start` の params に `"config": {"bypass_hook_trust": true}` を渡した場合だけ拒否・snapshot 不変となった。 CLI 本体 / codex exec ではフラグを使い、app-server では thread ごとの config 上書きを使う。helper の JSON の `trust_args` は CLI 用、`thread_config` は app-server の `thread/start.params.config` 用であり、通常 profile に自動適用しない。修正後 worker の実機セルは本体の再取得待ち。

以下は主が内容をレビューするための手順であり、この change は実ホームに適用しない。通常 profile への bypass の自動追加もしない。まず配布元 checkout の HEAD と差分、`hooks/codex/hooks.json`、adapter、依存4ファイルと bash/python3 の実体を確認する（絶対パスは helper の JSON と `.hook-bin` のリンク先で確認できる）。配布元が移動・更新されたら新しい一時 target でやり直す。

```sh
# harness_dir は確認した開発checkoutの絶対パス。通常profileとは別の一時targetだけを使う。
stage=$(mktemp -d "${TMPDIR:-/tmp}/codex-hook-stage.XXXXXX")
python3 "$harness_dir/plugins/dev-workflow/scripts/codex-hook-runtime.py" --target "$stage" > "$stage-metadata.json"
# helper は runtime に元の認証や他の設定をコピーしない。
# hooks.json の command と .hook-bin/bash・python3 のリンク先、metadata をレビューする。
```

同じ一時 target への二度目の配布は既存設定として拒否する。元 profile の `hooks.json` / `config.toml` / `requirements.toml` を target にコピーしない。既存設定がある場合は別の空 target を作る。worker では既知の最小 config と auth symlink のみを保持する。本体の一時起動でも、その2点だけを自分で用意し、上の隔離 probe で source と信頼を確認してから invocation bypass を使う。

実ホームへ常設する場合は、次の差分を主が承認してから適用する。

1. 対象の `hooks.json` を repo 外へ退避し、既存 Orca を含む全 event/group を保持する。`config.toml` / `requirements.toml` は書き換えない。追加 source が分からない場合は止める。
2. 承認した `.hook-bin` の bash/python3 リンクを常設先（例:対象 CODEX_HOME 配下の未使用 `harness-hook-bin`）へ配置する。既存ディレクトリは上書きしない。生成した command の PATH 中の一時 `.hook-bin` だけをその常設先の絶対パスへ置き換える。adapter/guard の絶対パスは確認した checkout を指すままにする。
3. 生成した `hooks.PreToolUse` の1 group を対象 `hooks.json` の同じ配列の末尾へ追加する。既存の配列を置換せず、他の event/group/属性は保持する。差分がこの1 groupのみで、既存 Orca 登録が残っていることを照合する。command の絶対パスと実行内容をもう一度確認する。
4. 起動時に Codex が示す hook 信頼操作で、追加した source を主がレビューして信頼する。操作が表示されない/版で変わった場合は、その版の help と公式 Hooks 文書を再確認して止め、未信頼の起動を成功にしない。実ホームで trust bypass を使って信頼を一括省略しない。
5. 一覧の隔離 probe の feature worktree から実拒否・無害な対照を確認してから通常利用へ進む。版更新・checkout移動後は依存解決と source/trust を再確認し、古い絶対パスの登録を使い続けない。

戻すときは追加した1 groupだけを削除し、他の設定が変わっていなければ退避した hooks.json と照合する。後から Orca 等の登録が変わっていたら退避ファイルで全置換しない。今回だけの `harness-hook-bin` と追加 source の信頼を主が取り消す。worker には永続登録がないため、古い worker が終了したことを確認して更新前の checkout に戻せばよい。一時 stage と metadata の削除先は絶対パスで指定する。
