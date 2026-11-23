# Tasks

R1 APPROVE が記録先 https://github.com/oratta/claude-harness/issues/1756 に記録されてから実装する。この工程では以下の実装タスクには着手しない。行番号は仕様作成時点の案内で、実装前に該当範囲を読み直す。

## 1. セッションの登録・切替と対象外の保護

- [x] 1.1 `epic-child-state.bats` に登録用の起動指示 helper を用意し、既存の一般ターン試験では対象の ID を明示的に登録する。任意入力で別 ID に切り替わる既存期待値と未登録 Stop の block 期待値を新契約へ更新する。未登録の通常入力・予約文・Stop が不変、一致する初回起動だけ世代1、同 ID の再送は owner、正規の再起動は旧世代+1、親子・repo 不一致と引用は切替不可、別 repo と Orca / tmux の両方、一致する起動指示を意図的に送ると切り替わる限界を試験する。検証: 1.2 と併せ `bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:3-161（fixture・入力・適用範囲・配線）、plugins/dev-workflow/tests/epic-child-state.bats:295-315（repo・tmux・拡張不正）、plugins/dev-workflow/tests/epic-child-state.bats:318-410（既存エラーと未登録）
- [x] 1.2 `epic-child-state.sh` に既存 `turn_input.session_id` と起動形による識別を設ける。対象外を拡張の詳細検査・ログ読取・保存設定の検査・ロック待ちより前に返し、入力のロック内でも再読した ID に対して判定する。未登録からの登録と別 ID への切替は既存 startup と同じ親子・repo 照合に一本化する。対象と確定した拡張不正・保存失敗は既存どおり拒否し、Stop は既存ガード1回と保存時のスナップショット照合を保つ。検証: `bash -n plugins/dev-workflow/scripts/epic-child-state.sh` と `bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:57-123（拡張・対象・startup）、plugins/dev-workflow/scripts/epic-child-state.sh:175-237（対象識別・ロック・共通 Stop）
- [x] 1.3 S1→S2→S1 のイベント列を追加する。S1 の入力・終了状態がある worktree に別セッション／claude -p 相当の S2 の入力と状態行の無い Stop を入れ、記録の内容と更新時刻が完全に同じで、S1 の Stop と次の通常ターンが保存できることを確かめる。S2 の親接頭辞・欠落／不正 ID・欠落／読取不能ログ・型不正 prompt、読める S1 ID と別項目の壊れた拡張、不正なロック設定と残留ロック、S2 の既存番号ガードによる拒否も含める。既存ガードの出力・終了コード・呼出回数を直接実行と比較する。入力の事前判定後に S2 の起動指示が切り替える競合、切替後の旧 Stop、既存の同 ID の世代競合と予約文の保持も試験する。検証: `bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0、対象外イベントで記録バイト列・更新時刻が不変。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:93-145（対象外・世代）、plugins/dev-workflow/tests/epic-child-state.bats:211-293（競合注入・既存ガード比較）、plugins/dev-workflow/tests/epic-child-state.bats:344-410（対象外とロック）、plugins/dev-workflow/scripts/epic-child-state.sh:175-237（試験で必要な調整）
- [x] 1.4 子の毎ターンの手順に、保存済み ID への限定、未登録の旧記録と誤った ID の記録を一致する起動指示の再送で登録し直す方法、起動形が認証ではない限界を記す。変更記録 `1756.md` に振る舞い・移行・戻し方を記し、版は上げない。既存 docs の語句検査に加え、移行案内が新契約と一致する検査を同 Bats に追加する。検証: `bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0、変更記録が存在し版の変更がないことを diff で確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:3-19（毎ターンの入力）、plugins/dev-workflow/tests/epic-child-state.bats:164-169（文書検査）、plugins/dev-workflow/changes/1756.md（新規）

## 2. 既存動作と仕様の結合確認

- [x] 2.1 既存の親の動作を含む結合確認を行う。検証: `bats plugins/dev-workflow/tests/epic-child-state.bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats`、`openspec validate scope-epic-child-hooks-to-session --type change --strict`、`git diff --check` がすべて exit 0。親の既存期待値・フック配線・記録 schema・版を変えない。失敗時は対象範囲内で原因を確認し、親・launcher 等への拡張が必要なら実装を止めて本体へ報告する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:57-237、plugins/dev-workflow/tests/epic-child-state.bats:1-430、plugins/dev-workflow/skills/develop/references/epic-child-stop.md:3-19、plugins/dev-workflow/changes/1756.md（新規）

## Workflow follow-up

- 実装＋verify の終了後に本体へ return する。次工程の archive で `scope-epic-child-hooks-to-session` を現行 `dev-workflow-epic-state` へ反映する。触る範囲: openspec/specs/dev-workflow-epic-state/spec.md:796-866（対象・拡張・分類）、openspec/specs/dev-workflow-epic-state/spec.md:950-964（未登録と処理失敗）、openspec/changes/scope-epic-child-hooks-to-session/（archive で移動）
- Draft PR の作成・仕様宣言は canonical finish 工程で行い、worker は merge・auto-merge を行わない。
