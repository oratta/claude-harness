## 1. アカウントレジストリ

- [ ] 1.1 レジストリ読み取りのテストを書く（Red）: 複数スロットの読み取り / `CLAUDE_CONFIG_DIR` への追随 / `CLAUDE_ACCOUNTS_FILE` による上書き / トップレベルが裸の配列なら不正扱い / ファイル不在・壊れた JSON・`accounts` 空配列で既定スロット 1 つ
- [ ] 1.2 不正スロット除外のテストを書く（Red）: `id` 欠損・書式違反のスロットを捨てる / `id` 重複は先勝ち / 9 個目以降を捨てる / `label` 欠損は `id` を使う / 全滅時は既定スロット 1 つに縮退
- [ ] 1.3 Keychain サービス名導出のテストを書く（Red）: `securestorage` が null・空文字で `Claude Code-credentials` / パスありで `Claude Code-credentials-<sha256 先頭 8 桁>` / NFC 正規化で表記揺れが同一になる
- [ ] 1.4 active スロット判定規則のテストを書く（Red）: サービス名一致で active / 表記違い（末尾スラッシュ）は一致せずフォールバック / env がどのスロットにも一致しなければ snapshot の `active` / 手掛かりが無ければ最初のスロット
- [ ] 1.5 レジストリ読み取り・不正スロット除外・サービス名導出・active 判定を実装する（Green）。probe と statusline の両方から同じ規則で使えるようにする
- [ ] 1.6 レジストリの雛形または生成手段（コマンドか README の手順）を用意する。`id` の書式・一意性・スロット上限 8 個を明記する。実ファイルはリポジトリに含めない

## 2. usage-probe.sh の複数スロット化と schema 2

- [ ] 2.1 schema 2 のテストを書く（Red）: `schema` が 2 / `accounts` にスロットごとの固定キー名（`label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active`） / `active` に現在のスロット id
- [ ] 2.2 後方互換のテストを書く（Red）: トップレベルの `fetched_at` / `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` が `accounts` の active スロットの同名フィールドと一致する
- [ ] 2.3 `fetched_at` の意味論のテストを書く（Red）: active スロットが fail-open で前回値を引き継いだとき、per-slot とトップレベルの `fetched_at` がどちらも前回の取得時刻のままで、probe の実行時刻に更新されない
- [ ] 2.4 スロット単位 fail-open のテストを書く（Red）: 片方のスロットのフェッチ失敗時に、そのスロットは前回値と前回の `fetched_at` を保ち、他スロットは新しい値に更新される / 前回値も無いスロットは全フィールド `null` の欠測スロットとして載る
- [ ] 2.5 1 スロット時の退行ガードのテストを書く（Red）: レジストリ不在で `accounts` が既定スロット 1 つだけになり、トップレベルの従来キー（`fetched_at` を含む）が変更前と同じ値になる。既存の `plugins/dev-workflow/tests/usage-probe.bats` のケースは**無改変で**通ること
- [ ] 2.6 全スロット失敗時の全体 fail-open のテストを書く（Red）: exit 0 で snapshot を書かない
- [ ] 2.7 スロットのループとスロットごとの Keychain 取得・フェッチを実装する（Green）。テスト用オーバーライド（`USAGE_PROBE_RESPONSE_FILE`）をスロット別に与えられるようにする
- [ ] 2.8 `five_hour`（消化率・`resets_at`・epoch）のパースを追加する（Green）
- [ ] 2.9 snapshot の組み立てを schema 2 + トップレベルミラーに変更する（Green）。ミラーは active スロットのオブジェクトのフィールドをそのまま写す操作として実装し、独立に計算しない
- [ ] 2.10 スロット単位 fail-open（既存 snapshot からの前回値と `fetched_at` の引き継ぎ）を実装する（Green）
- [ ] 2.11 `refresh_token` を使わない判断の理由をコードコメントに残す
- [ ] 2.12 TTL キャッシュと原子的書き込みが従来どおり効いていることを確認する（Refactor）

## 3. statusline.sh のアカウント別表示

