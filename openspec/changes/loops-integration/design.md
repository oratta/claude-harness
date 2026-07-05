# Design: loops-integration

## Context

本 change は run「公式ループ 4 タイプをハーネスに実装する（anthropic-knowledge-reflect）」の change-5 であり、change-1〜4 の全成果物（新プラグイン `plugins/loops/`・既存スキルの自己検証節・レシピ集・プロアクティブルーチン）が揃った後に**最後に直列実行**される統合ステップである。

このリポジトリは Claude Code プラグインの marketplace dir として運用されており、配布は `~/.claude/rules/plugin-editing.md` のルール（marketplace 版のみを編集・version bump 必須・`~/.claude/plugins/cache/` はバージョン単位キャッシュ）に従う。version bump と marketplace.json 同期を怠ると、内容を変えても他プロジェクトに反映されない。現時点の marketplace.json は top-level `version: 2.9.0`、`plugins[]` に 8 プラグイン（longrun 6.3.0 等）が登録されている。

一次ソース: `research/loop-engineering.md` 冒頭の公式記事セクション（トークン管理 6 項目・「ループはチャットの約 4 倍、マルチエージェント構成は約 15 倍」の定量事実・/usage//workflows レビュー）。

## Goals / Non-Goals

**Goals:**

- `loops` プラグインを marketplace.json に登録し、`/plugin install loops@oratta-claude-harness` で配布可能にする
- change-1〜4 で編集された全プラグインの version bump と marketplace.json 同期（plugin.json ↔ plugins[] エントリ ↔ top-level の整合）
- ルート README に公式 4 ループタイプとレシピ集の位置づけを要約追記する（公式記事リンク付き）
- `plugins/loops/references/cost-guardrails.md` を新設し、レシピの「コスト注意」節が参照する根拠を 1 箇所に集約する
- run 全体の機械検証可能な受け入れ条件を統合テスト（bats + grep/jq）として実装・実行し、エビデンスを記録する

**Non-Goals:**

- 定期実行の機構・配線（セッション内 cron 登録・SessionStart 復元 hook・session-host supervisor・launchd・`claude -p` 配線）。実行側は別セッションの Pikke プロセス整理が担う（plan.md「含まないもの」）
- 独自ループランタイム（常駐スクリプト・カスタム driver・宣言的 schema 実行系）。公式路線は「ネイティブプリミティブの合成」であり、本 change の統合検証はむしろその不在を検証する側
- change-1〜4 の成果物の内容修正（発見した問題は統合検証の FAIL として該当 change に差し戻す。本 change で仕様を書き換えない）
- 既存プラグインの機能変更（version bump のみ。SKILL.md 等の本文には触れない）
- レシピ形式の schema 化・機械検証の高度化（backlog 行き。grep ベース検証で足りる）

## Decisions

### D1: version 同期の検証は jq による機械比較とし、bats テストに恒久化する

- **選択肢**: (a) 目視確認のみ / (b) 統合検証時に 1 回だけスクリプト実行 / (c) bats テストとして恒久化
- **決定**: (c)。marketplace.json の `plugins[]` 全エントリについて `jq` で plugin.json の version と突き合わせるテストを `plugins/loops/tests/integration.bats` に置く
- **理由**: version 不整合は過去に繰り返し起きた事故パターン（plugin-editing.md が明文化された経緯）であり、run 終了後も `find plugins -name '*.bats'` の定常スイートで検出され続けることに価値がある。config.yaml rule「marketplace.json の version は各 plugin.json と完全一致させる」の実装

### D2: 統合テストの置き場所は plugins/loops/tests/ とする

- **選択肢**: (a) リポジトリルートに tests/ を新設 / (b) plugins/loops/tests/ に置く
- **決定**: (b)
- **理由**: テスト実行コマンドが `find plugins -name '*.bats' -print0 | xargs -0 bats` であり、plugins/ 配下でないと定常スイートに乗らない。また検証対象の中心（レシピ規約・ランタイム不在・cost-guardrails）が loops プラグインの規約であるため、loops に同居させるのが凝集的。リポジトリ横断の検証（marketplace 同期・README）も本 run の統合ゲートとして同ファイルに含める

### D3: README への追記は要約のみとし、レシピ固定見出し構造を README に持ち込まない

- **選択肢**: (a) README にレシピ一覧と各レシピの要点まで載せる / (b) 位置づけ + 4 タイプ + 公式リンク + インストールコマンド + plugins/loops/ への導線のみ
- **決定**: (b)
- **理由**: config.yaml rule「README への追記は要約に留め、詳細は plugins/loops/ と research/ に委ねる」の直接実装。レシピ本文を README に複製すると二重管理でドリフトする（レシピは change-4 の recipe-miner が更新し続けるため、複製先が陳腐化する）。「README にレシピ固定見出しが現れない」を grep 検証可能な形で仕様化した

### D4: cost-guardrails.md はモデル ID を書かず、6 項目は数えられる形式で列挙する

- **選択肢**: (a) 散文で自由に書く / (b) 6 項目を見出し/番号付きリストで機械的に数えられる形式にする
- **決定**: (b)。かつモデル ID（`claude-` プレフィクス）は書かない（`plugins/longrun/references/model-tiers.md` が唯一のソース、という run 全体の制約に従う）
- **理由**: 受け入れ条件 13「cost-guardrails.md が公式トークン管理 6 項目を含む」を grep/カウントで機械検証するため。定量事実（約 4 倍 / 約 15 倍）も文言を固定して grep 可能にする。一次ソースは research/loop-engineering.md 冒頭の公式記事セクションであり、コミュニティ由来の数値と混ぜない

### D5: 「独自ランタイム不在」の検証は 2 面で行う（スクリプト検査 + 起動コマンド検査）

