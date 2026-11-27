## MODIFIED Requirements

### Requirement: 憲法テンプレートは昇格トリップワイヤーを Step 3 に含む
`plugins/loops/templates/agent-loop-template.md` は、Step 3（実装モード）に昇格トリップワイヤー節を含まなければならない (SHALL)。節は3本のワイヤーを行為ベースの数えられる条件で定義し、それぞれ unmanned の既存経路に写像する: ①規模超過（編集対象ファイル5個超、または作業項目が見積もりから2回増）→ W が本体（憲法のメイン）に return し、develop スキルの判定（サブ issue 分割）に従う、②失敗ループ（同一テスト2連続失敗、または同一箇所2回書き直し）→ 本体が W を1段昇格したモデルで再開、③仕様の発明（issue に無い仕様決定を2回埋めた）→ 埋めた決定を列挙して Discord で質問し `needs-approval` を付けてサイクル終了。閾値が初期値であること、乗り換え時の成果引き継ぎ、dev-workflow のテンプレートへの参照を含めること。

Step 3 の開発の中身の委譲先は `dev-workflow` プラグインの `develop` スキル（`--unmanned`）でなければならず（MUST）、`github-issue` への参照を残してはならない（MUST NOT）。**develop の本体（オーケストレータ）は憲法のメイン自身が務め**、W / R1 の spawn はメインが行う（MUST）。Step 3 の実装をサブエージェントに委譲してそのサブエージェントに develop を起動させてはならない（MUST NOT。サブエージェントは Agent ツールを持たず W / R1 を起こせないため）。「コンテキスト管理（ディスパッチャ方式）」節の委譲対象から Step 3 を外し、Step 3 はメインが develop の本体として W / R1 を起こす旨に改める（SHALL）。

#### Scenario: トリップワイヤー3本が数値条件付きで存在する
- **WHEN** ユーザーが憲法テンプレートの Step 3 を読む
- **THEN** 規模超過・失敗ループ・仕様の発明の3本が、5個超・2連続・2回といった数えられる条件と、それぞれの乗り換え先（既存経路）付きで記載されている

#### Scenario: アクションに Workflow ツールの直接操作が無い
- **WHEN** 憲法テンプレートのトリップワイヤー節を検査する
- **THEN** 発火時のアクションはスキル呼び出し・本体への return・既存の憲法経路（サブ issue 分割 / Discord + needs-approval）のみで、Workflow ツールの直接呼び出し指示は含まれない

#### Scenario: 委譲先が develop でメインが本体を務める
- **WHEN** 憲法テンプレートとレシピ（`recipes/loop-dev-agent.md`）を grep する
- **THEN** Step 3 の委譲先は `develop` スキルであり、`github-issue` という文字列は現れず、Step 3 は「メインが develop の本体として W / R1 を spawn する」と書かれ、ディスパッチャ方式の委譲対象に Step 3 が含まれていない
