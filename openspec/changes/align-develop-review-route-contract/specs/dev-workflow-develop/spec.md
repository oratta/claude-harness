## MODIFIED Requirements

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の adapter が返した model に残量上限を適用した値を使い、G の推奨 model は参考値として扱わなければならない（MUST）。残量モード（`FABLE_BUDGET_MODE`）は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に従い、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由、`abundant` はどの役割も上げない、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、`SHARED_BUDGET_MODE` の `throttled` / `depleted` で `sonnet` 起点、と書かれている

#### Scenario: レビュアーの model 決定元を経路で分ける
- **WHEN** SKILL.md の「G が要求するレビュアー」の行を読む
- **THEN** 従来経路では G の推奨 model に従い、adapter 経路では adapter が返した model に残量上限を適用した値を使って推奨 model は参考値とする、と書かれている

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い

### Requirement: G はレビュー経路を起動指示の 1 行で判別する
develop の本体は、(4) で G を起動する指示・再開する指示・手渡しで後任の G を起動する指示のすべてに、起動形を問わず**常に** `レビュー経路: adapter` の 1 行を書かなければならない（MUST）。条件付きにしてはならない（MUST NOT）。現行の develop は実行先の 3 つの起動形（自動選択・明示 profile・旧形式の account/model 指定）すべてを adapter（`codex-develop.py request`）で解決するため、develop の本体が G を起こす場面はすべて adapter 経路である。Codex の G に対しては、request の instructions（`--input` に渡す指示ファイル）が起動指示に当たり、そこにも同じ行を書かなければならない（MUST）。

`レビュー経路: 従来` は、develop の本体以外の呼び出し元が `gate-runner.md` で G を起こす場合と、行を書かない古い本体のための値であり、develop の本体は書いてはならない（MUST NOT）。

