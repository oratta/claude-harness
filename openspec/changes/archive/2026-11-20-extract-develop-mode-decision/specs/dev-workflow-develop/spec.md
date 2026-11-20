## MODIFIED Requirements

### Requirement: 実行モードは引数・印・依頼の届き方で開始時に決める

本体は develop の新規開始時に 1 回、`plugins/dev-workflow/scripts/develop-mode.sh [--unmanned] [--channel-request]` を呼んで実行モードを決めなければならない（MUST）。develop の引数に `--unmanned` があれば同名フラグを、依頼の発言本文が `<channel source=` で始まれば `--channel-request` を渡す（MUST）。スクリプトは次の順を守る（MUST）。

1. `--unmanned` があれば unmanned、理由は `引数`
2. プロセスの `DEV_WORKFLOW_UNATTENDED` の前後の空白を git ガードと同じ規則で除き（Python の `.strip()` 相当）、未設定・空・`0` 以外なら channel、理由は `印`。印なしで `--channel-request` があれば channel、理由は `チャンネルの依頼`
3. どちらでもなければ interactive、理由は `既定`

成功時は `実行モード: <モード>（<理由>）` の改行付き 1 行だけを stdout に出し、stderr は空で exit 0 とする（MUST）。`--help` または `-h` 単独は入力条件・印の読み方・優先順・出力と終了コードを stdout に出して exit 0 とする（MUST）。判定フラグは順不同で、重複は有無として扱う。引数誤りは stdout 空・使い方を stderr に出して exit 1 とし、実行に必要な処理系が使えないときも stdout 空・理由を stderr に出して exit 1 とする（MUST）。スクリプトは GitHub・モデル・Git を呼ばず、状態や設定ファイルを読み書きしない（MUST NOT）。

本体は成功した 1 行を develop 開始コメントに記録しなければならない（MUST）。エラー時はモードを推測せず stderr を添えて報告して止まる（MUST）。途中でモードを変えてはならない（MUST NOT）。新しいセッションで引き継ぎから再開するときは、引き継ぎの `実行モード` の値を使い、スクリプトで決め直さない（MUST）。

SKILL.md「モードの決め方」は、スクリプトの呼び方 1 行（両フラグの入力条件を含む）と、4 通りの正常出力・exit 1 を受けた本体の動きを示す分類表を持つ（MUST）。優先順・印の正規化・許容例の説明を重複掲載しない（MUST NOT）。開始コメントへの記録・途中で変えないこと・引き継ぎの値を使うこと・直後の channel.md の読み込み案内は残す（MUST）。channel.md を読むのは channel に決めた直後で、引数の分岐や issueify の主への質問より前とする。引き継ぎから channel で再開したときとコンパクト後に読み直した開始コメントが channel のときも同じで、interactive・unmanned では読まない（MUST）。

この要件の守備範囲は、画面を見ている人のいないセッションやチャンネルで頼まれた開発が interactive になって AskUserQuestion で止まることを防ぐことである。入力は呼び手が今回の依頼から選んだフラグとプロセスの環境変数であり、スクリプトは依頼本文や会話を探さない。拾いたい誤りは、印のある住人と、印が付く前でもオーナーが Discord で頼んだ住人が interactive になること、既存の優先順と正規化が変わること。オーナーが自分の画面の前にいて Discord から頼んだセッションが channel になることは止めない（質問の届く先が変わるだけで止まらない）。印が付かず、依頼もチャンネル以外から届いた住人が interactive になることと、呼び手が届き方を誤認してフラグを付け忘れることは、スクリプトでは塞がない。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 印のあるセッション

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` のセッションで、引数に `--unmanned` の無い develop を始める
- **THEN** スクリプトは `実行モード: channel（印）` を 1 行で返し、stderr 空・exit 0 で、本体はこの行を develop 開始コメントに残す

#### Scenario: 印は無いがチャンネルで頼まれた

- **WHEN** 印の無いセッションで、develop の依頼の発言が `<channel source="plugin:discord:discord" ...>` で始まり、本体が `--channel-request` を渡す
- **THEN** スクリプトは `実行モード: channel（チャンネルの依頼）` を 1 行で返し、stderr 空・exit 0 で、本体はこの行を develop 開始コメントに残す

#### Scenario: 印の値が 0

- **WHEN** `DEV_WORKFLOW_UNATTENDED=0` のセッションで、画面の入力欄から develop を頼まれる
- **THEN** スクリプトは `実行モード: interactive（既定）` を 1 行で返し、stderr 空・exit 0 で、本体は interactive に決める

#### Scenario: SKILL.md の文面

- **WHEN** SKILL.md「モードの決め方」を読む
- **THEN** 両フラグの入力条件を含む呼び方 1 行と、4 通りの出力・exit 1 の扱いの分類表がある。判定の優先順と印の正規化の説明は無く、開始コメントの `実行モード: <モード>（<理由>）`、途中で変えないこと、引き継ぎの値を使うこと、末尾の channel.md の案内は残っている

#### Scenario: unmanned が他の入力に優先する

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` で `--unmanned --channel-request` を渡す。フラグの順を逆にした場合も、各フラグを重複して渡した場合も確かめる
- **THEN** すべて `実行モード: unmanned（引数）` の 1 行、stderr 空・exit 0 である

#### Scenario: 印がチャンネルの依頼の理由に優先する

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` で `--channel-request` を渡し、`--unmanned` は渡さない
- **THEN** `実行モード: channel（印）` の 1 行、stderr 空・exit 0 である

#### Scenario: 空白を除いた印なしの値

- **WHEN** 変数が未設定・空・空白だけ・`0`・前後に空白のある `0` のそれぞれで、フラグなしで呼ぶ。空白には space・tab・CR・LF・NBSP・全角空白を含める
- **THEN** すべて `実行モード: interactive（既定）` の 1 行、stderr 空・exit 0 である。同じ値で `--channel-request` だけを付ければ `実行モード: channel（チャンネルの依頼）` になる

#### Scenario: 0 以外の非空の印

- **WHEN** 変数が `1`・`false`・`00`・前後に空白のある非空文字列のそれぞれで、`--unmanned` を渡さず呼ぶ
- **THEN** すべて `実行モード: channel（印）` の 1 行、stderr 空・exit 0 である

#### Scenario: help と引数誤り

- **WHEN** `--help` と `-h` をそれぞれ単独で呼び、その後に未知の `--unknown`、位置引数 `1686`、値付き `--unmanned=true` をそれぞれ渡す
- **THEN** help は呼び方・入力条件・正規化・優先順・出力と終了コードを stdout に出して exit 0。引数誤りはすべて stdout 空、使い方を stderr に出して exit 1 である

#### Scenario: 判定に必要な処理系が無い

- **WHEN** Python 3 が実行できない環境で正常な判定フラグを渡す
- **THEN** モードの行を出さず、stderr に理由を出して exit 1 となる

#### Scenario: 判定は外部の操作をしない

- **WHEN** `gh`・`git`・`claude`・`orca` の呼び出しを記録するスタブを置き、全正常出力・help・引数誤りを実行する
- **THEN** スタブの記録は空のままで、状態・設定ファイルにも変更が無い

#### Scenario: 引き継ぎのモードを維持する

- **WHEN** 引き継ぎの `実行モード` が channel で、新セッションの印が未設定である
- **THEN** 本体はスクリプトを呼んで再判定せず channel を引き継ぎ、既存の案内どおり channel.md を読む
