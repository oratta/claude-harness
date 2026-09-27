## ADDED Requirements

### Requirement: `--by-role` による担当別集計の出力

`subagent-context-audit.sh` は `--by-role` フラグを受け付けなければならない（MUST）。`--by-role` を付けない既定の呼び出しは、この要件の追加前と完全に同じ出力（既存キーの形・値）にならなければならない（MUST。走査コストも変えない）。

`--by-role` を付けた場合、出力 JSON のトップレベルに `by_role` キーを追加しなければならない（SHALL）。`by_role` は常に 6 個の担当名（`W` / `R1` / `G` / `Reviewer` / `decider` / `unknown`）をキーに持ち、該当する件が 0 件の担当でもキー自体は省略しない（SHALL。集計対象がどの担当を含むかを呼び出し側が知っている必要がないようにするため）。各値は `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` を持ち（SHALL）、担当 `W` の値だけは追加で `reread_pct` を持たなければならない（SHALL）。

各担当の `first_median` / `last_median` / `over_cap_pct` の定義・母数（1 体のコンテキスト量の定義、初回・最終の判定方法、中央値の丸め方、`last_median` / `over_cap_pct` は最終コンテキストが見つかった件だけを母数にする点）は、全体の同名キーに使う既存 Requirement「サブエージェントのコンテキスト量の母集団集計」の定義と同一とし、担当ごとの部分母集団に適用したものでなければならない（MUST）。`count` が 0 の担当は `first_median` / `docs_median` / `last_median` を `null`、`over_cap_pct` を `0.0` とする（SHALL。`sources.isolated` / `sources.non_isolated` が 0 件のときと同じ扱い）。`W` の `reread_pct` は、算出対象（Requirement「`reread_pct`」参照）が 1 件も無い場合に `null` とする（SHALL）。

`by_role` の各担当の `count` の合計は、全体の `count` と一致しなければならない（MUST。分類できない件も `unknown` に含めて母集団から落とさないため）。

`--by-role` 指定時に `python3` が使えず既存の fail-open（固定文字列での `count: 0` 応答）に落ちる場合、`by_role` キーは出力しない（SHALL NOT。分類・集計そのものが `python3` を前提とするため）。この場合の応答は既存の fail-open 応答と同一のままとする。`python3` は使えるがトランスクリプトが 0 件の場合は、`by_role` の 6 キーそれぞれを `count: 0` の形（前段落のとおり）で出す（SHALL。fail-open ではなく正常系の 0 件応答のため）。

#### Scenario: 既定呼び出しは出力が変わらない

- **WHEN** `--by-role` を付けずに `subagent-context-audit.sh` を実行する
- **THEN** 出力 JSON に `by_role` キーは含まれず、既存キー（`count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at`）の値はこの要件の追加前と同じになる

#### Scenario: `--by-role` で担当別の内訳が出る

- **WHEN** 対象期間内に `W` / `R1` / `G` の名前付きサブエージェントのトランスクリプトが混在する状態で `--by-role` を付けて実行する
- **THEN** 出力 JSON に `by_role` キーが追加され、`W` / `R1` / `G` / `Reviewer` / `decider` / `unknown` の 6 キー全部に `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` が入る
- **AND** `by_role.W` にだけ `reread_pct` が入る

#### Scenario: 担当別の合計が全体件数と一致する

- **GIVEN** `--by-role` 指定の実行で `W` / `R1` / `G` / `Reviewer` / `decider` / `unknown` のいずれかに分類された件が混在する
- **WHEN** 各担当の `count` を合計する
- **THEN** その合計は全体の `count` と一致する

#### Scenario: 該当 0 件の担当は null / 0.0 で埋まる

- **GIVEN** `--by-role` 指定の実行で `Reviewer` に分類される件が 1 件も無い
- **WHEN** 出力 JSON を見る
- **THEN** `by_role.Reviewer.count` は `0`、`first_median` / `docs_median` / `last_median` は `null`、`over_cap_pct` は `0.0` になる

#### Scenario: python3 が無いときは by_role を出さない

- **GIVEN** 実行環境に `python3` が無い
- **WHEN** `--by-role` を付けて `subagent-context-audit.sh` を実行する
- **THEN** 出力は既存の fail-open 応答（`count: 0` の固定文字列）と同一で、`by_role` キーは含まれない

### Requirement: 担当分類の優先順位

`--by-role` の担当分類は、対象トランスクリプトの隣にある `agent-<id>.meta.json` を次の優先順位で判定しなければならない（SHALL）。

