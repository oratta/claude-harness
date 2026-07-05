# Design: proactive-routines

## Context

公式記事「Getting started with loops」（`research/loop-engineering.md` 冒頭）はプロアクティブループを「イベント/スケジュールがトリガー、人間不在。バグ分類・マイグレーション・依存関係更新などの定期業務」と定義し、合成例（`/schedule every hour: ... /goal: don't stop until every report ... is triaged, actioned, and responded to.`）と品質プラクティス「第二エージェントによるレビュー」を示す。`research/claude-code-official.md` §7（harnesses 論文）は長期タスクの外部状態設計（feature-list JSON・progress notes・1 セッション 1 機能・丁寧なテスト後にのみ passing・セッション開始時 smoke check）を、`research/anthropic-agent-knowledge.md` ソース 2 は fan-out 暴走防止の処理数上限を与える。

本 change は run「anthropic-knowledge-reflect」の change-4 であり、change-1（loops-plugin: レシピ形式規約・State 規約・references 置き場・/loops:design）と change-3（goal-and-time-recipes: シードレシピ 6 本）に依存する。plan.md の「含まないもの」により、定期実行の機構・配線一式（cron 登録・SessionStart hook・supervisor・launchd・`claude -p` 配線）は別トラック（Pikke プロセス整理）の責務であり、本 change のレシピは実行方法非依存に書く。

## Goals / Non-Goals

**Goals:**

- 人間不在で回るプロアクティブ合成ルーチン 3 本（backlog 消化 / 長期ビルド / レシピ採掘メタループ）を change-1 のレシピ形式規約に従った markdown レシピとして実装する
- 全ルーチンに安全設計（非破壊デフォルト・処理数上限・2 連続失敗凍結・silent drop 禁止・evidence 必須の状態更新）を焼き込む
- 各ルーチンの 1 サイクルデモを実施し、evidence ログを `{longrun-dir}` に残す

**Non-Goals:**

- 定期実行の機構・配線（スケジューラ登録・セッション運用・課金選択）。レシピは発火時プロンプト・推奨頻度・停止基準・実行環境の制約の宣言まで
- 独自ループランタイム（常駐スクリプト・カスタム driver・loop-definition schema）。反復・スケジュール・停止判定はネイティブプリミティブ（/goal の最大試行・/loop・/schedule・Workflow の budget）に任せる
- feature-list の JSON Schema による機械的強制（形式は references 記載のみ。schema 化は backlog）
- 既存プラグイン（daily-report / worktree 等）の本文変更、version bump・marketplace.json 同期（change-5 の責務）

## Decisions

### D1: ルーチンはネイティブプリミティブの合成レシピとして書き、ランタイムを持たない

- **選択肢**: (a) ルーチンごとに driver スクリプトを実装 / (b) レシピ（markdown 設計図）+ ネイティブコマンド文字列のみ
- **決定**: (b)。起動コマンド節はコピペで動く /schedule・/goal・/loop・skill 起動文字列を第一級の成果物とする
- **理由**: 公式路線は「ランタイムはネイティブ、ループはその合成」。config.yaml rule「独自 CLI やラッパースクリプトを作らない」および plan 制約「独自ループランタイムの再発明禁止」をそのまま実装する。受け入れ条件 7（独自ランタイム不存在）の検証対象でもある

### D2: 外向きアクションは Draft PR / issue コメントを上限とし、不可逆操作は人間へエスカレーションする

- **選択肢**: (a) 信頼度スコアで自動 merge を許可 / (b) 常に Draft PR 止まり
- **決定**: (b)。merge・close・force 系は全レシピの禁止事項として明記し、必要時は人間へのエスカレーションに倒す
- **理由**: 優先順位の最上位は安全性（暴走・課金・不可逆アクション防止）。このリポジトリの CLAUDE.md（Draft PR 運用・main 直 push 禁止）とも一致する。人間のレビューゲートが品質プラクティス「第二エージェントによるレビュー」の外側の最終防衛線になる

### D3: 停止基準は /goal の定量ゴール + 2 連続失敗凍結の二段構えにする

- **選択肢**: (a) 定量ゴールのみ / (b) 定量ゴール + 同一タスク/項目の 2 連続失敗で凍結 + 人間へエスカレーション
- **決定**: (b)
- **理由**: 定量ゴールだけでは達成不能タスクで無限リトライが起きる。凍結（対象から除外して記録）は進行を止めずに例外だけを人間に渡す設計であり、config.yaml rule「無限リトライ禁止」を実装する。long-build では凍結項目の feature-list からの削除を禁止し（harnesses 論文「項目・テスト削除禁止」）、progress notes に理由を記録する

### D4: 状態更新は evidence 必須・silent drop 禁止とし、change-1 の State 規約に載せる

- **選択肢**: (a) ルーチンの自己申告で state / passes を更新 / (b) evidence（verification コマンドの exit 0 ログ・生成物の実在）がある場合のみ更新し、処理しなかったものは繰り越し記録
- **決定**: (b)。long-build の `passes:true` 更新は verification exit 0 の evidence 必須。backlog-triage / recipe-miner の discovery 残余は state に繰り越しとして必ず記録する
- **理由**: 「完了は主張であり証明ではない」（意思決定ガイドライン）。報酬ハッキング（検証なき成功宣告）は Bad Loop 検査の対象そのものであり、ルーチン自身が違反しない設計にする。State は「エージェントは忘れるが、リポジトリは記憶する」の実装

