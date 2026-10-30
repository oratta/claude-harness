## MODIFIED Requirements

### Requirement: shell function から選択したアカウントで Claude を起動する
`plugins/dev-workflow/bin/cld`（`cld [claude-args...]`）と `plugins/dev-workflow/bin/cld-account`（`cld-account <slot-id> [claude-args...]`）は、実行ファイルとして置かなければならない（SHALL）。`~/.zshrc` に関数定義を置かず、実行ファイルのあるディレクトリを PATH に入れる 1 行と環境変数の 1 行だけで使えなければならない（SHALL）。`plugins/dev-workflow/README.md` は、その 2 行の設定例と、旧来の関数定義・`unalias` の行を消す手順を示さなければならない（SHALL）。`cld` は起動前に `usage-probe.sh` を best-effort で実行してから自動選択し、`cld-account` は id を selector へ渡して明示選択する。選択値が空なら `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset し、空でなければその値を設定して、残りの引数を引用したまま `claude` へ渡さなければならない（SHALL）。`CLAUDE_HARNESS_SCRIPTS` が設定されていればその `scripts` を、未設定なら実行ファイル自身の位置（symlink を解いた先）から求めた `scripts` を使う。

環境変数 `CLD_DEFAULT_ARGS` が設定されていれば、その値を空白で区切った語を `claude` の引数の先頭に置かなければならない（SHALL。値を `eval` してはならない（MUST NOT））。個人の既定フラグはこの環境変数で渡し、実行ファイルに埋めてはならない（MUST NOT）。環境変数 `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` は、`cld` / `cld-account` が上書きも既定値の追加もしてはならず（MUST NOT）、外から渡された値はそのまま `claude` に届かなければならない（SHALL）。

どちらの実行ファイルも selector の終了状態を検査し、非 0 の場合は Claude の起動を中止して同じ非 0 で終了しなければならない（SHALL）。selector の失敗を空の `securestorage` が返った成功として扱ってはならない（MUST NOT）。

**守備範囲（selector の終了状態と `CLD_DEFAULT_ARGS` の解析）**: ①入力の出どころは、`select-account.sh` の終了状態と stdout、実行したシェルの環境変数（`CLD_DEFAULT_ARGS`・`CLAUDE_HARNESS_SCRIPTS`・`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`）、`cld-account` の第 1 引数である。②拾いたい誤りは、selector の失敗を成功として `claude` を起動すること、`CLD_DEFAULT_ARGS` が `claude` に届かないこと、外から渡した閾値の上書き、slot id が無いのに `claude` を起動すること、symlink 経由の呼び出しで `scripts` を見失うこと。③通ることを許す入力は、`CLD_DEFAULT_ARGS='--dangerously-skip-permissions --remote-control'`（空白区切りの語）、未設定または空の `CLD_DEFAULT_ARGS`（既定引数なしで進む）、`CLAUDE_HARNESS_SCRIPTS` による `scripts` の差し替え、PATH 上の symlink 経由の呼び出し。④引用符や空白を含む引数を `CLD_DEFAULT_ARGS` に入れる書き方など、これ以外の書き損じを網羅して塞ぐことは完了条件にしない（空白区切りの語として扱い、`eval` で補わない）。

#### Scenario: 自動選択と statusline の active 表示が一致する
- **WHEN** `cld` が selector の選んだ非空の `securestorage` で Claude を起動する
- **THEN** 起動したセッションの statusline は同じレジストリスロットを active として表示する

#### Scenario: 既定アカウントでは環境変数を解除する
- **WHEN** selector が既定アカウントを表す空行を返す
- **THEN** `cld` は `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset した環境で Claude を起動する

#### Scenario: 未登録 id では Claude を起動しない
- **WHEN** `cld-account` に未登録 id を渡し、selector が stdout を空にして exit 2 で終了する
- **THEN** 実行ファイルも exit 2 で終了し、既定アカウントを含むどのアカウントでも `claude` を起動しない

#### Scenario: slot id が無い cld-account は claude を起動しない
- **WHEN** 引数なしで `cld-account` を実行する
- **THEN** usage を stderr に出して exit 2 で終わり、`claude` は起動しない

#### Scenario: CLD_DEFAULT_ARGS は両方の実行ファイルに適用される
- **WHEN** `CLD_DEFAULT_ARGS='--remote-control'` を設定して `cld-account b --resume` を実行する
- **THEN** `claude` の引数は `--remote-control`・`--resume` の順になり、slot id `b` は渡らない

#### Scenario: symlink 経由と scripts の上書き
- **WHEN** PATH 上の symlink 経由で `cld` を実行する、または `CLAUDE_HARNESS_SCRIPTS` を別の `scripts` に向けて実行する
- **THEN** 前者は実体の位置から求めた `scripts` の selector を、後者は指定した `scripts` の selector を使う

#### Scenario: 関数定義の無い zsh から同じアカウントで起動する
- **WHEN** `.zshrc` に関数定義が無く PATH と環境変数だけの非ログインシェルで `cld` と `cld-account <slot-id>` を実行する
- **THEN** 従来の関数と同じアカウント（selector の選んだ `securestorage`）で `claude` が起動し、引数は引用を保ったまま渡る

#### Scenario: CLD_DEFAULT_ARGS のフラグが claude に渡る
- **WHEN** `CLD_DEFAULT_ARGS='--dangerously-skip-permissions --remote-control'` を設定して `cld --resume` を実行する
- **THEN** `claude` の引数は `--dangerously-skip-permissions`・`--remote-control`・`--resume` の順になる

#### Scenario: 外から渡したアイドル時コンパクトの閾値を上書きしない
- **WHEN** `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=50000` を設定して `cld` を実行する
- **THEN** `claude` の環境の `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` は `50000` のまま。未設定で実行したときは `claude` の環境にも設定されない
