# usage-account-registry Specification

## Purpose
使用量観測の対象となる Claude アカウントを列挙するレジストリ（`accounts.json`）の所在・形状・不正スロットの扱いと、スロットから macOS Keychain のサービス名を導出する規則、および probe と statusline が共有する active スロットの判定規則を定める。レジストリを導入していない環境では既定アカウント 1 つに縮退し、挙動が変わらないことを保証する。

## Requirements

### Requirement: アカウントレジストリの所在と形状
使用量観測の対象となる Claude アカウントは、レジストリファイル `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（環境変数 `CLAUDE_ACCOUNTS_FILE` で上書き可能）に定義されなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を使う運用の前提が「`CLAUDE_CONFIG_DIR` は共有する」ことであるため、レジストリは `CLAUDE_CONFIG_DIR` 配下に置く。

レジストリのトップレベルは**オブジェクト**でなければならず（SHALL）、次の形状に固定する。トップレベルが裸の配列であってはならない（MUST NOT）:

```json
{
  "schema": 1,
  "accounts": [
    { "id": "a", "label": "A", "securestorage": null },
    { "id": "b", "label": "B", "securestorage": "/Users/example/.claude-b" }
  ],
  "codex": { "enabled": false }
}
```

- `schema`: 整数。省略時は `1` とみなす
- `accounts`: スロットの配列（必須）
- `codex`: Codex の設定のオブジェクト（任意）。`codex.enabled` が JSON の `false` のとき Codex は「オフ」で、意味は要件「Codex を codex.enabled でオフにできる」に従う。`accounts` のスロットとは独立で、スロットの配列には何も加えない。このキーを足しても `schema` は `1` のまま変えない
- スロットの `id`: snapshot のキーになる識別子。`^[A-Za-z0-9-]{1,32}$` に一致しなければならない（SHALL）
- スロットの `label`: statusline に表示する短いラベル。省略時は `id` を用いる。**端末上の表示幅**（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は 8 桁に切り詰める（SHALL）。全角 4 文字ぶんにあたる。文字数ではなく表示幅で扱うのは、日本語のラベル（`仕事` など）でも列が揃うようにするため。切り詰めはスロットを捨てる扱いにはしない（長すぎる label は表示上の行き過ぎであって、そのアカウントの行を消すほどの問題ではない）
- スロットの `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する
- スロットの `enabled`: 真偽値。省略時は `true` とみなす。`false` のスロットは「オフ」で、意味は要件「スロットを enabled でオフにできる」に従う。このフィールドを足しても `schema` は `1` のまま変えない（省略時の意味が従来と同じで、古い読み手は未知のキーとして読み飛ばすため）

`codex` の読み取りが扱う入力の守備範囲は、要件「Codex を codex.enabled でオフにできる」に従う。

`accounts` を読む処理は、`codex` を含む未知のトップレベルのキーを無視しなければならない（SHALL）。`accounts-init.sh` は文書を読んで書き戻すとき、`codex` を含むトップレベルのキーを消してはならない（MUST NOT）。

スロットの順序は宣言順を保たなければならない（SHALL）。リポジトリはレジストリの雛形または生成手段（コマンドか README の手順）を提供しなければならない（SHALL）。実ファイル自体はリポジトリに含めない。

#### Scenario: 複数スロットを読む
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null},{"id":"b","label":"B","securestorage":"/tmp/cb"}]}` を与えて読み取り処理を実行する
- **THEN** 宣言順に 2 つのスロットが得られ、それぞれ `id` / `label` / `securestorage` を保つ

#### Scenario: 環境変数でレジストリの場所を上書きする
- **WHEN** `CLAUDE_ACCOUNTS_FILE` に別のパスを設定して読み取り処理を実行する
- **THEN** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json` ではなく、指定されたパスのレジストリが読まれる

#### Scenario: CLAUDE_CONFIG_DIR に追随する
- **WHEN** `CLAUDE_CONFIG_DIR` を一時ディレクトリに設定し、`CLAUDE_ACCOUNTS_FILE` を設定せずに読み取り処理を実行する
- **THEN** レジストリは `$CLAUDE_CONFIG_DIR/accounts.json` から読まれ、`$HOME/.claude/accounts.json` は読まれない

#### Scenario: トップレベルが配列なら不正として扱う
- **WHEN** トップレベルが裸の配列 `[{"id":"a"}]` のレジストリを与えて読み取り処理を実行する
- **THEN** 不正なレジストリとして扱われ、既定アカウントを指すスロットが 1 つだけ得られる

#### Scenario: enabled を書いたスロットを読む
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null},{"id":"b","label":"B","securestorage":"/tmp/cb","enabled":false}]}` を与えて読み取り処理を実行する
- **THEN** 宣言順に 2 つのスロットが得られ、`a` はオン、`b` はオフとして読まれる

#### Scenario: codex を書いたレジストリのスロットは変わらずに読まれる
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}],"codex":{"enabled":false}}` を与えて読み取り処理を実行する
- **THEN** スロットは `a` の 1 つだけが得られ、`codex` はスロットとして数えられない

#### Scenario: accounts-init.sh は codex を消さない
- **WHEN** `"codex": {"enabled": false}` を持つレジストリに対して `accounts-init.sh --id a --label A2` を実行する
- **THEN** `a` の `label` は `A2` に変わり、トップレベルの `codex` は `{"enabled": false}` のまま残る

### Requirement: 不正なスロットの除外と id の一意性
`id` は全スロットで一意でなければならない（MUST）。読み取り処理は次の規則で不正なスロットを除外しなければならない（SHALL）:

- `id` が欠けている、または `^[A-Za-z0-9-]{1,32}$` に一致しないスロットは捨てる
- `id` が既出のスロットと重複する場合、先に現れたものを残し、後のものを捨てる
- スロットは先頭から最大 8 個までを採用し、それを超えるスロットは捨てる（probe の実行時間がスロット数に比例するため）
- `label` または `securestorage` に制御文字（`\t` `\n` `\r` 等の C0 制御文字および DEL）を含むスロットは捨てる。これらの値はスロット一覧として区切り付きで受け渡されるため、区切りを壊すと列がずれ、実在しない「幽霊スロット」が生まれる。幽霊スロットは `securestorage` が空になりやすく既定サービス名に一致して active を乗っ取りうるので、入口で落とす

除外の結果スロットが 0 個になった場合は、レジストリ不在時と同じく既定スロット 1 つに縮退しなければならない（SHALL）。除外はエラーとして扱ってはならない（MUST NOT）。