1. `agentType` が `dev-workflow:decider` と一致する場合、`description` の内容に関わらず常に `decider` に分類する
2. 1 に当たらない場合、`description` の先頭コロン区切りトークン（例: `W: #552 ...` の `W`）が `W` / `R1` / `G` / `Reviewer` のいずれかに完全一致すればそれに分類する
3. 1 にも 2 にも当たらない（`description` が無い・コロンが無い・未知のトークン・`meta.json` が無い/読めない）場合は `unknown` に分類する

分類できない件（`unknown`）も `by_role` の合計・母集団の `count` から落としてはならない（MUST NOT）。

この分類は `agent-<id>.meta.json` の `agentType` / `description` という自由記述を解釈する要件であり、次の 4 点を守備範囲とする。①入力の出どころ: `description` は develop 本体が `plugins/dev-workflow/skills/develop/SKILL.md:153` の紐付け規約（役割を問わず記録先番号を `#N` の形で入れる。例: `W: impl for #288`、`G: gate for PR #400 (#288)`）に沿って書く。②拾いたい誤り: develop の担当を別の担当に数えること、分類できない件が母集団の合計から落ちること。③通ることを許す入力の具体例: develop 以外の経路で起こした `G: ...` のような `description` も先頭トークン一致で `G` に数えてよい。`w:`（小文字）や `Reviewer1:` のような接頭辞の変形は `unknown` に落ちてよい（規約外の書式まで拾い切ることを目的にしない）。④新しい書き方が見つかるたびに規則を足して塞ぎ切ることを完了条件にしない。

`Reviewer` は「G のレビュアー」に割り当てる担当名だが、`plugins/dev-workflow/skills/develop/SKILL.md:153` の紐付け規約は `W:` と `G:` の例しか示しておらず、「G のレビュアー」の `description` が `Reviewer:` で始まる接頭辞を規定していない。したがって実データでは「G のレビュアー」が `unknown` に分類される可能性がある（想定内の挙動とする）。実データ集計（tasks.md「エピック #511 への基準値コメント」）で `Reviewer` の `count` がほぼ 0 で `unknown` に偏っている場合、この change の範囲外として、紐付け規約側に「G のレビュアー」の接頭辞を追加する別 issue を起こす。

#### Scenario: `agentType` が `description` の見た目より優先される

- **WHEN** `agent-<id>.meta.json` の `agentType` が `dev-workflow:decider` で、同じファイルの `description` が `R1: 仕様レビュー` のように別役割の体裁を取っている
- **THEN** その件は `decider` に分類される

#### Scenario: `description` の先頭トークンで分類される

- **WHEN** `agentType` が `dev-workflow:decider` ではなく、`description` が `G: #552 のマージ前検査` のように先頭コロン区切りトークンが `G` と完全一致する
- **THEN** その件は `G` に分類される

#### Scenario: どちらにも当たらない件は unknown に寄せられる

- **WHEN** `meta.json` が無い、または `description` の先頭トークンが `W` / `R1` / `G` / `Reviewer` のいずれとも一致しない
- **THEN** その件は `unknown` に分類され、全体の `count` には含まれたまま `by_role` の合計にも数えられる

### Requirement: `docs_median`（指示書の読み込み量の中央値）

`--by-role` は担当ごとに `docs_median` を算出しなければならない（SHALL）。算出対象のホップは、`Read` ツール呼び出し（`file_path` が harness の指示書格納パス `plugins/cache/oratta-claude-harness/` 配下の `.md` に一致するもの）または `Skill` ツール呼び出しを含む assistant ターンから、対応する `tool_result` を経て次に `usage` を持つ assistant レコードまでの 1 区間とする（SHALL）。各ホップの計上値は、次ホップの `usage` と現在の `usage` の差分とする（SHALL）。差分が負になった場合（コンパクション等でコンテキストが縮んだ場合）は 0 として計上する（SHALL）。1 ホップに複数の `tool_use` が混在する場合は、ホップ全体を docs 側の計上に丸める（SHALL。指示書以外の呼び出しコストと厳密に分離しない近似）。

`docs_median` は次の 2 段階で集約する（SHALL）。① 個体（1 トランスクリプト）ごとに、上記ホップの計上値をすべて合計し、その個体の「指示書読み込み量」とする。該当ホップが 1 つも無い個体は 0 とする（母数から除外しない）。② 担当内の全個体の①の値を中央値に集約したものを `docs_median` とする（偶数件のときは中央 2 値の平均を四捨五入した整数。既存の中央値の丸め方と同一）。

