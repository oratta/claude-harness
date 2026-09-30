## 1. spec delta

- [x] 1.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件に MODIFIED delta（無条件の再開禁止と条件付き手渡し許可の分離、`工程完了:`/`工程中断:` 宣言契約、停止指示〜停止確認、ノンブロッキング待ち、unmanned のサイクル終了）
- [x] 1.2 `dev-workflow-develop` の「本体はオーケストレータ専任でコードもレビューも書かない」要件に MODIFIED delta（同一 worktree の同一役割は常に 1 人）
- [x] 1.3 R1 2 周目の指摘（禁止対象を「作業継続の SendMessage（再開）」に絞る）を spec delta の文言に反映する
- [x] 1.4 `dev-workflow-develop` の「役割のモデルは事前分類と残量モードで決める」要件に重複していた無条件の手渡し記述を MODIFIED delta で条件付きに揃える（ゲート指摘: live spec と archive delta の両方）

## 2. decision-criteria.md 改訂（正本）

- [x] 2.1 「コンテキスト上限（サブエージェントの手渡し）」節に、exit 2 の無条件再開禁止（作業継続の SendMessage のみが対象）と `工程完了:` を条件とする手渡し許可を分けて追記する
- [x] 2.2 `工程完了: <工程名>` / `工程中断: <理由>` の 1 行目宣言契約（正本は worker.md）へのポインタを追記する
- [x] 2.3 前任が動作中に交代させる場合の手順（停止指示 → 停止確認 → spawn。停止確認待ちはノンブロッキング、unmanned は待ち続けずサイクルを終える）を追記する

## 3. worker.md / gate-runner.md 改訂

- [x] 3.1 worker.md「コンテキスト上限と手渡し」節の W 側の義務に、return の 1 行目を `工程完了: <工程名>` / `工程中断: <理由>` に完全一致させる規則（書式は `仕様化判断:` と同型）を追記する
- [x] 3.2 worker.md に、自分が起動したバックグラウンドコマンドが完了していない状態で `工程完了:` を宣言してはならないこと、成果一覧を併記していても未完了なら `工程中断:` にすることを追記する
- [x] 3.3 gate-runner.md に、G の return の 1 行目も同じ宣言契約に従うこと（`## Gate Result` 本文の前に 1 行目として置く）を追記する

## 4. SKILL.md 改訂

- [x] 4.1 1 ループ (3)(4) の「再開前に測り、上限超なら手渡し」の記述に、手渡しは前任の `工程完了:` return が条件であることを示す短いポインタを追加する
- [x] 4.2 「本体の役割」節・複数 change 並列の記述に、並列に起こしてよい役割は別々の worktree を持つものに限ること（同一 worktree に同一役割は常に 1 人）を追記する

## 5. escalation-tripwires.md

- [x] 5.1 トリップワイヤー 4（コンテキスト上限）に、手渡しは前任の `工程完了:` return が条件であること（1〜2 行、詳細は decision-criteria.md へのポインタ）を追記する

## 6. 周辺同期

- [x] 6.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version bump
- [x] 6.2 同じ規則を要約している重複記述を全部揃える（ゲート指摘）: `README.md`・`scripts/session-tripwires.sh` の注入文・`scripts/subagent-context.sh` のヘッダコメント・`plugin.json` の description・SKILL.md 1 ループ (3)(4)・`worker.md` の節冒頭

## 7. テスト

- [x] 7.1 新規 `plugins/dev-workflow/tests/handoff-declaration.bats` で、宣言契約・無条件再開禁止・条件付き手渡し・同一 worktree 制約の記述を grep で固定する
- [x] 7.3 同ファイルに否定アサーションを足す（ゲート指摘）: 手渡しの規則を述べる現行面（正本・live spec・この change の archive delta・README・スクリプト・plugin.json）を列挙し、旧文言（`再開せず／再開しない` に続けて手渡し・新しいエージェントを述べる形）が残っていたら落とす。手渡しに触れる面には必ず `工程完了:` の条件が書かれていることも固定する。CHANGELOG と過去の change の archive は歴史記録なので対象外
- [x] 7.2 このリポジトリのテストスイート（`bats` 等。実行方法は `CONTRIBUTING.md` / `AGENTS.md` で確認）を実行し、既存テスト（`plugins/dev-workflow/tests/subagent-context.bats` を含む）と新規テストが通ることを確認する（`bats plugins/dev-workflow/tests/ tests/marketplace-sync.bats` → 431 件全通過）

## 8. デプロイ後（マージ後の運用）

- [x] 8.1 change を archive し `openspec/specs/` に delta を sync する

## 9. 手渡し規則を 1 箇所に畳む（2026-09-09 の設計変更。spec 済み・apply 未）