#### Scenario: id が重複したスロットを捨てる
- **WHEN** 同じ `id` を持つスロットが 2 つ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 先に現れたスロットだけが残り、後のものは捨てられる

#### Scenario: id を欠くスロットを捨てる
- **WHEN** `id` の無いスロットと正しいスロットが 1 つずつ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 正しいスロットだけが得られる

#### Scenario: label を欠くスロットは id を label にする
- **WHEN** `label` の無いスロット（`id` は `"a"`）を含むレジストリを与えて読み取り処理を実行する
- **THEN** そのスロットの `label` は `"a"` になる

#### Scenario: 長すぎる label を表示幅で切り詰める
- **WHEN** 表示幅が 8 を超える `label`（半角 16 文字、または全角 5 文字以上）を持つスロットを与えて読み取り処理を実行する
- **THEN** `label` は表示幅 8 までに切り詰められ、スロット自体は残る

#### Scenario: 制御文字を含むスロットを捨てる
- **WHEN** `label` に改行を含むスロットと正しいスロットが 1 つずつ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 正しいスロットだけが得られ、列のずれによる幽霊スロットは現れない

#### Scenario: 全スロットが不正なら既定スロットに縮退する
- **WHEN** 全スロットが `id` を欠くレジストリを与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

### Requirement: レジストリ不在時は既定スロット 1 つに縮退する
レジストリファイルが存在しない、読み取れない、または JSON としてパースできない場合、読み取り処理は「既定アカウント（`securestorage` が `null`）を指すスロットが 1 つだけ存在するレジストリ」として扱わなければならない（SHALL）。この縮退はエラーとして扱ってはならない（MUST NOT）。

これにより、レジストリを導入していない環境（既定の環境）では使用量観測の挙動が一切変わらない。

#### Scenario: レジストリが存在しない
- **WHEN** レジストリファイルが存在しない状態で読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: レジストリが壊れている
- **WHEN** JSON としてパースできない内容のレジストリファイルを与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: accounts が空配列
- **WHEN** `{"schema":1,"accounts":[]}` を与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られる

### Requirement: スロットから Keychain サービス名を導出する規則
スロットから macOS Keychain のサービス名を導出する規則は、Claude Code 本体の生成ロジックと一致しなければならない（SHALL）:

- `securestorage` が `null` または空文字のとき → `Claude Code-credentials`
- それ以外のとき → `Claude Code-credentials-` + `sha256(<securestorage を NFC 正規化した文字列>)` の先頭 8 桁（小文字 16 進）

#### Scenario: 既定スロットのサービス名
- **WHEN** `securestorage` が `null` または空文字のスロットからサービス名を導出する
- **THEN** サービス名は `Claude Code-credentials` である

#### Scenario: securestorage を持つスロットのサービス名
- **WHEN** `securestorage` に具体的なパスを持つスロットからサービス名を導出する
- **THEN** サービス名は `Claude Code-credentials-` に、そのパスを NFC 正規化した文字列の sha256 の先頭 8 桁を続けたものである

#### Scenario: NFC 正規化を経る
- **WHEN** 合成済み文字と結合文字で表記が異なるが NFC 正規化すると同一になる 2 つのパスからサービス名を導出する
- **THEN** 2 つのサービス名は一致する

### Requirement: active スロットの判定規則
現在アクティブなスロットの判定は、probe と statusline の双方で同一の規則に従わなければならない（SHALL）。突き合わせは `CLAUDE_SECURESTORAGE_CONFIG_DIR` の**値そのものの文字列比較ではなく、その値から導出した Keychain サービス名**で行わなければならない（SHALL）。

サービス名での比較は、Claude Code 本体が認証情報を実際に置く場所と同じ同値関係になる。末尾スラッシュや `~` 展開が異なるパスは本体にとっても別の Keychain 項目であり、サービス名が異なれば「そのスロットの認証情報はそこには無い」ことを正しく意味する。素の文字列比較を使うと、この同値関係とずれて無言の取り違えが起きる。レジストリの `securestorage` には、実際に環境変数へ設定しているのと同一の文字列を記録すること。

判定の優先順位:

1. `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名と一致するスロットがあれば、それを active とする。**環境変数が未設定または空文字の場合も、空文字からの導出（＝既定サービス名 `Claude Code-credentials`）として突き合わせる**。既定スロット（`securestorage` が `null` または空文字）が存在すればここで一致する
2. 一致するスロットが無い場合、snapshot の `active` が実在するスロット id を指していればそれを active とする（probe 側では前回の snapshot、statusline 側では現在の snapshot）。既定スロットを持たないレジストリ（全スロットが explicit な `securestorage` を持つ）で環境変数が未設定のときが、この経路に落ちる代表例
3. どちらも得られない場合は最初のスロットを active とする

#### Scenario: サービス名が一致すれば active になる
- **WHEN** スロットの `securestorage` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` が同一の文字列である状態で判定する
- **THEN** 導出されるサービス名が一致し、そのスロットが active になる

#### Scenario: 表記が違えば別の Keychain 項目として扱う
- **WHEN** スロットの `securestorage` が `/Users/example/.claude-b`、`CLAUDE_SECURESTORAGE_CONFIG_DIR` が同じパスに末尾スラッシュを付けた値である状態で判定する
- **THEN** 導出されるサービス名が異なるため一致せず（本体にとっても別の Keychain 項目であるため）、フォールバック（snapshot の `active`、無ければ最初のスロット）に進む