`docs_median` の算出はトランスクリプトの全文を前方から走査する必要があり、`--by-role` を指定したときにのみ行う（SHALL。既定呼び出しの走査コストは変えない）。`claude --plugin-dir` で開発用 clone から指示書を読んだ場合、パスが `plugins/cache/oratta-claude-harness/` に一致しないため docs 側の計上対象に含まれない（既知の制約とし、この change では対応しない）。

#### Scenario: 個体ごとのホップ差分が合計され担当内の中央値になる

- **GIVEN** 担当 `W` の個体 A に、`docs_median` の対象ホップが 2 つあり、その差分が 3000 と 2000 である（合計 5000）
- **AND** 同じ担当の個体 B には対象ホップが 1 つも無い（合計 0）
- **WHEN** `--by-role` を実行する
- **THEN** `by_role.W.docs_median` は個体 A の 5000 と個体 B の 0 の中央値である 2500 になる

#### Scenario: 指示書 Read を含むホップが docs_median に計上される

- **WHEN** ある担当のトランスクリプトに、`file_path` が `plugins/cache/oratta-claude-harness/` 配下の `.md` に一致する `Read` の `tool_use` を含む assistant ターンがあり、対応する `tool_result` の次に `usage` 付き assistant レコードが続く
- **THEN** その区間の `usage` 差分が、その個体の指示書読み込み量の合計に含まれる

#### Scenario: Skill 呼び出しも docs_median に計上される

- **WHEN** ある担当のトランスクリプトに `Skill` ツール呼び出しを含む assistant ターンがある
- **THEN** そのホップの `usage` 差分も同じ個体の指示書読み込み量の合計に含まれる

### Requirement: `reread_pct`（作業担当 W の読み直し割合）

`--by-role` は担当 `W` についてのみ `reread_pct` を算出しなければならない（SHALL）。単位は既存の `over_cap_pct` と同様に 0〜100 のパーセントとする（SHALL。0〜1 の比率にしない）。算出手順は次のとおり。

1. 各 `W` の `description` に含まれる `#N`（記録先の issue/PR 番号）で、同じ記録先を担当した `W` を `timestamp`（トランスクリプトの最初のレコードのもの）の開始順にグループ化する（SHALL）。`description` に `#N` が複数出現する場合は、最も左（最初）に出現するものを記録先番号として使う（SHALL）
2. 各グループの 2 番目以降の `W` について、そのグループ内で自分より前に開始した全 `W` が読んだ `Read` の `file_path` の和集合に対し、自分が読み直した `file_path` の割合（0〜100）を求める（SHALL）。一致判定は `file_path` の末尾のファイル名（ベースネーム）で行い、フルパス一致では判定しない（SHALL。worktree ごとに絶対パスの先頭が変わるため、同名の別ディレクトリ配下のファイルも読み直しとして数えてよい）
3. 各グループの最初の `W`（先行が存在しない個体）は、この中央値の母数から除く（MUST。分母が定義できないため）
4. `description` から `#N` が取れない `W` は `reread_pct` の対象から除く（MUST。グルーピングできない個体を母数に含めない）
5. 2 で求めた割合を担当 `W` 内で中央値に集約し `reread_pct` とする（SHALL）。対象が 1 件も無い場合は `null` とする（SHALL）

#### Scenario: 同一記録先の後続 W の読み直し割合が算出される

- **GIVEN** `#552` を記録先とする `W` が 2 体（先行・後続の順で開始）存在し、先行が `fileA.md` と `fileB.md` を読み、後続が `fileA.md` を読み直した
- **WHEN** `--by-role` を実行する
- **THEN** 後続の `W` の読み直し割合 `50.0`（2 ファイル中 1 ファイル）が `reread_pct` の算出対象に含まれる

#### Scenario: グループ最初の W は母数から除かれる

- **GIVEN** `#552` を記録先とする `W` が 1 体だけ存在する（先行なし）
- **WHEN** `--by-role` を実行する
- **THEN** その `W` は `reread_pct` の中央値の母数に含まれない

#### Scenario: 記録先番号が取れない W は対象から除かれる

- **WHEN** ある `W` の `description` に `#N` の形式の記録先番号が含まれない
- **THEN** その `W` は `reread_pct` の算出対象から除かれる

#### Scenario: 記録先番号が複数出現する場合は最初のものを使う

