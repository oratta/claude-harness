## ADDED Requirements

### Requirement: lint.sh は公式の検証をリポジトリ直下と各プラグインに走らせる
`scripts/lint.sh` は、shellcheck のあとに、リポジトリ直下と、git が追跡している `plugins/<name>/.claude-plugin/plugin.json` を持つ各プラグインのディレクトリ（`plugins/<name>`）へ `claude plugin validate <対象>` を走らせなければならない（MUST）。対象のプラグイン名をスクリプトに固定で書いてはならない（MUST NOT）。`--strict` を付けてはならない（MUST NOT。version 未記載の警告は、版を commit SHA で決める運用どおりのため）。

どれか 1 つの対象で `claude plugin validate` が非 0 で終わったら、残りの対象も検証したうえで、`scripts/lint.sh` は非 0 で終わらなければならない（MUST）。shellcheck が指摘を出したときも検証は走らせ、shellcheck と検証のどちらかが失敗していれば非 0 で終わる（SHALL）。検証が通った対象は対象名を 1 行で出し、落ちた対象は `claude plugin validate` の出力をそのまま出す（SHALL）。

守備範囲: この要件が受け取る入力は、このリポジトリで git が追跡している設定ファイル（直下の `.claude-plugin/marketplace.json`、各プラグインの `.claude-plugin/plugin.json` と `hooks/hooks.json` など、`claude plugin validate` が読むもの）と、`scripts/lint.sh` を走らせる環境に入っている `claude` コマンドの 2 つに限る。設定ファイルを書くのはこのリポジトリの開発者（人とエージェント）である。拾いたい誤りは、`claude plugin validate` がエラーとして非 0 で返すもの（予約名を真似たプラグイン名、宣言していない `${user_config.*}`、壊れたパスなど）が、気づかれないまま PR に入ることである。次の入力は通ることを許す: 警告だけの状態（例: plugin.json に `version` が無い、`author` が無い）は終了コード 0 として通す／何をエラーにするかは走らせた `claude` の版が決めるので、古い版では新しい検査（2.1.281 で増えた `${user_config.*}` の宣言漏れなど）が効かないまま通る／追跡されていない作業中のプラグインのディレクトリは検証の対象に入らない／`claude` が無い環境（CI）では検証そのものが走らない（次の要件）／`claude plugin validate` が検査しない誤り（例: hook のスクリプトが実行時に失敗する）はこの要件では拾わない。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: すべて通れば exit 0
- **WHEN** shellcheck の指摘が無く、すべての対象で `claude plugin validate` が 0 を返す状態で `scripts/lint.sh` を引数なしで走らせる
- **THEN** リポジトリ直下と各プラグインのディレクトリのそれぞれについて `claude plugin validate <対象>` が `--strict` なしで 1 回ずつ呼ばれ、終了コードは 0 である

#### Scenario: 1 つのプラグインが落ちれば非 0 で、残りも検証する
- **WHEN** 2 つのプラグインのうち 1 つ目で `claude plugin validate` が 1 を返す状態で `scripts/lint.sh` を走らせる
- **THEN** 2 つ目のプラグインも検証され、落ちた対象の検証の出力が表示され、終了コードは 0 以外である

#### Scenario: 予約名のプラグインで落ちる
- **WHEN** 本物の `claude` がある環境で、どれか 1 つのプラグインの plugin.json の `name` を `claude-x` に変えて `scripts/lint.sh` を走らせる
- **THEN** 終了コードは 0 以外で、`name` を元に戻して走らせると 0 である

### Requirement: claude コマンドが無い環境では検証を飛ばして理由を出す
`claude` コマンドが見つからないとき、`scripts/lint.sh` は公式の検証を飛ばし、飛ばしたことと理由を出力しなければならない（MUST）。このとき検証を失敗として扱ってはならず（MUST NOT）、終了コードは shellcheck の結果だけで決める（SHALL）。

#### Scenario: claude が無ければ shellcheck の結果だけで終わる
- **WHEN** PATH に `claude` が無く、shellcheck の指摘が無い状態で `scripts/lint.sh` を走らせる
- **THEN** 出力に `claude plugin validate` を飛ばしたことと、`claude` コマンドが見つからないという理由が含まれ、終了コードは 0 である

### Requirement: フィルタ引数は検証の対象にも効く
`scripts/lint.sh` にフィルタ引数が渡されたとき、検証するプラグインは、パス `plugins/<name>/` にいずれかのフィルタが部分一致するものに絞らなければならない（MUST。shellcheck の対象と同じ OR の規則）。フィルタ引数があるとき、リポジトリ直下は検証しない（SHALL）。フィルタに一致するプラグインが 1 つも無いときは、検証の対象が無いことを出力して検証を飛ばし、それを失敗として扱ってはならない（MUST NOT）。

#### Scenario: フィルタに一致するプラグインだけを検証する
- **WHEN** プラグイン `alpha` と `beta` があり、`scripts/lint.sh alpha` を走らせる
- **THEN** `claude plugin validate` は `plugins/alpha` に対してだけ呼ばれ、`plugins/beta` とリポジトリ直下に対しては呼ばれない

#### Scenario: 一致するプラグインが無くても失敗にしない
- **WHEN** フィルタが `*.sh` には一致するがどのプラグインのパスにも一致しない状態で `scripts/lint.sh <フィルタ>` を走らせ、shellcheck の指摘は無い
- **THEN** `claude plugin validate` は 1 回も呼ばれず、終了コードは 0 である

### Requirement: hooks.json の command は CLAUDE_PLUGIN_ROOT を含むパスを二重引用符で囲む
各プラグインの `hooks/hooks.json` の command が `${CLAUDE_PLUGIN_ROOT}` を使うとき、`${CLAUDE_PLUGIN_ROOT}` を含むパス全体を二重引用符で囲まなければならない（MUST。例: `"\"${CLAUDE_PLUGIN_ROOT}/scripts/session-tripwires.sh\""`）。展開後のパスに空白があっても、コマンドが複数の語に割れないようにするためである。

#### Scenario: 引用符なしの警告が出ない
- **WHEN** hooks.json を持つ 4 プラグイン（capability-registry / cost-ledger / dev-workflow / worktree）のそれぞれについて `claude plugin validate plugins/<name> 2>&1 | grep -c 'without quotes'` を走らせる
- **THEN** どのプラグインでも 0 である

#### Scenario: command の値が引用符で始まり引用符で終わる
- **WHEN** 追跡されているすべての `plugins/*/hooks/hooks.json` を読み、`${CLAUDE_PLUGIN_ROOT}` を含む command の値を集める
- **THEN** どの値も `"${CLAUDE_PLUGIN_ROOT}/` で始まり `"` で終わる