- **選択肢**: (a) find で *.sh の不在のみ確認 / (b) スクリプトの反復・スケジューリング自前実装の grep 検査 + レシピ起動コマンドのネイティブプリミティブ検査の 2 面
- **決定**: (b)
- **理由**: (a) では「補助スクリプトは一切禁止」という過剰制約になる（決定論的作業のスクリプト化は公式ベストプラクティスであり、検証用スクリプト等は正当）。禁止すべきは「ループを回す常駐処理・driver」なので、検査対象を反復実行/スケジューリングの自前実装（while true / sleep ループ常駐）に絞り、加えてレシピの起動コマンドが /goal・/loop・/schedule・スラッシュコマンドで始まることを確認する。受け入れ条件 7 の直接実装

### D6: 統合検証で FAIL を発見した場合は該当 change の成果物を最小修正し、仕様の書き換えはしない

- **選択肢**: (a) FAIL に合わせて本 change の spec を緩める / (b) 該当成果物（レシピ・README・JSON）側を修正して PASS させる
- **決定**: (b)。修正は不整合の解消に必要な最小限とし、change-1〜4 の spec が定めた要件自体には触れない
- **理由**: 統合ステップの責務は「全体整合の担保」であり、基準を動かすと統合ゲートの意味が失われる。優先順位（安全性 > 公式路線への忠実さ > シンプルさ > レシピの本数）に照らし、検証を緩める選択はとらない

### D7: bump 対象プラグインは git diff で機械的に確定する

- **選択肢**: (a) plan.md 記載の想定リストを固定的に使う / (b) `git diff origin/main --name-only` で実際に変更されたプラグインを列挙して確定する
- **決定**: (b)
- **理由**: change-2（skill-verification）の棚卸し結果によって編集対象プラグインが変動するため、plan 時点のリストでは過不足が出うる。実変更ベースなら「変更していないプラグインを bump しない」（無意味なキャッシュ無効化の回避）も同時に担保できる

### D8: origin/main が無関係 PR で先行したため bump ベースラインを merge-base に切替

- **背景**: 実装時点で origin/main が本 run と無関係な PR #10（longrun ノンストップ実行、`longrun 6.4.0 / marketplace 2.10.0`）で先行していた。本 run の分岐点 merge-base は `longrun 6.3.0 / marketplace 2.9.0`。D7 の `git diff origin/main` では origin/main 側の先行差分が混入し「本 run が変更したプラグイン」を誤判定する
- **選択肢**: (a) spec 文言どおり origin/main HEAD 基準 / (b) merge-base 基準
- **決定**: (b)。統合テストの「main 時点より bump」検証と変更プラグイン列挙は `git merge-base HEAD origin/main` を基準に行う。version パリティ（plugin.json == marketplace.json）は基準非依存の恒久検証として別途実装し、bump 検証は base 未取得/base==current 時に skip する（マージ後の再実行でも安全）
- **理由**: D7 の意図（本 run の実変更プラグインだけ bump）に merge-base が正確に一致する。origin/main HEAD は無関係な先行差分を含み誤判定する。longrun は origin/main 6.4.0 とは別系統（本 run は自己検証節の追記のみ）のため 6.3.1（patch）とし、マージ時の最終 version 再調整は人間の責務（本 change のスコープ外）

## Risks / Trade-offs

- [change-1〜4 の成果物が不完全なまま本 change が走ると統合検証が大量 FAIL する] → 依存関係を「change-1〜4 全て完了後に直列実行」と固定（plan.md）。FAIL 時は D6 の方針で最小修正し、修正不能な構造問題は凍結して人間へエスカレーション
- [レシピ固定見出しの文言が change-1 の規約と本 change の grep パターンでズレる] → 統合テストの grep パターンは change-1 が確定させた規約文書（plugins/loops/ 配下のレシピ形式規約）から転記し、独自に見出し文言を発明しない
- [version bump の粒度（patch/minor）判断がブレる] → 機能追加を含むプラグインは minor、検証節追記のみは patch を目安とする。検証上は「main より上がっていること + 完全一致」のみを要件とし、粒度は要件にしない
- [「常駐処理の grep 検査」が正当な補助スクリプトを誤検知する] → 検査パターンを反復実行の自前実装（while true 等）に限定し、誤検知した場合はテスト側のパターンを絞る（規約の意図は「ループの実行系を持たない」であり、スクリプト全面禁止ではない）
- [README の追記が既存構成（プラグイン一覧の体裁）と不整合になる] → 既存 README のプラグイン紹介の体裁（見出し + 説明 + install コマンド + 機能箇条書き）に合わせて追記する

## Migration Plan

1. 統合テスト（integration.bats）を先に書く（RED）→ cost-guardrails.md 新設 → README 追記 → marketplace.json 登録 + version bump → 統合テスト全 PASS（GREEN）の順で実装する
2. **後方互換**: 既存プラグインの変更は version bump のみで機能に影響しない。marketplace.json への loops エントリ追加は追加的変更であり既存インストールを壊さない
3. **ロールバック**: 本 change は追加的（エントリ追加・ファイル新設・README 追記）であり、revert すれば loops が未配布に戻るだけで既存プラグインの動作には影響しない

## Open Questions

- bump 対象プラグインの最終リストは change-2〜4 の実変更確定後に `git diff origin/main --name-only` で確定する（D7。仕様は「編集済み全プラグイン」で固定済みのため設計は変わらない）
- 公式トークン管理 6 項目の正確な文言は `research/loop-engineering.md` 冒頭の公式記事セクションから転記して確定する（3 項目は plan.md に明示済み: 頻度最小化・決定論部分のスクリプト化・パイロット実行）