- [x] 9.1 `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件を、正本の位置・参照だけにする面の一覧・テストの形を規定する形に組み替える（live spec と archive delta の両方）
- [x] 9.2 `dev-workflow-develop` の「役割のモデルは事前分類と残量モードで決める」要件と、旧一経路のままだった Scenario「再開前にコンテキスト量を測る」「同一 worktree に同一役割を二重に spawn しない」を参照だけの形に揃える（Requirement と Scenario の内部矛盾の解消。live spec と archive delta の両方）
- [x] 9.3 正本（`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」）に本文を集約する（①送ってよい／送ってはならない SendMessage ②手渡しを行ってよい条件 ③return の 1 行目の宣言書式と選び方の義務 ④前任が動作中のまま交代させる手順と待ち方）
- [x] 9.4 `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`templates/escalation-tripwires.md`・`scripts/session-tripwires.sh` の常駐ルール文・`scripts/subagent-context.sh` のヘッダコメントを、正本への参照だけに置き換える（独自の言い換えを消す）。`session-tripwires.sh` の注入文には「正本を読むまで手渡さない」のガード 1 行を必ず置く（ファイルを開かずに届く唯一の面のため。spec の MUST）
- [x] 9.5 `plugins/dev-workflow/tests/handoff-declaration.bats` をホワイトリスト型に作り替える（「トリガー語に掛かった面は正本への参照を含む」）。面は `git ls-files` から機械的に列挙し、除外は 3 種だけ（歴史記録＝`CHANGELOG.md` 全体・この change 以外の archive・`_longruns/`／change の `proposal.md` と `tasks.md`／`plugin.json`）。トリガーは spec の語彙 A（リポジトリ全体）と語彙 B（`plugins/dev-workflow/` 配下と `openspec/specs/dev-workflow-*/spec.md`）をそのまま実装し、語彙 B だけで発火した面には理由コメント 1 行付きの除外表を用意する（除外表の各行は当該面がトリガー語を現に含むことを検査し、stale なら落とす）。語彙 A の面を除外表に入れてはならない。`plugins/dev-workflow/tests/` 自身も検査対象に入れる。**`references/workflow-execution.md` は除外表ではなく参照側で閉じる**（手渡しと同じ操作を「乗り換え時の成果引き継ぎ」と述べている唯一の面で、ここだけ実装者の裁量が残るため名指しで潰す）
- [x] 9.5.1 正本の中身を固定するアサーション（現行 `criteria:` 系 8 件。「再開の禁止は無条件」「工程完了: <工程名>」「成果一覧を書いていても」等）は**残す**。ホワイトリスト化の対象は参照面であって正本ではなく、正本が①〜④を実際に答えていることを担保するのはこのテストだけになる（spec の MUST）。`grep` の引数として正本の断片を引用することは言い換えに当たらない
- [x] 9.5.2 apply 後、語彙 A / B で発火して参照も除外表も持たない面が 0 件であることを実測で確認する（現時点の実測では `scripts/session-tripwires.sh` と `tests/tripwire-hook.bats` が語彙 A で参照無し、`references/workflow-execution.md`・`references/pr-body-format.md`・`tests/pr-body-format.bats`・`scripts/agent-model-guard.sh`・`scripts/usage-probe.sh`・`openspec/specs/dev-workflow-escalation-tripwires/spec.md` が語彙 B で参照無し）
- [x] 9.5.3 `tests/tripwire-hook.bats` に、`session-tripwires.sh` の注入行が正本への参照と「正本を読むまで手渡さない」のガード 1 行を持つことを検査するアサーションを足す（唯一の MUST が検査されないまま緑で通るのを防ぐ）。判定は `additionalContext` 全体ではなく注入行そのものに当てる（全体で見ると、同じ文字列を持つトリップワイヤーテンプレートが連結されているため旧文言のままでも緑になる）
- [x] 9.6 `plugins/dev-workflow/CHANGELOG.md` の 2.5.1 を、追随ではなく統合（本文 1 箇所＋参照）に合わせて書き直す（`CHANGELOG.md` はファイル単位で検査の除外なので、新しい項も検査対象外である点を前提にする）
- [x] 9.7 `bats plugins/dev-workflow/tests/ tests/marketplace-sync.bats` と `openspec validate --specs --strict` を通す

## 9.8 レビュー指摘の是正（2026-09-09。別コンテキストのレビュー: blocking 4 件・non-blocking 6 件）

指摘の核心は「再発防止に足したテストが、取り残しを検出できないまま緑で通る」形が場所を変えて残っていたこと。実装を壊して全テストが緑になるかで 1 件ずつ確かめた。

- [x] 9.8.1 ③の書式リテラル除去が話題語の判定にも掛かっていた（spec は「述語の判定にだけ使う。話題語と足切りは取り除く前の文に当てる」と定めている）。話題語と述語を別のパターンに分け、話題語はリテラル除去前の文に当てる。話題語がリテラルの中にしか無い文（書式を正しく引用した、実際に面へ書かれる形）が③から抜けていた
- [x] 9.8.2 `excluded()` を広げれば任意の面を検査から外せて全テストが緑のまま通った（名指しの 7 面＋2 つの live spec を足しても緑）。名指しした参照面と正本が検査対象に入っていることを固定するテストを足す
- [x] 9.8.3 ホワイトリスト走査に負のコントロールが無かった（参照判定を常に真に、語彙 A を絶対マッチしない正規表現に変えても緑）。使い捨てのリポジトリに違反を置く負のコントロールを `offenders` / `stale` / `vocab-a-exempt` に足す
- [x] 9.8.4 「正本を読むまで手渡さない」と書いた面で正本へのパスが解決しなかった（`README.md` と `templates/escalation-tripwires.md` はどちらも同じファイルの中で `references/` をプラグイン直下と定義している）。パスを直し、参照面のパスが実在するファイルに解決することを検査するテストを足す
- [x] 9.8.5 正本の④が①②と矛盾する 1 文を持っていた（「そのまま続行し手渡しはしない」＝再開もできず手渡しもできない）。前任が先に `工程完了:` を返したら通常の手渡しに戻る、と書き直す
- [x] 9.8.6 `gate-runner.md` が正本に無い書式規則（「1 行空けてから」）を自分の言葉で書いていたので落とす
- [x] 9.8.7 前処理（`【…】` の除去・書式リテラルの除去）はどちらも無効化しても緑だった。除去が効かないと検出できない形のサンプルを 1 本ずつ足す
- [x] 9.8.8 spec が列挙した語彙は一部を削除しても緑だった（`工程の終わり`）。語彙の各要素だけで組んだ合成文を走らせ、その規則だけで報告されることを検査する。あわせて言い換えサンプルを spec の MUST どおり「正本の語をひとつも使わない」形に直し、それを機械的に検査する
- [x] 9.8.9 `cap_sec` の節切り出しが後続 2 小節まで含んでいた（正本の本文が小節へ移動しても `criteria:` 系が緑のまま）。次の見出し（`## ` / `### `）で止める
- [x] 9.8.10 `marketplace.json` の description だけ手渡しの記述が無かった（spec がズレを許容したのは `plugin.json` だけ）。参照込みで追随させる
- [x] 9.8.11 spec に 2 点足す: 固定された 2 つの書式のどちらにも当てはまらない return の扱い（正本が規定する）、停止の指示に応答が返らないまま時間が過ぎたときの終端（同）。あわせて 9.8.2〜9.8.4・9.8.8 の検査を MUST として spec に書く