#### Scenario: env がどのスロットにも一致しない
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` がレジストリのどのスロットの `securestorage` とも一致せず、snapshot の `active` が実在するスロットを指す状態で判定する
- **THEN** snapshot の `active` が指すスロットが active になる

#### Scenario: env 未設定は既定スロットに一致する
- **WHEN** 既定スロット（`securestorage` が `null`）を含むレジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定の状態で判定する
- **THEN** 空文字から導出した既定サービス名が一致し、優先順位 1 でその既定スロットが active になる（snapshot の `active` が別のスロットを指していても優先順位 1 が勝つ）

#### Scenario: 手掛かりが無ければ最初のスロット
- **WHEN** 既定スロットを持たないレジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定、かつ snapshot も存在しない状態で判定する
- **THEN** レジストリの最初のスロットが active になる

### Requirement: 起動アカウントを headroom の余りから自動選択する
`plugins/dev-workflow/scripts/select-account.sh` は、引数が無いときに `dev-workflow-headroom` capability の `headroom.compute(now)` を呼び、その `best_by_provider.claude` が指すスロットを選ばなければならない（SHALL）。`now` は環境変数 `SELECT_ACCOUNT_NOW` があればその値、無ければ現在時刻とする。`best`（provider をまたいだ最大）を選択に使ってはならない（MUST NOT。Codex を指すことがあるため）。余り（`surplus_pct`）の数え方・候補の条件・同点の決め方は headroom の要件「一番余っているアカウント（best）を選ぶ」に従い、`select-account.sh` は経過率と使用率から余裕や余りを数え直してはならない（MUST NOT）。`.headroom.json` を読んで選んではならない（MUST NOT。probe が書かなかった実行で古い計算を使わないため）。選択は起動時の 1 回だけであり、起動済みセッションのアカウントを変更してはならない（MUST NOT）。どのスロットを候補に通し、どれを落とすかの守備範囲は、要件「古い・欠測・短期枠逼迫のスロットを候補から外す」の守備範囲の段落に従う。

#### Scenario: リセット権を持つスロットを margin より余りで選ぶ
- **WHEN** 2 スロットのうち `a` は週次 10%・リセット権なし、`b` は週次 40%・次の週次リセットより前に切れるリセット権 1 枚を持ち、margin（週の経過率 − 使用率）では `a` が大きく、`surplus_pct` では `b` が大きい
- **THEN** selector は `b` の `securestorage` を出力し、理由行は `selected=b reason=max-surplus` と、`a` と `b` の margin を小数点以下 2 桁で含む

#### Scenario: Codex が一番余っていても Claude のスロットを選ぶ
- **WHEN** headroom の `best` が Codex の `current` を指し、`best_by_provider.claude` がスロット `a` を指す
- **THEN** selector は `a` の `securestorage` を出力する

#### Scenario: 同点は宣言順で決める
- **WHEN** 利用可能な 2 スロットの `surplus_pct` が等しい（どちらも 0 の場合を含む）
- **THEN** selector は `accounts.json` で先に宣言されたスロットを選ぶ

#### Scenario: 使用量 API を叩かずにセッション記録だけで選ぶ
- **WHEN** usage snapshot が無く、A と B それぞれの鍵のセッション記録だけがあり、`surplus_pct` が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の margin を含める

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択の候補の外し方は、headroom の行の `status` と best の除外規則（`dev-workflow-headroom` の要件「アカウントごとの項目と status」「一番余っているアカウント（best）を選ぶ」）に従わなければならず（SHALL）、`select-account.sh` で独自の検査を足してはならない（MUST NOT）。したがって、取得からの経過時間でスロットを外さず（古さは実効値の規則で扱う）、`status` が `off`・`missing`・`stale` のスロットと、`five_hour_pct` が 90 以上のスロットを外し、`five_hour_pct` が分からない（null）スロットは候補に残す。理由行では、オフを `off`、週次の値が読めないものを `missing`、週次の実効値の `observed_at`（`build_view` がそのスロットに選んだ値の取得時刻。snapshot の値が採用されれば snapshot の取得時刻、セッション記録が採用されればその記録の時刻）が今より 60 秒を超えて未来のものを `stale`、5 時間枠による除外を `five-hour>=90` と書く。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選ばなければならない（SHALL）。このとき、レジストリに既定スロット（`securestorage` が `null` または空文字）があれば宣言順で最初のスロットの id を `selected` に出し、無ければ登録 id では使用できない `@unregistered-default` を出さなければならない（SHALL）。このときの `selected` の決め方は `enabled` を見ない（縮退先は常に既定アカウントであり、`selected` はその起動先を指すスロットを報告するため）。理由は、オンのスロットが 1 つも無ければ `default-due-to-all-off`、オンのスロットに `missing` か `stale` による除外が 1 つでもあれば `default-due-to-missing-usage`、オンのスロットがすべて `five-hour>=90` だけで除外された場合は `default-due-to-five-hour-limit` としなければならない（SHALL）。headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正で `compute` が例外を出したときも、同じ決め方で既定アカウントへ縮退し、理由を `default-due-to-invalid-headroom-setting`、`margins` を `-` として exit 0 で終わらなければならない（SHALL）。

**守備範囲（自動選択の候補の判定と、headroom の設定の不正の扱い）**: ①入力の出どころは、`headroom.compute(now)` が返す Claude のスロットの行（中身はレジストリ `accounts.json`、`build_view` が `.usage-snapshot` とステータスラインのセッション記録から作る週次と 5 時間の実効値、`.usage-snapshot` の `reset_grants`）と、`compute` が中で読む環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` である。各行の `status`（`off`・`missing`・`stale`）を決める判定は `dev-workflow-headroom` の要件「アカウントごとの項目と status」の守備範囲が担い、`select-account.sh` が担うのは、その `status` と `five_hour_pct` を候補・理由行の印・縮退の理由に写すことと、設定の不正による例外を縮退に変えることだけである。Codex の行は選択に使わない。②拾いたい誤りは、使えないスロット（オフ・週次の値が読めない・週次の実効値の `observed_at` が今より 60 秒を超えて未来・5 時間の使用率が 90 以上）を選んでしまうことと、headroom の設定（数でない・0〜100 の外）の誤りで `cld` が Claude を起動できなくなることである。③通してよい入力は、取得から何日もたった値でリセット時刻がまだ先のもの、リセット時刻を過ぎた値（0% として数える）、リセット時刻が 7 日より先の値、`observed_at` が今より 60 秒以内の未来の値、`five_hour_pct` が分からない（null）スロット、`enabled` を書いていないスロット、空文字や未設定の `HEADROOM_*`（既定値で数える）である。値が実際の使用量より低い（取得後の使用を反映していない）ことは検知しない。④この判定は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 古いがリセット前の値で選ぶ
- **WHEN** 片方のスロットの値が 1 日前に取得され、リセット時刻がまだ来ておらず、もう片方より `surplus_pct` が大きい
- **THEN** selector は古い方のスロットを候補に含め、`surplus_pct` が大きい方として選ぶ

#### Scenario: リセット時刻を過ぎた値は 0% として比べる
- **WHEN** スロット `a` の値が週次 95%・リセット時刻が現在より前で、スロット `b` の値が週次 30%・リセット時刻が現在より後である
- **THEN** selector は `a` の週次を 0% として数え、`a` を候補に含める

