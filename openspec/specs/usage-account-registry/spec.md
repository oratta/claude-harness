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
  ]
}
```

- `schema`: 整数。省略時は `1` とみなす
- `accounts`: スロットの配列（必須）
- スロットの `id`: snapshot のキーになる識別子。`^[A-Za-z0-9-]{1,32}$` に一致しなければならない（SHALL）
- スロットの `label`: statusline に表示する短いラベル。省略時は `id` を用いる。**端末上の表示幅**（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は 8 桁に切り詰める（SHALL）。全角 4 文字ぶんにあたる。文字数ではなく表示幅で扱うのは、日本語のラベル（`仕事` など）でも列が揃うようにするため。切り詰めはスロットを捨てる扱いにはしない（長すぎる label は表示上の行き過ぎであって、そのアカウントの行を消すほどの問題ではない）
- スロットの `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する

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

### Requirement: 起動アカウントを週次余裕から自動選択する
`plugins/dev-workflow/scripts/select-account.sh` は、引数が無いときにレジストリの宣言順でスロットと schema 2 usage snapshot の `accounts` を突き合わせ、利用可能な候補のうち週次余裕が最大のスロットを選ばなければならない（SHALL）。週次余裕は、現在時刻と `weekly_resets_epoch` から既存の共有枠モードと同じ式で求めて 0〜100 に clamp した週経過率から `weekly_all_pct` を引いた値とする。同点ではレジストリの宣言順で先のスロットを選ばなければならない（SHALL）。選択は起動時の 1 回だけであり、起動済みセッションのアカウントを変更してはならない（MUST NOT）。

#### Scenario: 週次余裕が大きいスロットを選ぶ
- **WHEN** 新鮮な 2 スロットの snapshot で週次余裕が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の週次余裕を小数点以下 2 桁で含める

#### Scenario: 同点は宣言順で決める
- **WHEN** 利用可能な 2 スロットの週次余裕が等しい
- **THEN** selector は `accounts.json` で先に宣言されたスロットを選ぶ

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択では `0 <= now - fetched_at < 300` 秒のスロットだけを新鮮とみなさなければならない（SHALL）。`fetched_at`、`weekly_all_pct`、`weekly_resets_epoch`、`five_hour_pct` のいずれかが欠測・非数値であるスロット、未来の `fetched_at` を持つスロット、および `five_hour_pct >= 90` のスロットを候補から外さなければならない（SHALL）。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選び、古い値を余裕があるものとして選んではならない（MUST NOT）。このとき、レジストリに既定スロット（`securestorage` が `null` または空文字）があれば宣言順で最初のスロットの id を `selected` に出し、無ければ登録 id では使用できない `@unregistered-default` を出さなければならない（SHALL）。`stale` または `missing` による除外が 1 つでもあれば理由を `default-due-to-missing-usage`、全スロットが `five-hour>=90` だけで除外された場合は `default-due-to-five-hour-limit` としなければならない（SHALL）。

#### Scenario: 閾値以上に古いスロットを選ばない
- **WHEN** 片方の `fetched_at` の age が 300 秒以上で、もう片方が 300 秒未満の snapshot を与える
- **THEN** selector は古いスロットを候補から外し、新鮮なスロットを選ぶ

#### Scenario: 全スロットが古いときは登録済み既定スロットへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットで `fetched_at` の age が 300 秒以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=a reason=default-due-to-missing-usage` と各スロットの `stale` を含める
- **AND** その値で起動したセッションでは環境変数が unset され、statusline の active も `a` になる

#### Scenario: 既定スロットが未登録なら sentinel を表示する
- **WHEN** 全スロットが明示的な非空の `securestorage` を持ち、かつ全スロットが古い
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=@unregistered-default reason=default-due-to-missing-usage` を含める
- **AND** `@unregistered-default` は実在する登録 id として扱われない

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** 週次余裕が最大のスロットの `five_hour_pct` が 90 で、別の新鮮なスロットが 90 未満である
- **THEN** selector は週次余裕が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 全スロットの 5 時間枠が逼迫したときは原因を区別する
- **WHEN** 全スロットの選択用データは新鮮かつ完全だが、`five_hour_pct` がすべて 90 以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=default-due-to-five-hour-limit` と各スロットの `five-hour>=90` を含める
- **AND** 理由行に `reason=default-due-to-missing-usage` を含めない

#### Scenario: 選択に必要な値が欠測している
- **WHEN** スロットの選択に必要な 4 フィールドのいずれかが null または非数値である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

### Requirement: 登録済みスロットを明示選択できる
`select-account.sh <slot-id>` は usage snapshot を読まず、レジストリに登録された id の `securestorage` を返さなければならない（SHALL）。id が未登録、または引数が 2 個以上なら stdout に値を出さず exit 2 で終了しなければならない（SHALL）。

#### Scenario: 登録済み id を snapshot 無しで選ぶ
- **WHEN** 登録済み id を 1 個渡し、usage snapshot が存在しない
- **THEN** selector はそのスロットの `securestorage` を返し、exit 0 になる

#### Scenario: 未登録 id を拒否する
- **WHEN** レジストリに無い id を渡す
- **THEN** selector は stdout に値を出さず、stderr に診断を出して exit 2 になる

### Requirement: 値と選択理由を別の出力ストリームで返す
成功時の selector は stdout に選んだ `securestorage` の実値だけを改行付きで出さなければならない（SHALL）。既定アカウントの stdout は空行とする。stderr には `selected=<id-or-sentinel> reason=<reason> margins=<entries>` の 1 行だけを出さなければならない（SHALL）。`selected` は選んだ登録スロットの実 id とし、登録されていない既定アカウントへの縮退だけは `@unregistered-default` とする。自動選択の `margins` は全登録スロットを宣言順に含み、候補は週次余裕を小数点以下 2 桁、候補外は `stale`、`missing`、`five-hour>=90` のいずれかで示さなければならない（SHALL）。

#### Scenario: shell は stdout だけを値として取り込める
- **WHEN** 自動選択の stdout を command substitution で取得し、stderr を端末へ残す
- **THEN** 変数には `securestorage` の実値だけが入り、選択 id・理由・全スロットの比較は stderr の 1 行で確認できる

#### Scenario: 明示選択の理由を示す
- **WHEN** 登録済み id を明示して選ぶ
- **THEN** stderr は `reason=explicit` と `margins=-` を含む

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

