## ADDED Requirements

### Requirement: 2 行目にプロンプトキャッシュのヒット率の区画を出す

`statusline.sh` は、stdin の JSON の `prompt_cache.hit_ratio` が 0 以上 1 以下の数値のとき、2 行目に `Cache <N>%` の区画を出さなければならない (MUST)。`<N>` は `hit_ratio × 100` を四捨五入した整数とする (MUST)。区画は `Context` 区画の直後、`API` 区画と `Session` 区画の前に置き、他の区画と同じ区切り（`│`）で連結しなければならない (MUST)。`Context` 区画が無いときは 2 行目の先頭に置く (MUST)。ヒット率の色は値によって変えてはならない (MUST NOT)。

#### Scenario: hit_ratio 0.82 は 82% と出る

- **WHEN** `prompt_cache.hit_ratio` が `0.82` の JSON を `statusline.sh` に渡す
- **THEN** ANSI エスケープを除いた 2 行目に `Cache 82%` が含まれる

#### Scenario: 四捨五入して整数で出す

- **WHEN** `hit_ratio` が `0.826` の JSON と `0.824` の JSON をそれぞれ渡す
- **THEN** 2 行目にそれぞれ `Cache 83%` と `Cache 82%` が含まれる

#### Scenario: 0 と 1 も出す

- **WHEN** `hit_ratio` が `0` の JSON と `1` の JSON をそれぞれ渡す
- **THEN** 2 行目にそれぞれ `Cache 0%` と `Cache 100%` が含まれる

#### Scenario: Context と Session のあいだに並ぶ

- **WHEN** `context_window.remaining_percentage` が `91`、`prompt_cache.hit_ratio` が `0.82`、`cost.total_cost_usd` が `1.5` の JSON を、`STATUSLINE_CURRENCY=USD` で渡す
- **THEN** ANSI エスケープを除いた 2 行目は `Context 91%  │  Cache 82%  │  Session $1.50` である

#### Scenario: Context が無ければ先頭に出る

- **WHEN** `context_window` が無く `prompt_cache.hit_ratio` が `0.82` の JSON を渡す
- **THEN** ANSI エスケープを除いた 2 行目は `Cache 82%` で始まる

#### Scenario: 値が違っても色は同じ

- **WHEN** `hit_ratio` が `0.05` の JSON と `0.95` の JSON をそれぞれ渡す
- **THEN** 2 行目の `Cache` の直前に置かれる ANSI エスケープ列は両者で同じである

### Requirement: ヒット率を出せない入力では従来と同じ出力にする

`statusline.sh` は、次のどの場合もキャッシュの区画を出してはならず (MUST NOT)、標準出力は `prompt_cache` を含まない同じ入力を渡したときと 1 バイトも違ってはならない (MUST): `prompt_cache` が無い、`prompt_cache` がオブジェクトでない、`hit_ratio` が `null`、`hit_ratio` のキーが無い、`hit_ratio` が数値でない、`hit_ratio` が 0 未満または 1 より大きい。このとき `last_miss_cause` に値があっても区画を出してはならない (MUST NOT)。どの場合も標準エラーには何も出さず、終了コードを変えてはならない (MUST NOT)。

#### Scenario: prompt_cache が無い JSON では区画が出ない

- **WHEN** `prompt_cache` を含まず `context_window.remaining_percentage` が `91` の JSON を、API 換算コストとセッションコストの表示が出ない条件で渡す
- **THEN** ANSI エスケープを除いた 2 行目は `Context 91%` だけで、出力のどの行にも `Cache` の区画が無い

#### Scenario: hit_ratio が null なら prompt_cache が無いときと同じ出力

- **WHEN** `prompt_cache` を含まない JSON と、同じ JSON に `"prompt_cache":{"hit_ratio":null,"last_miss_cause":{"causes":["tools_changed"]}}` を足した JSON をそれぞれ渡す
- **THEN** 2 つの標準出力は完全に一致する

#### Scenario: 壊れた形でも prompt_cache が無いときと同じ出力

- **WHEN** `prompt_cache` が文字列の JSON、`hit_ratio` が文字列 `"0.82"` の JSON、`hit_ratio` が `1.5` の JSON、`hit_ratio` が `-0.1` の JSON、`hit_ratio` のキーが無い `prompt_cache` を持つ JSON をそれぞれ渡す
- **THEN** どの標準出力も `prompt_cache` を含まない JSON を渡したときと完全に一致し、標準エラーは空で、終了コードは 0 である

### Requirement: 直近のミスの原因を同じ区画に短く添える

`statusline.sh` は、ヒット率の区画を出すときに `prompt_cache.last_miss_cause.causes` が 1 件以上の配列であれば、ヒット率の直後に空白 1 つを置いて `miss:<短い名前>` を続けなければならない (MUST)。短い名前は `causes` の先頭の要素から次のとおり決める (MUST): `tools_changed` は `tools`、`system_prompt_changed` は `system`、`ttl_expired_5m` は `ttl5m`、`likely_server_side` は `server`、それ以外は原因名そのままで 16 文字を超える分を切る。`causes` が 2 件以上あれば、短い名前の直後に `+<残りの件数>` を付けなければならない (MUST)。

