# dev-workflow-token-thresholds Specification

## Purpose
develop のトークンしきい値を固定モデル ID と判断時の実測へ結び付け、未知モデルや実測の前提が変わったときに再検証を促す。共通の解決結果と再実行手順を用意し、値を根拠なく使い続けることを防ぐ。

## Requirements

### Requirement: 固定モデルごとの値の横に判断の根拠を持つ

モデル別の表は各指標の値の横に、固定 ID の根拠モデル集合・判断日・実測の説明・結果 URL を持たなければならない（MUST）。初期登録は `claude-opus-5-5` と `claude-sonnet-5-5`、各行の値は文脈上限 150000・強制停止 220000・累計上限 30000000・エピックの子の権限 60000000 とする（MUST）。根拠は #1799 の 2026-11-24 の結論とし、混在標本と品質未測定を明記する（MUST）。

#### Scenario: 両モデルの各値から根拠をたどれる

- **WHEN** 表の両固定 ID の 4 指標を調べる
- **THEN** 値はそれぞれ 150000 / 220000 / 30000000 / 60000000 で、各値の隣に両固定 ID、2026-11-24、実測の説明、https://github.com/oratta/claude-harness/issues/1799#issuecomment-7120074012 がある

#### Scenario: 調査役と測定対象を混同しない

- **WHEN** 表と再検証手順の根拠の説明を読む
- **THEN** 結論の `opus-5-5` / `sonnet-5-5` が固定 ID に対応し、累計は Claude と Codex の混合集計であること、品質の最適値は未測定であることが分かる。調査役が sonnet だったことを根拠に他のモデルを登録していない

### Requirement: 未登録モデルは安全側の既定値と理由を返す

共通処理は固定 ID の完全一致で表を引き、未登録・不明・可変別名は 150000 / 220000 / 30000000 / 60000000 に倒さなければならない（MUST）。結果には採用値・出典・要求モデル・一致モデル・フォールバック有無・診断を含める（MUST）。守備範囲: 入力は呼出元のモデル ID と同梱表で、誤った測定済み扱いを防ぐ。`opus` や綴り違いは未知として通し、モデルの実在・窓との適合は保証しない。あらゆる入力の穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 既知の固定 ID は登録値を返す

- **WHEN** 環境上書き無しで `claude-opus-5-5` と `claude-sonnet-5-5` をそれぞれ解決する
- **THEN** 各指標は登録値と根拠を返し、一致モデルは渡した ID、フォールバックは false、値の出典種別は model となる

#### Scenario: 未知・モデル不明・別名を可視化する

- **WHEN** 環境上書き無しで `claude-opus-future`・空文字・モデル省略・`opus`・`sonnet` をそれぞれ解決する
- **THEN** 一致モデルは null、フォールバックは true、値の出典種別は fallback、4 指標は共通既定値で、unknown_model 診断に渡されたモデルまたは不明である旨が出る

### Requirement: 根拠モデルとの違いは再検証を通知する

使用モデルが各値の根拠モデル集合に無い、または不明なら、共通処理は再検証要フラグと診断を呼出しごとに返さなければならない（MUST）。診断は使用モデル・根拠モデル・対象指標・再検証手順のパスを含み、環境上書きでも消してはならない（MUST NOT）。守備範囲: 入力は呼出元が渡す実効 ID と表の根拠で、前提変更の黙殺を防ぐ。誤った ID を呼出元が渡すことや混在標本の限界は許容し、モデルの自動推定や穴の完全封鎖は完了条件にしない。

#### Scenario: 未知モデルでは再検証を通知する

- **WHEN** `claude-opus-future` を解決する
- **THEN** revalidation_required は true で、診断に使用モデル、両 5.5 固定 ID、4 指標、`plugins/dev-workflow/skills/develop/references/token-thresholds.md` が出る

#### Scenario: 登録済みでも根拠と違えば通知する

- **WHEN** テスト用の表で新固定 ID の行に 5.5 の根拠を残したまま、その新固定 ID を解決する
- **THEN** フォールバックは false でも再検証要は true となり、対象指標について revalidation_required 診断が出る

#### Scenario: 根拠に含まれるモデルは再検証通知無し

- **WHEN** 初期表で両 5.5 固定 ID をそれぞれ解決する
- **THEN** 再検証要は false、unknown_model と revalidation_required の診断は無い

