## 1. Codex ルーブリックの実測（結果で 3.2 の中身が分かれる）

- [ ] 1.1 小さな diff（この worktree の任意の 1 ファイルに 1 行足した一時的な変更、または既存コミット 1 つの範囲）と、書式を指定しない短いレビュー指示を用意し、`plugins/dev-workflow/references/subagent-waiting.md` の雛形どおり `codex exec -c approval_policy=never -c model_reasoning_effort=medium -` に標準入力で渡して完了まで待つ（待ち方は同ファイルの正本に従う）。一時的な変更は実測後に自分で消し、コミットしない
- [ ] 1.2 出力に `[P0]`〜`[P3]` の見出し・`priority`・`confidence_score` のどれかが現れるかを確認し、実行コマンド・終了コード・出力の要点・判定（適用される / されない / どちらとも言えない）を `openspec/changes/pr-review-gate-finding-format/codex-rubric-measurement.md` に書く（(3b) で PR コメントに転記する）。Codex が使えない（バイナリ無し・認証切れ・総待ち上限）ときは実測した不可条件を書き、判定は「未実測」として 3.2 は「適用されない」側で進め、return に明記する

## 2. テストを先に書く（TDD）

- [ ] 2.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、固定書式の見出し語（深刻度・検証・根拠・場所・何が起きるか・直し方）、深刻度 3 値（`blocking` / `should` / `nit`）、検証 2 値（`confirmed` / `plausible`）、状態 3 値（`fixed` / `unresolved` / `wontfix`）、例外 3 種（安全機構の穴・データ破壊・無言の機能不全）、全件列挙の 1 文、手順 5 の「全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済み）が 0 件」の検査を足す
- [ ] 2.2 同 bats に、「この一般則は1周目に適用する」が SKILL.md に残っていないことの検査と、判定の文が 1 か所にあること（判定の見出し語が 1 回だけ現れ、収束ルールの「2周目の終わりにやること」節がその見出しを参照していること）の検査を足す。既存の固定文言（「マージ後に issue で直せるものは blocking にしない」「高深刻度」「2周」「follow-up issue」）は残す。あわせて同 bats 373〜378 行目の既存テスト「convergence (#281): the defect-means-failed rule yields to the convergence rule from round 2」（旧「欠陥ありなら PR コメントに再現手順と修正点を書き」の行に「1周目」「収束ルール」を要求する）を、その行が無く、手順 2-1 の判定の段落が参照されていることを見る検査に書き換える
- [ ] 2.3 `plugins/dev-workflow/tests/subagent-waiting.bats` か `pr-review-gate-skill.bats` に、`references/subagent-waiting.md` の指示文雛形が SKILL.md 手順 2-1 のブロックを貼る指示と全件列挙の 1 文を含み、深刻度の定義表を再掲していないことの検査を足す
- [ ] 2.4 `plugins/dev-workflow/tests/develop-roles.bats` に、gate-runner.md の needs-reviewer payload が SKILL.md 手順 2-1 のブロックを指定する行を持つこと、`grep -n "手順 3 以降を続ける"` が needs-reviewer 節で無条件の継続指示を返さないこと、needs-reviewer 節と再開節の両方が周回別分岐（1周目・failed・2周目・仕分け）を持つか再開節を参照していることの検査を足す（#352 の受け入れ条件）。gate-runner.md の Gate Result の仕分け欄と保留節が「止める指摘」の語で書かれ、「引用できる指摘が残」の字面が残っていないことの検査も足す
- [ ] 2.5 追加した検査が現行ファイルで落ちることを確認する

## 3. SKILL.md を書き換える

- [ ] 3.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 2-1 の「姿勢」の後に、レビュアー向け指示ブロック（固定書式・深刻度の定義表・全件列挙の 1 文・再レビューの制限・直し方どおりの箇所を再指摘しない）を貼り付け可能な形で置く
- [ ] 3.2 1.2 の判定に従う: 適用されない（または未実測・どちらとも言えない）なら対応表は置かない。適用されるなら、手順 2-1 に Codex の JSON（`priority` / `confidence_score` / `code_location`）から固定書式への対応表を置き、`confidence_score` を `confirmed` の代わりにしないことを添える
- [ ] 3.3 全周共通の判定を 1 か所（手順 2-1 内の見出し付きの段落）に書き、143 行目の「欠陥ありなら…この一般則は1周目に適用する。2周目…が優先する」を、判定への参照と「止める指摘が残ったら 1 周目は failed、2 周目と続行指示の周は収束ルールの『2周目の終わりにやること』」に置き換える。1 周目で failed にするときの止めない指摘の扱い（一覧で残し、follow-up issue は手順 3 へ進むときに切る）もここに書く
- [ ] 3.4 収束ルール節の「2周目の終わりにやること」手順 1〜3 を、止めるかどうかの基準は判定を参照する形にそろえる（引用元の範囲・記録の義務・引用元が無いときの扱い・`needs-approval` の停止は残す。判定の文を言い換えて再掲しない）。同節の「決める役はキャップの判定に関与しない」段落（現行 158 行目）の「引用の有無で決まる」も「全周共通の判定で止める指摘が残るかどうかで決まる」に揃える
- [ ] 3.5 手順 5 の冒頭に、最後のレビュー結果で全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済み）が 0 件であることを合格処理の条件として足す
- [ ] 3.6 `plugins/dev-workflow` 配下（tests と CHANGELOG を除く）で「一般則」「欠陥ありなら」「収束ルールが優先」を grep し、判定を周で分ける字面が残っていないことを確認する（「1周目」は SKILL.md 149・204 行目や gate-runner.md 再開節に正当な用例があるので grep 対象にしない。手順 2-2 の中身は変えない）

## 4. 指示文の雛形と gate-runner.md をそろえる

- [ ] 4.1 `plugins/dev-workflow/references/subagent-waiting.md` 58 行目の `<レビュー指示をそのまま書く…>` を、固定した HEAD・diff 範囲・受け入れ条件に加えて SKILL.md 手順 2-1 のレビュアー向け指示ブロックを貼ること、「該当する指摘を全部列挙するまで止まらない」の 1 文を含む形にする（書式の欄と定義表は再掲しない）
- [ ] 4.2 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の needs-reviewer payload に「レビュアーに渡す指示: SKILL.md 手順 2-1 のレビュアー向け指示ブロック（固定書式）」の行を足す
- [ ] 4.3 同ファイル needs-reviewer 節 54 行目の「手順 3 以降を続ける」を、「レビュー実行者:」コメントの投稿のあと再開節の「レビュアーの要約受領」の分岐に従う、の参照にする
- [ ] 4.4 同ファイル再開節の「レビュアーの要約受領」を、全周共通の判定を通してから分岐する形に書き換える（止める指摘なし → follow-up issue に切って手順 3 以降／あり → 1周目は failed、2周目と続行指示の周は仕分けを記録して保留）。#281 の既存検査が見る語（1周目・failed・2周目・仕分け）は残す
- [ ] 4.5 同ファイルの Gate Result の仕分け欄（現行 66 行目の「引用できる指摘が残っている場合は failed ではなく保留で返す」）と保留節（現行 76 行目の「引用できる指摘が残った」）を、「全周共通の判定で止める指摘が残った」の語に揃える

## 5. 検証と付随作業

- [ ] 5.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats plugins/dev-workflow/tests/subagent-waiting.bats plugins/dev-workflow/tests/model-escalation-policy.bats` を実行し、文言変更の巻き込みが無いことを確認する（落ちたら追随）
- [ ] 5.2 `scripts/test.sh` で全件を実行して通す（`tests/injection-budget.bats` を含む）
- [ ] 5.3 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow の version を 2.13.16 → 2.13.17 に上げ、`CHANGELOG.md` に記載する（#349 と #352 を併記）
- [ ] 5.4 `openspec validate pr-review-gate-finding-format --strict` を通す
- [ ] 5.5 (3b) の PR 本文は `Closes #349` を先頭に置き、`Closes #352` を併記する。1.2 の実測結果（実測できなかったときは実測した不可条件）を PR コメントに転記する
