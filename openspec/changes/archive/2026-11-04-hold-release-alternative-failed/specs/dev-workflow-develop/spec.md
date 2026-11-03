## MODIFIED Requirements

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md`（W の修正後の再レビューのときは加えて `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力） | `needs-reviewer` / 保留 / `重複で降りた` |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すとき・`needs-carryover-judge` を返すときは加えて `stages/hold.md`） | passed / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md`（切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節） | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返す（MUST）。`次の段へ` の `次の段: 前提確認と重さ判定` は、W の修正が要らないときだけに使う。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/hold.md` を読んで試す（MUST）。引き継ぎの判定を受けて起こされた合格処理の G（前の Gate Result が `段: 合格処理`・Status `needs-carryover-judge`）は、`declarations.md` の手順 3 から入り直し、3-c で PR の判定の記録を読まなければならない（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい（MAY）。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く（MUST）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、SKILL.md の (4) の範囲と gate-runner.md の全体に `SendMessage` と `G を再開` の文字列が無い

#### Scenario: 従来経路の G

- **WHEN** develop の本体以外の呼び出し元が `レビュー経路: 従来` で G を起こす
- **THEN** G は手順 1〜5 と保留までを 1 体で続けてよく、Gate Result に `段: 一括（従来経路）` と `次の段: なし` を書く

#### Scenario: 代替案への作り直し

- **WHEN** 主が許容せず、代替案で手順 2 からやり直すと答える
- **THEN** 保留の解除の G は `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返し、次の前提確認と重さ判定の G は W の修正後の再レビューとして `周回:` を 1 増やす

#### Scenario: 保留の解除のあとの合格処理

- **WHEN** 保留の解除の G が主の許容を受けて `次の段へ`・`次の段: 合格処理` で返し、本体が合格処理の G を起こす
- **THEN** 合格処理の G は前の Gate Result の `段: 保留の解除` を見て、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば宣言を出し直さず手順 5 の真正性確認から入る

#### Scenario: 切り出しの確認を解除したあとの合格処理

- **WHEN** 照合と振り分けの G が切り出すかを主に聞く保留を返し、主が「切り出す」と答えて保留の解除の G が `次の段: 合格処理` で返す
- **THEN** 今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントが無いので、合格処理の G は `declarations.md` の手順 3 から入る

#### Scenario: 保留の解除の G が切り出しの確認の回答で追加に読むもの

- **WHEN** `gate-runner.md` の「時点ごとに読むファイル」の表の保留の解除の行を読む
- **THEN** 切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読むことが書かれている

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

#### Scenario: 段の表に needs-fix-check がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 照合と振り分けの行の起こす時点に「直し方の判定を受け取ったとき」があり、返しうる Status に `needs-fix-check` がある

#### Scenario: 段の表に needs-carryover-judge がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 合格処理の行の起こす時点に「引き継ぎの判定を受け取ったとき」があり、返しうる Status に `needs-carryover-judge` がある

#### Scenario: 引き継ぎの判定のあとの合格処理

- **WHEN** 合格処理の G が `needs-carryover-judge` で返し、本体が判定の記録を投稿して合格処理の G を新しく起こす
- **THEN** 新しい合格処理の G は前の Gate Result の `段: 合格処理`・Status `needs-carryover-judge` を見て `declarations.md` の手順 3 から入り直し、3-c で判定の記録を読む

### Requirement: Gate Result は段と次の段を持つ

`gate-runner.md` の Gate Result の共通欄は、`段: <前提確認と重さ判定|照合と振り分け|合格処理|保留の解除|一括（従来経路）>` と `次の段: <段の名前|なし>` を持たなければならない（MUST）。Status には `次の段へ` と `needs-fix-check`（直し方の判定の依頼）と `needs-carryover-judge`（許容の引き継ぎの判定の依頼）と `重複で降りた`（前提確認と重さ判定の G が、同じ HEAD に別のセッションの担当が着手済みと見て降りたとき）を足す（MUST）。降りる条件・降りない例外・`担当セッション:` の行・守備範囲は `dev-workflow-pr-review-gate` の要件「着手前の重複チェックで別のセッションの担当と重ならない」に従い、本体は主から前の担当は止まっていると聞いて同じ HEAD のゲートを取り直すとき、G の起動指示に `取り直し: 明示（理由）` の 1 行を書かなければならない（MUST）。`次の段:` の値は G が次の表どおりに決めて書く（MUST）。

| Status | `次の段:` |
|---|---|
| `次の段へ` | 照合と振り分けの G は `合格処理`。保留の解除の G は `合格処理`、または W の修正が要らないときだけ `前提確認と重さ判定`（代替案への作り直しは failed で返す） |
| failed | 戻した指摘が順 3 だけなら `照合と振り分け`、それ以外は `前提確認と重さ判定` |
| needs-reviewer / needs-decider / needs-fix-check | `照合と振り分け` |
| needs-carryover-judge | `合格処理` |
| 保留 | `保留の解除` |
| passed / review-incomplete / 重複で降りた | `なし` |

本体は Status と `次の段:` だけを見て次に起こす G の段を決め、段についての判断（止める指摘が残っているか、戻した指摘の仕分け、復帰手順がどこへ進むか）をしてはならない（MUST NOT）。failed のときは W の修正のあと、failed の Gate Result の `次の段:` どおりに起こす（MUST）。戻した指摘が順 3 だけの修正のあとに起こされた照合と振り分けの G は、`stages/prepare.md` の手順 1 で新しい HEAD を固め、前の重さ判定を写した `レビュー重量:` コメントを `固定 HEAD: <新しい HEAD>` 付きで投稿してから 2 段の照合に入らなければならない（MUST）。

#### Scenario: 重複で降りた

- **WHEN** 前提確認と重さ判定の G が、最新の `レビュー重量:` コメントの `固定 HEAD:` が現在の HEAD と一致し、`agent-review:passed` が付いておらず、`担当セッション:` が自分のセッション ID と違い（行が無い・自分の ID が取れないときも違うとみなす）、起動指示に `取り直し: 明示（理由）` の行も前の段の Gate Result も無いため降りる
- **THEN** Gate Result は Status `重複で降りた`・`次の段: なし` を持ち、本体は取り直さずに着手済みコメントの URL を主に報告し、主から前の担当は止まっていると返事が来てから `取り直し: 明示（理由）` を添えて起こし直す

#### Scenario: 順 3 だけの failed

- **WHEN** 照合と振り分けの G が、戻す指摘が順 3 だけの failed を返す
- **THEN** Gate Result は `次の段: 照合と振り分け` を持ち、本体は W の修正のあと照合と振り分けの G を起こす

#### Scenario: 止める指摘が無いとき

- **WHEN** 照合と振り分けの G が止める指摘なしで終わる
- **THEN** G は Status `次の段へ`、`次の段: 合格処理` で返し、本体は合格処理の G を新しく起こす

#### Scenario: needs-fix-check の次の段

- **WHEN** 照合と振り分けの G が Status `needs-fix-check` で返す
- **THEN** Gate Result は `次の段: 照合と振り分け` を持ち、本体は直し方の判定のあと照合と振り分けの G を新しく起こす

#### Scenario: needs-carryover-judge の次の段

- **WHEN** 合格処理の G が Status `needs-carryover-judge` で返す
- **THEN** Gate Result は `次の段: 合格処理` を持ち、本体は判定役の判定のあと合格処理の G を新しく起こす
