# Verification Guide

## 環境
- 対象: CLI プラグイン（Claude Code セッション内）。Web UI なし
- テスト: `find plugins -name '*.bats' | xargs bats`
- 構文検証: `jq . <file>.json` / `node --check <file>.js`

## change-1: loops-plugin

### S1: [loops-design-skill] 選択フレームワークの対応が記載されている
- WHEN: `plugins/loops/skills/loops-design/SKILL.md` を読む
- THEN: 「検証ステップ」「停止条件」「トリガー」「プロンプト自体」の 4 つの手放す対象と、ターンベース / ゴールベース / タイムベース / プロアクティブの 4 ループタイプの対応に基づく選定フローが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S2: [loops-design-skill] loop-types リファレンスを参照している
- WHEN: SKILL.md 本文を grep する
- THEN: `references/loop-types.md` への参照が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S3: [loops-design-skill] 停止基準が無い場合は出力を拒否する
- WHEN: ユーザーが `/loops:design` の対話で停止基準を提示しないままレシピの書き出しを求める
- THEN: スキルはレシピを出力せず、停止基準（最大試行数 / 時間 / 定量ゴール）の指定を求めるヒアリングを続ける
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S4: [loops-design-skill] SKILL.md に停止基準必須のゲートが明記されている
- WHEN: `plugins/loops/skills/loops-design/SKILL.md` を grep する
- THEN: 停止基準が確定しない限りレシピを出力しない旨の必須チェックが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S5: [loops-design-skill] Bad Loop 検査 4 項目が SKILL.md に定義されている
- WHEN: `plugins/loops/skills/loops-design/SKILL.md` を grep する
- THEN: 停止基準の欠如・検証なき成功宣告・報酬ハッキング余地・過剰な実行頻度の 4 検査項目がすべて記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S6: [loops-design-skill] 検査に該当したら修正提示して再設計する
- WHEN: 設計中のループが Bad Loop 検査のいずれかに該当する
- THEN: スキルは該当項目と修正案をユーザーに提示し、そのままの出力は行わない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S7: [loops-design-skill] 出力レシピが 7 見出しを持つ
- WHEN: `/loops:design` で小さなループを 1 本設計しレシピを書き出す
- THEN: 出力された `recipes/<name>.md` に固定見出し 7 項目（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）がすべて存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S8: [loops-design-skill] 起動コマンドがネイティブプリミティブである
- WHEN: 出力されたレシピの「起動コマンド」節を確認する
- THEN: /goal・/loop・/schedule・skill 起動のいずれかのコピペ可能なコマンド文字列であり、独自 CLI やラッパースクリプトへの言及がない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S9: [loops-goalify-skill] インラインテキストを受け付ける
- WHEN: ユーザーが `/loops:goalify` にやりたいことのテキストを直接渡して起動する
- THEN: スキルはそのテキストを brain dump として解析を開始する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S10: [loops-goalify-skill] ファイルパスを受け付ける
- WHEN: ユーザーが `/loops:goalify` に既存ファイルのパスを渡して起動する
- THEN: スキルはそのファイルの内容を brain dump として解析を開始する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S11: [loops-goalify-skill] 不足観点のみ質問される
- WHEN: 成功基準と前提は書かれているが停止条件とスコープ境界が無い brain dump を与えて `/loops:goalify` を実行する
- THEN: 停止条件とスコープ境界についてのみ質問され、成功基準・前提についての質問は行われない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S12: [loops-goalify-skill] 全情報が揃っていればヒアリングは 0 問
- WHEN: 4 観点（成功基準の機械検証可能化 / 停止条件 / スコープ境界 / 前提）すべてが書かれている brain dump を与えて `/loops:goalify` を実行する
- THEN: AskUserQuestion による質問は 0 問で、そのまま生成に進む
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S13: [loops-goalify-skill] goal ブリーフが生成される
- WHEN: `/loops:goalify` が生成を完了する
- THEN: `goals/<name>.goal.md` が作成され、「目的」「成功基準」「制約」「参照パス」「エスカレーション条件」の見出しをすべて持つ
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S14: [loops-goalify-skill] 成功基準がすべて機械検証可能である
- WHEN: 生成された `goals/<name>.goal.md` の「成功基準」節を確認する
- THEN: 各項目が実行コマンドと期待値（exit code・出力・ファイル実在等）の組で書かれており、主観的基準が含まれない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S15: [loops-goalify-skill] /goal 起動コマンド 1 行が提示される
- WHEN: `/loops:goalify` が生成を完了する
- THEN: 生成した goal ブリーフを参照するコピペ可能な /goal 起動コマンドが 1 行で出力に含まれる
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S16: [loops-goalify-skill] レシピ昇格の案内が出力に含まれる
- WHEN: `/loops:goalify` が生成を完了する
- THEN: 出力に「反復利用するならレシピへ昇格する」旨の案内が 1 行含まれる
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S17: [loops-loop-types-reference] 4 タイプの表が存在する
- WHEN: `plugins/loops/references/loop-types.md` を grep する
- THEN: ターンベース・ゴールベース・タイムベース・プロアクティブの 4 タイプがすべて記載され、各タイプに手放す対象（ターンベース = 検証ステップ / ゴールベース = 停止条件 / タイムベース = トリガー / プロアクティブ = プロンプト自体）と対応するネイティブプリミティブ（skill の自己検証 / /goal / /loop・/schedule / 合成）が対応付けられている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S18: [loops-loop-types-reference] 使い分けと具体例が記載されている
- WHEN: 各タイプの説明を読む
- THEN: どういう業務にどのタイプを選ぶかの基準と、具体例（例: PR 面倒見 = タイムベース、テスト全 PASS まで = ゴールベース）が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S19: [loops-loop-types-reference] 責務分離の節が存在する
- WHEN: `plugins/loops/references/loop-types.md` の見出しを確認する
- THEN: 実行機構との責務分離を扱う節が存在し、レシピの宣言範囲 4 項目（発火時プロンプト / 推奨頻度 / 停止基準 / 実行環境の制約）が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S20: [loops-loop-types-reference] 定期実行の配線がスコープ外であると明記されている
- WHEN: 同じ節（実行機構との責務分離の節）を読む
- THEN: スケジューラへの登録・セッション運用・課金選択は呼び出し側の責務であり、レシピは実行方法非依存に書くことが明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S21: [loops-plugin-structure] plugin.json が妥当な JSON である
- WHEN: `plugins/loops/.claude-plugin/plugin.json` を JSON としてパースする（例: `jq . plugins/loops/.claude-plugin/plugin.json`）
- THEN: exit 0 でパースが成功し、`name` フィールドが `loops`、`version` フィールドが semver 形式（`X.Y.Z`）である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S22: [loops-plugin-structure] 必須ファイル一式が存在する
- WHEN: `plugins/loops/` 配下のファイル存在を確認する
- THEN: `skills/loops-design/SKILL.md`・`skills/loops-goalify/SKILL.md`・`references/loop-types.md`・`references/recipe-format.md`・`templates/recipe-template.md`・`templates/state-template.md` がすべて存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S23: [loops-plugin-structure] 実行スクリプトが存在しない
- WHEN: `plugins/loops/` 配下で `*.bats` を除く実行可能スクリプト（`*.sh`・`*.js`・`*.py` 等）を検索する（例: `find plugins/loops -type f \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) ! -name '*.bats'`）
- THEN: 該当ファイルは 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S24: [loops-plugin-structure] ループ定義 schema が存在しない
- WHEN: `plugins/loops/` 配下で `*.schema.json` を検索する
- THEN: 該当ファイルは 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S25: [loops-plugin-structure] モデル ID の grep が 0 件である
- WHEN: `plugins/loops/` 配下で `claude-` で始まるモデル ID 文字列を grep する（例: `grep -rE 'claude-(opus|sonnet|haiku|[0-9])' plugins/loops/`）
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S26: [loops-recipe-format] 規約文書が固定見出し 7 項目を列挙している
- WHEN: `plugins/loops/references/recipe-format.md` を grep する
- THEN: 「ループ型」「目的」「起動コマンド」「停止基準」「前提」「コスト注意」「エスカレーション」の 7 見出しすべてが規約として記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S27: [loops-recipe-format] 停止基準が必須項目として明記されている
- WHEN: `plugins/loops/references/recipe-format.md` の「停止基準」の説明を読む
- THEN: 停止基準が必須項目であること、および最大試行数・時間・定量ゴールのいずれか 1 つ以上を含むべきことが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S28: [loops-recipe-format] テンプレートが 7 見出しを持つ
- WHEN: `plugins/loops/templates/recipe-template.md` の見出しを grep する
- THEN: 「ループ型」「目的」「起動コマンド」「停止基準」「前提」「コスト注意」「エスカレーション」の 7 見出しがすべて存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S29: [loops-recipe-format] 起動コマンド節にネイティブプリミティブの注記がある
- WHEN: テンプレートの「起動コマンド」節を読む
- THEN: コピペ可能なネイティブコマンド文字列（/goal・/loop・/schedule・skill 起動）を書くこと、および独自 CLI・ラッパースクリプトを作らないことが注記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S30: [loops-recipe-format] 宣言範囲の 4 項目が規約に定義されている
- WHEN: `plugins/loops/references/recipe-format.md` の実行インターフェースに関する節を読む
- THEN: レシピが宣言するのは「発火時に投入するプロンプト」「推奨頻度」「停止基準」「実行環境の制約（例: ローカルの `~/.claude/projects/` jsonl を読むループはローカル実行が必要）」までであることが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S31: [loops-recipe-format] スケジューラ登録が呼び出し側の責務とされている
- WHEN: 同じ節（実行インターフェースに関する節）を読む
- THEN: スケジューラへの登録・セッション運用・課金選択はレシピのスコープ外であり呼び出し側の責務であることが明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S32: [loops-state-convention] State 規約が 4 節を定義している
- WHEN: loops プラグインの references 配下で State 規約の記述を grep する
- THEN: `loops/state/<name>.state.md` という配置規約と、「現在の作業」「前回の試行と結果」「人間への引き継ぎ待ち」「繰り越しタスク」の 4 節がすべて定義されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S33: [loops-state-convention] 永続化の設計原則が明記されている
- WHEN: State 規約の説明を読む
- THEN: セッションをまたぐ記憶をファイルに永続化する旨（「エージェントは忘れるが、リポジトリは記憶する」相当の原則）が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S34: [loops-state-convention] テンプレートが 4 見出しを持つ
- WHEN: `plugins/loops/templates/state-template.md` の見出しを grep する
- THEN: 「現在の作業」「前回の試行と結果」「人間への引き継ぎ待ち」「繰り越しタスク」の 4 見出しがすべて存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S35: [loops-state-convention] silent drop 禁止の注記がある
- WHEN: テンプレートの「繰り越しタスク」節を読む
- THEN: 処理しなかったタスク（discovery で拾ったが処理しなかったタスク）を必ず繰り越しとして記録する旨の注記が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

