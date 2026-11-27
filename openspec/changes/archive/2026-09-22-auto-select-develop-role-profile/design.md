## Context

現行の `codex-develop.py request` は `--profile` または旧 `--account/--model` を必須とし、profile の厳密検証、phase から canonical role への対応、CODEX_HOME の解決を一か所で行う。組み込み profile は全 Codex の `codex-standard` / `codex-economy` と、Codex が書き Claude がレビューする `hybrid-standard` である。profile 未指定の通常 develop は coordinator の Claude 既定構成を使う。

Claude の schema 2 `~/.claude/.usage-snapshot` には account ごとの週次使用率・reset・取得時刻があり、トップレベル値は snapshot 生成時の active account のミラーにすぎない。Codex の `.statusline-codex` は一つの `CODEX_HOME` だけを観測し、さらに statusline plugin の install 時に設定ディレクトリへコピーされるため、dev-workflow からその存在や版を前提にできない。複数 Codex account を比較するには dev-workflow 自身が cache を分離して全 home を取得する必要がある。姉妹 issue #374 は 2026-09-22 時点で freshness 値を未決定のため、本 change で probe の 5 分 cache に合わせて 300 秒と決め、#374 も同じ境界へ揃える。

## Goals / Non-Goals

**Goals:**

- 明示 profile が無い各工程で、同じ物差しの週次余裕から provider 構成を決定論的に選ぶ。
- 書く provider と検査する provider を分ける逆向き hybrid を提供する。
- 複数 Codex account を安全に観測し、選択した account を実行設定へ固定する。
- 選択根拠を人が追跡でき、既存 profile 検証と品質工程を維持する。

**Non-Goals:**

- 工程の途中で provider/account を切り替えること。
- provider が失敗したときに別 provider へ failover すること。
- burn 全体の配分、全 account の台帳、reset ticket の利用を実装すること。
- 明示 profile の role/account/model/effort を残量に応じて書き換えること。
- #374 の Claude 起動 account selector 自体を実装すること。

## Decisions

### 1. 新しい組み込み profile は `claude-write-codex-review`

名前は executor の向きを直接表し、既存 `hybrid-standard` を再定義しない。設定は次のとおりとする。

| role | executor | account | model | effort |
|---|---|---|---|---|
| spec-write | claude | current | sonnet | medium |
| implement | claude | current | sonnet | medium |
| explore / summarize | claude | current | haiku | low |
| spec-review / impl-review / review / decider | codex | current | gpt-6-astra | high |

`finish` / `gate` は既存どおり implement role を使う。Codex 側を全て astra/high にするのは、レビューと裁定へ判断能力を集中し、書いた Claude と異なる系統で検査するためである。`hybrid-standard` の改名・反転は既存利用者の意味を変えるため採用しない。

### 2. 自動選択は `codex-develop.py request` の resolver 入口へ統合する

別 selector スクリプトは作らず、`request` が profile/legacy 指定を受けなかった場合だけ自動選択する。既存入口は account-home 表、profile 検証、phase→role、Claude/Codex 分岐を既に所有しており、別プロセスにすると検証と優先順位が二重化するためである。

- 明示 `--profile` または旧 `--account/--model` は従来どおり最優先し、自動選択用 snapshot を開かない。
- 自動選択が Claude 既定構成を選んだ場合は、JSON の架空 profile を増やさず coordinator の現行既定 role/model 上限経路へ `agent-required` を返す。
- `claude-write-codex-review` または `codex-standard` を選んだ場合は通常の `load_profile` / `validate_role_entry` を通す。
- 自動選択で Codex account が `current` 以外になった場合だけ、選択済み組み込み profile の全 Codex role の account を代表 account に束縛してから検証・hash 化する。明示 profile の account は置換しない。
- 戻り値は `selection_mode`、選択した構成、phase/role、Claude/Codex の margin・fetched_at、選択 Codex account、理由コードを持つ。秘密、CODEX_HOME パス、生応答は含めない。

### 3. 余裕は reset から算出し、freshness は 300 秒に固定する

provider ごとの未丸め margin を次で計算する。

`elapsed_pct = 100 * (1 - (reset_epoch - now) / 604800)`

`margin = elapsed_pct - weekly_used_pct`

表示だけ小数 1 桁に丸め、比較は未丸め値を使う。`margin >= 0` を余裕あり、負値を詰まりとする。snapshot は `fetched_at` が整数で `0 <= now - fetched_at <= 300`、使用率が有限の 0..100、reset が現在より後かつ 7 日以内である場合だけ fresh とする。未来の fetched_at、期限切れ reset、不正値は欠測扱いにする。

300 秒は Claude usage probe の 5 分 cache と一致し、取得失敗時に保持された古い値を「余っている」と誤認しない最短の共有境界である。#374 の design/spec は同じ `<= 300` / `> 300` 境界を採用し、両 change が揃った時点で契約テストにより drift を検出する必要がある。