- [ ] 3.1 1 スロット時の出力同一性のテストを書く（Red）: レジストリ不在で、変更前と同じ stdin・snapshot を与えたときの出力がバイト単位で一致し、label 列が出ない。既存の `plugins/statusline/tests/statusline.bats` のケースは**無改変で**通ること
- [ ] 3.2 複数スロット描画のテストを書く（Red）: 2 スロットで 4 行、各行の左端に label
- [ ] 3.3 行を出す条件のテストを書く（Red）: 欠測スロットは行を出さない / 5h があり 7d が無いスロットは `5h` 行だけ / `rate_limits` も snapshot も無ければレートリミット行が 1 行も出ない
- [ ] 3.4 active / 非 active の描画元のテストを書く（Red）: active は stdin のライブ値、非 active は snapshot の値＋`fetched_at` からの経過時間
- [ ] 3.5 6 時間鮮度ゲートのテストを書く（Red）: active スロットの `fetched_at` が 6 時間より古ければ Fable バーを描かない（現行と同じ） / 非 active スロットは 2 日前でも Fable バーを描き経過時間を併記する
- [ ] 3.6 非 active スロットの `resets_at` が過去のときのテストを書く（Red）: 日程分母と残り時間を出さず、バーは消化率だけで描く
- [ ] 3.7 active スロット判定のテストを書く（Red）: `CLAUDE_SECURESTORAGE_CONFIG_DIR` 優先、未設定なら snapshot の `active` にフォールバック
- [ ] 3.8 schema 1 の snapshot に対する前方互換のテストを書く（Red）: `accounts` が無ければ既定スロット 1 つとして描画する
- [ ] 3.9 レートリミット行の生成をスロットのループに包み、label 列を追加する（Green）。`bar_seg` / `bar2` は変更しない
- [ ] 3.10 6 時間鮮度ゲートを active スロット限定にする（Green）
- [ ] 3.11 非 active スロットの経過時間表示（例 `2h前`）と、`resets_at` が過去のときの分母・残り時間の非表示を実装する（Green）
- [ ] 3.12 active スロット判定を共通規則（サービス名での突き合わせ → snapshot の `active` → 最初のスロット）で実装する（Green）

## 4. 仕様・ドキュメント・バージョン

- [ ] 4.1 archive 時に `openspec/specs/` を更新する: `dev-workflow-escalation-tripwires/spec.md` の「usage-probe と snapshot 契約」を delta の内容に差し替え、**新規 capability 2 本**（`usage-account-registry` / `statusline-multi-account-usage`）を `# <capability> Specification` + `## Purpose` + `## Requirements` の正本形式で新規作成する（落とすと `tests/openspec-specs-format.bats` が落ちる。issue #156 の再発防止）
- [ ] 4.2 `plugins/statusline/README.md` を新レイアウトとレジストリの説明に更新する（レジストリのパス・形状・`id` の規則・鮮度ゲートの非対称を含む）
- [ ] 4.3 `plugins/dev-workflow/.claude-plugin/plugin.json` と `plugins/statusline/.claude-plugin/plugin.json` のバージョンを上げ、ルートの `.claude-plugin/marketplace.json` も同時に更新する
- [ ] 4.4 `plugins/dev-workflow/CHANGELOG.md` に schema 2 と後方互換の扱いを記載する

## 5. 検証

- [ ] 5.1 `bats plugins/dev-workflow/tests/usage-probe.bats` を実行し exit code と出力を記録する
- [ ] 5.2 `bats plugins/statusline/tests/statusline.bats` を実行し exit code と出力を記録する
- [ ] 5.3 `bats plugins/dev-workflow/tests/tripwire-hook.bats` を実行し exit code と出力を記録する。schema 2 の snapshot を食わせて `FABLE_BUDGET_MODE` の導出結果が schema 1 のときと変わらないケースを 1 本足す（トップレベルミラーの唯一の存在理由なので、ここに退行ガードが要る）
- [ ] 5.4 `bats tests/marketplace-sync.bats tests/openspec-specs-format.bats` を実行し exit code と出力を記録する
- [ ] 5.5 実測値（5h 55% / 7d 82%（日程 74%） / Fable weekly 94% / weekly_all 74%）のフィクスチャで 2 スロットのレイアウトを目視確認する
- [ ] 5.6 レジストリ不在の状態で statusline を実行し、変更前の出力と diff が空であることを確認する