### Requirement: 明示の数値環境変数がモデル既定値より優先する

共通処理は既存の文脈上限・強制停止・累計上限の数値 env を対応する指標だけに優先し、出典を environment として基準値の根拠も残さなければならない（MUST）。権限値の env を新設せず、累計上限へ自動適用してはならない（MUST NOT）。守備範囲: 入力は利用者の明示 env で、不正値の黙殺を防ぐ。空白だけは未設定、前後空白付きの ASCII 非負整数と 0 は許容する。大小関係や権限の妥当性は判定せず、入力の穴の完全封鎖は完了条件にしない。

#### Scenario: 既知モデルで個別の env が優先する

- **WHEN** `DEV_WORKFLOW_CONTEXT_CAP=160000`、`DEV_WORKFLOW_CONTEXT_HARD_CAP=230000`、`DEV_WORKFLOW_PR_TOKEN_CAP=40000000` で既知モデルを解決する
- **THEN** 対応する 3 指標だけがその値と environment の出典になり、基準値とその根拠も残る。権限値は 60000000 のままで、再検証済みの値とは表示しない

#### Scenario: 未知モデルへの上書きは注意を消さない

- **WHEN** 未知モデルに `DEV_WORKFLOW_PR_TOKEN_CAP=45000000` を設定して解決する
- **THEN** 累計上限は 45000000 だが、フォールバックと再検証要は true、両診断が残る

#### Scenario: 空白・0・前後の空白を扱う

- **WHEN** 累計上限 env を空白だけ・`0`・` 40000000 ` にした 3 ケースを解決する
- **THEN** それぞれ表の値・0・40000000 となる。他指標と権限値を変えない

#### Scenario: 不正な上書きは成功値を返さない

- **WHEN** 3 つの数値 env のそれぞれに `-1`・`1.5`・`abc` を設定して CLI を呼ぶ
- **THEN** exit 1 で invalid_override の error JSON と env 名・理由を返し、利用可能な thresholds は返さない

### Requirement: 共通処理を単独で呼び通知と失敗を確認できる

共通処理は import と CLI の両方から同じ解決結果を得られ、表は cwd に依存せず読めなければならない（MUST）。CLI は成功時 1 行 JSON と exit 0、診断があれば stderr にも通知する（MUST）。表が使えないときは invalid_table の error JSON と理由を返し exit 1 とする（MUST）。守備範囲: 同梱表の破損・必須情報の欠落を検出する。追加フィールドは許容し、内容の学術的正しさや表の悪意ある改変を完全に防ぐことは完了条件にしない。

#### Scenario: 任意の cwd から未知モデルを呼べる

- **WHEN** repo 外を cwd に CLI を絶対パスで実行して未知モデルを渡す
- **THEN** exit 0 で stdout は解決結果の 1 行 JSON、stderr にフォールバックと再検証の通知が出る。同じモデルと env の import 結果と JSON 内容が一致する

#### Scenario: 同梱表の不備を隠さない

- **WHEN** テストで表の欠損・不正 JSON・schema_version 不一致・必須指標欠落・根拠欠落のそれぞれを模す
- **THEN** CLI 相当の入口は exit 1 と invalid_table の error を返し、成功した thresholds を返さない。import API は ValueError を返す

### Requirement: 同じ集計を再実行する手順と更新記録を一か所に持つ

再検証手順は原スクリプトの取得、材料、実行順、期待する集計、限界、結果の保存先を一か所に記さなければならない（MUST）。値を変えるたび同じ手順の結果を判断用 issue / PR に残し、各値の出典を更新する（MUST）。原スクリプト未取得を再現済みとせず、repo に集計スクリプトを追加してはならない（MUST NOT）。decision-criteria.md から表と手順に到達できること（MUST）。

#### Scenario: 必要な材料と集計順が分かる

- **WHEN** 手順を読む
- **THEN** #1799 の基準 38 件と新モデル標本の区別、ログ・全ページのコメント・Codex 消費・PR ファイル情報、原スクリプトと引数/hash の取得、collect → calib → analyze → analyze2 → analyze3 → handover → ctxcap → analyze4 → analyze5 の順、固定分・見積もり誤差・手渡し損益分岐・4 上限の再検討が記されている

#### Scenario: 原スクリプトや保存先が不足する