## change-2: skill-verification

### S36: [loops-self-verification-reference] リファレンスが中核原則を含む
- WHEN: ユーザーが `plugins/loops/references/self-verification.md` を開き「完了は主張であり証明ではない」を grep する
- THEN: ファイルが存在し、中核原則の文（「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」）が本文に記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S37: [loops-self-verification-reference] evidence の 4 種別が列挙されている
- WHEN: ユーザーが `plugins/loops/references/self-verification.md` の evidence 種別の節を読む
- THEN: 「テスト出力」「exit code」「生成物の実在と形式チェック」「実行結果ログ」の 4 種がすべて列挙されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S38: [loops-self-verification-reference] 記載ルールが明記されている
- WHEN: ユーザーが `plugins/loops/references/self-verification.md` のスキル側への記載ルールの節を読む
- THEN: 「1 行参照 + スキル固有の検証手順のみ」「共通原則本文のコピー禁止」に相当するルールが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S39: [loops-self-verification-reference] 中核原則の文言が SKILL.md に重複していない
- WHEN: ユーザーが `plugins/*/skills/*/SKILL.md` の全ファイルに対して「完了は主張であり証明ではない」を grep する
- THEN: ヒットは 0 件である（中核原則の本文は `plugins/loops/references/self-verification.md` にのみ存在する）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S40: [loops-self-verification-reference] 棚卸しリストに最低 7 スキルの実パスが記録されている
- WHEN: ユーザーが `plugins/loops/references/self-verification.md` の「対象スキル一覧」節で対象と判定されたスキルのパスを確認する
- THEN: 7 スキル（`plugins/longrun/skills/longrun-plan/SKILL.md`・`plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`）の実パスがすべて対象として記録されており、e2s-distill のエントリは `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` の実パスで記載されている（`e2s-distill` をパスに含む存在しないパスの記載が 0 件）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S41: [loops-self-verification-reference] 対象外スキルに理由が記録されている
- WHEN: ユーザーが「対象スキル一覧」節で対象外と判定されたスキルのエントリを読む
- THEN: 各対象外エントリに判定理由（例: 成果物を出さない、既に検証ステップが本文に明示されている）が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S42: [skill-verification-sections] 最低 7 スキルの SKILL.md に「## 自己検証」節が存在する
- WHEN: ユーザーが `plugins/longrun/skills/longrun-plan/SKILL.md`・`plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` の各ファイルで「## 自己検証」を grep する
- THEN: 7 ファイルすべてで見出しがちょうど 1 件ヒットする
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S43: [skill-verification-sections] 各節が共通原則リファレンスへの参照 1 行を含む
- WHEN: ユーザーが対象スキルの「## 自己検証」節で `loops/references/self-verification.md` を grep する
- THEN: 各対象スキルの節にリファレンスへのパス参照が 1 行含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S44: [skill-verification-sections] 各節に検証コマンドまたは成果物パスが最低 1 つある
- WHEN: ユーザーが対象スキルの「## 自己検証」節の固有手順を読む
- THEN: 各節に、実行可能な検証コマンド（例: テスト実行・lint・`jq` による形式チェック）または検証対象の成果物パス（例: 生成されるファイルのパス）が最低 1 つ記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S45: [skill-verification-sections] 節本文の完全一致ペアが存在しない
- WHEN: ユーザーが全対象スキルの「## 自己検証」節から参照 1 行を除いた本文を相互に比較する
- THEN: 完全一致する本文のペアは 0 組である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S46: [skill-verification-sections] 検証手段がそのスキルの成果物を名指ししている
- WHEN: レビュアーが任意の対象スキルの「## 自己検証」節を読む
- THEN: そのスキル固有の成果物（例: daily-report なら生成される diary ファイル、wt-setup なら作成された worktree と Draft PR）が検証対象として名指しされており、どのスキルにも当てはまる汎用文言だけの節が 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S47: [skill-verification-sections] frontmatter が変更されていない
- WHEN: ユーザーが本 change の実装前後で各対象 SKILL.md の frontmatter を diff する
- THEN: name・description を含む frontmatter の変更行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S48: [skill-verification-sections] 変更が節の追加のみである
- WHEN: ユーザーが本 change の実装前後で各対象 SKILL.md を `git diff` で比較する
- THEN: 削除行・既存行の変更は 0 件であり、追加行は「## 自己検証」節（見出し・参照 1 行・固有手順）のみである
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S49: [skill-verification-sections] 追加後 500 行以下のスキルは節が SKILL.md 内に完結している
- WHEN: ユーザーが「## 自己検証」節の追加後に `wc -l` が 500 行以下の対象 SKILL.md を確認する
- THEN: 検証手順が SKILL.md の節内に完結しており、references への分離は要求されない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S50: [skill-verification-sections] 追加後 500 行を超えるスキルは詳細が references に分離されている
- WHEN: ユーザーが「## 自己検証」節の追加後に 500 行を超える対象 SKILL.md（例: 追加前から 506 行ある `plugins/worktree/skills/wt-clean/SKILL.md`）を確認する
- THEN: 検証詳細が同プラグインの `references/` 配下のファイルに存在し、SKILL.md 内の「## 自己検証」節は見出し行を含めて 15 行以内である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

