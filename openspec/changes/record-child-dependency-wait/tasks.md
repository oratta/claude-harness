# Tasks

実装開始の前提は issue #1775 の仕様化判断と、この change に対する R1 の APPROVE。チェックは実装工程で行い、この仕様化工程では未着手のまま残す。行番号は仕様化時点の案内であり、編集前に該当範囲を読み直す。

## 1. 任意項目の検査・生成と子への説明

- [ ] 1.1 `extension()` に任意 boolean の検査を追加する。実フックのテストで `true` / `false` / 欠落は型検査を通し、文字列・数・null・配列・オブジェクトは既存の拡張不正として扱って新たな有効状態を保存しないこと、ターン項目の無い旧記録からの初回入力と新項目の無い旧状態が従来どおり扱えることを確かめる。`TMPDIR=$(mktemp -d) bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:57-75（extension）、plugins/dev-workflow/tests/epic-child-state.bats:31-61、plugins/dev-workflow/tests/epic-child-state.bats:125-145
- [ ] 1.2 既存の依存待ち末尾処理を共有し、現在発言・正しい作業報告・既存 Stop の許可がそろった保存計画だけに `dependency_wait: true` を含める。実フックを通して成功、CRLF・空白行・行頭0/1個、通常報告、別の状態値、後続文、引用・閉鎖/未閉鎖フェンス、長い全文、状態行欠落・古い Stop・既存 Stop の拒否を検査し、それ以外の新状態は項目を省く。既存 `--dependency-wait` の状態行なしの形式と exit も維持する。子側 Bats 全体が exit 0。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:12-31（status）、plugins/dev-workflow/scripts/epic-child-state.sh:77-168（末尾判定・保存計画）、plugins/dev-workflow/scripts/epic-child-state.sh:223-247（Stop 保存）、plugins/dev-workflow/tests/epic-child-state.bats:57-91、plugins/dev-workflow/tests/epic-child-state.bats:180-209、plugins/dev-workflow/tests/epic-child-state.bats:419-448
- [ ] 1.3 `epic-child-stop.md`「依存待ちで終了する」を、Stop が同じ終了状態へ boolean を保存して渡す説明に合わせる。成功時の `状態: 作業報告`、依存登録・確認・停止コメントと失敗時の手順を維持し、この節の「親が会話ログから検知する」を更新する。文書テストを追加して状態行と新記録の説明を検査し、子側 Bats が exit 0。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:22-37、plugins/dev-workflow/tests/epic-child-state.bats:164-169

## 2. 無効化・排他と変更前の親との互換

- [ ] 2.1 新項目を既存の state 全体の置き換え・無効化へ載せる。実フックの回帰テストで、主・親・起動形の次の通常入力、同世代の Stop 差し戻し、通常報告への書き直しで古い印が消えること、予約文は保つこと、新入力との競合は新世代を壊さないことを確認する。既存のロック・原子的置換・親と未知項目の保持・失敗時の診断/exit と再停止の扱いも検証し、子側 Bats が exit 0。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:182-194（処理失敗）、plugins/dev-workflow/scripts/epic-child-state.sh:213-247（入力更新・Stop 再照合）、plugins/dev-workflow/tests/epic-child-state.bats:31-38、plugins/dev-workflow/tests/epic-child-state.bats:80-123、plugins/dev-workflow/tests/epic-child-state.bats:211-258、plugins/dev-workflow/tests/epic-child-state.bats:450-569
- [ ] 2.2 子側テストの既存 parent fixture を使い、新 boolean の有無で変更前の親の出力・判定が変わらないケースを追加する。`epic-dispatch.sh` と親の期待値を変更せず、子側 Bats と `TMPDIR=$(mktemp -d) bats plugins/dev-workflow/tests/epic-dispatch.bats` が exit 0。消費側の復旧・承認をこの成功から主張しない。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:171-209（parent_fixture と互換ケース）
- [ ] 2.3 生成側の機能追加、旧記録互換と親の消費側が #1744 であることを変更記録に残し、記述が実装・仕様と一致することを確認する。触る範囲: plugins/dev-workflow/changes/1775.md（新規）

## 3. 統合検証

- [ ] 3.1 `bash -n plugins/dev-workflow/scripts/epic-child-state.sh`、`scripts/lint.sh epic-child-state.sh`、`openspec validate record-child-dependency-wait --type change --strict`、`git diff --check` を実行し、各 exit 0 を確認する。差分が子側の契約の範囲に限られ、親のスクリプトと archive 済み change を変更していないことを確認する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:1-247、openspec/changes/record-child-dependency-wait/（仕様化成果一式）

## Workflow follow-up

- 本体が R1 を別に起動する。R1 APPROVE 前に実装へ進まない。
- 実装後の verify・archive・PR とレビューは本体の後続工程で行う。この worker の仕様化工程では実装・テスト編集・PR 作成・merge を行わない。