- **WHEN** 原スクリプトが取得できない、または派生ログの保存に必要な LLM_LOG_DIR が未設定である
- **THEN** 手順は前者を再現未完と記録するよう求め、後者は保存先の確認を求める。repo 内や推測した個人ディレクトリに保存させない

#### Scenario: 値を更新するときに同じ結果を残す

- **WHEN** 再検証の結果を受けて登録値を変更する
- **THEN** 手順に従い対象モデル・日付・材料・再実行コマンド/hash・集計表・旧新値・採否理由・限界を issue または PR コメントに残し、表の該当レコードの根拠をその結果へ更新する

#### Scenario: 入口と配線の境界が読める

- **WHEN** decision-criteria.md の文脈上限の節を読む
- **THEN** 表と再検証手順へのリンクがあり、共通処理が subagent-context.sh と context-tripwire.sh の文脈上限・強制停止へ接続済み、pr-token-budget.sh の累計上限へ未配線であることが明記される。モデルは各計測に採用したレコードから取得すること、上書き・CLI と hook の 0 の差・stderr 診断・失敗時の fail-open が分かり、既存の停止・権限の意味は変わらない。利用手順 token-thresholds.md 自体の未配線注記の更新は change 3 の担当で、この change では編集しない

### Requirement: 文脈計測は採用した usage のモデルで共通の値を引く

`subagent-context.sh` と `context-tripwire.sh` は、各自の既存計測で採用した assistant レコードの `message.model` を共通解決処理へ渡し、前者は `context_cap`、後者は `context_cap` と `context_hard_cap` を使わなければならない（MUST）。モデルが欠落・非文字列・空白だけなら不明とし、それ以外は無加工で渡す（MUST）。親・環境・metadata・別名から固定 ID を推測したり、別のレコードのモデルを補ったりしてはならない（MUST NOT）。守備範囲は採用 usage とモデルの対応であり、モデルの実在や申告の真偽を保証せず、入力の穴の完全封鎖を完了条件にしない。

#### Scenario: 既知モデルの行を使ったことを判別できる

- **WHEN** テスト用プラグインの表で既知の固定 ID の文脈上限・強制停止を fallback と異なる値にし、その ID を持つ usage で両スクリプトを動かす
- **THEN** CLI の `cap` と超過判定、hook の通知・拒否の境界がモデル行の値になる。環境上書きは無く、fallback の値では合格しない検査になる

#### Scenario: 使用モデルは最後に採った usage と同じレコードにある

- **WHEN** 対象ログに異なるモデルの assistant レコードがあり、最後に計測対象となったレコードのモデルが既知の固定 ID である
- **THEN** 各スクリプトはそのモデル行を使う。CLI が既存ルールで除外する末尾の API エラー・全 usage が 0 のレコードのモデルに切り替わらない。hook は従来の末尾計測で選ぶレコードを変えない

#### Scenario: モデルが無くても前のモデルで補わない

- **WHEN** 計測可能な最後のレコードのモデルが欠落・null・数値・空文字・空白だけで、過去のレコードや親ログ・payload・metadata・モデル環境変数には既知 ID がある
- **THEN** 各ケースとも不明として fallback を使い、診断を出す。過去や親のモデル行は使わず、usage があること自体は計測不能として扱わない

#### Scenario: 未知モデルと別名は無加工で fallback になる

- **WHEN** 採用レコードのモデルが未知 ID、`opus`、`sonnet`、または既知 ID の前後に空白が付いた文字列である
- **THEN** 文字列をそのまま共通処理へ渡して fallback と再検証の診断を出し、初期表では文脈上限 150000・強制停止 220000 を使う。未知であるだけでは fail-open にしない

### Requirement: 文脈計測の上書きは呼出元の優先順位と正数条件を守る

CLI は `--cap` > 文脈上限 env > モデル行 / fallback、hook は各文脈 env > モデル行 / fallback で解決しなければならない（MUST）。各呼出元は使う指標の env だけを渡し、CLI の有効な `--cap` は同 env を遮蔽する（MUST）。env は空白だけを未設定、前後空白付き ASCII 非負整数を有効とし、`--cap` は従来の ASCII 数字列だけとする（MUST）。CLI の 0 は有効、hook は cap / hard のどちらかが 0 なら stdout 空・exit 0 の fail-open とし、`hard <= cap` なら PreToolUse は拒否しない（MUST）。拒否しない場合の stdout は、再検証通知が無ければ空、あれば診断だけの JSON とする（診断の要件に従う）。

