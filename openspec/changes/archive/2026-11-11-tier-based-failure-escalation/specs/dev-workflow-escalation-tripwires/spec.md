## MODIFIED Requirements

### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、作業役（develop スキルの W、または hook 注入を読む本体自身）が手を止める条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → 分割**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた。W として起動されている場合は本体に return し、本体が change / 子 issue（develop スキルのエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop のエピック化、またはネイティブ Workflow 実行（型は `plugins/dev-workflow/references/workflow-execution.md`。スクリプトは `workflow-authoring` スキルを読んで書く）に切り替える
2. **失敗ループ → 決める役 / 実行役の分離ラダー**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した。実行役を1段ずつ上げるのではなく、失敗の原因が「決めた内容が間違っていた（判断側）」か「決めたとおりに実行できなかった（実行側）」かで、上げる相手を**一方だけ**決める（両方同時に上げない）。決める役は数ターンで終わるので先に上げ、実行役を上げるのは実行側が原因と分かったときだけとする（SHALL）。ラダーは格（最安・中位・上位・最上位。語の正本は `model-tier-resolution`）と、`codex-develop.py request` に渡す `--failure` の値で書かなければならない（MUST）。モデル名は `plugins/dev-workflow/references/model-tier-map.json` で引いた値とし、Claude での値は括弧書きの例に留めなければならない（MUST。Claude・Codex の片方の名前だけで段を書いてはならない）。表の格は `request` の要求の格（`requested_tier`。残量モードと構成の上限を適用する前の値）であり、テンプレートはそのことを表の直前か直後に明記しなければならない（MUST）。ラダーは次のとおり:

   | 段階 | `--failure` | 決める役の要求の格（phase `decider`） | 実行役の要求の格（W の phase） |
   |---|---|---|---|
   | 初回 | なし | 仕様化判断と R1 レビューが担う（既存の流れ） | 既定の格（中位。Claude では `sonnet`） |
   | 1 回目の失敗 | `first` | 上位（Claude では `opus`）。失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする | 格を変えずに再試行 |
   | 2 回目の失敗・指示どおりやって結果が違う（実行側） | `executor` | 上位 | 上位（上限。Claude では `opus`） |
   | 2 回目の失敗・指示を解釈できなかった / 指示自体が外れていた（判断側） | `judgment` | 最上位（Claude では `fable`） | 格を変えない |
   | 最上位が決めて上位が実行しても落ちる | — | 人間へ（interactive は AskUserQuestion、unmanned は `needs-approval`） | — |

   各段の決める役と実行役のモデルは、その段の `--failure` の値を渡した `request` が返した `model` を使い、表から計算し直してはならない（MUST NOT。残量モードと構成の上限は `request` が適用済み）。決める役を起こすときは、どの段階でも `subagent_type` を `dev-workflow:decider` に固定しなければならない（MUST。`general-purpose` に読み替えない）。実行役の格の上限は上位であり、実行役を最上位で起こしてはならない（MUST NOT。Claude の強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`）。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では決める役も上位止まりとする（種別は `dev-workflow:decider` のまま）。共有枠モード `SHARED_BUDGET_MODE` の下限が先に効く（`depleted` は昇格なし、`throttled` は上位が上限）。上限を適用したあとの格とモデルは `request` の返り値で決まり、表の格と違ってよい（例: `SHARED_BUDGET_MODE=depleted` では決める役も中位の model が返る）
3. **仕様の発明検知 → 壁打ち/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した。局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻す
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

**守備範囲（失敗ループの原因の分類）**: ①入力の出どころは、W の return にある「指示のどこまでやって、どこで何が起きたか」と失敗したテストの出力、および決める役が出した指示の文面だけである。②拾いたい誤りは、決める役と実行役を両方同時に上げること、原因が判断側なのに実行役を上げること（同じ指示のまま強いモデルで繰り返して消費だけが増える）、実行役を最上位にすること、段に合わない `--failure` の値を `request` に渡すことである。③通してよい入力の例: 原因が判断側にも実行側にも見える return で、本体が理由を書いてどちらか一方を選んで進めることは許す（外れていれば次の失敗で人間へ上がる段に進む）。1 回目の失敗では分類せず `first` を渡すことも許す。④本体の分類がいつも正しいことや、W の return の書き漏れをすべて見つけることは、この要件の完了条件にしない（再開か fresh thread かの判定の守備範囲は `manual-codex-develop` の要件「委譲は前景実行の 3 手順で行う」に従う）。

#### Scenario: 規模超過での乗り換え
- **WHEN** 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、W なら本体に return して分割を委ね、本体自身なら develop のエピック化またはネイティブ Workflow 実行（`references/workflow-execution.md`）に切り替える

#### Scenario: 1 回目の失敗では誰も上げない
- **WHEN** 同じテストが2連続で落ちて 1 回目の失敗として扱う
- **THEN** 実行役は格を変えずに再試行し、`--failure first` を渡した `request` が返した（上限適用後の）model で `subagent_type: dev-workflow:decider` の決める役を立て、失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする

#### Scenario: 実行側が原因なら実行役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示どおりやったのに結果が違うと分類される
- **THEN** 実行役は `--failure executor` を渡した `request` が返した（上限適用後の）model で起こし、決める役も `--failure executor` の返り値を使う。残量モードと構成の上限が無いとき、実行役の格は上位、決める役の格は上位で、最上位にはならない

#### Scenario: 判断側が原因なら決める役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示を解釈できなかった、または指示自体が外れていたと分類される
- **THEN** `--failure judgment` を渡した `request` が返した（上限適用後の）model で決める役（`dev-workflow:decider`）を立て、実行役の格は変えない。残量モードと構成の上限が無いとき、決める役の格は最上位である

#### Scenario: 実行役は Fable にならない
- **WHEN** 昇格ラダーのどの段階かにかかわらず実行役のモデルを決める
- **THEN** 格の上限は上位で、Claude では `model: fable` の実行役 spawn が `agent-model-guard.sh` に拒否される

#### Scenario: ラダーがどちらの提供元でも同じ文で読める
- **WHEN** `templates/escalation-tripwires.md` の失敗ループの表を読む
- **THEN** 各段に `--failure` の値と要求の格が書かれ、表の格が上限適用前の要求の格であることが明記され、モデル名は `references/model-tier-map.json` を引くよう書かれており、Claude のモデル名は括弧書きの例としてだけ現れる

#### Scenario: exhausted では昇格が Opus 上限
- **WHEN** `FABLE_BUDGET_MODE=exhausted` のセッションで失敗ループのトリップワイヤーを踏む
- **THEN** interactive / unmanned を問わず `request` は上位までの model を返し、決める役は `dev-workflow:decider` のままその model で立てられる（種別は変えない）

#### Scenario: depleted では決める役も中位の model になる
- **WHEN** `SHARED_BUDGET_MODE=depleted` のセッションで、2 回目の失敗が判断側と分類される
- **THEN** 本体は `request --phase decider --failure judgment` が返した中位の model で `dev-workflow:decider` を立て、表の要求の格（最上位）から model を計算し直さない

#### Scenario: 仕様の発明での停止
- **WHEN** ユーザーの指示に無い仕様決定（例:「DB は SQLite でいいだろう」）を自分で埋めた回数が2回に達する
- **THEN** 手を止めて埋めた決定を列挙し、局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻し、unmanned なら Discord 質問 + needs-approval でサイクル終了する

#### Scenario: rate-limit 実エラーでの reactive 降格
- **WHEN** Fable 実行が rate-limit / weekly-limit の実エラー（429・weekly limit reached 等）を返す
- **THEN** 予測的な閾値判定とは別系統として、その場で Opus に降格し成果を引き継いで作業を継続し、usage snapshot を更新して以降のセッションの導出に反映する