## change-3: goal-time-recipes

### S51: [loops-goal-recipes] goal レシピ 3 ファイルが存在する
- WHEN: `plugins/loops/recipes/` を一覧する
- THEN: `goal-tests-green.md`・`goal-acceptance-pass.md`・`goal-lighthouse.md` の 3 ファイルが全て存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S52: [loops-goal-recipes] 固定見出しが grep で確認できる
- WHEN: 各 goal レシピに対して固定見出し 7 種（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をそれぞれ grep する
- THEN: 3 ファイル全てで 7 見出し全てがヒットする（欠落 0 件）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S53: [loops-goal-recipes] ループ型がゴールベースと明記されている
- WHEN: 各 goal レシピのループ型の節を grep する
- THEN: 3 ファイル全てに「ゴールベース」の記載がある
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S54: [loops-goal-recipes] goal-tests-green の成功基準がコマンドと期待値で書かれている
- WHEN: `goal-tests-green.md` の停止基準の節を読む
- THEN: bats 実行コマンド（`find plugins -name '*.bats' -print0 | xargs -0 bats`）と期待値（exit 0 / 全 PASS）が明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S55: [loops-goal-recipes] goal-acceptance-pass の成功基準がコマンドと期待値で書かれている
- WHEN: `goal-acceptance-pass.md` の停止基準の節を読む
- THEN: 「対象 longrun の plan.md の受け入れ条件に列挙された機械検証コマンドが全て PASS すること」が成功基準として明記され、受け入れ条件の各項目をコマンド + 期待値として読み取る手順が書かれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S56: [loops-goal-recipes] goal-lighthouse の成功基準が公式例準拠のスコア閾値で書かれている
- WHEN: `goal-lighthouse.md` の停止基準の節を読む
- THEN: Lighthouse スコアの閾値（デフォルト 90 以上）と測定コマンド（または測定手段）が明記され、公式例（stop after 5 tries 相当の最大試行数）が反映されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S57: [loops-goal-recipes] 主観基準が存在しない
- WHEN: 3 本の goal レシピの停止基準の節をレビューする
- THEN: 全ての成功基準がコマンド + 期待値（exit code・PASS 件数・スコア閾値のいずれか）で構成され、「良くなったら」等の主観的表現による基準が 1 件も存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S58: [loops-goal-recipes] 各 goal レシピに最大試行数のデフォルト値がある
- WHEN: 3 本の goal レシピの停止基準の節をそれぞれ読む
- THEN: 全てのレシピに最大試行数（または時間上限）の具体的なデフォルト値と、その変更方法（起動コマンド中のどこを書き換えるか）が明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S59: [loops-goal-recipes] 打ち切り条件の無いレシピが 0 件である
- WHEN: `plugins/loops/recipes/goal-*.md` の全ファイルについて停止基準の節を検査する
- THEN: 成功基準のみで打ち切り条件（最大試行数 or 時間上限）を欠くレシピは 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S60: [loops-goal-recipes] 起動コマンドがコピペ可能な /goal 文字列である
- WHEN: 各 goal レシピの起動コマンドの節を読む
- THEN: 3 ファイル全てに `/goal` で始まるコピペ可能なコマンド文字列が含まれており、成功基準（コマンド + 期待値）と最大試行数がそのコマンド文字列内に埋め込まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S61: [loops-goal-recipes] 独自ランタイム・モデル ID への参照が無い
- WHEN: `plugins/loops/recipes/goal-*.md` に対して独自スクリプト起動（例: `bash .*loop.*\.sh`）と `claude-` で始まるモデル ID を grep する
- THEN: いずれも 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S62: [loops-time-recipes] time レシピ 3 ファイルが存在する
- WHEN: `plugins/loops/recipes/` を一覧する
- THEN: `loop-pr-babysit.md`・`cron-daily-report.md`・`cron-weekly-report.md` の 3 ファイルが全て存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S63: [loops-time-recipes] 固定見出しが grep で確認できる
- WHEN: 各 time レシピに対して固定見出し 7 種（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をそれぞれ grep する
- THEN: 3 ファイル全てで 7 見出し全てがヒットする（欠落 0 件）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S64: [loops-time-recipes] ループ型がタイムベースと明記されている
- WHEN: 各 time レシピのループ型の節を grep する
- THEN: 3 ファイル全てに「タイムベース」の記載がある
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S65: [loops-time-recipes] /loop 起動コマンドと保守的な間隔デフォルトがある
- WHEN: `loop-pr-babysit.md` の起動コマンドの節を読む
- THEN: `/loop` で始まるコピペ可能なコマンド文字列（PR のチェック・レビューコメント対応・CI 失敗修正）が存在し、間隔のデフォルトが 5〜10 分の範囲で指定され、間隔の変更方法（コマンド文字列中の該当箇所）が併記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S66: [loops-time-recipes] 非破壊制約とエスカレーションが明記されている
- WHEN: `loop-pr-babysit.md` の本文を読む
- THEN: マージ・Ready for Review 切り替え・main への直接 push を行わないこと（feature branch への push と Draft PR の更新までを許可）、およびそれらが必要になった場合は人間へエスカレーションすることが明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S67: [loops-time-recipes] PR 終了時の停止基準がある
- WHEN: `loop-pr-babysit.md` の停止基準の節を読む
- THEN: 対象 PR のマージまたはクローズを検知したらループを終了（/loop のキャンセル）する条件が明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S68: [loops-time-recipes] 発火時プロンプトと推奨頻度が定義されている
- WHEN: `cron-daily-report.md` と `cron-weekly-report.md` の起動コマンドの節を読む
- THEN: 両ファイルに発火時に投入するコピペ可能なプロンプト（非対話モードでのスキル起動文字列）が存在し、推奨頻度がそれぞれ日次 / 週次のデフォルト（保守的デフォルト）と変更方法つきで記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S69: [loops-time-recipes] ローカル実行必須の制約が明記されている
- WHEN: 両 cron レシピの前提の節を読む
- THEN: ローカルデータ（Obsidian Vault・`~/.claude/projects/` のセッション jsonl）を読むためローカル実行が必須である旨の制約が両ファイルに明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S70: [loops-time-recipes] スケジューラ登録が呼び出し側の責務と明記されている
- WHEN: 両 cron レシピの本文を読む
- THEN: スケジューラへの登録・セッション運用は呼び出し側の責務でありレシピのスコープ外であることが明記され、特定のスケジューラ（セッション内 cron / launchd / `claude -p` 配線等）への登録手順が含まれていない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S71: [loops-time-recipes] 既存レポートプラグインの本文が変更されていない
- WHEN: 本 change の実装後に `plugins/daily-report/` と `plugins/weekly-report/` の diff を確認する
- THEN: 両プラグイン配下のファイルに変更が 0 件である（レシピは登録・運用手順のみで既存スキル本文に触れない）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S72: [loops-time-recipes] 停止基準の無い time レシピが 0 件である
- WHEN: `plugins/loops/recipes/loop-*.md` と `plugins/loops/recipes/cron-*.md` の全ファイルについて停止基準の節を検査する
- THEN: 全ファイルに具体的な終了・解除条件（対象イベントの完了検知・最大継続期間・手動キャンセルの手順のいずれか複数）が記述されており、停止基準が空または欠落しているレシピは 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S73: [loops-time-recipes] コスト注意にトークン管理該当項目がある
- WHEN: 3 本の time レシピのコスト注意の節をそれぞれ読む
- THEN: 全ファイルに「実行頻度を必要最小限にする」観点の記述があり、決定論的作業のスクリプト化またはパイロット実行のうちそのレシピに該当する項目が明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S74: [loops-time-recipes] 独自ランタイム・モデル ID への参照が無い
- WHEN: `plugins/loops/recipes/` 配下の time レシピ 3 ファイルに対して独自スクリプト起動（例: `bash .*loop.*\.sh`）と `claude-` で始まるモデル ID を grep する
- THEN: いずれも 0 件であり、起動コマンドは全てネイティブプリミティブ（/loop・/schedule・skill 起動文字列）である
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

