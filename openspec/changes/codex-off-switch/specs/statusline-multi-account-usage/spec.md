## ADDED Requirements

### Requirement: Codex がオフのとき Codex 行は off を出し、取得しない
レジストリの `codex.enabled` が `false`（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」）のとき、`plugins/statusline/scripts/statusline-codex.py` は、使用量の代わりに `off` の 1 行だけを標準出力に出して終わらなければならない（SHALL）。`codex` の起動（`app-server`）、Codex の認証ファイルの読み出し、キャッシュ（`.statusline-codex`）の読み書き、`--refresh` の子プロセスの起動のいずれも行ってはならない（MUST NOT）。出力は 2 通りに分かれる（SHALL）。通常の描画（引数なし、または `--read`）は `off` と改行の 1 行、`--refresh` は何も出さず（標準出力は空）に終わる。`--refresh` は描画用の出力を持たない子プロセスなので、`off` を出さない。

この要件は、要件「Codex のアカウント上限を最後に1行追加する」と要件「Codex リセット権の残数と期限を表示する」に優先する（SHALL）。この 2 つの要件が求める使用量・リセット権の描画とキャッシュの読み取りは、Codex がオフのときは適用しない。オフのとき、認証済みで取得済みのキャッシュが残っていても、使用量もリセット権も描かず、キャッシュも読まない（残ったキャッシュは消さず、オンに戻したとき従来どおり使われる）。

オフの判定は、認証の有無やバイナリの有無の判定より先に行わなければならない（SHALL）。Codex にログインしていない環境でも、オフにした利用者が止めたことを `off` で確認できるようにするため。

`plugins/statusline/scripts/statusline.sh` は、`off` を受け取ったとき、`取得待ち` の行と同じ組み立て（`Codex` のラベル、label 列の幅までの詰め、`DIM`）で、`Codex  off` の 1 行を出さなければならない（SHALL）。使用率・バー・リセット権・取得からの経過時間は出さない。`STATUSLINE_CODEX=0` のときは、従来どおり Codex 行そのものを出さず、オフの設定より優先する。

`codex.enabled` が無い、または `false` 以外のとき、出力は変更前とバイト単位で同一でなければならない（SHALL）。`statusline-codex.py` は他プラグインのスクリプトを実行時に読まず、`codex.enabled` の読み取りを自分で実装しなければならない（SHALL）。

#### Scenario: オフなら off を出して codex を起動しない
- **WHEN** `codex.enabled` が `false` で、`STATUSLINE_CODEX_BIN` に起動を記録するスタブを指定して `statusline-codex.py` を実行する
- **THEN** 標準出力は `off` の 1 行で、スタブは 1 回も起動されず、`.statusline-codex` は作られない

#### Scenario: 認証済みで既存のキャッシュがあってもオフなら off だけ
- **WHEN** `codex.enabled` が `false` で、`auth.json` が有効で、`.statusline-codex` に使用量とリセット権の取得済みの値がある状態で statusline を実行する
- **THEN** Codex 行は `off` だけで、使用量・バー・`リセット` の表示は出ない。`.statusline-codex` は読まれも書き換えられもせず、内容は変わらない

#### Scenario: オフなら認証が無くても off を出す
- **WHEN** `codex.enabled` が `false` で、`CODEX_HOME` に `auth.json` が無い状態で `statusline-codex.py` を実行する
- **THEN** 標準出力は `off` の 1 行になる

#### Scenario: オフなら --refresh は何もしない
- **WHEN** `codex.enabled` が `false` で `statusline-codex.py --refresh` を実行する
- **THEN** 標準出力は空（`off` も出さない）で、`codex` は起動されず、キャッシュも作られない

#### Scenario: statusline.sh は Codex 行を off にする
- **WHEN** `codex.enabled` が `false` の状態で statusline を実行する
- **THEN** ANSI エスケープを取り除いた Codex 行は `Codex` ラベルのあとに `off` だけが続く 1 行で、使用率・バー・経過時間は出ない

#### Scenario: STATUSLINE_CODEX=0 はオフの設定より優先する
- **WHEN** `codex.enabled` が `false` で `STATUSLINE_CODEX=0` の状態で statusline を実行する
- **THEN** Codex 行は出ない

#### Scenario: 設定が無い環境では出力が変わらない
- **WHEN** `codex` を書いていないレジストリと `"codex": {"enabled": true}` のレジストリを、同じ入力と同じキャッシュで順に与える
- **THEN** 2 つの出力は変更前とバイト単位で一致する
