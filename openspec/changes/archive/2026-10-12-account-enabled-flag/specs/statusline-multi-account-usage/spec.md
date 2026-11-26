## ADDED Requirements

### Requirement: オフのスロットは値の代わりに off を 1 行出す
スロットが複数あるとき、`plugins/statusline/scripts/statusline.sh` は、オフのスロット（`usage-account-registry` capability の要件「スロットを enabled でオフにできる」。`enabled` が JSON の `false` のスロットだけ）のうち active でないものについて、レートリミットの行の代わりに `off` の行を 1 行だけ出さなければならない（SHALL）。行の位置はレジストリの宣言順のままとする。

`off` の行は、非 active 行と同じ行頭（半角スペース 2 つ、`DIM` の `label`、label 列の幅までの詰め、半角スペース 2 つ）に `DIM` の `off` を続けたものでなければならない（SHALL）。この行には使用率・バー・リセットまでの残り時間・取得からの経過時間を出してはならない（MUST NOT）。セッション記録や snapshot にそのスロットの値が残っていても描かず、値が 1 つも無くても行は出す。要件「値が得られたスロットごとにレートリミット行を描画する」の「5h 消化率が得られない非 active スロットは行を出さない」は、オフのスロットには適用しない。行を消さないのは、登録してあるアカウントが表示から消えると「登録が壊れた」のか「オフにした」のかを見分けられないため。

オフのスロットも label 列の幅の計算と、スロットが複数かどうかの判定に数えなければならない（SHALL）。オンのスロットが 1 つでオフのスロットが 1 つのレジストリは複数スロットとして扱い、active の目印と label 列を出す。

active スロットがオフの場合（`CLAUDE_SECURESTORAGE_CONFIG_DIR` を手で設定してオフのアカウントで起動したセッションのほか、オフにした既定アカウントへ自動選択が縮退して起動したセッション、起動したあとでそのアカウントをオフにしたセッション）は、`off` を出さず、要件「active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く」のとおりライブ値で描かなければならない（SHALL）。いま使っているアカウントの残量を隠さないため。スロットが 1 つだけのレジストリでは、そのスロットがオフでも要件「スロットが 1 つのときは現行と同一の出力にする」が優先する。

`enabled` がどのスロットにも書かれていないレジストリでは、出力はこの変更の前とバイト単位で同一でなければならない（SHALL）。statusline は他プラグインのスクリプトを実行時に読まず、`enabled` の読み取りを自分で実装しなければならない（SHALL）。

目標レイアウト（`B` がオフ）:

```
▸ A  5h      ▓▓▓▓▓▓▓▓░░░░░░░░  55%          ~4h 12m
▸ A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  82%/74%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%   ~2d 3h
  B  off
```

#### Scenario: オフのスロットは off の 1 行になる
- **WHEN** 2 スロットのレジストリで非 active の `B` が `enabled: false`、snapshot とセッション記録に `B` の値がある状態で statusline を実行する
- **THEN** `B` の行は 1 行だけで、ANSI エスケープを取り除くと `  B  off` になり、`B` の使用率・バー・経過時間はどこにも出ない

#### Scenario: 値が無いオフのスロットも行を出す
- **WHEN** 非 active の `B` が `enabled: false` で、snapshot にもセッション記録にも `B` の値が無い状態で statusline を実行する
- **THEN** `B` の `off` の行が 1 行出る

#### Scenario: enabled を書いていないレジストリでは出力が変わらない
- **WHEN** どのスロットにも `enabled` が無い 2 スロットのレジストリと、全スロットに `"enabled": true` を書いた同じ内容のレジストリを、同じ stdin・snapshot・セッション記録で順に与えて statusline を実行する
- **THEN** 2 つのレジストリで出力がバイト単位で一致する
- **AND** `enabled` を書いていないレジストリを使う既存のバイト同一のテストは、期待値を変えずに通る

#### Scenario: enabled が true のスロットは従来どおり描く
- **WHEN** 非 active の `B` に `"enabled": true` を書いたレジストリと、`B` の値を含む snapshot を与えて statusline を実行する
- **THEN** `B` の行は `enabled` を書かない場合とバイト単位で同じになる

#### Scenario: active のスロットがオフでもライブ値で描く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が `enabled: false` のスロット `B` の `securestorage` と一致し、stdin に `rate_limits` がある状態で statusline を実行する
- **THEN** `B` の行は `▸ ` で始まり stdin のライブ値で描かれ、`off` は出ない

#### Scenario: オフのスロットの label も列幅に数える
- **WHEN** オンのスロットの `label` が `A`、オフのスロットの `label` が `仕事`（表示幅 4）であるレジストリで statusline を実行する
- **THEN** `A` の行の `5h` の開始位置と、`仕事` の行の `off` の開始位置（表示幅）が一致する