## change-4: proactive-routines

### S75: [loops-routine-backlog-triage] レシピファイルが固定見出しを全て持つ
- WHEN: `plugins/loops/recipes/routine-backlog-triage.md` に対して固定見出し 7 節（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を grep する
- THEN: 7 節すべてがヒットし、ループ型節にプロアクティブの記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S76: [loops-routine-backlog-triage] 起動コマンドがネイティブプリミティブのみである
- WHEN: レシピの起動コマンド節を検査する
- THEN: /schedule・/goal・/loop・skill 起動のいずれかで構成されたコピペ可能なコマンド文字列が存在し、独自スクリプトのパス・独自 CLI 名は現れない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S77: [loops-routine-backlog-triage] 停止基準が定量的に宣言されている
- WHEN: レシピの停止基準節を検査する
- THEN: 「選定したタスクが全て Draft PR または凍結記録に到達するまで」に相当する /goal 停止基準の記載があり、停止基準節が空でない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S78: [loops-routine-backlog-triage] Draft PR までの非破壊制約が明記されている
- WHEN: レシピ本文に対して非破壊制約の記載を grep する
- THEN: 「Draft PR まで」（外向きアクションの上限は Draft PR / issue コメントまで）に相当する上限の明記と、merge・close・force 系操作の禁止の列挙が見つかる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S79: [loops-routine-backlog-triage] マージは人間へエスカレーションされる
- WHEN: レシピのエスカレーション節を検査する
- THEN: マージ等の不可逆操作を人間の判断に委ねる旨が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S80: [loops-routine-backlog-triage] 処理数上限が数値で記載されている
- WHEN: レシピの discovery 手順（`openspec/backlog.md` と open issues からの着手可能タスク選定）を検査する
- THEN: 1 サイクルの処理数上限が具体的な数値（例: 最大 2 件）で記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S81: [loops-routine-backlog-triage] 繰り越し記録の手順がある
- WHEN: レシピの state 更新手順を検査する
- THEN: 処理しなかったタスクを繰り越しとして state（`loops/state/<name>.state.md`）に記録するステップが存在し、silent drop 禁止の旨が明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S82: [loops-routine-backlog-triage] state 更新が 3 区分をカバーする
- WHEN: レシピの state 更新手順を検査する
- THEN: 処理済み / 繰り越し / 引き継ぎ待ちの 3 区分すべてへの言及がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S83: [loops-routine-backlog-triage] 2 連続失敗の凍結条件が記載されている
- WHEN: レシピの停止基準節・エスカレーション節を検査する
- THEN: 同一タスク 2 連続失敗で凍結（当該サイクル以降の自動リトライ対象から除外）+ 人間へエスカレーションする旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S84: [loops-routine-backlog-triage] デモ実行ログが存在する
- WHEN: `{longrun-dir}` 配下を検査する
- THEN: backlog-triage の 1 サイクルデモ実行ログ（このリポジトリまたは安全なサンドボックスで実行）が存在し、Draft PR 作成（または安全なサンドボックスでの相当物）・state 更新・繰り越し記録の確認結果を含む
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S85: [loops-routine-backlog-triage] 規約検査はスキル起動に依存せず手動実行される
- WHEN: デモの evidence を検査する
- THEN: `/loops:design` の起動記録ではなく、references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S86: [loops-routine-long-build] レシピファイルが固定見出しを全て持つ
- WHEN: `plugins/loops/recipes/routine-long-build.md` に対して固定見出し 7 節を grep する
- THEN: 7 節すべてがヒットし、ループ型節にプロアクティブの記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S87: [loops-routine-long-build] 前提節が外部状態ファイルを宣言している
- WHEN: レシピの前提節を検査する
- THEN: feature-list.json（`{longrun-dir}/feature-list.json`）と claude-progress.md（progress notes）の 2 つの外部状態ファイルへの言及がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S88: [loops-routine-long-build] 起動コマンドがネイティブプリミティブのみである
- WHEN: レシピの起動コマンド節を検査する
- THEN: /schedule または手動再起動 + /goal によるコピペ可能なコマンド文字列が存在し、独自 driver スクリプト（常駐スクリプト・カスタム driver）への参照は現れない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S89: [loops-routine-long-build] 1 サイクル 1 項目が明記されている
- WHEN: レシピの 1 サイクル手順を検査する
- THEN: `passes:false` の先頭 1 項目のみを実装対象とする旨が明記され、複数項目の同時実装を認める記載がない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S90: [loops-routine-long-build] サイクルは smoke check から始まる
- WHEN: レシピの 1 サイクル手順の先頭ステップを検査する
- THEN: 直近 passing 項目の verification コマンド再実行（smoke check）が実装ステップより前に置かれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S91: [loops-routine-long-build] サイクルは commit と progress 追記で終わる
- WHEN: レシピの 1 サイクル手順の末尾を検査する
- THEN: 説明的 commit と claude-progress.md への追記が passes 更新の後に置かれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S92: [loops-routine-long-build] evidence 必須の passes 更新条件が記載されている
- WHEN: レシピの passes 更新手順を検査する
- THEN: 当該項目の verification コマンドを実行し exit 0 の evidence（実行ログ）がある場合のみ `passes:true` に更新できる旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S93: [loops-routine-long-build] 自己申告更新の禁止がルーチンプロンプトに含まれる
- WHEN: レシピの発火時プロンプト本文を検査する
- THEN: evidence なしで `passes:true` にしてはならない旨の指示が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S94: [loops-routine-long-build] 停止基準に凍結条件が含まれる
- WHEN: レシピの停止基準節を検査する
- THEN: 「全項目 passes:true」の定量ゴール（/goal による）と「同一項目 2 連続 FAIL で凍結 + 人間へエスカレーション」の両方が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S95: [loops-routine-long-build] 凍結項目は削除ではなく記録される
- WHEN: レシピの凍結手順を検査する
- THEN: 凍結項目を feature-list から削除せず、凍結の事実と理由を progress notes に記録する旨が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S96: [loops-routine-long-build] リファレンスが feature-list の形式を定義している
- WHEN: `plugins/loops/references/feature-list-format.md` を検査する
- THEN: `id` / `description` / `verification` / `passes` の 4 キーの説明、`passes:false` 初期値、項目・verification の削除禁止の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S97: [loops-routine-long-build] schema による強制が存在しない
- WHEN: `plugins/loops/` 配下で feature-list 用の JSON Schema ファイルを探索する
- THEN: feature-list を機械検証する schema ファイルは存在しない（形式は references の記載のみ）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S98: [loops-routine-long-build] 2 サイクル以上の完走デモログが存在する
- WHEN: `{longrun-dir}` 配下を検査する
- THEN: 3 項目以上の feature-list に対する 2 サイクル以上のデモ実行ログが存在し、各サイクルの smoke check・実装項目・verification exit code・passes 更新・progress 追記が確認できる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S99: [loops-routine-long-build] 故意の失敗で凍結とエスカレーションが機能する
- WHEN: デモ中に 1 項目を故意に 2 連続 FAIL させる
- THEN: 当該項目が凍結され（`passes:false` のまま削除されない）、人間へのエスカレーションが progress notes に記録されたことがログで確認できる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S100: [loops-routine-long-build] 規約検査はスキル起動に依存せず手動実行される
- WHEN: デモの evidence を検査する
- THEN: references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている（`/loops:design` の起動には依存しない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S101: [loops-routine-recipe-miner] レシピファイルが固定見出しを全て持つ
- WHEN: `plugins/loops/recipes/routine-recipe-miner.md` に対して固定見出し 7 節を grep する
- THEN: 7 節すべてがヒットし、ループ型節にプロアクティブ（メタループ）の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S102: [loops-routine-recipe-miner] 定期実行の配線はスコープ外である
- WHEN: レシピ本文を検査する
- THEN: 発火時プロンプト・推奨頻度（週 1 想定）・停止基準・実行環境の制約は記載されているが、スケジューラ登録手順（cron 設定・launchd・`claude -p` 配線）は記載されていない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S103: [loops-routine-recipe-miner] ローカル実行必須の制約が明記されている
- WHEN: レシピの前提節または実行環境の制約の記載を検査する
- THEN: セッション jsonl（`~/.claude/projects/`）を読むためローカル実行が必須である旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S104: [loops-routine-recipe-miner] 実行登録が呼び出し側の責務であることが明記されている
- WHEN: レシピ本文を検査する
- THEN: 定期実行への登録・実行方法の選択は呼び出し側の責務でスコープ外である旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S105: [loops-routine-recipe-miner] サブエージェント隔離が明記されている
- WHEN: レシピの discovery 手順を検査する
- THEN: 直近 7 日のセッション jsonl の解析をサブエージェントで実行し（daily-report の llm-log-compactor の jq パターンを流用した圧縮解析）、候補リストのみをメインに返す旨と、生ログをメインセッションのコンテキストに載せない旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S106: [loops-routine-recipe-miner] 4 種の抽出候補が定義されている
- WHEN: レシピの discovery 手順を検査する
- THEN: (a) 同型依頼の 3 回以上の反復 = ループ化候補、(b) 修正→テスト→修正の長い往復 = /goal 化候補、(c) 定時性のある依頼 = /schedule 化候補、(d) 既存レシピの実行痕跡 = 停止基準・頻度の実測チューニング候補、の 4 種の抽出基準が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S107: [loops-routine-recipe-miner] 提案上限 3 件が明記されている
- WHEN: レシピの生成手順を検査する
- THEN: 1 サイクルで提案するレシピ新規案 / 更新 diff は最大 3 件の提案上限が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S108: [loops-routine-recipe-miner] 検査を通らない提案は見送り記録される
- WHEN: レシピの生成手順を検査する
- THEN: 停止基準必須・Bad Loop 検査（停止基準の欠如 / 検証なき成功宣告 / 報酬ハッキング余地 / 過剰な実行頻度）を通らない提案は Draft PR に含めず、見送り理由を state に記録する旨が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S109: [loops-routine-recipe-miner] Draft PR 出力と自動 merge 禁止が明記されている
- WHEN: レシピの出力手順を検査する
- THEN: 提案をこの marketplace リポジトリへの Draft PR として出力する旨・自動 merge 禁止・採否は人間が判断する旨の記載がある（merge・close・force 系操作を実行する手順を含まない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S110: [loops-routine-recipe-miner] state 記録の 3 区分が定義されている
- WHEN: レシピの persistence 手順を検査する
- THEN: change-1 の State 規約に従い、提案済み / 見送り理由 / 繰り越し候補の 3 区分を state に記録する旨の記載がある（discovery で拾ったが処理しなかった候補の silent drop は不許可）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S111: [loops-routine-recipe-miner] 候補ゼロで正常終了する
- WHEN: レシピの手順を検査する
- THEN: 候補ゼロのサイクルは「提案なし」で正常終了する旨の記載がある
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S112: [loops-routine-recipe-miner] 手動 1 サイクルデモのログが存在する
- WHEN: `{longrun-dir}` 配下を検査する
- THEN: 直近の実セッションログに対する手動 1 サイクルデモの実行ログが存在し、提案 Draft PR（または「提案なし」の正常終了）と state 更新・繰り越し記録が確認できる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S113: [loops-routine-recipe-miner] デモで定期実行への登録を行わない
- WHEN: デモの evidence を検査する
- THEN: スケジューラ登録・cron 設定の実行記録が含まれていない（手動起動のみ）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S114: [loops-routine-recipe-miner] 規約検査はスキル起動に依存せず手動実行される
- WHEN: デモの evidence を検査する
- THEN: `/loops:design` の起動に依存せず、references の検査手順（停止基準必須・Bad Loop 検査）を手動実行した結果（各検査項目の PASS/FAIL）が記録されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-5: loops-integration

