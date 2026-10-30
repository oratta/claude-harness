## Context

`cld` の関数は README にだけあり、テストは README から関数を取り出して zsh で試している（`tests/account-selector.bats`）。`epic-dispatch.sh` の既定の起動コマンドは `cld` という語で、Orca の端末（Orca が開くシェル）か tmux の `send-keys` で打ち込まれる。受け側は対話シェルなので `.zshrc` の関数が解けていたが、PATH にも関数にも無い端末では起動が止まる。

## Goals / Non-Goals

**Goals:** 端末の準備を「PATH の 1 行と環境変数の 1 行」にする。`epic-dispatch.sh` の既定が `.zshrc` に依存しない。
**Non-Goals:** アカウント選択のロジック（`select-account.sh`）、probe、`accounts.sh` の変更。Pro の `.zshrc` 固有の `_cld_launch` の取り込み（個人設定で、公開版に混ぜない）。

## Decisions

1. **実行ファイルは bash で書く（zsh でなく）。** 非ログイン・非対話のシェルから呼ばれ、macOS 標準の bash 3.2 でも動くようにする。`CLAUDE_HARNESS_SCRIPTS` が未設定なら、実行ファイル自身の位置（symlink を解いた先）から `../scripts` を求める。設定済みならそれを使う（今の README と同じ上書き口）。
2. **`CLD_DEFAULT_ARGS` はシェルの語分割で `claude` の引数の先頭に置く。** 値は空白区切りで、引用が要る引数は扱わない（個人の既定フラグはどれも単純な語。引用を解釈する実装は `eval` が要り、環境変数の値をコードとして実行することになるので採らない）。呼び出し側の引数はその後ろに引用を保ったまま足す。
3. **`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` は外から渡された値があればそのまま子の `claude` に渡す。** 未設定のときに既定値を足すかどうかは、公開版に個人設定を混ぜない方針に従い、実行ファイルでは足さない（Pro の `.zshrc` の 120000 は個人設定。必要な人が自分の `.zshrc` の環境変数の行で渡す）。`reply-after-idle.md` の「主の起動コマンドが未設定のときだけ 120000 を入れる」の運用は変えない（置き場が `cld` の関数から利用者の環境変数に変わるだけ）。
4. **`epic-dispatch.sh` の既定は `bin/cld` の絶対パス（スクリプト自身の位置から `../bin/cld`）。** 比較した案: (a) 既定を `cld` のままにして PATH に頼る — 非ログインのシェルで解けず、受け入れ条件を満たさない。(b) `PATH=<bin>:$PATH cld ...` を前置する — 起動コマンドの語が増え、`EPIC_DISPATCH_CLAUDE_CMD` で差し替える人が前置を意識しなければならない。(c) 絶対パス — 採用。空白を含むパスは単一引用符で包む。実行ファイルが無い（古い clone など）ときは従来の `cld` に戻す。`EPIC_DISPATCH_CLAUDE_CMD` を設定した人は今までどおりその値が勝つ。
5. **子セッションの `--dangerously-skip-permissions` は `CLD_DEFAULT_ARGS` から来る。** これまで `cld` の関数が付けていた（`epic.md` 140 行目）。環境変数に移るので、子を起動するシェル（Orca の端末・tmux のウィンドウ）に `CLD_DEFAULT_ARGS` が届く必要がある。両方とも対話シェルとして `.zshrc` を読むので、README の「環境変数の 1 行」を `.zshrc` に書けば届く。届かない端末では子は許可確認で止まるので、README と `epic.md` に「子で許可を飛ばしたいなら `CLD_DEFAULT_ARGS` を `.zshrc` に書く」と明記する。
6. **既存の関数との共存。** 関数は PATH の実行ファイルに勝つので、関数を消さない端末は古い挙動のまま動く。README に「関数定義と `unalias` の行は消す」と書く。

## Risks / Trade-offs

- 既定が絶対パスになるので、`epic-dispatch.sh` が出す起動コマンドの文字列が変わる（`cld` → `/…/plugins/dev-workflow/bin/cld`）。テストと、他の要件のシナリオが `cld --model …` と書いている箇所は、先頭の語が既定の語に置き換わった形で読む。
- marketplace clone の場所が変わるとパスが変わるが、起動のたびにスクリプトの位置から求めるので記録は残らない。
- `CLD_DEFAULT_ARGS` に引用付きの引数を入れても 1 語ずつに割れる（Decision 2）。README に明記する。
