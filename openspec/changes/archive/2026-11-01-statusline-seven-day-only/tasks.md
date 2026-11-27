# Tasks

行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。編集の前に該当範囲を読む。

## 1. snapshot を週次だけでも書く

- [x] 1.1 snapshot を書く条件を「5h か 7d の使用率のどちらかがある」にし、`obs_sig` と `--argjson five_pct` の 5h を `null` に倒す。`statusline-rate-snapshot.bats` に、週次だけの入力で `five_hour_pct` と `five_hour_resets_at` が null・7d が入力どおり・共有先の本文が同じ・両方無ければ更新しないテストを足して通す。触る範囲: plugins/statusline/scripts/statusline.sh:124-133、plugins/statusline/scripts/statusline.sh:155-165、plugins/statusline/tests/statusline-rate-snapshot.bats:70-76（writer H の後ろに足す）
- [x] 1.2 署名のテストを足して通す: 週次だけの同じ値の再表示で `observed_at` が進まない、5h が戻ると現在時刻になる、両方あるときの `obs_sig` が変更前の文字列と同じ。触る範囲: plugins/statusline/tests/statusline-rate-snapshot.bats:36-49（writer A-D の並び）

## 2. 記録を週次だけでも書く

- [x] 2.1 ハッシュ計算と記録の書き込みの条件を「5h か 7d の使用率のどちらかがある」にし、`_rec_sig` と printf の 5h を `:-null` にする。`statusline-session-records.bats` に、週次だけの記録が妥当な JSON で 5h が null・同じ値の描き直しで書かれない・5h が戻ると書かれるテストを足して通す。触る範囲: plugins/statusline/scripts/statusline.sh:195-216、plugins/statusline/tests/statusline-session-records.bats:120-125（「a missing seven_day」の後ろに足す）

## 3. 週次だけのスロットを描く

- [x] 3.1 `render_slot` の打ち切りを「5h も 7d も無い」ときだけにし、`5h` の行の組み立てを 5h があるときに限る。`statusline-multi-account.bats` に、1 スロットで Codex の行なしの週次だけ（将来のリセット時刻で残り時間あり・`5h` の行なし・`0%` なし）、1 スロットで Codex の行ありの週次だけ（名前の列あり・目印なし）、Fable の区画、非 active の週次だけ（経過時間つき）、リセット権の区画が `7d All` の行の末尾に出るテストを足して通す。触る範囲: plugins/statusline/scripts/statusline.sh:956-992、plugins/statusline/tests/statusline-multi-account.bats:957-973（節の後ろに足す）
- [x] 3.2 active の `取得待ち` の条件を「5h も 7d も無い」にする。2 スロットの active に週次だけのとき `取得待ち` が出ず `7d All` の行が出ること、`rate_limits` が無いときは今までどおり `取得待ち` になることのテストを足して通す。触る範囲: plugins/statusline/scripts/statusline.sh:1070-1072、plugins/statusline/tests/statusline-multi-account.bats:722-733
- [x] 3.3 `hr_use` の判定から 5h の条件を外す。`statusline-headroom.bats` に、週次だけの active で `tickets.count` が 0 より大きいときロケットモードとリセット権の表示が出るテストと、週次のリセット時刻が無ければ使えないままのテストを足して通す。触る範囲: plugins/statusline/scripts/statusline.sh:927-939、plugins/statusline/tests/statusline-headroom.bats:476-502（columns の並びの前後）

- [x] 3.4 混在構成のテストを `statusline-headroom.bats` に足して通す: 2 スロットと Codex の行があり、週次だけの active だけが値を使えるとき、非 active の行と Codex の行にも列が空き、バーの左端が全行で揃い、それらの行の変更前との差が空白だけであること。触る範囲: plugins/statusline/tests/statusline-headroom.bats:491-502（columns の並び）

## 4. 読み手の動きをテストで固定する（本番コードは変えない）

- [x] 4.1 `test_usage_view.py` に、記録の 5 時間が null で週次とリセット前の時刻があるとき実効値の週次が入り 5 時間が null（0 でない）のテストと、記録が null で snapshot の 5 時間がリセット前なら snapshot の値を採るテストを足して通す。触る範囲: plugins/dev-workflow/tests/test_usage_view.py:169-180（5 時間枠のテストの並び）
- [x] 4.2 `test_headroom.py` に、全スロットの 5 時間が null で週次の余りで `best` が決まるテストを足して通す（`test_high_five_hour_is_skipped` は片方だけ null なので覆っていない）。触る範囲: plugins/dev-workflow/tests/test_headroom.py:433-440
- [x] 4.3 `usage-probe-reset-grants.bats` に、応答の `five_hour` が明示の `null` のときも `[null,33]` で書かれるテストを足して通す（既存はキーが無い場合だけ）。`account-selector.bats` は :463 と :654 で覆われているので足さない。触る範囲: plugins/dev-workflow/tests/usage-probe-reset-grants.bats:180-186

## 5. 文書

- [x] 5.1 `README.md` の rate snapshot の説明を「5h か 7d の使用率」に直し、null は欠測で 0 ではないことを読み手との契約として書き、セッション記録と描画の説明に 5 時間枠が無いときの動きを足す。`grep -n '5h の使用率' plugins/statusline/README.md` が 0 件になることを確かめる。触る範囲: plugins/statusline/README.md:90-92
- [x] 5.2 `plugins/statusline/changes/1547.md` に、変えたこと・変えていないこと（読み手、両方あるときの出力）・未確認の点（stdin の中身）・連携先の読み手の 0.0 は連携先の issue で直すこと・戻し方を書く。連携先の固有名は書かず「連携先の読み手」と書く。触る範囲: plugins/statusline/changes/1547.md（新規）

## 6. 統合の確認

- [x] 6.1 `plugins/statusline/tests/` と `plugins/dev-workflow/tests/` の該当テスト、`tests/public-private-split.bats` がすべて通ることを確かめる。触る範囲: plugins/statusline/tests/、plugins/dev-workflow/tests/
- [x] 6.2 `statusline.sh` の修正だけを origin/main の内容に一時的に置き換え、1〜3 で足したテスト（3.4 を含む）が落ちることを確かめて元に戻す（scratchpad のコピーで行い、作業ツリーの git の破壊的操作は使わない）。触る範囲: plugins/statusline/scripts/statusline.sh
- [x] 6.3 5h と 7d の両方がある同じ入力で、origin/main の `statusline.sh` と変更後の出力が 1 スロット・2 スロットともバイト単位で一致することを確かめる。既存の「byte-identical to origin/main」のテストが通ることでよい。触る範囲: plugins/statusline/tests/statusline-headroom.bats:164、plugins/statusline/tests/statusline-headroom.bats:532

## Workflow follow-up

- archive と PR の作成は (3b) で行う
- マージ後に `.rate-limit-snapshot` の更新が再開するかを確かめる（`design.md` の Risks の stdin の確認）