`gate-runner.md` は、新しい G が起動指示の `レビュー経路:` 行だけで経路を判別し、環境変数・記録先のコメント・自分の起動方法から推測しないことを書かなければならない（MUST）。`レビュー経路: adapter` で起動された同一の G は、その後の再開指示に `レビュー経路:` 行が無くても adapter 経路のまま動かなければならない（MUST）。行が無いときに従来経路として扱う規則は、新しい G の起動指示（手渡しで起こされた後任 G の起動指示を含む）に行が無かった場合にだけ適用しなければならない（MUST）。あわせて、`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、従来モードのレビュー実行者の表は `レビュー経路: 従来`、または行の無い起動指示で開始された G にだけ適用すると書かなければならない（MUST）。`SKILL.md` は、G の起動・再開指示に常に `レビュー経路: adapter` を書く本体の責任を、Role profile の選択節と (4) の両方に書かなければならない（MUST）。

`codex-develop.md` は、行が無い fresh G を従来経路として扱う説明を executor ごとに分け、Claude の G は full で Codex を直接呼び、Codex の G は prompt の禁止により Codex を直接呼ばないことを書かなければならない（MUST）。経路の既定と executor に許された操作を同一視してはならない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、呼び出し元から G へ渡される起動指示と再開指示である。防ぐ誤りは、adapter 経路で起動済みの同一 G が、再開指示で `レビュー経路:` 行が欠落したために従来経路へ切り替わることと、従来経路の Codex G が provider の禁止を越えて別の Codex を直接呼ぶことである。一方、行の無い指示で新しい G または手渡し後の後任 G が起動された場合に従来経路として扱うこと、従来経路の Claude G が Codex を直接呼ぶことは許容される。任意の不正入力や将来の executor へ対応を際限なく追加することは、この要件の完了条件としない。

#### Scenario: 自動選択での G 起動
- **WHEN** 本体が自動選択（profile も旧形式も無指定）で develop を進め、(4) で G を起動する
- **THEN** G の起動指示に `レビュー経路: adapter` の行があり、G はこの行を見て adapter 経路の規則に従う

#### Scenario: 明示 profile で Codex の G を起動
- **WHEN** 本体が明示 profile で develop を進め、phase `gate` の投げ先が Codex で request を作る
- **THEN** request の instructions に `レビュー経路: adapter` の行がある

#### Scenario: 行が無い Claude G 起動
- **WHEN** `レビュー経路:` の行を含まない起動指示で新しい Claude の G（手渡しで起こされた後任 G を含む）が起動される
- **THEN** G は従来経路として扱い、full では Bash から Codex を直接呼ぶ

#### Scenario: 行が無い Codex G 起動
- **WHEN** `レビュー経路:` の行を含まない起動指示で新しい Codex の G（手渡しで起こされた後任 G を含む）が起動される
- **THEN** G は従来経路として扱うが、prompt の禁止に従って Codex を直接呼ばず `needs-reviewer` を返す

#### Scenario: adapter 経路で起動済みの G を行無しで再開
- **WHEN** `レビュー経路: adapter` で起動された同一の G が、`レビュー経路:` の行を含まない指示で再開される
- **THEN** G は adapter 経路のまま動き、従来経路へ切り替わらない

#### Scenario: 手渡し後の G 再開
- **WHEN** 本体が G を SendMessage で再開する、または手渡しで後任の G を起動する
- **THEN** その指示にも `レビュー経路: adapter` の行がある

### Requirement: adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す
`gate-runner.md` の冒頭にある本体からの入力一覧は、PR 番号・記録先・実行モードに加えて `レビュー経路:` の 1 行を含み、adapter 経路でレビュー要約を受けて再開するときは、選ばれた executor / model と dispatch 記録のコメント URL も入力に含むことを書かなければならない（MUST）。

`gate-runner.md` は、G（phase `gate` として起動された G）が `レビュー経路: adapter` のとき、full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）を済ませ、同一 PR/HEAD で他の G が着手済みでないことを確認してから `needs-reviewer` を返すことを書かなければならない（MUST）。full のときの payload の判定は `full（adapter 経路）` とし、Codex 不可の実測を行わないことを書かなければならない（MUST）。adapter 経路の payload では `選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` を `未実行（adapter 経路）` と書き、Codex の証拠を作らないことを書かなければならない（MUST）。`pr-review-gate/SKILL.md` の PR コメント雛形も、この 5 欄すべての閉じた列挙に `未実行（adapter 経路）` を含めなければならない（MUST）。

この規則は phase `review` のレビュアーとして起動されたときには適用しないと限定しなければならない（MUST）。従来経路の Claude G の既定（full は G の Bash から Codex を直接呼び、Codex が使えないときと light のときだけ `needs-reviewer` を返す）は変えてはならない（MUST NOT）。従来経路の Codex G は prompt の禁止に従って別の Codex を直接呼んではならない（MUST NOT）。

この要件で検査する入力は、G の起動・再開指示、同一 PR/HEAD の着手記録、G が返す payload である。拾う誤りは、経路や再開情報の入力漏れ、同じ PR/HEAD への review dispatch の重複、adapter 経路なのに Codex を実行したような証拠を作ることである。fresh G の行無し指示を従来経路として扱うこと、adapter 経路で 5 欄を明示的な未実行として通すことは許容する。任意の malformed な指示や分散実行のすべての競合を塞ぎ切ることは完了条件としない。

#### Scenario: G の入力一覧が経路と再開情報を含む
- **WHEN** `gate-runner.md` 冒頭の「本体が渡すもの」を読む
- **THEN** `レビュー経路:` の 1 行が含まれ、adapter 経路の再開時は executor / model と dispatch 記録のコメント URL をレビュー要約に含める、と書かれている

#### Scenario: adapter 経路の full レビュー
- **WHEN** `レビュー経路: adapter` で起動された G が手順 2-0 で full と判定する
- **THEN** G は同一 PR/HEAD で他の G が着手済みでないことを確認し、Codex を起動せず、判定 `full（adapter 経路）`・HEAD SHA・受け入れ条件の所在を含み、実行の証拠欄が `未実行（adapter 経路）` の `needs-reviewer` を返す

#### Scenario: adapter 経路の証拠欄をコメント雛形で選べる
- **WHEN** `pr-review-gate/SKILL.md` の PR コメント雛形を読む
- **THEN** `選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` の 5 欄すべてで `未実行（adapter 経路）` を選べる

#### Scenario: 従来経路の Claude G による full レビュー
- **WHEN** `レビュー経路: 従来` で起動された Claude の G が手順 2-0 で full と判定する
- **THEN** G は Bash から `codex exec` または `codex-companion.mjs` で Codex を呼ぶ

#### Scenario: 従来経路の Codex G による full レビュー
- **WHEN** `レビュー経路: 従来` で起動された Codex の G が手順 2-0 で full と判定する
- **THEN** G は prompt の禁止に従って Codex を直接呼ばず `needs-reviewer` を返す

#### Scenario: phase review のレビュアーが gate-runner.md を読む
- **WHEN** Codex に委譲された phase `review` のレビュアーが `gate-runner.md` を読む
- **THEN** adapter 経路の `needs-reviewer` 規則は G 向けに限定されており、レビュアーは自分でレビューを行う
