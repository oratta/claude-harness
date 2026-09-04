## 1. アカウントレジストリ

- [ ] 1.1 レジストリ読み取りのテストを書く（Red）: 複数スロットの読み取り / ファイル不在で既定スロット 1 つ / 壊れた JSON で既定スロット 1 つ / 空配列で既定スロット 1 つ / `CLAUDE_ACCOUNTS_FILE` による上書き
- [ ] 1.2 Keychain サービス名導出のテストを書く（Red）: `securestorage` が null・空文字で `Claude Code-credentials` / パスありで `Claude Code-credentials-<sha256 先頭 8 桁>` / NFC 正規化で表記揺れが同一になる
- [ ] 1.3 レジストリ読み取りとサービス名導出を実装する（Green）。probe と statusline の両方から同じ規則で読めるようにする
- [ ] 1.4 レジストリの雛形または生成手段（コマンドか README の手順）を用意する。実ファイルはリポジトリに含めない

## 2. usage-probe.sh の複数スロット化と schema 2

- [ ] 2.1 schema 2 のテストを書く（Red）: `schema` が 2 / `accounts` にスロットごとの `five_hour`・`seven_day`・Fable weekly・取得時刻 / `active` に現在のスロット id
- [ ] 2.2 後方互換のテストを書く（Red）: トップレベルの `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` が `accounts` の active スロットの値と一致する
- [ ] 2.3 スロット単位 fail-open のテストを書く（Red）: 片方のスロットのフェッチ失敗時に、そのスロットは前回値と前回の取得時刻を保ち、他スロットは新しい値に更新される
- [ ] 2.4 1 スロット時の退行ガードのテストを書く（Red）: レジストリ不在で `accounts` が既定スロット 1 つだけになり、トップレベルの従来キーが変更前と同じ値になる。既存の `plugins/dev-workflow/tests/usage-probe.bats` のケースは**無改変で**通ること
- [ ] 2.5 全スロット失敗時の全体 fail-open のテストを書く（Red）: exit 0 で snapshot を書かない
- [ ] 2.6 スロットのループとスロットごとの Keychain 取得・フェッチを実装する（Green）。テスト用オーバーライド（`USAGE_PROBE_RESPONSE_FILE`）をスロット別に与えられるようにする
- [ ] 2.7 `five_hour`（消化率・`resets_at`）のパースを追加する（Green）
- [ ] 2.8 snapshot の組み立てを schema 2 + トップレベルミラーに変更する（Green）。ミラーは active スロットの値から機械的に生成し、独立に計算しない
- [ ] 2.9 スロット単位 fail-open（既存 snapshot からの前回値引き継ぎ）を実装する（Green）
- [ ] 2.10 `refresh_token` を使わない判断の理由をコードコメントに残す
- [ ] 2.11 TTL キャッシュと原子的書き込みが従来どおり効いていることを確認する（Refactor）

## 3. statusline.sh のアカウント別表示

- [ ] 3.1 1 スロット時の出力同一性のテストを書く（Red）: レジストリ不在で、変更前と同じ stdin・snapshot を与えたときの出力がバイト単位で一致し、label 列が出ない。既存の `plugins/statusline/tests/statusline.bats` のケースは**無改変で**通ること
- [ ] 3.2 複数スロット描画のテストを書く（Red）: 2 スロットで 4 行、各行の左端に label
- [ ] 3.3 active / 非 active の描画元のテストを書く（Red）: active は stdin のライブ値、非 active は snapshot の値＋取得からの経過時間
- [ ] 3.4 active スロット判定のテストを書く（Red）: `CLAUDE_SECURESTORAGE_CONFIG_DIR` 優先、未設定なら snapshot の `active` にフォールバック
- [ ] 3.5 schema 1 の snapshot に対する前方互換のテストを書く（Red）: `accounts` が無ければ既定スロット 1 つとして描画する
- [ ] 3.6 レートリミット行の生成をスロットのループに包み、label 列を追加する（Green）。`bar_seg` / `bar2` は変更しない
- [ ] 3.7 非 active スロットの経過時間表示（例 `2h前`）を実装する（Green）
- [ ] 3.8 active スロット判定の二段フォールバックを実装する（Green）

## 4. 仕様・ドキュメント・バージョン

- [ ] 4.1 `openspec/specs/dev-workflow-escalation-tripwires/spec.md` の「usage-probe と snapshot 契約」を delta の内容に更新する（archive 工程で行う）
- [ ] 4.2 `plugins/statusline/README.md` を新レイアウトとレジストリの説明に更新する
- [ ] 4.3 `plugins/dev-workflow/.claude-plugin/plugin.json` と `plugins/statusline/.claude-plugin/plugin.json` のバージョンを上げ、ルートの `.claude-plugin/marketplace.json` も同時に更新する
- [ ] 4.4 `plugins/dev-workflow/CHANGELOG.md` に schema 2 と後方互換の扱いを記載する

## 5. 検証

- [ ] 5.1 `bats plugins/dev-workflow/tests/usage-probe.bats` を実行し exit code と出力を記録する
- [ ] 5.2 `bats plugins/statusline/tests/statusline.bats` を実行し exit code と出力を記録する
- [ ] 5.3 `bats tests/marketplace-sync.bats tests/openspec-specs-format.bats` を実行し exit code と出力を記録する
- [ ] 5.4 実測値（5h 55% / 7d 82%（日程 74%） / Fable weekly 94% / weekly_all 74%）のフィクスチャで 2 スロットのレイアウトを目視確認する
- [ ] 5.5 レジストリ不在の状態で statusline を実行し、変更前の出力と diff が空であることを確認する
