## MODIFIED Requirements

### Requirement: 入力の送り手は予約文と起動形と先頭の接頭辞で決める

フックは予約文を先に除外し、記録の親子と一致する既存 launcher の起動形をそのセッションで初めて受けたら `startup`、それ以外で先頭が `親エピック #` / `主の返事（親エピック #` なら `parent`、要件「裏の作業の通知などで始まる入力は直前の送り手を引き継ぐ」の接頭辞で始まる入力はその要件の送り手、残りを `owner` としなければならない（MUST）。対象外入力では分類結果を記録してはならない（MUST NOT）。起動形の子は `#N` または `owner/repo#N` とし、明示された子 repo は記録側と双方小文字化して一致することを求める（MUST）。記録の表記は変えてはならない（MUST NOT）。起動形は先頭の子番号・親番号に加え、明示されたエピックの repo と記録側を双方小文字化して照合し、省略時の同一 repo 判定も双方小文字化しなければならない（MUST）。一致する起動指示でだけ未登録または別 ID から登録・切替し、保存済みの世代を1増やす（初回は1）（MUST）。送り手は到着経路であり承認の権限を表さない。本文の途中の引用や子の自己申告から決めてはならない（MUST NOT）。

#### Scenario: 主が直接入力する
- **WHEN** 主が保存済み ID と同じ子のタブに `調査結果を教えて` と入力する
- **THEN** `sender` は `owner` である。同じ ID に同じ起動指示を再送した場合も `startup` とせず `owner` になる

#### Scenario: 親の判断と親経由の主の返事を同じ輸送経路にする
- **WHEN** 保存済み ID と同じセッションへの入力が `親エピック #1732 の判断（主の承認ではない）:` または `主の返事（親エピック #1732 経由）:` で始まる（別repoの括弧付き表記を含む）
- **THEN** `sender` は `parent` であり、主本人の承認かどうかの既存の検証は省かない

#### Scenario: 起動し直しの指示に埋め込まれた返事を分類する
- **WHEN** 新セッションの初回入力が記録の親子・エピックの repo と一致する launcher の `/develop #<子> （エピック #<親> の子。…）` の形であり、返事も埋め込まれている
- **THEN** `sender` は `startup` であり、新 ID と旧世代+1、`turn_state: null` を一度に保存する。別repoの起動形でも同じであり、旧 ID の入力・Stop は新 ID の記録を変えない

#### Scenario: 引用は送り手を変えない
- **WHEN** 対象の通常入力の途中に `親エピック #1732` の引用がある
- **THEN** その引用を理由に `parent` にせず `owner` と記録する

#### Scenario: 起動指示の番号や repo の不一致と引用では切り替えない
- **WHEN** 未登録または異なる ID から、子番号違い・親番号違い・エピックの repo 違い・別 repo の子で repo の記載省略・本文途中に引用した起動形のいずれかを受ける
- **THEN** 登録・切替せず記録全体を保つ。同じ repo の子は repo の記載省略を許し、別 repo でも正しい repo を明示した起動指示は登録・切替できる

#### Scenario: 一致する起動指示の形は認証に使わない
- **WHEN** 同じ worktree の別セッションに、記録の親子・repo と一致する起動指示を意図的に送り直す
- **THEN** その ID への切替を受理する。これは起動指示の輸送上の分類であり、主本人の承認や起動元の認証を証明しない

#### Scenario: 裏の作業の通知で始まった入力は owner にしない
- **WHEN** 保存済み ID と同じセッションへの入力が `<task-notification>` で始まる
- **THEN** `sender` は `owner` にならず、要件「裏の作業の通知などで始まる入力は直前の送り手を引き継ぐ」の送り手になる

## ADDED Requirements

### Requirement: 裏の作業の通知などで始まる入力は直前の送り手を引き継ぐ

フックは、予約文でも起動形でもない対象の入力のうち、先頭の空白を除いた本文が `<task-notification` / `<local-command-` / `<bash-input>` / `<bash-stdout>` / `<bash-stderr>` のどれかで始まるものの `sender` を、同じセッションの直前の `turn_input.sender` にしなければならない（MUST）。世代を 1 増やし、受付時刻と会話ログの位置を更新し、`turn_state` を `null` にする扱いはほかの通常入力と同じにする（MUST）。`sender` の値を `owner` / `parent` / `startup` 以外にしてはならない（MUST NOT）。

#### Scenario: 親の作業の通知で起こされたターンの返事待ちは止まりになる
- **WHEN** 直前の `sender` が `parent`（または `startup`）の子が `<task-notification>` で始まる入力を受け、そのターンを `状態: 主の返事待ち — <中身>` で終える
- **THEN** 記録の `sender` は `parent`（または `startup`）のまま世代が 1 増え、`epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped <N>` は `stopped <N>` を返す

#### Scenario: 主の作業の通知で起こされたターンは今までどおり owner の扱い
- **WHEN** 直前の `sender` が `owner` の子が `<task-notification>` で始まる入力を受け、そのターンを `主の返事待ち` で終える
- **THEN** 記録の `sender` は `owner` のままで、`wait --watch-stopped` は `stopped` を返さず、`turn_state.recorded_at` から `EPIC_DISPATCH_OWNER_AWAY_SEC` たてば `owner-away <N>` を返す

#### Scenario: 5 つの接頭辞と先頭の空白
- **WHEN** 直前の `sender` が `parent` の子が、先頭に空白や改行を置いたものを含め、`<task-notification` / `<local-command-` / `<bash-input>` / `<bash-stdout>` / `<bash-stderr>` のどれかで始まる入力を受ける
- **THEN** どれも `sender` は `parent` で、本文の途中にだけこれらの文字列がある入力は `owner` になる

#### Scenario: 主が子のタブで打った入力は変わらない
- **WHEN** 主が保存済み ID と同じ子のタブに通常の文を打ち、そのターンを `主の返事待ち` で終える
- **THEN** `sender` は `owner` で、`wait --watch-stopped` は `stopped` を返さず、`EPIC_DISPATCH_OWNER_AWAY_SEC` たてば `owner-away <N>` を一度だけ返す
