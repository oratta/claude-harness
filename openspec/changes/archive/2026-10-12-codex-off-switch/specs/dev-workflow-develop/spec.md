## ADDED Requirements

### Requirement: Codex がオフのとき自動選択は Claude だけの構成を返し、明示指定は拒否する
`plugins/dev-workflow/scripts/codex-develop.py` は、レジストリの `codex.enabled` が `false`（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」）のとき、次のとおり動かなければならない（SHALL）。

自動選択（profile も旧形式も無指定）は、Codex の週次の余裕の値にかかわらず、構成 `claude-default`・reason `codex-off` を返す。Codex の使用量を取得せず（app-server の起動もキャッシュの更新もしない）、selection evidence の `codex` ブロックは `account`・`margin`・`fetched_at` を `null`、`enabled` を `false` とする。Claude の余裕の評価と、`claude` ブロックの形は変えない。`select_configuration` は、`codex_enabled` を引数に取り（既定は真）、偽なら余裕の値にかかわらず `('claude-default', 'codex-off')` を返す。

明示指定は、オフのとき黙って Claude に差し替えてはならない（MUST NOT）。旧形式（`--account` / `--model`）と、いずれかの role の executor が `codex` の profile（`--profile`）は、依頼ファイルを作らず、`status: blocked` と exit 2 で拒否する。エラー文にはオフであること、戻し方（`codex.enabled` を `true` にするか `codex` のキーを消すこと）、読んだ登録簿のパスを入れる。この拒否は、アカウント対応表の検査（`account is not registered` など）より先に行う。executor が `codex` の role を 1 つも持たない profile は拒否しない。

`codex.enabled` の読み方（入力の出どころ、オフになる条件が `false` との一致 1 つであること、書き損じを防ぎ切ることを完了条件にしないこと）は `usage-account-registry` の要件「Codex を codex.enabled でオフにできる」の守備範囲に従い、ここで独自の検査を足さない（SHALL）。

`codex.enabled` が無い、または `false` 以外のとき、選ばれる構成・reason・selection evidence・依頼ファイルは変更前と同一でなければならない（SHALL）。

#### Scenario: オフなら Codex の余裕が大きくても Claude だけを選ぶ
- **WHEN** `codex.enabled` が `false` で、Codex の週次の余裕が Claude より大きい（両方 0 以上）状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off` で、`codex.enabled` は `false`。Codex の使用量の取得は呼ばれない

#### Scenario: オフで Claude にも余裕が無いとき
- **WHEN** `codex.enabled` が `false` で、Claude の余裕が負（または欠測）の状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off`（`no-provider-has-headroom` ではない）

#### Scenario: オフで Codex の profile を明示すると拒否する
- **WHEN** `codex.enabled` が `false` で、`--profile codex-standard` を指定して `request` を実行する
- **THEN** exit 2 で終わり、`status` は `blocked`、エラー文にオフであることが出る。依頼ファイルは作られない

#### Scenario: オフで旧形式を明示しても拒否する
- **WHEN** `codex.enabled` が `false` で、`--account NAME --model MODEL` を指定して `request` を実行する
- **THEN** exit 2 で終わり、エラー文にオフであることが出る

#### Scenario: オフの拒否は対応表の検査より先
- **WHEN** `codex.enabled` が `false` で、`--account-home` を渡さずに `--profile codex-standard` を指定する
- **THEN** エラー文は `account is not registered` ではなくオフであることを示す

#### Scenario: 設定が無い環境では変わらない
- **WHEN** `codex` を書いていないレジストリ、レジストリ無し、`codex.enabled` が `true` のレジストリのそれぞれで、同じ使用量の入力で自動選択する
- **THEN** 3 つとも、選ばれる構成・reason・selection evidence が同一で、`codex` ブロックに `enabled` のキーは無い