守備範囲: 入力元は利用者の `--cap`・env と同梱表・共通処理。優先順位・形式・正数条件・大小関係の誤適用を拾う。再検証通知がある場合の stdout 例外は拒否・締めの境界を変えない。有効な `--cap 100` に隠れる不正 env `abc` や未使用指標の不正 env は許容する。入力の穴の完全封鎖は完了条件にしない。

#### Scenario: 有効な cap 引数は env を遮蔽する

- **WHEN** CLI で `--cap 100` を指定し、文脈上限 env が `200` または `abc` である
- **THEN** どちらも `cap` は 100 で、同じモデルの解決結果に従って `ctx > 100` を判定する。env の不正値を先に検証して exit 1 にしない

#### Scenario: 未設定と空白の env はモデル行を使う

- **WHEN** CLI と hook の対応する env を未設定・空文字・空白だけにし、次に ` 100 ` にする
- **THEN** 前 3 ケースはモデル行 / fallback の値、最後は 100 を使う。CLI の従来の空白 env 拒否は共通契約に揃えて解消する。`--cap ' 100 '` は従来どおり引数エラーで exit 1

#### Scenario: CLI と hook の 0 の違いを保持する

- **WHEN** CLI の `--cap` または文脈上限 env を 0 にし、hook は cap のみ 0・hard のみ 0・両方 0 の各ケースを実行する
- **THEN** CLI は `cap=0` と `ctx > 0` の判定を返す。hook は両イベントとも stdout 空・exit 0 で、正数条件違反の理由を stderr に出す。既定値への置き換えや 0 による通知・拒否は行わない

#### Scenario: 関係ない env が文脈計測を無効にしない

- **WHEN** CLI に不正な強制停止 env と累計上限 env、hook に不正な累計上限 env を設定する
- **THEN** 利用する文脈指標は通常どおり解決でき、無関係な env を理由とする invalid_override は出ない

#### Scenario: 大小関係と閾値ちょうどの判定を維持する

- **WHEN** `hard <= cap` の状態で両 hook イベントを実行し、別途 `ctx == cap` と `ctx == hard` の境界も調べる。再検証が不要なモデルと、再検証通知が出るモデルの両方で行う
- **THEN** 大小関係が逆なら PreToolUse は拒否せず exit 0 で、stdout は再検証不要なら空、再検証通知があれば診断だけの JSON（決定フィールドなし）になる。PostToolUse は cap 超で通知する（再検証通知があれば別段落で追記）。cap / hard ちょうどではその閾値の通知 / 拒否をしない。再検証通知だけは境界でも出てよい

### Requirement: 文脈計測の診断は既存 JSON と配布先の手順参照を保つ

文脈計測の呼出元は fallback と利用指標の再検証診断を呼出しごとに stderr に出し、環境上書きでも消してはならない（MUST / MUST NOT）。再検証文は要求モデル・根拠モデル・対象指標と、実行中の同梱プラグインを起点とする手順の絶対パスを含める（MUST）。累計・権限の再検証診断をここで出してはならない（MUST NOT）。CLI の stdout は既存の測定 JSON のままとし、hook の通知・拒否の本文は変更してはならない（MUST）。

hook は、利用する文脈指標に `revalidation_required` があるとき、同じ再検証診断を stderr に加え、その hook が動くサブエージェント本人に届く `hookSpecificOutput.additionalContext` にも入れなければならない（MUST）。exit 0 の stderr は Claude に届かず、`additionalContext` は PreToolUse / PostToolUse とも Claude の文脈に配送されるため、本人への通知経路は `additionalContext` とする。再検証通知文は、要求モデル・根拠モデル・対象指標・手順の絶対パスを含み、「根拠モデルと異なるため、案内した手順でしきい値を再検証する必要がある」と明示する（MUST）。診断だけでは締め・今すぐの return・拒否を要求してはならず、`permissionDecision`・`decision`・`continue:false`・`systemMessage` を付けてはならない（MUST NOT）。

再検証通知を受けた本人は、この通知だけを理由に今の作業を止めず、自分で再検証も始めず、次の return に再検証が要る旨（要求モデル・根拠モデル・対象指標）を書く。通知文はこの動きを明示する（MUST）。