- **GIVEN** ある `W` の `description` が `W: gate for PR #400 (#288)` のように `#N` を 2 つ含む
- **WHEN** グループ化のための記録先番号を決める
- **THEN** 最も左に出現する `#400` が使われる

### Requirement: `usage-audit.md` への `--by-role` の追記

`plugins/dev-workflow/docs/usage-audit.md` は `--by-role` の使い方を追記しなければならない（SHALL）。追記内容は次を含む（SHALL）: ① `--by-role` の実行コマンド例 ② `by_role` 配下の出力キー（`count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` / `W` のみの `reread_pct`）の意味 ③ 担当分類の優先順位（`agentType` → `description` 先頭トークン → `unknown`）と `Reviewer` の接頭辞が規約に未確定である旨 ④ `reread_pct` の母数の注意（グループ最初の個体・記録先番号が取れない個体を除く、ベースネーム一致）。

#### Scenario: `--by-role` の読み方が文書からたどれる

- **WHEN** 担当別の傾向を確認したい人が `plugins/dev-workflow/docs/usage-audit.md` を読む
- **THEN** `--by-role` の実行コマンド・出力キーの意味・分類規則・`reread_pct` の母数の注意が揃っており、他のファイルを見ずに担当別監査を 1 回回せる

## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト量の母集団集計

`plugins/dev-workflow/scripts/subagent-context-audit.sh` は、直近 N 日（`--days`、既定 14）のサブエージェントのトランスクリプトを走査し、母集団の統計を 1 行 JSON で標準出力に出さなければならない（SHALL）。JSON は次のキーを含む（SHALL）: `count`（対象件数）/ `first_median` / `first_max`（初回コンテキストの中央値・最大）/ `last_median` / `last_max`（最終コンテキストの中央値・最大）/ `over_cap_pct`（最終コンテキストが上限を超えた件数の割合、0〜100）/ `cap` / `days` / `sources` / `generated_at`。

`sources` は隔離の有無で分けた統計であり、`isolated`（`isolation: "worktree"` で起こしたもの）と `non_isolated` のそれぞれが `count` / `first_median` / `last_median` / `over_cap_pct` を持たなければならない（MUST）。件数だけの内訳にしてはならない（MUST NOT。隔離の有無は役割と相関して母集団の性質が異なるため、構成比が動いただけの変化と固定分そのものの増加を読み手が後から切り分けられる必要がある）。傾向判断の主系列は全体の `first_median` とし、`sources` はその切り分けに使う。