### D5: デモは /loops:design のスキル起動に依存せず、references の規約検査手順を手動実行する

- **選択肢**: (a) デモ内で `/loops:design` を起動して規約検査させる / (b) `plugins/loops/references/` に記載された検査手順（停止基準必須・Bad Loop 検査）を手動実行し、各検査項目の PASS/FAIL を evidence に残す
- **決定**: (b)（Build Contract レビュー NOTE の反映）
- **理由**: loops プラグインは本 run の時点では未インストールであり、スキル起動（`/loops:design`）はデモ環境で解決できない可能性がある。検査の実体は references に書かれた手順であり、手動実行でも検査内容は同一。デモの成立条件から外部依存を外すことで、デモ失敗の原因をルーチン自体の問題に限定できる

### D6: 3 ルーチン + 各デモを独立サブマイルストーン（独立 commit）にする

- **選択肢**: (a) 3 ルーチンをまとめて実装し最後に一括デモ / (b) ルーチンごとに「テスト先行 → レシピ実装 → commit」「デモ実行 → evidence → commit」を独立に完結させる
- **決定**: (b)（Build Contract レビュー NOTE の反映）。tasks.md のグループをルーチン単位・デモ単位で分割する
- **理由**: 1 ルーチンのデモ失敗（例: recipe-miner の実ログ解析で候補ゼロ以外の異常）が他 2 本の完成・commit をブロックしない。git-commit-policy（細かい単位で commit）とも整合し、部分完了でも Draft PR に進捗が残る

### D7: recipe-miner のログ解析はサブエージェント隔離 + jq 圧縮とする

- **選択肢**: (a) メインセッションで jsonl を直接読む / (b) サブエージェントに隔離し、daily-report の llm-log-compactor の jq パターンを流用して圧縮解析、候補リストのみをメインに返す
- **決定**: (b)
- **理由**: 生ログは巨大でメインのコンテキストを汚染する（トークン管理「決定論的作業はスクリプト化」に反する）。config.yaml rule「ログ解析はサブエージェントに隔離し、抽出結果のみをメインに返す」をそのまま実装する。jsonl の所在（`~/.claude/projects/`）がローカル限定である事実は、レシピの実行環境制約（ローカル実行必須）として明記する

### D8: モデル ID はレシピに書かない

- **選択肢**: (a) ルーチンプロンプトに使用モデルを直書き / (b) モデル指定が必要な場合も `plugins/longrun/references/model-tiers.md` を唯一のソースとして参照し、レシピ本文にはモデル ID を書かない
- **決定**: (b)
- **理由**: plan 制約「モデル ID 直書き禁止」。モデル世代交代時のドリフトを構造的に防ぐ（model-allocation change の D3 と同根）

## Risks / Trade-offs

- [backlog-triage デモが実 backlog を消費し、意図しない Draft PR がリポジトリに残る] → デモは処理数上限 1 件で実行し、生成した Draft PR はデモ evidence 記録後にクローズ可能（Draft はマージ前なら非破壊）。または安全なサンドボックスで相当物を実行する
- [long-build デモ用の feature-list がリポジトリ実体と乖離した人工例になる] → 3 項目以上の小さな実在検証コマンド（bats / grep / jq）を verification に使い、exit code evidence が本物であることを担保する
- [recipe-miner の実ログ解析で候補が 0 件になりデモが「提案なし」で終わる] → 「提案なし」の正常終了 + state 更新は仕様上の正常系であり、デモ成立条件として受け入れ条件 12 に明記されている。異常系（解析失敗）とは区別してログに残す
- [レシピの安全制約（禁止事項・凍結・上限）が散文で書かれ、grep 検証と実際の挙動が乖離する] → 各安全制約を固定見出し節（停止基準 / エスカレーション）配下の明示的な箇条書きにし、bats + grep でキーフレーズの存在を機械検証する。挙動面はデモの evidence で確認する
- [change-1 / change-3 の成果物（レシピ規約・State 規約・シードレシピ）が未確定のまま着手すると手戻りが出る] → 依存関係どおり change-1 → change-3 → change-4 の順で実施する。レシピ規約の固定見出し 7 節は plan.md で確定済みのため、見出し構造は先行して固定できる

## Migration Plan

1. backlog-triage（テスト → レシピ → commit → デモ → commit）→ long-build（同）→ recipe-miner（同）の順で、各サブマイルストーンを独立に完結させる
2. 追加のみの change であり既存ファイルの変更はない。ロールバックは追加ファイル（recipes 3 本 + references 1 本 + tests）の削除で完全復帰する
3. marketplace.json への loops 登録・version 同期は change-5 が担うため、本 change 単独ではプラグイン配布状態に影響しない

## Open Questions

- backlog-triage デモの実行場所（このリポジトリの実 backlog vs サンドボックス）は、デモ時点の backlog.md に安全に 1 サイクル回せる小タスクが存在するかで決める（存在しなければサンドボックスに倒す。どちらでも受け入れ条件 10 は満たせる）
- recipe-miner のデモに使う実ログの範囲（直近 7 日で候補が出る密度があるか）はデモ時に確認する。候補ゼロでも正常系として成立する