Claude は `usage-account-registry` capability の「active スロットの判定規則」に従い、起動時の `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出した Keychain サービス名との一致、snapshot の `active`、レジストリ先頭の順で対象スロットを解決し、schema 2 の `accounts[slot-id]` を読む。起動環境と snapshot の `active` が異なる場合は起動環境とのサービス名一致が勝つ。schema 2 で解決したスロットの entry が無い／不正な場合は Claude を欠測とし、別 account から生成された可能性があるトップレベルのミラーへフォールバックしない。

Codex は `minutes=10080` の有効な 7 日窓だけを比較に用いる。5 時間窓や reset credit を週次余裕に代用しない。

### 4. Codex quota 取得は dev-workflow 内に閉じ、account 別 cache を並行更新する

`codex-develop.py` が Codex App Server の `account/rateLimits/read` と cache の読み書きを直接所有する。登録順を保った account-home 表の全 home を、各 `CODEX_HOME` を明示した subprocess で並行取得し、全体を一つの RPC timeout 程度に抑える。機械向け quota helper を statusline plugin や設定ディレクトリから解決する契約は設けず、必要な実装版は dev-workflow plugin の配布版そのものとする。statusline plugin が未導入でも動作し、コピー済み `~/.claude/statusline-codex.py` が無い／旧版／新版のいずれでも参照しない。

cache は `${CLAUDE_CONFIG_DIR:-~/.claude}/codex-usage/` 配下に、resolved CODEX_HOME の SHA-256 を名前として分離する。directory は 0700、file/lock は 0600 とし、認証情報・home path・生 RPC 応答を保存しない。account ごとに identity を照合し、取得成功時だけ window と `fetched_at` を更新する。取得失敗時は前回の window と `fetched_at` を保持し、今回の取得成否ではなく保持値の検証結果と age だけで候補資格を決める。

したがって、取得に失敗した account A の前回値が age=200 秒・margin=+30、取得に成功した account B が margin=+10 なら A を代表にする。失敗後の前回値は age=300 秒まで候補、age=301 秒から欠測である。fresh な 7 日窓を持つ account のうち margin 最大を Codex 代表とし、同点は account-home 宣言順で先のものを選ぶ。全 account が欠測なら Codex provider 全体を欠測とする。

既存 `.statusline-codex` を直接読む案は一 account しか表現できず、statusline の install・更新状態にも左右されるため採用しない。`statusline-codex.py` に機械向け mode を追加して呼ぶ案も、別 plugin の install が helper を設定ディレクトリへコピーし、更新に install の再実行を要するため採用しない。単一共有 cache を順に上書きする案は account 切替で前値を失い並行実行にも耐えないため採用しない。

### 5. 選択表と記録を固定する

明示指定が無い場合の結果は次の表に固定する。

| Claude | best Codex | 結果 |
|---|---|---|
| 余裕あり | 余裕あり | `claude-write-codex-review` |
| 余裕あり | 負値または欠測 | Claude 既定構成 |
| 負値または欠測 | 余裕あり | `codex-standard`（代表 account を束縛） |
| 負値または欠測 | 負値または欠測 | Claude 既定構成 |

各 canonical phase の開始時に再評価し、開始済み role は切り替えない。最初の工程の結果は記録先の最初の develop 開始コメントへ、選択名、reason code、両 margin、両 fetched_at、代表 Codex account とともに記録する。後続工程も dispatch 記録へ同じ evidence を残す。値が無い場合は `missing` と明示し、0 に変換しない。

## Risks / Trade-offs

- [工程開始が quota RPC 待ちで遅くなる] → account probe を並行化し、固定 timeout と fresh cache を使って上限を固定する。
- [statusline と quota RPC 実装が重複する] → plugin 間のコピー版依存を避けることを優先し、dev-workflow の契約テストで App Server 応答と cache 形式を固定する。将来共有する場合も配布境界を持つ versioned protocol ができるまでは片方を直接 import／実行しない。
- [#374 と freshness がずれる] → 300 秒を双方の spec に置き、統合後に境界契約テストを追加する。
- [自動 account 束縛が profile の静的 account と異なる] → 自動選択時だけ解決済み roles に反映し、execution config hash と記録 evidence へ account を残す。明示 profile は不変にする。
- [欠測時に Codex の空き枠を使えない] → fail-safe として既に動いている Claude coordinator を選び、次工程で再取得する。

## Migration Plan

1. 新 profile と厳密検証テストを追加する。
2. dev-workflow 内に account 別 Codex quota 取得と cache isolation を追加する。
3. resolver の自動選択と記録 evidence を追加し、明示指定回帰を通す。
4. docs/spec/version を更新し、手動 `/develop --profile` なしの実機証跡を取る。

ロールバックは自動選択入口を外し、既存の明示 profile と Claude 既定経路へ戻す。既存 profile 名・形式と statusline helper/cache は変更しないためデータ migration は不要である。

## Open Questions

なし。#374 は freshness を 300 秒へ合わせる必要があるが、本 change の選択規則はこの値で確定する。
