## ADDED Requirements

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

CLI は `--cap` > 文脈上限 env > モデル行 / fallback、hook は各文脈 env > モデル行 / fallback で解決しなければならない（MUST）。各呼出元は使う指標の env だけを渡し、CLI の有効な `--cap` は同 env を遮蔽する（MUST）。env は空白だけを未設定、前後空白付き ASCII 非負整数を有効とし、`--cap` は従来の ASCII 数字列だけとする（MUST）。CLI の 0 は有効、hook は cap / hard のどちらかが 0 なら stdout 空・exit 0 の fail-open とし、`hard <= cap` なら PreToolUse だけ fail-open にする（MUST）。

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

- **WHEN** `hard <= cap` の状態で両 hook イベントを実行し、別途 `ctx == cap` と `ctx == hard` の境界も調べる
- **THEN** 大小関係が逆なら PreToolUse は stdout 空・exit 0、PostToolUse は cap 超で通知する。cap / hard ちょうどではその閾値の通知 / 拒否をしない

### Requirement: 文脈計測の診断は既存 JSON と配布先の手順参照を保つ

文脈計測の呼出元は fallback と利用指標の再検証診断を呼出しごとに stderr に出し、環境上書きでも消してはならない（MUST / MUST NOT）。再検証文は要求モデル・根拠モデル・対象指標と、実行中の同梱プラグインを起点とする手順の絶対パスを含める（MUST）。累計・権限の再検証診断をここで出さず、stdout の既存測定 JSON / hook JSON と通知・拒否の本文は保たなければならない（MUST）。診断だけでツールを拒否したり additionalContext に締めの指示を足したりしてはならない（MUST NOT）。

#### Scenario: 未知モデルの診断は出力の形を壊さない

- **WHEN** 未知モデルで CLI、cap 内の PostToolUse と PreToolUse、cap 超の PostToolUse、hard 超の編集ツールの PreToolUse をそれぞれ実行する
- **THEN** 各 stderr に fallback と文脈指標の再検証診断が出る。CLI stdout は測定の 1 行 JSON、cap 内の hook stdout は空、通知と拒否の stdout は従来の単一 JSON で、締め・return 宣言・commit を本体が行う等の既存文を保つ。hook はいずれも exit 0

#### Scenario: 環境上書きと再呼出しでも注意を消さない

- **WHEN** 未知モデルの文脈 env を上書きして、同じログで呼出しを繰り返す
- **THEN** 採用値は上書きに従うが、各呼出しの stderr に同じモデルの fallback と再検証の診断が残る。通知抑制用の状態ファイルを作らない

#### Scenario: 既知モデルでも根拠と違えば再検証を出す

- **WHEN** テスト用の表で、登録固定 ID の文脈指標の根拠モデル集合にその ID が無い状態を作って実行する
- **THEN** モデル行の値を使って fallback 診断は出さず、該当する文脈指標の再検証診断を stderr に出す。根拠に含まれる初期の両既知 ID では両種の診断とも出さない

#### Scenario: 配布先と任意の cwd から手順を開ける

- **WHEN** `plugins/dev-workflow` という親を持たない一時プラグイン配置に実体をコピーし、別の cwd から両スクリプトで未知モデルを測る
- **THEN** stderr の手順パスはそのコピーの `skills/develop/references/token-thresholds.md` を指す実在する絶対パスである。cwd や開発 checkout のパス、共通処理が返す repo 相対パスを誤ってそのまま案内しない

### Requirement: 文脈の共通解決が失敗しても hook はツールを止めない

共通処理の invalid_table / invalid_override またはロード失敗時に、CLI は `error` 文字列を持つ 1 行 JSON と exit 1、hook は stdout 空と exit 0 を返し、いずれも呼出元名・コード・理由を stderr に出さなければならない（MUST）。ロード失敗のコードは resolver_unavailable、hook の正数条件違反は invalid_hook_threshold とする（MUST）。失敗時に隠れた定数や環境値だけで解決成功を装ってはならない（MUST NOT）。守備範囲は設定不良を通知して既存 fail-open へつなぐことであり、予測不能な全障害の完全処理は完了条件にしない。

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

## MODIFIED Requirements

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
