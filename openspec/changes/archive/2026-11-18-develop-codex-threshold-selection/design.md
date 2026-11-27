## Context

今の規則は `select_configuration` の 4 分岐だけで、Claude と Codex の余裕をそれぞれ「0 以上か」で二値にして表を引く。余裕の値は `dev-workflow-headroom` の行の `margin` を使い、代表 Codex account は余裕が最大の account（`automatic_selection`）。headroom の設定（`HEADROOM_7D_CAP_PCT` など）は環境変数で、不正値は `headroom.ConfigError` → `_setting_error` → `status: blocked`・exit 2 で止まる。

## Goals / Non-Goals

**Goals:**
- issue #1677 の表どおりの選択（Codex の余裕が基準以上なら Claude を問わず `codex-standard`）
- 基準を設定で変えられ、不正値では黙って既定に倒さず止まる

**Non-Goals:**
- 余裕の値の計算（headroom）、代表 Codex account の選び方、Codex オフの読み方は変えない
- 選択の根拠（selection evidence）に基準の値を足さない（理由コードで基準以上だったことは分かる）
- flatmate の `account_allocation.py` との統合、バーンの起動の判定

## Decisions

### 基準の置き場は環境変数 `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT`

- 採用理由: 同じ自動選択が読む headroom の設定がすでに環境変数で、不正値を `blocked`・exit 2 で止める経路がある。基準の不正値も同じ経路で止められる。flatmate の対応する下限 `ACCOUNT_ALLOC_MIN_SURPLUS_PCT` も環境変数。利用者は `~/.claude/settings.json` の `env` で変える
- 他の案 `accounts.json` の `codex.<キー>`（issue の推定）: そこを読む `usage_view.read_codex_enabled` は「壊れた JSON・書き損じはオンと読み、止めない」規則（`usage-account-registry`「Codex を codex.enabled でオフにできる」）で、同じブロックに「不正なら止める」値を置くと 1 つのブロックに逆向きの読み方が混ざる。登録簿はアカウントの一覧で、選択の方針を足すと `usage-account-registry` の要件まで広がる。採らない
- 名前: 「全役割を Codex にする（all Codex）ための Codex の余裕の下限（min margin）」を表す

### 値の検査は headroom の設定と同じ形

未設定・空白だけは既定 10。`float` に読めない・有限でない・0〜100 の外はエラー（文に設定の名前を含める）。margin は 100 を超えないので、100 超は意図と食い違う書き損じとして止める。検査は自動選択のときだけ行い、明示 profile・旧形式では読まない。Codex オフのときも自動選択の一部として検査する（分岐を増やさない。オフの利用者が不正値を書いた場合も止まり、直せば進む）。

### 規則の順序

`codex_enabled` が偽 → `codex-off`（最優先、今と同じ）。次に Codex の余裕が欠測でなく基準以上 → `codex-standard`・`codex-headroom-meets-threshold`（Claude の値を見ない）。残りは今の 4 分岐をそのまま使う（Codex 0 以上・基準未満で Claude 0 以上なら `both-providers-have-headroom`、Claude 0 未満か欠測なら `only-codex-has-headroom`、Codex 0 未満か欠測なら今の 2 つ）。境界はどちらも「以上」（Codex = 基準ちょうどは `codex-standard`）。`select_configuration` は基準を引数に取り、既定を 10 にする（既存の呼び方を変えない）。

## Risks / Trade-offs

- [Codex の余裕が大きい間は、Claude にも余裕があっても実装が Codex になる] → オーナーの決定どおりの挙動。Codex レビュアーが一時ディレクトリを使うテストを再実行できない既知の制約（#1649）は別 issue
- [基準 0 を設定すると `claude-write-codex-review` が選ばれなくなる] → 0 は許す入力（意図して全 Codex 寄りにする設定として通す）

## Migration Plan

設定の追加は任意で、未設定なら既定 10 で動く。戻すときはこの change の差分を戻す（状態ファイルの形は変えない）。