### S115: [loops-cost-guardrails] 6 項目が数えられる形式で存在する
- WHEN: ユーザーが `plugins/loops/references/cost-guardrails.md` のトークン管理セクションの項目（見出しまたは番号付きリスト）を数える
- THEN: ちょうど 6 項目が列挙されている（`research/loop-engineering.md` 冒頭の公式記事セクションを一次ソースとする公式トークン管理ベストプラクティス 6 項目）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S116: [loops-cost-guardrails] 主要 3 項目の文言が確認できる
- WHEN: ユーザーが `cost-guardrails.md` に対して「頻度」「スクリプト化」「パイロット」をそれぞれ grep する
- THEN: 3 語すべてが 6 項目の記述内でヒットする（「ルーチン実行頻度を必要最小限にする」「決定論的作業はスクリプト化する」「大規模実行前にパイロット実行する」）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S117: [loops-cost-guardrails] 定量事実が記載されている
- WHEN: ユーザーが `cost-guardrails.md` に対して「4倍」（または「約 4 倍」）と「15倍」（または「約 15 倍」）を grep する
- THEN: 両方の倍率がループ / マルチエージェントのトークン消費に関する文脈でヒットする（「ループはチャットの約 4 倍のトークンを消費する」「マルチエージェント構成は約 15 倍のトークンを消費する」）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S118: [loops-cost-guardrails] レビュー手順に 2 コマンドが含まれる
- WHEN: ユーザーが `cost-guardrails.md` に対して `/usage` と `/workflows` をそれぞれ grep する
- THEN: 両コマンドがコストレビュー手順の記述内でヒットする（手順は「いつ確認するか（例: 新レシピのパイロット実行後・定常運用の定期見直し時）」を含む）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S119: [loops-cost-guardrails] モデル ID のハードコードが無い
- WHEN: ユーザーが `cost-guardrails.md` に対して `claude-` で始まるモデル ID 文字列を grep する
- THEN: ヒットは 0 件である（モデルティアへの言及は `plugins/longrun/references/model-tiers.md` への参照で行う）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S120: [loops-integration-verification] 統合テストが存在し全 PASS する
- WHEN: ユーザーが `bats plugins/loops/tests/integration.bats` を実行する
- THEN: 全テストケースが PASS し exit 0 で終了する（統合テストは grep / jq / find のみで構成され、(a) marketplace.json ↔ 各 plugin.json の version 完全一致、(b) 全レシピの固定見出し規約、(c) plugins/loops/ に独自ランタイムが存在しないこと、(d) README の loops セクションの存在、を検証する）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S121: [loops-integration-verification] リポジトリ全体の bats スイートが PASS する
- WHEN: ユーザーが `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行する
- THEN: 全テストが PASS し exit 0 で終了する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S122: [loops-integration-verification] 固定見出しの横断 grep 検証が PASS する
- WHEN: ユーザーが `plugins/loops/recipes/*.md` の各ファイルに対して 7 つの固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の存在を grep で確認するループを実行する
- THEN: 全レシピで 7 見出しすべてがヒットし、欠落は 0 件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S123: [loops-integration-verification] 停止基準の無いレシピが存在しない
- WHEN: ユーザーが `grep -L '停止基準' plugins/loops/recipes/*.md` を実行する
- THEN: 出力は空である（停止基準見出しを持たないレシピが 0 件）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S124: [loops-integration-verification] 常駐スクリプト・driver が存在しない
- WHEN: ユーザーが `plugins/loops/` 配下のスクリプトファイルを `find` で列挙し、反復実行・スケジューリングの自前実装（例: `while true`・sleep ループによる常駐処理）を grep で検査する
- THEN: 該当するスクリプトは 0 件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S125: [loops-integration-verification] 起動コマンドが全てネイティブプリミティブである
- WHEN: ユーザーが全レシピの「起動コマンド」節からコマンド行を抽出する
- THEN: すべての行が `/goal`・`/loop`・`/schedule` またはスラッシュコマンド（skill）起動のいずれかで始まり、独自 CLI やラッパースクリプトの呼び出しが 0 件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S126: [loops-integration-verification] エビデンスログが残っている
- WHEN: ユーザーが `{longrun-dir}` 配下の統合検証ログを開く
- THEN: 全 bats 実行の出力（PASS 件数と exit 0）および version 一致・レシピ規約・ランタイム不在の各検証コマンドの実行結果が確認できる（「完了は主張であり証明ではない」原則に従い、エビデンスなしに受け入れ条件を PASS と報告しない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S127: [loops-marketplace-sync] loops エントリが存在する
- WHEN: ユーザーが `jq '.plugins[] | select(.name == "loops")' .claude-plugin/marketplace.json` を実行する
- THEN: `source` が `./plugins/loops` であるエントリが 1 件返り、`description` と `version` が非空である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S128: [loops-marketplace-sync] loops の version が plugin.json と一致する
- WHEN: ユーザーが `jq -r '.plugins[] | select(.name == "loops") | .version' .claude-plugin/marketplace.json` と `jq -r '.version' plugins/loops/.claude-plugin/plugin.json` の出力を比較する
- THEN: 両者は文字列として完全一致する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S129: [loops-marketplace-sync] インストールコマンドで新プラグインが見える
- WHEN: マージ後の新セッションでユーザーが `/plugin install loops@oratta-claude-harness` → `/reload-plugins` を実行する
- THEN: `/loops:design`・`/loops:goalify` がスラッシュコマンド一覧に現れる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S130: [loops-marketplace-sync] 全プラグインで plugin.json と marketplace.json の version が一致する
- WHEN: ユーザーが marketplace.json の `plugins[]` 全エントリについて、`jq -r .version plugins/<name>/.claude-plugin/plugin.json` と marketplace.json 側の `version` を突き合わせるループを実行する
- THEN: 全エントリで両者が完全一致し、不一致は 0 件である
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S131: [loops-marketplace-sync] 編集済みプラグインの version が bump されている
- WHEN: ユーザーが `git diff origin/main --name-only` で変更されたプラグインを特定し、各プラグインの plugin.json の `version` を `git show origin/main:plugins/<name>/.claude-plugin/plugin.json` の `version` と比較する
- THEN: 変更された全プラグインで version が main 時点より上がっている（変更していないプラグインの version は bump しない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S132: [loops-marketplace-sync] top-level version が上がっている
- WHEN: ユーザーが `jq -r .version .claude-plugin/marketplace.json` の出力を `git show origin/main:.claude-plugin/marketplace.json | jq -r .version` と比較する
- THEN: top-level version が main 時点より上がっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S133: [loops-marketplace-sync] 全 JSON ファイルが parse できる
- WHEN: ユーザーが `jq . .claude-plugin/marketplace.json` と、全プラグインの `jq . plugins/*/.claude-plugin/plugin.json` を実行する
- THEN: 全ファイルが exit 0 で parse に成功する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S134: [loops-readme-positioning] 4 ループタイプの名称が README に現れる
- WHEN: ユーザーが `README.md` に対して「ターンベース」「ゴールベース」「タイムベース」「プロアクティブ」の 4 語をそれぞれ grep する
- THEN: 4 語すべてが loops プラグインのセクション内でヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S135: [loops-readme-positioning] 公式記事リンクが記載されている
- WHEN: ユーザーが `README.md` に対して `https://claude.com/blog/getting-started-with-loops` を grep する
- THEN: 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S136: [loops-readme-positioning] インストールコマンドが記載されている
- WHEN: ユーザーが `README.md` に対して `/plugin install loops@oratta-claude-harness` を grep する
- THEN: 1 件以上ヒットする
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S137: [loops-readme-positioning] 詳細への導線がある
- WHEN: ユーザーが README の loops セクションを読む
- THEN: `plugins/loops/` への参照（パスまたはリンク）が記載されている（README は要約に留め、詳細は `plugins/loops/` および調査資料の `research/` に委ねる。ハーネスの責務は「ネイティブプリミティブの合成レシピ」であり独自ランタイムではない旨を 1 文で示し、定期実行のスケジューラ登録手順は README に書かない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S138: [loops-readme-positioning] レシピ本文が README に複製されていない
- WHEN: ユーザーが `README.md` に対してレシピ固定見出し（「## 停止基準」「## エスカレーション」等のレシピ規約見出し）を grep する
- THEN: ヒットは 0 件である（README にはレシピの固定見出し構造が現れない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
