## Context

`/cost` のコマンド本文は Bash で `python3 "$CL" cost $ARGUMENTS` を呼ぶ。実機の観測（issue #729 のコメント）で次が分かった。

- 本文の Bash 実行に `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` は渡らない
- 本文の `${user_config.LEDGER_PATH}` は、コマンド読み込み時に設定値へ置換される（`${CLAUDE_PLUGIN_ROOT}` も同様）
- 未設定のとき `${user_config.LEDGER_PATH}` は置換されず、文字列のまま残る

## Goals / Non-Goals

**Goals**
- `LEDGER_PATH` だけを `/config` で設定した人でも、`/cost` が台帳から読む
- 未設定の人（`COST_LEDGER_PATH` だけの人を含む）の動きを変えない

**Non-Goals**
- Stop hook の経路の変更（hook には環境変数が渡るので #713 のまま）
- `CLAUDE_PLUGIN_ROOT` の扱いの変更（既存の glob 探索は残す）

## Decisions

**決定 1: 本文の `${user_config.LEDGER_PATH}` を環境変数に写して渡す。** 集計の呼び出しを `CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' python3 "$CL" cost $ARGUMENTS` にする。`cost_ledger.py` は #713 で既にこの環境変数を最優先で読むので、スクリプト側の優先順位（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が `COST_LEDGER_PATH` に勝つ）がそのまま `/cost` にも効く。

- 案 A（採用）: 本文の置換値を環境変数で渡す。実機で置換が効くことを確認済み。コマンド側の変更は 1 行で、台帳パスの解決は引き続き `ledger_path()` の 1 か所。
- 案 B: Python が Claude Code の設定ファイル（`pluginConfigs`）を直接読む。設定ファイルの場所と形式は内部実装で、公式の契約に無い。却下。
- 案 C: `/cost` は台帳を読まず、`COST_LEDGER_PATH` だけを案内し続ける。`/config` で設定した人との食い違いが残る。却下。

**決定 2: 置換されず残ったプレースホルダは `ledger_path()` が未設定として扱う。** 未設定のとき渡る値は文字列 `${user_config.LEDGER_PATH}` で、そのままだと「空でない値」として `COST_LEDGER_PATH` に勝ち、リポジトリ相対のパスと解釈されてしまう。判定は `ledger_path()`（台帳の場所を決める唯一の入口）に置く: `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` の値が `${user_config.` で始まるときは空文字と同じに扱い、`COST_LEDGER_PATH` に落ちる。シェル側の `case` に置く案は、判定の文字列自体が本文の置換に巻き込まれうるので採らない。bats で `ledger_path()` を直接検査できる点でも Python 側がよい。

**決定 3: 案内文は `/config` を先に書く。** 未設定時は「会話ログを直接読んで答えたうえで、台帳の置き場所を聞く」のまま（既定の場所は決めない・リポジトリ配下は不可）。決まったら、`/config` でプラグイン設定「台帳ファイルのパス」に設定するよう案内し、続けて従来の方法（`~/.claude/settings.json` の `env` の `COST_LEDGER_PATH`）も使えると添える。初回の取り込み `ledger-sync` の案内は残す。

## Risks / Trade-offs

- パスにシングルクォート `'` を含む値は、本文の置換後にシェルの引用が壊れる。台帳のパスは利用者が選ぶ置き場所で、通常は含まないため、案内文に「`'` を含まないパスにする」と 1 行書いて受け入れる（その場合も `/cost` は壊れるだけで、台帳へは書かない）。
- 置換が効かない将来の版では、`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` にプレースホルダの文字列が入る。決定 2 により未設定扱いになり、`/cost` は従来どおり `COST_LEDGER_PATH` か会話ログ直読みに落ちる（安全側）。
