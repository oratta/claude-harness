## MODIFIED Requirements

### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、作業役（develop スキルの W、または hook 注入を読む本体自身）が手を止める条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → 分割**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた。W として起動されている場合は本体に return し、本体が change / 子 issue（develop スキルのエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop のエピック化、またはネイティブ Workflow 実行（型は `plugins/dev-workflow/references/workflow-execution.md`。スクリプトは `workflow-authoring` スキルを読んで書く）に切り替える
2. **失敗ループ → 決める役 / 実行役の分離ラダー**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した。実行役を1段ずつ上げるのではなく、失敗の原因が「決めた内容が間違っていた（判断側）」か「決めたとおりに実行できなかった（実行側）」かで、上げる相手を**一方だけ**決める（両方同時に上げない）。決める役は数ターンで終わるので先に上げ、実行役を上げるのは実行側が原因と分かったときだけとする（SHALL）。ラダーは次のとおり:

   | 段階 | 決める役 | 実行役 |
   |---|---|---|
   | 初回 | 仕様化判断と R1 レビューが担う（既存の流れ） | `sonnet` |
   | 1 回目の失敗 | `dev-workflow:decider` を `model: opus` で spawn（本体が opus 以上ならその場で）し、失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする | `sonnet` で再試行 |
   | 2 回目の失敗・指示どおりやって結果が違う | `dev-workflow:decider`（`model: opus`） | `opus` |
   | 2 回目の失敗・指示を解釈できなかった / 指示自体が外れていた | `dev-workflow:decider`（`model: fable`。本体が fable ならその場で） | `sonnet` または `opus` |
   | fable が決めて opus が実行しても落ちる | 人間へ（interactive は AskUserQuestion、unmanned は `needs-approval`） | — |

   決める役を spawn するときは、どの段階でも `subagent_type` を `dev-workflow:decider` に固定し `model` だけを切り替えなければならない（MUST。`general-purpose` に読み替えない）。実行役の上限は `opus` であり、実行役を Fable で spawn してはならない（MUST NOT。強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`）。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では決める役も `model: opus` 止まりとする（種別は `dev-workflow:decider` のまま）。共有枠モード `SHARED_BUDGET_MODE` の下限が先に効く（`depleted` は昇格なし、`throttled` は Opus 上限）
3. **仕様の発明検知 → 壁打ち/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した。局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻す
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、W なら本体に return して分割を委ね、本体自身なら develop のエピック化またはネイティブ Workflow 実行（`references/workflow-execution.md`）に切り替える

#### Scenario: 1 回目の失敗では誰も上げない
- **WHEN** 同じテストが2連続で落ちて 1 回目の失敗として扱う
- **THEN** 実行役は `sonnet` のまま再試行し、`subagent_type: dev-workflow:decider` を `model: opus` で立てた決める役が失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする

#### Scenario: 実行側が原因なら実行役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示どおりやったのに結果が違うと分類される
- **THEN** 実行役を `opus` に上げ、決める役は `opus` のままで Fable には上げない

#### Scenario: 判断側が原因なら決める役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示を解釈できなかった、または指示自体が外れていたと分類される
- **THEN** 決める役を `dev-workflow:decider`（`fable`）に上げ、実行役は `sonnet` または `opus` のままとする

#### Scenario: 実行役は Fable にならない
- **WHEN** 昇格ラダーのどの段階かにかかわらず実行役のモデルを決める
- **THEN** 上限は `opus` で、`model: fable` の実行役 spawn は `agent-model-guard.sh` に拒否される

#### Scenario: exhausted では昇格が Opus 上限
- **WHEN** `FABLE_BUDGET_MODE=exhausted` のセッションで失敗ループのトリップワイヤーを踏む
- **THEN** interactive / unmanned を問わず昇格は Opus までに留まり、決める役は `dev-workflow:decider` のまま `model: opus` で立てられる（種別は変えない）

#### Scenario: 仕様の発明での停止
- **WHEN** ユーザーの指示に無い仕様決定（例:「DB は SQLite でいいだろう」）を自分で埋めた回数が2回に達する
- **THEN** 手を止めて埋めた決定を列挙し、局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻し、unmanned なら Discord 質問 + needs-approval でサイクル終了する

#### Scenario: rate-limit 実エラーでの reactive 降格
- **WHEN** Fable 実行が rate-limit / weekly-limit の実エラー（429・weekly limit reached 等）を返す
- **THEN** 予測的な閾値判定とは別系統として、その場で Opus に降格し成果を引き継いで作業を継続し、usage snapshot を更新して以降のセッションの導出に反映する