hook の stdout は次のとおりとする。この一覧は、解決が成功し正数条件を満たしたあとに当てる。解除・計測不能・解決失敗・正数条件違反では stdout 空が優先し、診断は stderr だけに出す（MUST）。
- 再検証通知が無く閾値以内、または拒否も通知もしない場合: 空。
- 再検証通知があり、閾値以内（cap 内の両イベント、cap 超 hard 以内の PreToolUse、`hard <= cap` の PreToolUse を含む）: 当該イベントの `hookEventName` と再検証通知だけを持つ単一 JSON。exit 0。
- cap 超の PostToolUse: 既存の通知本文をそのまま保ち、別段落で再検証通知を追記した単一 JSON。
- hard 超の対象ツールの PreToolUse: 既存の deny と `permissionDecisionReason` を変更せず、同じ `hookSpecificOutput` に再検証の `additionalContext` を追加した単一 JSON。

通知は環境上書きでも消さず、呼出しごとに出す。状態保存や一度だけの抑制を追加してはならない（MUST NOT）。

守備範囲は、同梱表・共通処理が返す fallback・再検証の判定と、呼出元が受け取るモデル文字列を入力元とし、再検証の必要が stderr だけに留まって再開されない本人に届かない誤り、診断だけで締め・拒否が起きる誤り、既存の測定 JSON・通知・拒否本文を壊す誤りを拾う。通してよい入力は、根拠違いでも通常の解決に通る形式正しい表である。通知の到達は Bats による出力検査と公式仕様の配送規則を根拠とし、実機での配送観測や、表の根拠内容の真偽、入力の穴の完全封鎖を完了条件にしない。

#### Scenario: 未知モデルの診断は出力の形を壊さない

- **WHEN** 未知モデルで CLI、cap 内の PostToolUse と PreToolUse、cap 超の PostToolUse、hard 超の編集ツールの PreToolUse をそれぞれ実行し、hook の stdout を JSON として解析する
- **THEN** 各 stderr に fallback と文脈指標の再検証診断が出る。CLI stdout は測定の 1 行 JSON。cap 内の hook stdout は `hookSpecificOutput.additionalContext` だけの単一 JSON で、要求モデル・根拠モデル・対象指標・手順の絶対パスと「根拠モデルと異なるため、案内した手順でしきい値を再検証する必要がある」旨を含む。cap 超の PostToolUse は既存の締め通知本文を保ったうえで別段落に再検証通知を持ち、hard 超の PreToolUse は既存の deny と理由を保ったうえで同じ出力に再検証の `additionalContext` を持つ。hook はいずれも exit 0

#### Scenario: 診断だけでは締めも拒否もしない

- **WHEN** 再検証通知が出る未知モデルと既知モデルの根拠違いで、cap 内の PostToolUse と PreToolUse を実行し、出力を解析する
- **THEN** 出力に `permissionDecision`・`decision`・`continue`・`systemMessage` が無く、`additionalContext` に締め・今すぐの return・commit を求める文が無く、次の return に再検証が要る旨を書くよう案内する文がある。ツールは拒否されず exit 0

#### Scenario: 環境上書きと再呼出しでも注意を消さない

- **WHEN** 未知モデルの文脈 env を有効な正の値で上書きして、同じログで呼出しを繰り返す
- **THEN** 採用値は上書きに従うが、各呼出しの stderr と hook の `additionalContext` に同じモデルの fallback と再検証の診断が残る。通知抑制用の状態ファイルを作らない

#### Scenario: 既知モデルでも根拠と違えば再検証を出す

- **WHEN** テスト用の表で、登録固定 ID の文脈指標の根拠モデル集合にその ID が無い状態を作って実行する
- **THEN** モデル行の値を使って fallback 診断は出さず、該当する文脈指標の再検証診断を stderr と、hook では両イベントの `additionalContext`（閾値内・通知・拒否の各出力）に出す。根拠に含まれる初期の両既知 ID では両種の診断とも出さず、hook の stdout も閾値以内では空になる

#### Scenario: 配布先と任意の cwd から手順を開ける

- **WHEN** `plugins/dev-workflow` という親を持たない一時プラグイン配置に実体をコピーし、別の cwd から両スクリプトで未知モデルを測る
- **THEN** stderr と hook の `additionalContext` の手順パスはそのコピーの `skills/develop/references/token-thresholds.md` を指す実在する絶対パスである。cwd や開発 checkout のパス、共通処理が返す repo 相対パスを誤ってそのまま案内しない

