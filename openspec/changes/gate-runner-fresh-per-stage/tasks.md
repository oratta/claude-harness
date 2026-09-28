規模の判断: 編集ファイルは約 14 個で規模超過トリップワイヤーの閾値 5 個を超えるが、どれも「G を SendMessage で再開する」同じ記述の直しで、分けると文書が食い違う期間ができるため、本体の判断で単一 change のまま進める（実装中にこれを理由に return しない）。

## 1. 検査を先に書く（Red）

- [ ] 1.1 develop の役割の bats（`develop-roles.bats`・`develop-skill.bats`）に次を足す: SKILL.md の (4) と `gate-runner.md` に段ごとに新しい G を起こす記述と `段:` の行の指示がある／SKILL.md の (4) の範囲（`(4) G を` で始まる行から、そのコードブロックの閉じ ``` の行まで）と `gate-runner.md` の全体に `SendMessage` と `G を再開` の文字列が無い／`gate-runner.md` の Gate Result に `段:`（`一括（従来経路）` を含む）・`次の段:`・Status `次の段へ` と、Status ごとの `次の段:` の表（failed は順 3 だけなら `照合と振り分け`）がある／G の名前 `G-<PR>-<prepare|triage|pass|hold>-<n>` と description `G: <段> for PR #N (#issue)` がある／`gate-runner.md` と SKILL.md の (4) に G を `subagent-context.sh` で測る記述が無い
- [ ] 1.2 「レビュー実行者:」コメントの段落が `stages/triage.md` にだけあること、`gate-runner.md`・SKILL.md・`references/codex-develop.md` に adapter 経路の保持規則が無いことの検査を足す
- [ ] 1.3 1.1・1.2 を走らせて落ちることを確かめる

## 2. 本文を直す

- [ ] 2.1 `gate-runner.md`: 「時点ごとに読むファイル」の表を 4 段に揃え、`## 再開（本体が SendMessage で G を再開する）` を段ごとの起動と入力を定める節に書き換える（レビュアーの要約受領・補足レビュー結果の受領の分岐はこの節の照合と振り分けの入力に置く）。Gate Result に `段:`・`次の段:`・Status `次の段へ` を足す。受け渡しの PR コメント（`固定 HEAD:` の行・`レビュー三表:`・仕分けコメント）と「PR コメントを正とする」を書く。`周回:` の引き継ぎを書く。adapter 経路の保持規則と、G を `subagent-context.sh` で測る記述を消す
- [ ] 2.2 `skills/develop/SKILL.md`: 前提の表の Agent / SendMessage の行、(4) の各分岐（needs-reviewer の ④・failed のあとの再レビュー・needs-decider の裁定の渡し方・CI の見張りのあとの取り直し）と、(4) の「G の起動・再開・手渡しの指示」（110 行付近）・「G を再開か手渡しで起こして」（117 行付近）を段ごとの新しい G に書き換え、failed のあとは Gate Result の `次の段:` どおりに起こすことを書き、起動指示に `段:` と前の Gate Result ブロックを貼ることを書く。`工程中断:` のときは同じ段の新しい G を起こし、条件は decision-criteria.md の「手渡しの許可」を参照する。adapter 経路の保持規則を消す
- [ ] 2.3 `decision-criteria.md`: 「W / G は名前付き spawn ＋ SendMessage 再開」「W / G を SendMessage で再開する前に測る」の記述を W に絞る。停止の指示の SendMessage の規則は残す
- [ ] 2.4 `stages/prepare.md`: `レビュー重量:` コメントに `固定 HEAD: <SHA>` の行を足し、最新の 1 件を正とすることを書く。W の修正後の再レビューで起こされたときは `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力を読み、前の周の指摘を仕分けコメントから取り、全体レビューの判定と行数の記録を自分で行うことを「G として動くとき（develop）」節に書く（規則そのものは写さない）。「レビュー実行者:」コメントの段落を `stages/triage.md` へ移す
- [ ] 2.5 `stages/triage.md`・`stages/hold.md`・`stages/pass.md`: 「G として動くとき（develop）」節の再開の小節を、その段で起こされたときの入力として書き換える。triage に「レビュー実行者:」の段落と `レビュー三表:` コメント（`補足済み回数:` の行を持ち、補足の `needs-reviewer` を返す前に投稿する）の投稿を足し、止める指摘が無いときは止めない指摘を follow-up issue に切ってから `次の段へ`（`次の段: 合格処理`）で返すこと、failed の `次の段:` の決め方を書く。hold に、復帰手順が別の段の作業に進むときは `次の段へ`（許容・切り出して残りなしは `合格処理`、代替案で手順 2 からは `前提確認と重さ判定`）で返すことを書く。pass に、前の Gate Result が `段: 保留の解除` なら同じ HEAD で宣言を出し直さず手順 5 の真正性確認から入ること、前の HEAD の許容があれば宣言の前に `stages/hold.md` の 3-c を試すことを書く。gate-runner.md の従来経路は手順 1〜5 と保留を 1 体で続け、`段: 一括（従来経路）`・`次の段: なし` と書くことを書く。`SendMessage で G に返す` の記述を直す
- [ ] 2.6 `plugins/dev-workflow/references/codex-develop.md`: adapter 経路の保持規則と、Claude の G を SendMessage で再開する記述を直す
- [ ] 2.7 `plugins/dev-workflow/templates/escalation-tripwires.md`（78 行付近）と `plugins/dev-workflow/scripts/session-tripwires.sh`（129 行付近）の G の再開の記述を段ごとの新しい G に直す

## 3. 既存検査の付け替えと確認

- [ ] 3.1 G の再開を前提にした既存の bats のアサーション（`develop-roles.bats` 278 行付近、`develop-skill.bats` 173・325 行付近、`develop-adapter-review-routing.bats` 191 行付近ほか `git grep -n 'SendMessage\|再開' -- plugins/dev-workflow/tests` の G に関わる全件）を新しい記述に付け替える
- [ ] 3.2 `./scripts/test.sh` と `./scripts/lint.sh` が exit 0 であることを確かめる
- [ ] 3.3 `openspec validate gate-runner-fresh-per-stage --strict` が通ることを確かめる

## 4. 記録

- [ ] 4.1 `plugins/dev-workflow/changes/554.md` に変更記録を書く。受け入れ条件 3（develop で通した PR 5 本で G の上限超えの割合が 15% 以下）はマージ後にエピック #511 で測る、と 1 行残す
- [ ] 4.2 PR 本文に、受け入れ条件 2 の記録の枠を用意する: この PR のゲートを本体が worktree 側の新しい SKILL.md と `gate-runner.md` に従って段ごとの G で回し、G ごとの段と終了時のコンテキスト量・150K を超えた G の数・上限による手渡しの回数を書く。実行時に読まれるプラグインのキャッシュはマージ前の版なので、マージ前の版で測った値であることを明記する（実測値はゲート通過後に記入）
