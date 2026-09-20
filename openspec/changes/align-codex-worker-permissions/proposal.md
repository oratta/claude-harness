## Why

指揮役は Claude Code で、呼び出し先が Claude のサブエージェントでも Codex の worker でも、工程の流れと各担当がやることを同じにする、というのがこの仕組みの前提である。いま Codex の worker だけ harness 側の固定値でネットワークを遮断し（`codex-worker.py` の turn policy が全 role で `networkAccess: False`）、環境変数を 8 個の allowlist に絞り（`clean_env()`）、書き込みを cwd と専用一時領域だけに限っているため、実装担当が「ファイルを書く」以外を自分で完了できない。その結果、Codex 経路にだけ本体の代理作業（GitHub の取得・コメント・ラベル・push・Draft PR 作成・`git commit`・localhost を使うテスト）があり、工程表が 1 本でも実際の担当分担が二重になっている。

この制約は Codex の仕様ではない（App Server の `SandboxPolicy` は `readOnly` / `workspaceWrite` の両方で `networkAccess: true` を受け、`dangerFullAccess` も選べる）。閉じる理由を比較検討した記録も設計文書に無く、`openspec/specs/codex-worker/spec.md` に MUST として書かれているだけである。

## What Changes

- **BREAKING（仕様の反転）**: `codex-worker` の Requirement「一時領域の追加許可以外の砂場を維持する」から「networkAccess は false を維持しなければならない」「read-only role の許可を拡大したり danger-full-access に変更したりしてはならない」を取り除き、「Claude のサブエージェントと同じ水準まで開ける」方針に置き換える
- 書く役（`implement` / `spec-write`）の turn を `networkAccess: true` にし、`writableRoots` に Git 共通ディレクトリ（`git rev-parse --git-common-dir`）を足して、linked worktree でも worker の中で `git commit` が通るようにする
- 読む役は `readOnly` を保ったまま、`networkAccess` を Claude 側の同じ役の取得手段に合わせる。本体が汎用サブエージェントとして起こす `review` / `spec-review` / `impl-review` は `true` にして GitHub の読み取りを揃え、Read / Grep / Glob だけでシェルを持たない `decider` は `false` のまま据え置く。どちらも書き込み許可は増やさない
- 子へ渡す環境変数を 8 個の allowlist から「親の環境を引き継いで、渡してはいけないものだけ落とす」形に変える。落とすのは worker が自分で決める値（`CODEX_HOME` / `TMPDIR` / `TMPPREFIX`）と、Codex の認証・課金経路を別物にすり替える値（`OPENAI_API_KEY` など Codex 自身が読む認証変数）
- Codex の `shell_environment_policy` が子シェルへの引き継ぎを絞る場合は、job ごとの runtime `config.toml` で引き継ぎを開く（現在の runtime config は `cli_auth_credentials_store` と `features.apps` だけを書いている）
- 上の範囲で足りない役が実測で出た場合に限り、その役だけ `dangerFullAccess`（`thread/start` は `danger-full-access`）へ落とせるようにする。対象は書く役（`implement` / `spec-write`）だけで、読む役は `readOnly` を維持する。判断は実測の失敗出力と、その失敗が砂場の拒否によるものだと確認した根拠とともに記録する
- 揃えた結果不要になる代理実行の記述を削る: `plugins/dev-workflow/references/codex-develop.md` の「共通 worker は network 無効／sandbox が git commit を拒否した場合も本体が commit する」段落、`plugins/dev-workflow/docs/codex-develop.md` の同趣旨の段落
- 実 Codex での実測（127.0.0.1 への HTTP・worker 内での `git commit` / `git push` / `gh pr create --draft` / `gh issue comment`・flatmate の `scripts/test-task-store-worker.sh` 完走）と、揃えられなかった項目の記録を証跡として残すことを要件にする

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-worker`: 砂場の要件を改める。（a）書く役はネットワークと Git 共通ディレクトリへの書き込みを持ち、worker の中で GitHub 操作と commit / push を自分で完了できる（b）読む役は書き込みを増やさずネットワークだけ揃える（c）子へ渡す環境変数の範囲と、渡してはいけない変数（d）緩める判断は段階的で、各段の採否を実測の証跡とともに記録する（e）実 Codex の受け入れ証跡に localhost・Git・GitHub・外部リポのテストスクリプトを加える
- `codex-develop-continuation`: Requirement「coordinator と担当者の責務境界を守る」を書き直す。現行は「coordinator が GitHub 操作と worker が実行できない場合の commit/push の代理を担う（MUST）」「担当者は GitHub 操作・ログ取得を行ってはならない（MUST NOT）」で、worker が自分で `gh` を使い push する今回の変更と正面衝突する。coordinator に残すのは記録先の選択・継続記録の生成/解析・GitHub コメントの取得/保存・LLM ログの取得・run の整合性検証とし、GitHub 操作と commit/push は権限を持つ役が自分で行い、代理は「揃えられなかった項目」として記録済みの操作だけに限る。read-only role のレビュー結果を coordinator が代理投稿する経路は残す

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`: `clean_env()`、turn の `sandboxPolicy`、`runtime_home()` の config 生成、`writableRoots` の算出
- `plugins/dev-workflow/tests/test_codex_worker.py`: fake App Server が受け取る policy と環境変数の回帰テスト
- `plugins/dev-workflow/scripts/CODEX-WORKER.md`: 実際の範囲と制約の記述（現行は「全 role で networkAccess=false」「子環境変数は allowlist だけ」と書いてある）
- `plugins/dev-workflow/references/codex-develop.md` / `plugins/dev-workflow/docs/codex-develop.md`: 代理実行の記述の削除
- `openspec/specs/codex-worker/spec.md`: archive 時に反映（Purpose の TBD もこの機会に埋める）
- `openspec/specs/codex-develop-continuation/spec.md`: Requirement「coordinator と担当者の責務境界を守る」を archive 時に反映（GitHub 操作と commit/push の担い手が変わる）
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`: dev-workflow のバージョンを 2.13.8 → 2.13.9
- 受け入れるリスク: 認証情報を持ち外と通信できる子を、途中で誰も止められない（`approvalPolicy: never` は変えない）。これは許可を飛ばす設定で動いている Claude のサブエージェントと同じ水準で、Codex 側だけが増やすリスクではない
- 触らないもの: `approvalPolicy: never`、切り離して投げて後で拾う作り、`excludeSlashTmp` / `excludeTmpdirEnvVar`、一時領域の所有と片付け、account ごとの同時実行と枠判定（`codex-worker-concurrency`）、Claude の hooks が Codex に効かない点（製品の違いなので対象外）
