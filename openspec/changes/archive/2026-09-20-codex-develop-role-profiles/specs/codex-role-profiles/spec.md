## ADDED Requirements

### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --executor codex --profile NAME [--profile-file PATH]` と対応する develop CLI init を提供しなければならない（MUST）。組み込み名は codex-standard と codex-economy とし、各 entry は executor/account/model/effort を持つ。形式版1の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。この版は codex executor のみ受理し、Claude Agent 混在を拒否する。profile と旧 account/model の併用を拒否しなければならない（MUST）。

#### Scenario: 二つの組み込みセットを解決する
- **WHEN** codex-standard または codex-economy を init する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review/decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。正式モデル名は design の表の値と一致し、全 entry は executor=codex、account=current となる

#### Scenario: 役割ごとに登録 account を選ぶ
- **WHEN** version=1 の外部 profile-file の各役割に異なる登録 account を指定して init する
- **THEN** 各 entry の account を保存し、外部ファイルを組み込みと merge せず、各 job は当該 entry の account だけを使う

#### Scenario: 曖昧または不完全な指定を拒否する
- **WHEN** profile と account/model のいずれかを併用する、profile-file のみ指定する、未知版/名前/キー/役割・重複キー・欠落役割・空値・未登録 account・非codex executor がある
- **THEN** init は失敗し、実行可能な run や job を作らず、既定値や別 account に置換しない

### Requirement: 解決済み設定と版を init で固定する
profile run は execution_config の version/profile/roles と execution_config_hash を保存しなければならない（MUST）。resume は保存 snapshot を正本とし、外部設定を再読込してはならない（MUST NOT）。旧 run は従来の account/model を全役割へ適用し、effort 省略を保持しなければならない（MUST）。

#### Scenario: 設定ファイルが変更または削除される
- **WHEN** init 後にファイルを変更/削除して別工程を dispatch または継続復元する
- **THEN** 保存した版/名前/全 entry だけで解決し、snapshot/hash 不一致や未知版なら停止する

#### Scenario: 旧 run を再開する
- **WHEN** execution_config を持たない旧 run を再開する
- **THEN** 全役割に旧 account/model を適用し、run や旧 request に effort を追加しない

### Requirement: pending の役割と設定を固定して再送する
profile dispatch は pending_execution の role/executor/account/model/effort と payload hash を submit より前に保存しなければならない（MUST）。retry はこれらと snapshot、保存 request の request_id/cwd/role/設定/hash を照合し、元 request を再生成せず submit しなければならない（MUST）。旧 pending のキーや hash を変更してはならない（MUST NOT）。

#### Scenario: 異なる役割 account を持つ run の送信応答が失われる
- **WHEN** spec-review の pending があり retry する
- **THEN** run 全体の account/model ではなく spec-review の固定 entry を照合し、元 request_id と payload のまま同一 job を回収する

#### Scenario: pending の値が変わる
- **WHEN** executor/account/model/effort/role/cwd/request_id/hash または snapshot との一致が崩れる
- **THEN** retry は拒否し、prompt 再生成、新しい job、別 account への送信を行わない

#### Scenario: 旧 pending を新しい worker で再送する
- **WHEN** effort が無く旧テンプレートの prompt を持つ保存 request を retry する
- **THEN** 元キーと値と payload hash を維持し、effort=null や executor も追記せず、既存結果があれば model/list を呼ばず回収する

#### Scenario: unknown の job を再送する
- **WHEN** 同じ request_id が unknown として保存されている
- **THEN** 同一 job の状態を返すだけで再実行せず、ack や別 job への置換による迂回を許さない

### Requirement: 設定切替は品質工程を変えない
役割/ティアは既存 roles と model-tiers を参照し、phase は役割指示の選択に留めなければならない（MUST）。spec/review/finish/gate の既存 role 対応を保持し、explore/summarize は read-only の任意の補助役としなければならない（MUST）。手動とバーンの呼び出し側に同じ版付き設定と CLI resolver を提供し、独自の品質工程を作ってはならない（MUST NOT）。

#### Scenario: セットを切り替えて既存工程を実行する
- **WHEN** 標準/節約/旧形式で同じ coordinator の仕様不要・仕様必要・レビュー差戻し・gate 失敗の fixture を実行する
- **THEN** 仕様要否、独立レビュー条件、工程順、差戻し判断/上限は同じであり、変わるのは設定と観測結果だけである。finish/gate は implement の設定を使う

#### Scenario: 手動とバーンの呼び出し例を解決する
- **WHEN** 同じ名前と設定を手動 CLI とバーン呼出し側の fixture から同じ init/resolver に渡す
- **THEN** 同じ snapshot が得られ、手動でバーン窓を要求せず、バーン接続/自動配分を今回新設しない

### Requirement: 実モデル受け入れと回帰を残す
実装は両セットそれぞれで仕様作成、独立仕様レビュー、実装、独立実装レビューを実モデルで一件完走し、各役割の要求と取得できた実効 model/effort、account、executor、job/thread/turn ID、対象 HEAD を記録しなければならない（MUST）。未観測の実効設定や失敗を成功と扱ってはならない（MUST NOT）。

#### Scenario: 両セットの実機証拠を検査する
- **WHEN** coordinator が各セットの実行証跡を回収する
- **THEN** 別 job/thread の独立レビューと実効設定の観測元を確認でき、実効値が未観測または要求と異なる場合はその受け入れを未達と報告する

#### Scenario: ローカル回帰を実行する
- **WHEN** scripts/test.sh と test_codex_*.py を実行する
- **THEN** worker の開始前拒否/両RPC、develop の工程不変/pending固定/旧retry/継続v1-v2を fixture で検証し、薄い bats ラッパー経由でも Python 回帰が全件検出される
