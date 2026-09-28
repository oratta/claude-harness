## ADDED Requirements

### Requirement: W と G は役割ごとの種別で起こす
develop の本体は W を `subagent_type: dev-workflow:worker`、G を `subagent_type: dev-workflow:gate-runner` で spawn しなければならない（MUST）。`general-purpose` で起こしてはならない（MUST NOT）。種別を替えても `model` は従来どおり spawn のたびに明示しなければならない（MUST。W は事前分類に当たれば `opus`、それ以外 `sonnet`。G は `sonnet`）。手渡しで後任を起こすときと、段ごとに新しい G を起こすときも同じ種別を使う（SHALL）。

`references/codex-develop.md` の Claude role の起動（W / G を Claude で起こす経路）も同じ種別を使わなければならない（MUST）。

仕様レビュー R1（決める役でないとき）と、G が要求するレビュアーの種別は変えない（SHALL。`general-purpose`。決める役に当たるときは従来どおり `dev-workflow:decider`）。

`develop/SKILL.md` の役割表と (1)・(3)・(4) の spawn の記述、`references/roles/worker.md`・`references/roles/gate-runner.md` の冒頭は、それぞれの種別を書かなければならない（MUST）。

#### Scenario: 役割表が種別を書く
- **WHEN** `plugins/dev-workflow/skills/develop/SKILL.md` の役割表を読む
- **THEN** W の行に `dev-workflow:worker`、G の行に `dev-workflow:gate-runner` があり、R1 とレビュアーの行は `general-purpose`（決める役に当たるときは `dev-workflow:decider`）のまま

#### Scenario: spawn の記述が種別を書く
- **WHEN** `develop/SKILL.md` の (1) と (4) の spawn の行、`worker.md` と `gate-runner.md` の冒頭、`references/codex-develop.md` の Claude role の起動を読む
- **THEN** W には `dev-workflow:worker`、G には `dev-workflow:gate-runner` が書かれ、W / G を `general-purpose` で起こす記述が無い