次のどの場合も原因を出してはならず (MUST NOT)、ヒット率だけの区画（`Cache <N>%`）にしなければならない (MUST): `last_miss_cause` が `null`、`last_miss_cause` のキーが無い、`last_miss_cause` がオブジェクトでない、`causes` が配列でない、`causes` が空、先頭の要素が文字列でない・空・`[A-Za-z0-9_]` 以外の文字を含む。`last_miss_cause` のキーが無い入力と `null` の入力は同じ出力でなければならない (MUST)（2.1.251〜2.1.259 の版がどちらの形で渡すかは未確認のため、どちらでも成り立つ要件とする）。

`tools_added`・`tools_removed`・`system_char_delta` など `causes` 以外の項目は出してはならない (MUST NOT)。

#### Scenario: 対応表にある原因は短い名前で出る

- **WHEN** `hit_ratio` が `0.82` で、`last_miss_cause.causes` がそれぞれ `["tools_changed"]`・`["system_prompt_changed"]`・`["ttl_expired_5m"]`・`["likely_server_side"]` の JSON を渡す
- **THEN** ANSI エスケープを除いた 2 行目にそれぞれ `Cache 82% miss:tools`・`Cache 82% miss:system`・`Cache 82% miss:ttl5m`・`Cache 82% miss:server` が含まれる

#### Scenario: 原因が複数なら先頭と残りの件数を出す

- **WHEN** `last_miss_cause.causes` が `["tools_changed","system_prompt_changed"]` の JSON を渡す
- **THEN** 2 行目に `miss:tools+1` が含まれ、`system` は含まれない

#### Scenario: 対応表に無い原因はそのまま出し、16 文字で切る

- **WHEN** `last_miss_cause.causes` が `["model_changed"]` の JSON と `["some_future_cause_name_x"]` の JSON をそれぞれ渡す
- **THEN** 2 行目にそれぞれ `miss:model_changed` と `miss:some_future_caus` が含まれ、後者に `some_future_cause` は含まれない

#### Scenario: last_miss_cause が null でもキー無しでも原因を出さない

- **WHEN** `hit_ratio` が `0.82` で `last_miss_cause` が `null` の JSON と、同じ JSON から `last_miss_cause` のキーを除いた JSON をそれぞれ渡す
- **THEN** 2 つの標準出力は完全に一致し、2 行目に `Cache 82%` が含まれ、`miss:` は含まれない

#### Scenario: 原因の形が壊れていればヒット率だけ出す

- **WHEN** `hit_ratio` が `0.82` で、`last_miss_cause` が文字列の JSON、`causes` が空配列の JSON、`causes` が文字列の JSON、`causes` が `[3]` の JSON、`causes` の先頭が ESC（U+001B）を含む文字列の JSON、`causes` の先頭が空白を含む文字列の JSON をそれぞれ渡す
- **THEN** どの出力も 2 行目に `Cache 82%` を含み、`miss:` を含まず、標準エラーは空で、終了コードは 0 である

#### Scenario: 付随する数値は出さない

- **WHEN** `last_miss_cause` が `{"causes":["tools_changed"],"tools_added":7,"tools_removed":9}` の JSON を渡す
- **THEN** 2 行目のキャッシュの区画は `Cache 82% miss:tools` で、`7` も `9` も含まない

### Requirement: 環境変数でキャッシュの区画を消せる

`statusline.sh` は、環境変数 `STATUSLINE_PROMPT_CACHE` が `0` のとき、入力に `prompt_cache` があってもキャッシュの区画を出してはならず (MUST NOT)、標準出力は `prompt_cache` を含まない同じ入力を渡したときと完全に一致しなければならない (MUST)。未設定を含む `0` 以外の値では区画を出す (MUST)。`plugins/statusline/README.md` の環境変数の表と `statusline.sh` 冒頭の環境変数一覧に、この変数を載せなければならない (MUST)。

#### Scenario: STATUSLINE_PROMPT_CACHE=0 で区画が消える

- **WHEN** `hit_ratio` が `0.82` の JSON を `STATUSLINE_PROMPT_CACHE=0` で渡す
- **THEN** 標準出力は、`prompt_cache` を含まない同じ JSON を渡したときと完全に一致する

#### Scenario: 未設定なら区画が出る

- **WHEN** `hit_ratio` が `0.82` の JSON を `STATUSLINE_PROMPT_CACHE` を未設定にして渡す
- **THEN** 2 行目に `Cache 82%` が含まれる

#### Scenario: 変数が README とスクリプト冒頭に載っている

- **WHEN** `plugins/statusline/README.md` と `plugins/statusline/scripts/statusline.sh` の冒頭コメントを `STATUSLINE_PROMPT_CACHE` で検索する
- **THEN** どちらにも 1 件以上見つかる

### Requirement: キャッシュの区画は描画のたびにファイルにもネットワークにも触らない

キャッシュの区画の組み立ては、stdin の JSON だけを入力にしなければならない (MUST)。ファイルの読み書きとネットワークアクセスをしてはならない (MUST NOT)。

#### Scenario: 区画を出しても書かれるファイルは増えない

- **WHEN** `prompt_cache` を含まない JSON と、同じ JSON に `prompt_cache.hit_ratio: 0.82` と `last_miss_cause` を足した JSON を、それぞれ別の空の `CLAUDE_CONFIG_DIR` と空の `HOME` で渡す
- **THEN** 実行後の `CLAUDE_CONFIG_DIR` と `HOME` の下のファイル一覧（相対パス）は両者で同じである