## 10. 見張りテストの撤去（2026-09-09）

9.5 系と 9.8.1〜9.8.4 で作った「本文が 1 箇所にあることの機械検査」を、この change から外した。
ゲート 7 周・仕様レビュー 4 周がすべて同じ形（緑が「違反が無い」のか「検査が何も見ていない」のか
区別できない）で落ち、原因が調整不足ではなく「規則の言い換えを機械で検出する」という目的そのもの
にあると判断したため。事故を止める本体（return 1 行目の完全一致による宣言契約）は 9.1〜9.4 で
完成しており、見張りはその保険にすぎない。

- [x] 10.1 `plugins/dev-workflow/tests/lib/handoff-scan.py` を削除する（9.5 で新規作成したもの）
- [x] 10.2 `plugins/dev-workflow/tests/handoff-declaration.bats` から走査系・ホワイトリスト系のテストを削除し、正本の中身を固定する `criteria:` 系と同一 worktree 制約の検査だけを残す（9.5.1 で残すと決めた分がそのまま残る）
- [x] 10.3 `plugins/dev-workflow/tests/retirement.bats` の `ALLOW_RE` から、削除した `handoff-scan.py` の行を落とす
- [x] 10.4 live spec と archive delta から、走査の語彙・除外表・検査対象の下限・パスの実在検査・負のコントロール・「テストが spec の語彙を読む」MUST を削除し、「本文が正本 1 箇所にしかないことは規約であり機械検査の対象外」を 1 段落で置く（follow-up は https://github.com/oratta/claude-harness/issues/265）
- [x] 10.5 `plugins/dev-workflow/CHANGELOG.md` の 2.6.1 を、見張りを入れない形に書き直す
- [x] 10.6 `bash scripts/test.sh` 全件と `openspec validate --specs --strict` を通す
- [x] 10.7 9.8.11 で spec に足した「停止の指示に応答が返らないまま時間が過ぎたときの終端」は `3fe3190` で撤回した（レビュー指摘 B1〜B3。終端の帰結がテストで固定できず、「人間に可否を仰ぐ」が手渡しの許可条件と矛盾する第 3 の経路を作り、「本体のターン 3 回」は単位が終端の役に立たなかった）。行き先は https://github.com/oratta/claude-harness/issues/266
