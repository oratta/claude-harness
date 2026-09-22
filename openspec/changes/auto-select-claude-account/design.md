## Context

`usage-probe.sh` は `accounts.json` の各スロットについて `weekly_all_pct`、`weekly_resets_epoch`、`five_hour_pct`、`fetched_at` を schema 2 の usage snapshot に保存する。現在は statusline がその値を表示するだけで、利用者は `cld` とアカウント別 alias を残量を見ながら選んでいる。

選択処理は shell の起動前に 1 回だけ実行される必要がある。セッション中の切り替え、OAuth token の refresh、`.zshrc` 自体の配布は対象外である。既定アカウントは `CLAUDE_SECURESTORAGE_CONFIG_DIR` を空に設定することではなく、未設定にすることで起動する。

## Goals / Non-Goals

**Goals:**

- 既存 snapshot から、週の進行に対する余裕が最大で、直近 5 時間枠にも余裕があるスロットを決定論的に選ぶ。
- 欠測・古い観測から誤って余裕があると判定しない。
- shell が安全に取り込める値と、人が判断を確認できる理由を同時に出す。
- 自動選択と明示選択のどちらでも、起動後の statusline の active 表示と同じ `securestorage` を使う。

**Non-Goals:**

- 起動済みセッションの途中でアカウントを切り替えること。
- refresh token を使って非 active アカウントの token を更新すること。
- `.zshrc` をリポジトリで管理すること。
- Fable 専用枠を選択指標へ加えること。

## Decisions

### D1. `select-account.sh` を追加し、選択は既存レジストリ capability に置く

スクリプト名は `plugins/dev-workflow/scripts/select-account.sh` とする。選択規則は新規 capability に分けず、`usage-account-registry` に追加する。選択はレジストリの既定スロット、宣言順、`securestorage` の意味をそのまま使う消費規則であり、別 spec にすると同じデータ契約を重複して説明するためである。

代案の `startup-account-selection` 新設は、今後選択元がレジストリ以外にも増える場合には有効だが、今回は 1 スクリプトと 1 shell integration に閉じるため採らない。

### D2. 鮮度の有効範囲は `0 <= now - fetched_at < 300` 秒とする

`usage-probe.sh` の既定 TTL 300 秒と同じ半開区間を使い、age が 300 秒以上、負値、非数値、または `fetched_at` 欠測なら候補から外す。probe は age が 300 秒に達すると再取得を試みるため、選択側だけ 300 秒以上の値を有効にする理由がない。

代案の 600 秒は一時的な取得失敗に強いが、probe が失敗時に前回値を保持する契約と組み合わさると最大 2 キャッシュ区間の古い値を「現在の余裕」として選びうるため採らない。

### D3. 5 時間枠は `five_hour_pct >= 90` を候補から外す

90% 未満だけを候補とする。`five_hour_pct` が欠測・非数値の場合も、短期枠の安全性を判断できないため候補から外す。90% は既存の共有枠モードが「実質使い切り」とみなす `> 90` に近い境界で、残り 10% を新しいセッションの最低限の余白として確保できる。境界値で起動する競合を避けるため、ちょうど 90% も除外する。

代案の 100% は新規セッションがほぼ直ちに止まる余地を残し、80% は 5 時間窓の残り時間を見ずに候補を落とし過ぎるため採らない。

### D4. 週次余裕は既存の共有枠モードと同じ式で計算する

各候補について、`weekly_resets_epoch` から `week_elapsed_pct = (604800 - (weekly_resets_epoch - now)) / 604800 * 100` を求め、0〜100 に clamp する。`margin = week_elapsed_pct - weekly_all_pct` が最大のスロットを選ぶ。`weekly_all_pct` または `weekly_resets_epoch` が欠測・非数値なら候補外とする。同じ margin は `accounts.json` の宣言順で先のスロットを選ぶ。

「週次消化率が最小」を使う代案では週の前半と後半を区別できず、共有枠モードの判断と食い違うため採らない。