### Requirement: 文脈の共通解決が失敗しても hook はツールを止めない

共通処理の invalid_table / invalid_override、ロード失敗、API 欠損・呼出し時の通常例外のいずれかが起きたとき、CLI は `error` 文字列を持つ 1 行 JSON と exit 1、hook は stdout 空と exit 0 を返し、いずれも呼出元名・コード・理由を stderr に出さなければならない（MUST）。ロード失敗・解決 API の欠損や非 callable・呼出し時の通常例外（`RuntimeError` 等）・必須の戻り値の欠損のコードは resolver_unavailable とし、既存の ValueError による invalid_table / invalid_override の分類は維持する（MUST）。捕捉は共通処理との境界（API の取得・呼出し・必須結果の取り出し・診断準備）に限り、`BaseException` や処理全体の一括握り潰しに広げてはならず（MUST NOT）、失敗時に途中出力や traceback を出してはならない（MUST NOT）。hook の正数条件違反は invalid_hook_threshold とする（MUST）。失敗時に隠れた定数や環境値だけで解決成功を装ってはならない（MUST NOT）。

守備範囲は、利用者の引数・env、同梱表・共通処理を入力元とする設定不良・ロード失敗・API 欠損と呼出し時の通常例外を通知して既存 fail-open へつなぐことである。不正な表や利用対象の不正 env、共通処理の欠損を黙って既定値で補い成功を装う誤りと、hook がそれらの失敗でツールを止める誤りを拾う。形式が正しい同梱表の根拠内容の真偽は検証せず、その表が通常の解決に通ることを許す。入力の穴の完全封鎖や予測不能な全障害の完全処理は完了条件にしない。

#### Scenario: 壊れた表でも隠れた値を使わない

- **WHEN** 一時プラグインの表を欠損または不正 JSON にして、測定可能なログで両スクリプトを実行する（CLI の有効な `--cap` がある場合も含む）
- **THEN** CLI は `error` の JSON と exit 1、hook は stdout 空・exit 0、両 stderr に invalid_table と理由を返す。env や定数だけで測定成功・通知・拒否を返さない

#### Scenario: 不正な関連 env では理由付き fail-open

- **WHEN** CLI の文脈上限 env または hook の文脈上限 / 強制停止 env に `-1`・`1.5`・`abc` をそれぞれ渡し、CLI の `--cap` は指定しない
- **THEN** CLI は exit 1、hook は stdout 空・exit 0 で、stderr に invalid_override・env 名・理由を出す。モデル既定値へ黙って戻らない

#### Scenario: 共通部品をロードできなくても hook は拒否しない

- **WHEN** 一時プラグインから共通処理を取り除き、測定可能なログで両スクリプトを実行する
- **THEN** CLI は `error` の JSON と exit 1、hook は stdout 空・exit 0 で、stderr に resolver_unavailable と原因を出す。未捕捉例外で出力契約を壊さない

#### Scenario: 判定する対象が無い既存の終了経路を保つ

- **WHEN** CLI に対象ログや採用できる usage が無い、または hook が全解除・python3 不在・メインスレッド・対象ログ無し・usage 無し・探索打切りに当たる
- **THEN** CLI は従来のエラー JSON と exit 1、hook は従来どおり両出力とも空・exit 0。hook の該当早期経路では Python を追加起動しない。対象モデルが分からないというだけの診断をこれらの経路に追加しない

#### Scenario: ロードできても解決 API が使えなければ拒否も未捕捉例外もない

- **WHEN** ロード可能な一時の共通処理モジュールで、①解決関数の欠損、②非 callable、③呼出し時の `RuntimeError`、④必須キーを欠く戻り値のそれぞれを用意し、測定可能なログで両スクリプトを実行する（CLI の有効な `--cap` がある場合も含む）
- **THEN** CLI は `error` 文字列を持つ 1 行 JSON と exit 1、hook は PreToolUse・PostToolUse とも stdout 空・exit 0 で、stderr に呼出元名・resolver_unavailable・原因を出す。stdout にも stderr にも traceback は出ず、既存の invalid_table / invalid_override の検査は変わらない。④の場合、stderr は呼出元名・resolver_unavailable・原因の行だけで、その前に fallback や再検証の診断を出さない