#### Scenario: 全スロットが欠測のときは登録済み既定スロットへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットで、セッション記録も snapshot の値も無い
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=a reason=default-due-to-missing-usage` と各スロットの `missing` を含める
- **AND** その値で起動したセッションでは環境変数が unset され、statusline の active も `a` になる

#### Scenario: 既定スロットが未登録なら sentinel を表示する
- **WHEN** 全スロットが明示的な非空の `securestorage` を持ち、かつ全スロットが欠測である
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=@unregistered-default reason=default-due-to-missing-usage` を含める
- **AND** `@unregistered-default` は実在する登録 id として扱われない

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** `surplus_pct` が最大のスロットの実効値の `five_hour_pct` が 90 で、別のスロットが 90 未満である
- **THEN** selector は `surplus_pct` が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 全スロットの 5 時間枠が逼迫したときは原因を区別する
- **WHEN** 全スロットの実効値は欠測が無いが、`five_hour_pct` がすべて 90 以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=default-due-to-five-hour-limit` と各スロットの `five-hour>=90` を含める
- **AND** 理由行に `reason=default-due-to-missing-usage` を含めない

#### Scenario: 週次の値が欠測している
- **WHEN** スロットの実効値の週次の使用率かリセット時刻が欠測である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

#### Scenario: 5 時間枠の値が分からないスロットは候補に残す
- **WHEN** スロット `a` の実効値の `five_hour_pct` が欠測で、週次の値は揃っている
- **THEN** selector は `a` を候補に含め、理由行の `a` の欄は margin の値になり `missing` にならない

#### Scenario: 取得時刻が 60 秒を超えて未来のスロットは外す
- **WHEN** スロット `b` の週次の実効値（`build_view` が選んだ値）の `observed_at` が現在より 61 秒先で、スロット `a` の値は現在の取得である
- **THEN** selector は `b` を候補から外し、理由行の `b` の欄を `stale` にする。`observed_at` が現在より 60 秒先なら外さない

#### Scenario: セッション記録が採用されたスロットは記録の時刻で未来を判定する
- **WHEN** スロット `b` の snapshot の取得時刻は現在より 120 秒先だが、`build_view` が `b` の週次の実効値に現在の時刻のセッション記録を採用する
- **THEN** selector は `b` を `stale` にせず候補に含める

#### Scenario: 使用量 API が 429 を返し続けても記録で選ぶ
- **WHEN** usage-probe が全スロットで 429 を受けて snapshot を更新できず、A と B のセッション記録がある
- **THEN** selector は記録から求めた実効値で選び、理由行に `missing` を含めない

#### Scenario: オフのスロットは余りが最大でも選ばない
- **WHEN** スロット `a` がオンで margin が 10、スロット `b` が `enabled: false` で実効値からは `a` より余る
- **THEN** selector は `a` の `securestorage` を出力し、理由行は `selected=a reason=max-surplus` と `margins=a:10.00,b:off` を含む

#### Scenario: enabled を書いていない登録簿では選択が変わらない
- **WHEN** どのスロットにも `enabled` が無い登録簿と、全スロットに `"enabled": true` を書いた同じ内容の登録簿を、同じセッション記録・snapshot で順に与える
- **THEN** 2 つの登録簿で stdout と理由行が一致する

#### Scenario: 全スロットがオフなら既定アカウントへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットが `enabled: false` である
- **THEN** selector は空の `securestorage` を出力して exit 0 で終わり、理由行は `selected=a reason=default-due-to-all-off` と各スロットの `off` を含む

#### Scenario: オンのスロットが欠測でオフのスロットに値があるとき
- **WHEN** 既定スロット `a` がオンで欠測、スロット `b` が `enabled: false` で実効値が揃っている
- **THEN** selector は `b` を選ばず、空の `securestorage` を出力し、理由行は `selected=a reason=default-due-to-missing-usage` と `margins=a:missing,b:off` を含む

#### Scenario: headroom の設定が不正なら既定アカウントで起動させる
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` で、id が `a` の既定スロットがある
- **THEN** selector は空の `securestorage` を出力して exit 0 で終わり、理由行は `selected=a reason=default-due-to-invalid-headroom-setting margins=-` になる

### Requirement: 登録済みスロットを明示選択できる
`select-account.sh <slot-id>` は usage snapshot を読まず、レジストリに登録されたオンのスロットの id の `securestorage` を返さなければならない（SHALL）。id が未登録、または引数が 2 個以上なら stdout に値を出さず exit 2 で終了しなければならない（SHALL）。id がオフのスロット（要件「スロットを enabled でオフにできる」）を指す場合も stdout に値を出さず exit 2 で終了し、stderr の 1 行に、その id・オフであること・戻し方（読んだレジストリファイルのパスと、`accounts.sh on <id>` を実行すること）を含めなければならない（SHALL）。未登録の診断と同じ文面にしてはならない（MUST NOT）。登録はあるのに使えない理由と直し方が、未登録の場合と違うため。

#### Scenario: 登録済み id を snapshot 無しで選ぶ
- **WHEN** 登録済み id を 1 個渡し、usage snapshot が存在しない
- **THEN** selector はそのスロットの `securestorage` を返し、exit 0 になる

#### Scenario: 未登録 id を拒否する
- **WHEN** レジストリに無い id を渡す
- **THEN** selector は stdout に値を出さず、stderr に診断を出して exit 2 になる

#### Scenario: オフのスロットの明示選択を拒否する
- **WHEN** `enabled: false` のスロットの id を 1 個渡す
- **THEN** selector は stdout に値を出さず exit 2 になり、stderr はその id、`enabled`、レジストリファイルのパス、`accounts.sh on <id>` を含む 1 行である

### Requirement: 値と選択理由を別の出力ストリームで返す
成功時の selector は stdout に選んだ `securestorage` の実値だけを改行付きで出さなければならない（SHALL）。既定アカウントの stdout は空行とする。stderr には `selected=<id-or-sentinel> reason=<reason> margins=<entries>` の 1 行だけを出さなければならない（SHALL）。`selected` は選んだ登録スロットの実 id とし、登録されていない既定アカウントへの縮退だけは `@unregistered-default` とする。自動選択の `margins` は全登録スロットを宣言順に含み、候補は headroom の行の `margin`（週の経過率 − 使用率。選択には使わない）を小数点以下 2 桁、候補外は `missing`、`stale`、`five-hour>=90`、`off` のいずれかで示さなければならない（SHALL）。オフのスロットも `margins` から省いてはならない（MUST NOT）。省くと、登録したはずのスロットが選ばれない理由を理由行から読めなくなる。

