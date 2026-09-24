## 1. 収集スクリプト（TDD）

- [x] 1.1 `plugins/dev-workflow/tests/codex-records.bats` を先に書く（`gh` を PATH のスタブに差し替え、全番号成功・最初の番号の失敗・途中ページの失敗・次の番号の失敗・JSON でない出力・前回のファイルが残っている状態での失敗・引数不足・PATH から `gh` を外した状態を再現する）。この時点で落ちることを確認する
- [x] 1.2 `plugins/dev-workflow/scripts/codex-records.sh` を実装し、1.1 のテストを通す
- [x] 1.3 収集が失敗したときに集計へ進まないこと（失敗時に上限以内の JSON が出ないこと）を、`codex-records.sh && pr-token-budget.sh` の組み合わせで確かめるテストを 1.1 のファイルに足す

## 2. 本体手順

- [x] 2.1 `plugins/dev-workflow/tests/develop-skill.bats` の PR トークン上限の文言テストを、`codex-records.sh` を使う手順と、失敗時に集計を呼ばず exit 1 と同じ扱いにする手順（exit 1 の理由の列挙に「Codex 消費コメントを取得できなかった」があること）を確かめる形に直す。492-499 行の `^Codex 消費: ` の grep も新しい手順に合わせて書き直す（先に落ちることを確認する）
- [x] 2.2 `plugins/dev-workflow/skills/develop/SKILL.md` の「PR トークン上限」節の計測手順を書き換え、2.1 を通す

## 3. 記録と検証

- [x] 3.1 `plugins/dev-workflow/changes/419.md` に変更の記録を書く（版番号は上げない）
- [x] 3.2 `scripts/test.sh` を全件流して通ることを確認し、`openspec validate codex-records-fetch-failure --strict` を通す