### D5. 候補が無ければ空の `securestorage` へ縮退する

全スロットが欠測・古い・5 時間枠 90% 以上のいずれかで候補外なら、登録の有無にかかわらず既定アカウントを表す空文字を返す。理由は `no-eligible-usage` とし、欠測を原因とする安全側の縮退であることを示す。古い値から見かけ上余っているスロットを選ぶより、従来の `cld` と同じ既定アカウントへ戻る方が予測可能である。

### D6. stdout は値 1 行、stderr は理由 1 行に分離する

成功時の stdout は選んだ `securestorage` の実値だけを 1 行で出す。既定アカウントは空行である。stderr は次の安定した形の 1 行を出す。

```text
selected=<id> reason=<max-weekly-margin|explicit|no-eligible-usage> margins=<id>:<数値または除外理由>,...
```

自動選択では全登録スロットを宣言順に `margins` へ載せ、候補には小数点以下 2 桁の margin、候補外には `stale`、`missing`、`five-hour>=90` のいずれかを出す。これにより受け入れ条件の 2 スロットの余裕を 1 行で比較できる。明示指定では `reason=explicit` とし、`margins=-` とする。縮退では `selected=default reason=no-eligible-usage` とする。

JSON 1 本を stdout に出す代案は shell 側に `jq` と field extraction を要求する。`KEY=value` を同じ stdout に混ぜる代案は、空文字を含む任意の path を command substitution で安全に受け取れないため採らない。

### D7. 明示 id はレジストリだけを読み、snapshot を読まない

位置引数を 1 個与えた場合はスロット id として扱う。登録済みならその `securestorage` を D6 の形式で返し、未登録なら診断を stderr に出して exit 2 とする。この経路では usage snapshot の存在・妥当性に結果を依存させない。引数 0 個が自動選択、2 個以上は使用法エラー exit 2 とする。

### D8. README は zsh の shell function 2 本を示す

単純 alias では command substitution の失敗処理、Claude 引数の転送、既定アカウントでの環境変数解除を同時に扱いにくいため、README は次の構造の shell function を示す。

- `cld [claude-args...]`: `usage-probe.sh` を best-effort で実行し、`select-account.sh` の stdout を取得する。空なら `env -u CLAUDE_SECURESTORAGE_CONFIG_DIR claude "$@"`、非空なら `CLAUDE_SECURESTORAGE_CONFIG_DIR="$selected" claude "$@"` で起動する。理由行は stderr を通して端末に残す。
- `cld-account <slot-id> [claude-args...]`: selector に id を渡し、同じ方法で明示したアカウントを起動する。id を Claude 本体の引数に混ぜない。

スクリプト位置は自動更新される marketplace clone の `$HOME/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/scripts` を既定例にし、利用者が変数 1 つで差し替えられる書き方にする。旧 `cldb` は移行後に利用者が削除できるが、リポジトリから `.zshrc` を変更しない。

## Risks / Trade-offs

- [probe が非 active アカウントを更新できず候補が減る] → 古い値を推測で使わず既定アカウントへ縮退し、理由行に除外理由を出す。
- [選択から Claude 起動までに使用率が変わる] → 選択は起動時 1 回という制約を維持し、90% の短期枠ガードで直後停止の確率を下げる。
- [securestorage path に空白がある] → stdout を値専用にし、README の function は常に引用して受け取る。
- [既定アカウントを空文字の環境変数で起動して active 判定がずれる] → 空の場合は `env -u` で明示的に unset する。

## Migration Plan

1. 選択スクリプト、bats、README、spec を同じ plugin version で配布する。
2. 利用者が README の shell function を `.zshrc` に追加し、従来の `cld` / `cldb` を置き換える。
3. 戻す場合は shell function を従来の alias に戻す。レジストリと snapshot の schema は変更しないためデータ移行は不要である。

## Open Questions

なし。