### Requirement: W は Skill を使わず openspec CLI で進める
`dev-workflow:worker` は `Skill` を持たないので、W は `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` を呼んではならない（MUST NOT）。仕様化は `openspec new change` と artifact の直書き（雛形は `openspec instructions <artifact> --change <name>`）、実装の検証は `openspec validate <change> --strict` と `tasks.md` のチェックボックスの確認、archive は `openspec archive <change>` で行わなければならない（MUST）。工程の区切り（(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言）と R1 の仕様レビューは変えない（SHALL）。

既存の要件と文書が W に `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` を指示している箇所は、それぞれ上の CLI の手順と読み替えなければならない（MUST）。`/opsx:verify` の合否を載せるとしている箇所は、`openspec validate <change> --strict` の exit code と読み替える（SHALL）。`worker.md` の本文は CLI の経路を既定として書かなければならない（MUST）。

#### Scenario: worker.md が CLI の経路を既定にする
- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/worker.md` の仕様化と (3a)・(3b) の節を読む
- **THEN** `openspec new change`・`openspec validate <change> --strict`・`openspec archive <change>` を使う手順が既定として書かれ、W が `/opsx:` のスラッシュコマンドを実行する指示が無い

### Requirement: .worktreeinclude が無いときの /wt-setup は本体が行う
worktree に `.worktreeinclude` が無いときに `/wt-setup` を呼ぶのは本体でなければならない（MUST）。W は `/wt-setup` を呼んではならない（MUST NOT。`dev-workflow:worker` は `Skill` を持たない）。`worker.md` の「W がしないこと」から W が `/wt-setup` を呼ぶ例外を消し、`develop/SKILL.md` の worktree を用意する節に本体の仕事として書かなければならない（MUST）。

#### Scenario: 例外が本体の仕事に移っている
- **WHEN** `worker.md` と `develop/SKILL.md` を読む
- **THEN** `worker.md` に W が `/wt-setup` を呼ぶ記述が無く、`develop/SKILL.md` の worktree を用意する節に、`.worktreeinclude` が無いとき本体が `/wt-setup` を呼ぶことが書かれている

### Requirement: W の (3a) の return は画面確認の要否を 1 行で書く
W の (3a) の return（1 行目 `工程完了: 実装＋verify`）は、`画面確認:` で始まる行を 1 行持たなければならない（MUST）。値は `不要` か、`要る — <開く URL か起動手順> / <見る点>` のどちらかとする（SHALL）。`要る` のときは開く URL か起動手順と、見る点の両方を書かなければならない（MUST。画面確認役 V は実装の経緯を知らないため）。要否は、受け入れ条件または記録先の「動作確認ポイント」が画面での観測を求めているかで W が決める（SHALL）。W 自身は画面で確認しない（MUST NOT）。

#### Scenario: 画面確認が要らない変更
- **WHEN** 受け入れ条件が画面での観測を求めない変更で W が (3a) を終えて return する
- **THEN** return に `画面確認: 不要` の行がある

#### Scenario: 画面確認が要る変更
- **WHEN** 受け入れ条件が画面での観測を求める変更で W が (3a) を終えて return する
- **THEN** return に `画面確認: 要る — ` で始まり、URL か起動手順と見る点を `/` で区切って書いた行がある

### Requirement: 画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす
本体は W の (3a) の return の `画面確認:` の行が `要る` のときだけ、(3b) を指示する前に画面確認役 V を spawn しなければならない（MUST）。`不要` のときは V を起こしてはならない（MUST NOT）。V は `subagent_type: general-purpose`・`model: sonnet` で起こし（SHALL。ブラウザの道具を持つ既存の種別を使い、新しい種別を作らない）、名前は `V-<記録先番号>-<n>`、description は `V: screen check for #N` とする（SHALL。先頭の `V:` を残す）。V の指示書は `skills/develop/references/roles/screen-checker.md` に置かなければならない（MUST）。

V はファイルを編集してはならず、commit・push・記録先への投稿もしてはならない（MUST NOT）。V の return の 1 行目は `^画面確認結果: (合格|不合格|実行不能)$` に一致しなければならない（MUST）。

- `合格`: 2 行目以降に、開いた URL・見た要素・観測した値を書く（MUST）。本体はその return を (3b) の W に渡し（MUST）、(3b) の W はそれを動作確認の証拠の入力にする（SHALL）
- `不合格`: 2 行目以降に、期待と違った観測を書く（MUST）。本体は (3b) に進まず、W を (3a) で再開して直させなければならない（MUST）。同じ画面確認で `不合格` が 2 回続いたら、昇格トリップワイヤーの失敗ループ（同じテストが 2 連続で落ちた）と同じ扱いにする（SHALL）
- `実行不能`: Chrome 拡張が繋がらない・無人実行で拡張が無いなど、観測できなかった理由を書く（MUST）。本体は (3b) の W に「画面確認は実行不能」と理由を渡し、(3b) の W は画面確認の証拠を書かない（SHALL）。そのあとは pr-review-gate の既存の保留経路（自力で検証できない動作確認を主に依頼する経路）に委ねる（SHALL）。V は待ったり、主に直接依頼したりしてはならない（MUST NOT）

V は数ターンで終わる役なので、SendMessage で再開してはならない（MUST NOT）。もう一度確認が要るときは新しい V を起こす（SHALL）。

#### Scenario: 画面確認が要るときだけ V を起こす
- **WHEN** W の (3a) の return に `画面確認: 要る — http://localhost:3000/settings / 保存ボタンを押すとトーストが出る` がある
- **THEN** 本体は (3b) の前に V を `general-purpose`・`model: sonnet` で起こし、V の return を (3b) の W に渡す

#### Scenario: 画面確認が要らないときは V を起こさない
- **WHEN** W の (3a) の return に `画面確認: 不要` がある
- **THEN** 本体は V を起こさずに (3b) を指示する

#### Scenario: V がブラウザの道具を使える
- **WHEN** Chrome 拡張が繋がった環境で V を起こし、1 ページを開かせる
- **THEN** V は `mcp__claude-in-chrome__*` の道具でページを開き、`画面確認結果: 合格` または `不合格` と観測した内容を返す

#### Scenario: 拡張が繋がらないときは既存の保留経路に落とす
- **WHEN** V が `画面確認結果: 実行不能` を返す
- **THEN** 本体は (3b) の W に実行不能とその理由を渡し、(3b) の W は画面確認の証拠を書かず、動作確認は pr-review-gate の保留経路で主に依頼される

#### Scenario: 不合格なら (3a) に戻す
- **WHEN** V が `画面確認結果: 不合格` を返す
- **THEN** 本体は (3b) を指示せず、V の観測を渡して W を (3a) で再開する