#### Scenario: shell は stdout だけを値として取り込める
- **WHEN** 自動選択の stdout を command substitution で取得し、stderr を端末へ残す
- **THEN** 変数には `securestorage` の実値だけが入り、選択 id・理由・全スロットの比較は stderr の 1 行で確認できる

#### Scenario: 明示選択の理由を示す
- **WHEN** 登録済み id を明示して選ぶ
- **THEN** stderr は `reason=explicit` と `margins=-` を含む

#### Scenario: オフのスロットも margins に並ぶ
- **WHEN** 2 番目のスロットが `enabled: false` の登録簿で自動選択する
- **THEN** stderr の `margins` は宣言順に 2 スロットを含み、2 番目は `<id>:off` である

#### Scenario: margins は headroom の margin を出す
- **WHEN** 週次リセットが 7 日より先のスロットを含めて自動選択する
- **THEN** そのスロットの `margins` の値は headroom の行の `margin`（経過率を 0〜100 に切り詰めない値）と小数点以下 2 桁で一致する

### Requirement: shell function から選択したアカウントで Claude を起動する
`plugins/dev-workflow/README.md` は zsh の `cld [claude-args...]` と `cld-account <slot-id> [claude-args...]` の設定例を示さなければならない（SHALL）。`cld` は起動前に `usage-probe.sh` を best-effort で実行してから自動選択し、`cld-account` は id を selector へ渡して明示選択する。選択値が空なら `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset し、空でなければその値を設定して、残りの引数を引用したまま `claude` へ渡さなければならない（SHALL）。

どちらの shell function も selector の終了状態を検査し、非 0 の場合は Claude の起動を中止して同じ非 0 で終了しなければならない（SHALL）。selector の失敗を空の `securestorage` が返った成功として扱ってはならない（MUST NOT）。

#### Scenario: 自動選択と statusline の active 表示が一致する
- **WHEN** `cld` が selector の選んだ非空の `securestorage` で Claude を起動する
- **THEN** 起動したセッションの statusline は同じレジストリスロットを active として表示する

#### Scenario: 既定アカウントでは環境変数を解除する
- **WHEN** selector が既定アカウントを表す空行を返す
- **THEN** `cld` は `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset した環境で Claude を起動する

#### Scenario: 未登録 id では Claude を起動しない
- **WHEN** `cld-account` に未登録 id を渡し、selector が stdout を空にして exit 2 で終了する
- **THEN** shell function も exit 2 で終了し、既定アカウントを含むどのアカウントでも `claude` を起動しない

### Requirement: スロットを enabled でオフにできる
スロットの `enabled` が JSON の `false` であるとき、そのスロットは「オフ」として扱わなければならない（SHALL）。`enabled` が省略されているとき、および `true` のときは「オン」とする。`enabled` が真偽値でない（文字列の `"false"`、数値の `0`、`null` など）ときもオンとして扱わなければならず（SHALL）、そのスロットを捨ててはならない（MUST NOT）。オフにするのは利用者が明示したときだけにし、書き損じでアカウントが黙って候補から消えないようにするため。書き損じた場合もオンとして行が残る。この判定が扱う入力は、手で編集した `accounts.json`、`accounts-init.sh` の出力、`accounts.sh on|off` の出力の 3 つである。`false` 以外の書き損じを見つけて報告することはこの要件の範囲外で、新しい書き損じの形が見つかっても判定を増やさない（オフになる条件は `false` との一致 1 つのままにする）。

オフのスロットは次のように扱わなければならない（SHALL）:

- 起動時の自動選択の候補にしない（要件「古い・欠測・短期枠逼迫のスロットを候補から外す」）
- 明示選択を拒否する（要件「登録済みスロットを明示選択できる」）
- 使用量を取得しない（要件「オフのスロットは使用量を取得しない」）
- ステータスラインでは非 active の行を出さず、active ならライブ値で描く（`statusline-multi-account-usage` capability）

オフのスロットもレジストリのスロットであり続ける。宣言順、先頭 8 個までの上限、`id` の一意性、不正なスロットの除外、active スロットの判定は、オンのスロットと同じ規則で数えなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を手で設定してオフのスロットのアカウントで起動したセッションでは、そのスロットが active になる。`enabled` はアカウントの認証情報にも、セッション記録・snapshot に残っている値にも触れない。オンに戻せば、残っている値からそのまま再開する。

レジストリを読む 6 か所（`usage_view.py`、`select-account.sh`、`usage-probe.sh`、`statusline.sh`、`accounts-init.sh`、`accounts.sh list`）は、この同じ意味で `enabled` を読まなければならない（SHALL）。

#### Scenario: false だけがオフになる
- **WHEN** `enabled` が `false`、`true`、省略、文字列 `"false"`、数値 `0`、`null` の 6 スロットを与えて読み取り処理を実行する
- **THEN** `false` のスロットだけがオフとして読まれ、残りの 5 つはオンとして読まれる。6 つとも捨てられない

#### Scenario: オフのスロットも上限と順序に数える
- **WHEN** 先頭がオフのスロットである 9 スロットのレジストリを与えて読み取り処理を実行する
- **THEN** 先頭 8 スロットが宣言順に得られ、オフのスロットはその 1 番目に含まれる

