# dev-workflow-synced-skills-name-only Specification

## Purpose
TBD - created by archiving change dev-workflow-synced-skills-name-only. Update Purpose after archive.

## Requirements

### Requirement: 同期スキルの名前は skills/synced 配下のディレクトリ名から取り、anthropic-skills: を付ける
`synced-skills-name-only.sh` は、設定ディレクトリ（`CLAUDE_CONFIG_DIR`、未設定なら `$HOME/.claude`）の `skills/synced/<バケット>/<名>/SKILL.md` がある `<名>` を同期スキルとし、`skillOverrides` のキーを `anthropic-skills:<名>` としなければならない（MUST）。名前が `.` で始まるものはバケットにも `<名>` にも数えてはならず（MUST NOT）、バケットが複数なら和集合を取る（MUST）。

守備範囲: 入力は Claude Code が書く `skills/synced` の構成。拾いたい誤りは、同期スキルでないものをキーにすることと取りこぼし。使われていない古いディレクトリ（`staleDirs` など）や別アカウントのバケットがキーになる／`SKILL.md` が壊れていても存在すればキーになる、は通すことを許し、塞ぎ切ることは完了条件にしない。

#### Scenario: 同期スキルをキーとして列挙する
- **WHEN** 一時ディレクトリの設定ディレクトリに `skills/synced/org_acct/pdf/SKILL.md` と `skills/synced/org_acct/docs/SKILL.md` を置き、さらに `skills/synced/.bucket-x/pdf2/SKILL.md` と `skills/synced/org_acct/.hidden/SKILL.md`、`skills/synced/org_acct/.last-complete-round`（ファイル）を置いて `--dry-run` で実行する
- **THEN** 足す候補は `anthropic-skills:pdf` と `anthropic-skills:docs` の 2 つだけ

### Requirement: skillOverrides には name-only で足し、既存のキーの値と他の設定を変えない
スクリプトは `skillOverrides` に、まだ無いキーだけを値 `name-only` で足さなければならない（MUST）。同じキーが既にあれば値が何であっても変えてはならず（MUST NOT）、`skillOverrides` 以外のトップレベルのキーと既存の `skillOverrides` のキーはそのまま残さなければならない（MUST）。

#### Scenario: 既存の値を上書きしない
- **WHEN** `settings.json` が `{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"off","mine":"on"}}` で、同期スキルが pdf と docs の場合に適用する
- **THEN** `skillOverrides` は `anthropic-skills:pdf` が `off` のまま、`mine` が `on` のまま、`anthropic-skills:docs` が `name-only` で加わり、`model` は `opus` のまま

#### Scenario: skillOverrides が無い設定にも足せる
- **WHEN** `settings.json` が `{"model":"opus"}` の場合に適用する
- **THEN** `skillOverrides` が同期スキルの数だけの `name-only` で作られ、`model` は `opus` のまま

### Requirement: 足すものが無いとき、同期スキルが無いとき、dry-run のときは書かない
足すキーが 0 本のとき、および `--dry-run` のとき、スクリプトは `settings.json` を変更してもバックアップを作ってもならない（MUST NOT）。同期スキルの有無は `settings.json` を読む前に判定し、無ければその旨を標準出力に出して、`settings.json` が壊れていても exit 0 で終わらなければならない（MUST）。適用の出力には足したキーを 1 行 1 件で列挙しなければならない（MUST）。

#### Scenario: 同期スキルが無い環境
- **WHEN** `skills/synced` が無い設定ディレクトリで適用する
- **THEN** 出力に同期スキルが無い旨があり、`settings.json` は変わらず、バックアップは作られず、終了コードは 0

#### Scenario: 同期スキルが無ければ壊れた設定でも成功する
- **WHEN** 同期スキルが無い設定ディレクトリで、`settings.json` の中身が JSON でない状態で適用する
- **THEN** 終了コードは 0 で、`settings.json` は変わらない

#### Scenario: 2 回目の実行は何も書き換えない
- **WHEN** 適用した直後にもう一度適用する
- **THEN** `settings.json` の内容と更新時刻は 1 回目の直後のまま、バックアップは増えない

#### Scenario: 増えた分だけを足す
- **WHEN** 適用したあとに同期スキルが 1 本増えて、もう一度適用する
- **THEN** 足されるのは増えた 1 本だけで、すでに入っていたキーの値は変わらない

#### Scenario: dry-run は書かずに候補を見せる
- **WHEN** `--dry-run` で実行する
- **THEN** 足すキーが出力に出て、`settings.json` は変わらず、バックアップは作られない

### Requirement: 書き込みはバックアップを取り、symlink と権限を保つ
足すときは、既存の `settings.json` があればその書き込みの前に `settings.json.bak-<日時>` を作り（MUST。無いときはバックアップを作らず `{}` から作る）、同じディレクトリの一時ファイルに書いてから置き換えなければならない（MUST）。`settings.json` が symlink のときは symlink を残して指す先の実体を書き換え、書き換えたあとの権限は書き換え前と同じにしなければならない（MUST）。