集計の母数は 2 種類あり、一致しない場合がある。`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致しなければならない（MUST。分類できない件も母集団から落とさず `non_isolated` に寄せるため）。一方で `last_median` / `last_max` / `over_cap_pct` は**最終コンテキストが見つかった件だけ**を母数とし（窓を上限まで広げても `usage` 付きレコードが見つからない件は最終側の集計から除くため）、その母数は全体の `count` 以下になる（SHALL）。

1 体のコンテキスト量の定義は `subagent-context.sh` と同一で、assistant レコードの `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` でなければならない（MUST）。初回はファイル先頭から最初に現れた `usage` 付き assistant レコード、最終は末尾から遡って最初に見つかる同レコードとする（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を用いる（SHALL）。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数とする（SHALL）。

走査対象は projects ディレクトリ（既定 `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}`。`--projects DIR` で差し替えられる）配下の `*/*/subagents/agent-*.jsonl` の 1 経路に限らなければならない（MUST）。`isolation: "worktree"` で起こしたサブエージェントも同じ場所に置かれ、隔離によって変わるのはファイル名だけである（隔離ありは名前が載らず `agent-<agentId>.jsonl`、隔離なしは `agent-a<name>-<hash>.jsonl`）。したがってこの 1 経路で隔離エージェントも自然に含まれる。`subagents/` の外にあるトランスクリプト（メインセッション、および worktree の中から起動された入れ子の `claude` セッション。project ディレクトリ名が `*--claude-worktrees-agent-*` に一致するものを含む）は、サブエージェントではないので集計に含めてはならない（MUST NOT）。Workflow 経由で起こしたサブエージェント（`subagents/workflows/<wf-id>/agent-*.jsonl`）は `subagents/` の内側にあるが、固定深さのこの 1 経路に当たらないので母集団に含めない（MUST NOT）。

隔離の有無の分類は、同じディレクトリの `agent-<id>.meta.json` の `spawnedWithWorktree` が `true` かどうかで行う（SHALL）。meta.json が無い・読めない場合は `non_isolated` に数える（SHALL。ファイル名からの推定は行わない）。分類できないことを理由にその 1 件を全体の `count` から落としてはならない（MUST NOT）。

対象期間の判定はファイルの mtime で行う（SHALL。レコード内のタイムスタンプは見ない）。

トランスクリプトの全文を読んではならない（MUST NOT）。**ただし `--by-role` を指定した場合を除く**（この場合の全文走査は「担当分類の優先順位」「`docs_median`」「`reread_pct`」の各 Requirement が定める目的にのみ用いる）。`--by-role` を指定しない場合、初回は最初の `usage` 付きレコードで読み取りを打ち切り、最終は末尾から固定サイズの窓（既定 256 KiB）を読んで見つからなければ上限（4 MiB）まで窓を倍加し、それでも見つからない 1 件は最終側の集計から除く（SHALL）。

集計結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に 1 行 JSON で保存しなければならない（MUST）。**ただし `--cache` を明示しない場合、`--by-role` を指定したときは既定パスに `.by-role` サフィックスを足したパス（`${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}.by-role`）に保存する（SHALL。既定呼び出しと `--by-role` の集計内容が異なるため、同じキャッシュファイルを共有すると TTL 内でどちらかの結果が誤って返るのを避ける）。`--cache` を明示した場合はそのパスにそのまま保存する（`--by-role` の有無でサフィックスを足さない。呼び出し側が衝突を自分で管理する前提）。** キャッシュの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）以内なら、トランスクリプトを走査せずキャッシュの内容をそのまま出力する（SHALL）。`--refresh` は TTL を無視して再走査する（SHALL）。

この集計は観測専用であり、閾値に基づいてセッション・ツール・エージェントの実行を止めてはならない（MUST NOT。強制停止は別の仕組みが担う）。引数エラー以外はすべて exit 0 とし、トランスクリプトが 1 件も無い・projects ディレクトリが無い・`python3` が無い場合は `count` が 0 の結果を出して exit 0 で終わらなければならない（MUST。fail-open）。個々のレコードの JSON が壊れていても、その行を飛ばして他の件の集計を続けなければならない（MUST）。

#### Scenario: 直近 14 日の集計が 1 行 JSON で出る

- **WHEN** 対象期間内に名前付きサブエージェントのトランスクリプトが複数存在する状態で `subagent-context-audit.sh` を実行する
- **THEN** `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を含む 1 行 JSON が出力され、exit 0 になる

#### Scenario: worktree 隔離のエージェントが集計に含まれる

- **WHEN** `subagents/` に、隔離ありのトランスクリプト（`agent-<agentId>.jsonl` と `spawnedWithWorktree: true` を持つ meta.json）と隔離なしのトランスクリプト（`agent-a<name>-<hash>.jsonl`）が混在している
- **THEN** 両方とも `count` に含まれ、前者は `sources.isolated`、後者は `sources.non_isolated` の `count` / `first_median` / `last_median` / `over_cap_pct` に反映される

#### Scenario: サブエージェント以外のトランスクリプトは数えない

- **WHEN** project ディレクトリ名が `--claude-worktrees-agent-<hash>` で終わるディレクトリの直下に `<uuid>.jsonl`（worktree の中から起動された入れ子の `claude` セッション）がある
- **THEN** そのファイルは `count` にも `sources` のどちらにも含まれない

#### Scenario: meta.json が無くても集計は落ちない

- **WHEN** 対象トランスクリプトの隣に meta.json が無い、またはその中身が壊れている
- **THEN** そのファイルは全体の `count` に含まれたまま `sources.non_isolated` に数えられ、`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致する

#### Scenario: `--by-role` 指定時のみ全文走査が許される

- **WHEN** `--by-role` を付けて `subagent-context-audit.sh` を実行する
- **THEN** 担当分類・`docs_median`・`reread_pct` の算出のためにトランスクリプトの全文が前方から走査される

#### Scenario: 既定と `--by-role` でキャッシュファイルが分かれる

- **GIVEN** `--cache` を指定せずに `subagent-context-audit.sh` と `subagent-context-audit.sh --by-role` を同じ環境で実行する
- **WHEN** それぞれの実行後にキャッシュファイルを見る
- **THEN** 既定の実行は `~/.claude/.subagent-context-audit` に、`--by-role` の実行は `~/.claude/.subagent-context-audit.by-role` に、それぞれ別ファイルとして結果が保存される