#### Scenario: オフのスロットも active になりうる
- **WHEN** `enabled: false` のスロットの `securestorage` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` が同一の文字列である状態で active を判定する
- **THEN** そのオフのスロットが active になる

### Requirement: オフのスロットは使用量を取得しない
`plugins/dev-workflow/scripts/usage-probe.sh` は、オフのスロットについて使用量を取得してはならない（MUST NOT）。認証情報の読み出し（Keychain と平文の credentials ファイル）も使用量 API の呼び出しも行わず、試行状態（`${USAGE_PROBE_STATE}`）にそのスロットの試行を記録しない。セッション記録や snapshot の値がどれだけ古くても、オフのスロットは叩く対象に入れない。

snapshot を書くとき、オフのスロットの項目は前回の値（`fetched_at` 込み）をそのまま引き継がなければならない（SHALL）。項目を消してはならない（MUST NOT）。オンに戻したときに、ステータスラインと自動選択が残っている値から再開できるようにするため。active スロットの判定と `--print-slots` の出力（`id` / `label` / `securestorage` / サービス名の 4 列）は `enabled` で変えない。

#### Scenario: オフのスロットの認証情報を読まず API も呼ばない
- **WHEN** 2 スロットのうち `b` が `enabled: false` で、両スロットとも値が古く叩く条件を満たす状態で、本番経路の probe を実行する
- **THEN** `b` のサービス名での Keychain の読み出しと `b` のための API 呼び出しは 1 回も起きず、`a` だけが取得される

#### Scenario: オフのスロットの前回値を引き継ぐ
- **WHEN** snapshot に `b` の前回値があり、`b` が `enabled: false` の状態で probe が `a` の新しい値を取得して snapshot を書く
- **THEN** snapshot の `accounts.b` は `fetched_at` を含めて前回値のまま残る

#### Scenario: 全スロットがオフなら何も取得しない
- **WHEN** 全スロットが `enabled: false` の状態で probe を実行する
- **THEN** 認証情報の読み出しも API 呼び出しも起きず、snapshot も試行状態も書き換えられず、exit 0 で終わる

### Requirement: 生成手段は既存スロットの enabled を保つ
`plugins/dev-workflow/scripts/accounts-init.sh` は、既にある `id` のスロットを上書きするとき、そのスロットに書かれていた `enabled` を同じ値のまま残さなければならない（SHALL）。ラベルや `securestorage` を登録し直しただけで、オフにしていたアカウントが黙ってオンに戻らないようにするため。新しい `id` を追加するとき、および上書き前のスロットに `enabled` が無いときは、`enabled` を書き足してはならない（MUST NOT）。

#### Scenario: オフのスロットを登録し直してもオフのまま
- **WHEN** `enabled: false` の `b` があるレジストリに対して `accounts-init.sh --id b --label B2` を実行する
- **THEN** `b` の `label` は `B2` に変わり、`enabled` は `false` のまま残る

#### Scenario: enabled の無いスロットには書き足さない
- **WHEN** `enabled` の無い `a` があるレジストリに対して `accounts-init.sh --id a --label A2` を実行し、続けて新しい id `c` を追加する
- **THEN** `a` と `c` のどちらにも `enabled` は書かれない

### Requirement: 登録簿を一覧・追加・オン・オフするコマンド
`plugins/dev-workflow/scripts/accounts.sh` は、サブコマンド `list`、`add <id> [--label <label>]`、`off <id>`、`on <id>` を持たなければならない（SHALL）。登録簿の場所は `accounts-init.sh` と同じ規則（`CLAUDE_ACCOUNTS_FILE`、無ければ `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`）で決める。id と label の検査は `accounts-init.sh` と同じ（`add` の id の位置の例外は下記。id は英数字とハイフン 1〜32 文字、label は制御文字を含まない 16 文字以下、省略時は id）。

- `list` は登録簿を変えず、スロットごとに `<id>`・`<label>`・`on` または `off`・`<securestorage>`（`null` は `-`）をタブ区切りで 1 行ずつ、宣言順に stdout へ出さなければならない（SHALL）。オフの判定は要件「スロットを enabled でオフにできる」に従う
- `add <id>` の `<id>` の位置に来たハイフン始まりの引数（`--lable`、`--version`、`-H`、`--`、`-` など。`--help` / `-h` は使い方を出して exit 0）は、id として受け取らず exit 2 で拒否しなければならない（SHALL）。したがって `add` の id 検査は `accounts-init.sh` より厳しく、ハイフンで始まる id（`-a` など）は `add` では登録できない（`on` / `off` と `accounts-init.sh` は従来どおりこの形の id を受ける）。タイプミスしたオプションが id として登録され、認証情報の置き場所とログインコマンドまで作られるのを防ぐため。
- `add <id>` は、認証情報の置き場所 `<基点>/<id>` を作り、末尾に `{"id", "label", "securestorage"}` のスロットを足さなければならない（SHALL）。`securestorage` には作ったディレクトリの絶対パスを書く。基点は環境変数 `CLAUDE_ACCOUNTS_HOME`（既定 `$HOME/.claude-accounts`）で、絶対パスでなければ exit 2。`enabled` は書かない。完了時に stdout へ、ログインするコマンドを 1 行（`CLAUDE_SECURESTORAGE_CONFIG_DIR=<絶対パス> claude`）出さなければならない（SHALL）。パスはシェルの単一引用符で囲み（パス中の `'` は `'\''` に置き換える）、空白や記号を含む基点でも、表示された 1 行をそのまま貼って実行できなければならない（SHALL）
- `off <id>` / `on <id>` は、そのスロットの `enabled` を JSON の `false` / `true` に書き換えなければならない（SHALL）。`label`・`securestorage`・スロットの順序・未知のキーは変えてはならない（MUST NOT）。認証情報の置き場所は消してはならない（MUST NOT）
- 登録済みのスロットがすでに 8 個以上ある登録簿への、新しい id の `add` は要件「登録できるスロットは 8 個まで」に従い exit 2 で拒否する
- 既にある id の `add`、登録簿に無い id の `on` / `off`、未知のサブコマンド、必須引数の欠落は、stderr に理由を出して exit 2 で終わり、登録簿を変えてはならない（MUST NOT）。`add` が exit 2 で終わるとき、認証情報の置き場所を新しく作ってはならない（MUST NOT）
- 登録簿を書き換えるサブコマンド（`add` / `on` / `off`）は、書き換える前に既存の登録簿を `<登録簿>.bak` に控えなければならない（SHALL）。登録簿が JSON として読めない、または `accounts` が配列でないときは、何も書かず、stderr に理由を出して exit 1 で終わらなければならない（SHALL）。壊れた登録簿の上に書くと、既定アカウント 1 つへの縮退（要件「レジストリ不在時は既定スロット 1 つに縮退する」）で気づきにくくなるため
- `accounts-init.sh` の挙動は、要件「登録できるスロットは 8 個まで」の拒否を除いて変えてはならない（MUST NOT）

守備範囲: このコマンドの検査（id・label・基点・登録簿の形）が受け取る入力は、利用者が自分の端末で打つコマンドライン引数と環境変数、および同じ利用者が作った（このコマンドか `accounts-init.sh` か手編集による）登録簿ファイルの 2 つに限る。悪意のある第三者が作った入力は想定しない。拾いたい誤りは、タイプミスや書きかけの登録簿のせいで、登録簿が黙って消える・別のスロットが変わる・認証情報の置き場所が意図しない場所にできることの 3 つ。次の入力は誤ったまま通ることを許す: 実在しないアカウントの id（`test` など）はそのまま登録する／`label` が他のスロットと同じでも登録する／基点が実在しない親ディレクトリの下でも作れる範囲で作る（作れなければ exit 1）／`enabled` が `false` 以外の書き損じ（`"false"`、`0` など）が入っているスロットへの `on` / `off` は、その値を `true` / `false` に上書きするだけで報告しない／同時に 2 つのコマンドが走ったときは、後から置き換えた方の書き込みが残る／`.bak` は 1 世代で、続けて 2 回実行すると最初の状態の控えは残らない／登録簿の `accounts` の中にあるスロットの形が不正（`id` を欠く、など）でも、`on` / `off` は対象の id が見つかればそのスロットだけを書き換え、ほかは変えない。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 空の登録簿に追加する
- **WHEN** `{"schema":1,"accounts":[]}` の登録簿と `CLAUDE_ACCOUNTS_HOME=<一時ディレクトリ>` で `accounts.sh add b --label B` を実行する
- **THEN** exit 0、登録簿のスロットが 1 つ増え、その `securestorage` は `<一時ディレクトリ>/b` の絶対パスで、そのディレクトリが存在する。stdout にログインコマンドが 1 行出る

#### Scenario: 既にある id の追加を拒否する
- **WHEN** id `b` が登録済みの登録簿に `accounts.sh add b` を実行する
- **THEN** exit 2 で、登録簿の内容は変わらず、`<基点>/b` も新しく作られない

#### Scenario: オフにしてオンに戻す
- **WHEN** `enabled` の無いスロット `b` を持つ登録簿に `accounts.sh off b`、続けて `accounts.sh on b` を実行する
- **THEN** `b` の `enabled` は `false`、続けて `true` になり、どちらの時点でも `label`・`securestorage`・スロットの順序は変わらない

#### Scenario: 存在しない id のオン・オフを拒否する
- **WHEN** 登録簿に無い id `z` に `accounts.sh off z` と `accounts.sh on z` を実行する
- **THEN** どちらも exit 2 で、登録簿の内容は変わらない

#### Scenario: 一覧にオフが出る
- **WHEN** `b` が `enabled: false` の登録簿に `accounts.sh list` を実行する
- **THEN** `b` の行の 3 列目が `off`、オンのスロットの行は `on` で、登録簿は変わらない

#### Scenario: 壊れた登録簿は書き換えない
- **WHEN** JSON として読めない登録簿に `accounts.sh off b` を実行する
- **THEN** exit 1 で、登録簿の内容は 1 バイトも変わらない

#### Scenario: 書き換える前に控えを取る
- **WHEN** 既存の登録簿に `accounts.sh off b` を実行する
- **THEN** `<登録簿>.bak` が実行前の登録簿と同じ内容で存在する

#### Scenario: 空白を含む基点でもログインコマンドが実行できる
- **WHEN** `CLAUDE_ACCOUNTS_HOME` を空白を含む絶対パスにして `accounts.sh add b` を実行し、stdout の 1 行を `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値を確かめるシェルで評価する
- **THEN** 評価された環境変数の値は登録簿の `b` の `securestorage` と一致する