#### Scenario: 設定ファイルが無いときは作り、バックアップは作らない
- **WHEN** 同期スキルがあり `settings.json` が無い設定ディレクトリで適用する
- **THEN** `settings.json` が作られて同期スキルの数だけの `name-only` が入り、`settings.json.bak-*` は作られない

#### Scenario: symlink と権限を保つ
- **WHEN** `settings.json` が別の場所の実体への symlink で、実体の権限が 0644 の状態で適用する
- **THEN** `settings.json` は symlink のままで、実体にキーが足され、実体の権限は 0644 のまま

### Requirement: 読めない設定と不正な呼び方は書かずに失敗する
同期スキルが 1 本以上あるとき、`settings.json` が JSON として読めない、最上位がオブジェクトでない（`[]`、`null` など）、または `skillOverrides` がオブジェクトでないときは、何も書かずに非 0 で終わり、理由を標準エラーに出さなければならない（MUST）。`jq` が使えないとき、`--dry-run` 以外の引数を渡されたときも、何も書かずに非 0 で終わらなければならない（MUST。この2つの検査は同期スキルの列挙より先で、同期スキルが無い環境でも非 0 になる）。

守備範囲: 入力は利用者が手で編集することもある `settings.json` と、打ち間違えうる引数。拾いたい誤りは、読めない設定を空と見なして既存の設定を消すことと、打ち間違いが確認なしの書き込みになること。次の入力は誤ったまま通ることを許す: `skillOverrides` の既存の値が未知のモード名でもそのまま残す／他のキーの中身が不正でも検査しない／書き込み中に別のプロセスが同じファイルを書く競合。これらの穴を塞ぎ切ることは完了条件にしない。

#### Scenario: 壊れた settings.json
- **WHEN** 同期スキルがある設定ディレクトリで、`settings.json` の中身が JSON でない状態で適用する
- **THEN** 終了コードは非 0 で、`settings.json` の内容は変わらず、バックアップは作られない

#### Scenario: 最上位がオブジェクトでない
- **WHEN** 同期スキルがある設定ディレクトリで、`settings.json` の中身が `[]`（または `null`）の状態で適用する
- **THEN** 終了コードは非 0 で、`settings.json` の内容は変わらず、バックアップは作られない

#### Scenario: skillOverrides がオブジェクトでない
- **WHEN** 同期スキルがある設定ディレクトリで、`settings.json` が `{"skillOverrides":["x"]}` の状態で適用する
- **THEN** 終了コードは非 0 で、`settings.json` の内容は変わらず、バックアップは作られない

#### Scenario: 未知の引数
- **WHEN** 同期スキルがある設定ディレクトリで `--dry-rnu` を付けて実行する
- **THEN** 終了コードは非 0 で、`settings.json` は変わらず、バックアップは作られない

#### Scenario: jq が無い
- **WHEN** `jq` を含まない（必要なコマンドだけを置いた）ディレクトリだけを `PATH` にして、同期スキルの有無を問わず実行する
- **THEN** 終了コードは非 0 で、`settings.json` は変わらない

### Requirement: 設定コマンドは内容を見せて確認を取ってから書く
`plugins/dev-workflow/commands/synced-skills-slim.md` は、まず `--dry-run` の結果を見せ、足すキーがあるときは確認を得てから `--dry-run` なしで実行しなければならない（MUST）。断られたらスクリプトを `--dry-run` なしで呼ばず、`settings.json` を変更してはならない（MUST NOT）。`allowed-tools` に `AskUserQuestion` を含め（MUST）、コマンドを `plugins/dev-workflow/.claude-plugin/plugin.json` の `commands` に登録しなければならない（MUST）。`SessionStart` などの hook から確認なしにスクリプトを呼んではならない（MUST NOT）。

#### Scenario: コマンドが plugin.json に登録されている
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` の `commands` を読む
- **THEN** `./commands/synced-skills-slim.md` が含まれ、そのファイルが存在する

#### Scenario: 確認を挟み、断ったら書かない
- **WHEN** `synced-skills-slim.md` を読む
- **THEN** frontmatter の `allowed-tools` に `AskUserQuestion` があり、本文で `--dry-run` の実行、確認、`--dry-run` なしの実行がこの順に書かれ、断ったときはスクリプトを `--dry-run` なしで呼ばずに終わると書かれている

#### Scenario: hook からは呼ばれない
- **WHEN** `plugins/dev-workflow/hooks/` を調べる
- **THEN** `synced-skills-name-only.sh` を呼ぶ記述が無い

### Requirement: コマンドの案内に戻し方と注意を書く
コマンドの案内には、元に戻す手順（バックアップを戻す方法、または足したキーだけを `jq` で消す方法）、`name-only` は名前を指定した呼び出しが動くが名前を指定しない依頼での自動選択は比較していないこと、実測した Claude Code の版を書かなければならない（MUST）。

#### Scenario: 案内に戻し方がある
- **WHEN** コマンドのファイルを読む
- **THEN** `settings.json.bak-` を戻す手順と `del(.skillOverrides` を使う手順の両方が書かれている