#### Scenario: このコマンドでオフにしたスロットは自動選択で選ばれない
- **WHEN** 余り（`surplus_pct`）が最大のスロット `b` を `accounts.sh off b` でオフにして `select-account.sh` を実行する
- **THEN** `b` は選ばれず、理由行の `margins` に `b:off` が出る

#### Scenario: id の位置のハイフン始まりの引数を拒否する
- **WHEN** 空の登録簿に `accounts.sh add --lable`、`accounts.sh add --version`、`accounts.sh add -H`、`accounts.sh add --`、`accounts.sh add -` を実行する
- **THEN** どれも exit 2 で、登録簿の内容は変わらず、`<基点>` 以下にディレクトリも作られない

### Requirement: Codex を codex.enabled でオフにできる
レジストリのトップレベルの `codex.enabled` が JSON の `false` であるとき、Codex は「オフ」として扱わなければならない（SHALL）。`codex` が無い、オブジェクトでない、`enabled` が無い、`true`、真偽値でない値（文字列の `"false"`、数値の `0`、`null` など）のときはオンとする。レジストリが無い・読めない・トップレベルが配列のときもオンとする。オフにするのは利用者が明示したときだけにし、書き損じで Codex が黙って止まらないようにするため。オフになる条件は `false` との一致 1 つのままにし、`false` 以外の書き損じを検出して報告することはこの要件の範囲外とする。

**守備範囲（`codex` の読み取りが扱う入力）。** 入力の出どころは、手で編集した `accounts.json` と `accounts-init.sh` の出力の 2 つに限る。拾いたい誤りは「止めるつもりで書いたのに Codex が止まらない」ことではなく、「止めるつもりが無いのに Codex が黙って止まる」ことである（後者は無言でレビューや投げ先が外れ、気づきにくい）。そのため、オフになる条件は `false` との一致 1 つだけにする。通ることを許す入力（オンと読む）の例は、`"codex"` の欠落、`"codex": false`、`"enabled": "false"`、`"enabled": 0`、`"enabled": null`、壊れた JSON、トップレベルが配列のレジストリ。これらを検出して報告したり、オフと解釈したりしない。書き損じの形が新しく見つかるたびに判定を増やして防ぎ切ることは、この変更の完了条件にしない。書き損じた場合も、Codex が利用可能なら通常の行が残る。

Codex のオフは、Codex の提供元全体に対する設定であり、Codex のアカウントごとには持たない。オフの意味は次のとおり（SHALL）:

- develop の投げ先の自動選択は Codex を候補にしない（`dev-workflow-develop` capability）
- pr-review-gate の従来モードは、full でも Codex を試さない（`dev-workflow-pr-review-gate` capability）
- ステータスラインは Codex の行を出さず、使用量を取得しない（`statusline-multi-account-usage` capability）

読み取りは次の 2 つの実装が行い、どちらも同じ意味で `codex.enabled` を読まなければならない（SHALL）。`plugins/dev-workflow/scripts/usage_view.py` の `read_codex_enabled`（`codex-develop.py` と、CLI の `--codex-enabled`、すなわち pr-review-gate の G が使う）と、`plugins/statusline/scripts/statusline-codex.py`（他プラグインのスクリプトを実行時に読まないため、自分で実装する）。登録簿の場所は要件「アカウントレジストリの所在と形状」に従う。

`usage_view.py --codex-enabled` は、`on` か `off` のどちらか 1 行だけを標準出力に出し、常に exit 0 で終わらなければならない（SHALL）。

#### Scenario: false だけがオフになる
- **WHEN** `codex.enabled` が `false`、`true`、省略、文字列 `"false"`、数値 `0`、`null` の 6 つのレジストリと、`codex` がオブジェクトでないレジストリ（`"codex": false`）を順に与えて読み取り処理を実行する
- **THEN** `codex.enabled` が `false` のレジストリだけがオフと読まれ、残りの 6 つはオンと読まれる

#### Scenario: 設定が無い環境はオン
- **WHEN** レジストリのファイルが無い環境、壊れた JSON、トップレベルが裸の配列のレジストリのそれぞれで読み取り処理を実行する
- **THEN** どれもオンと読まれる

#### Scenario: CLI は on か off を 1 行出す
- **WHEN** `codex.enabled` が `false` のレジストリと、`codex` の無いレジストリのそれぞれで `usage_view.py --codex-enabled` を実行する
- **THEN** 前者は標準出力が `off` の 1 行、後者は `on` の 1 行で、どちらも exit 0 になる

#### Scenario: statusline の読み取りも同じ意味になる
- **WHEN** 上の 6 つの `codex.enabled` の値を `statusline-codex.py` に順に与える
- **THEN** `false` のときだけオフと読まれる

### Requirement: Codex の表示名を codex.label で決める
レジストリのトップレベルの `codex` オブジェクトは、任意の `label`（文字列）を持てる（SHALL）。statusline が Codex の行の名前 `Codex <label>` の `<label>` に使う。次の読み方に従わなければならない（SHALL）:

- `codex.label` が空でない文字列で、制御文字（C0 制御文字および DEL）を含まなければそれを使う。表示幅（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は、スロットの `label` と同じ規則で 8 桁に切り詰める
- それ以外（`codex` や `label` の欠落、文字列でない値、空文字、制御文字を含む値、壊れたレジストリ、レジストリ不在）は `A` を使う。不正な値を報告したり、Codex の行を消したりしない
- `codex.enabled` とは独立に読む。`label` を足しても `schema` は `1` のまま変えない（古い読み手は未知のキーとして読み飛ばすため）

`accounts-init.sh` はスロットの更新時にトップレベルの `codex` を保つ既存の規定に従い、`label` もそのまま残す。

**守備範囲（`codex.label` の読み取りが扱う入力）。** 入力の出どころは、手で編集した `accounts.json` と `accounts-init.sh` の出力の 2 つに限る。拾いたい誤りは、タブや改行などの制御文字で列がずれることと、名前が空になることの 2 つ。次の入力は通ることを許す: 空白だけの label、ゼロ幅や East Asian Width が Ambiguous の文字、絵文字など表示幅が端末によって変わる文字（そのまま使い、列が多少ずれてもよい）。これらを検出したり、書き損じの形が新しく見つかるたびに判定を増やして塞ぎ切ることは、この変更の完了条件にしない。書き損じた場合はステータスラインの Codex の名前で気づける。

#### Scenario: label が無ければ A
- **WHEN** `{"schema":1,"accounts":[...],"codex":{"enabled":true}}` と `codex` 自体が無いレジストリのそれぞれを与えて Codex の表示名を求める
- **THEN** どちらも `A` になる

#### Scenario: label があればそれを使う
- **WHEN** `"codex": {"label": "X"}` を持つレジストリを与えて Codex の表示名を求める
- **THEN** `X` になる

#### Scenario: 不正な label は A に戻す
- **WHEN** `"codex": {"label": ""}`、`"codex": {"label": 3}`、制御文字を含む label のそれぞれを与えて Codex の表示名を求める
- **THEN** いずれも `A` になる

#### Scenario: 長い label は 8 桁に切る
- **WHEN** 表示幅が 8 を超える `codex.label` を与えて Codex の表示名を求める
- **THEN** 8 桁に切り詰めた値になる

### Requirement: 登録できるスロットは 8 個まで
`accounts.sh add` と `accounts-init.sh` は、`accounts` 配列の要素がすでに 8 個以上あるとき、登録簿にまだ無い `id` を足さず、上限の理由を stderr に出して exit 2 で終わらなければならない（SHALL）。使用量を読む処理は先頭 8 個で打ち切るので、9 個目は黙って効かなくなるため。判定は要素の数で行い、すでにある `id` の登録し直しは拒否しない。

守備範囲: 入力は利用者が打つコマンドと同じ利用者の登録簿に限り、拾う誤りは「9 個目が黙って効かない」だけ。手編集で 9 個以上にした登録簿そのもの（読み取り側に任せる）／同時実行での 9 個目／不正な要素を含む 8 要素の配列への追加の拒否（登録簿を直せば足せる）／配列でない `accounts`（init は従来どおり空扱い）は許す。塞ぎ切ることは完了条件にしない。

#### Scenario: 8 個登録済みで add の 9 個目を拒否する
- **WHEN** 8 個のスロットが登録された登録簿に `accounts.sh add z` を実行する
- **THEN** exit 2 で、stderr に上限の理由が出て、登録簿（`.bak` を含む）の内容は変わらず、`<基点>/z` も作られない

#### Scenario: 8 個登録済みで accounts-init.sh の 9 個目を拒否する
- **WHEN** 8 個のスロットが登録された登録簿に、まだ無い id で `accounts-init.sh --id z` を実行する
- **THEN** exit 2 で、stderr に上限の理由が出て、登録簿の内容は変わらない

#### Scenario: 8 個登録済みでも既存 id の登録し直しはできる
- **WHEN** 8 個のスロットが登録された登録簿に、すでにある id で `accounts-init.sh --id a --label A2` を実行する
- **THEN** exit 0 で、`a` の `label` が `A2` に変わり、スロット数は 8 個のまま

#### Scenario: 9 個以上の登録簿への追加も拒否する
- **WHEN** すでに 9 個の要素がある登録簿に、まだ無い id で `accounts.sh add z` と `accounts-init.sh --id z` を実行する
- **THEN** どちらも exit 2 で、登録簿の内容は変わらない

#### Scenario: 7 個から 8 個目は足せる
- **WHEN** 7 個のスロットが登録された登録簿に `accounts.sh add z` を実行し、別の 7 個の登録簿に `accounts-init.sh --id z` を実行する
- **THEN** どちらも exit 0 で、スロットは 8 個になる
