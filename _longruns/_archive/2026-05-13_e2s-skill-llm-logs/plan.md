# Plan: experience-to-skill リファクタリング（jsonl 起点・スキル化専門への純化）

## 生成情報
- 作成日: 2026-05-13
- Brain Dump元: セッション内対話（worktree e2s-skill-llm-logs-2）
- 質問回数: 6問

## ゴール

experience-to-skill プラグインを「Claude Code セッションの jsonl ログを素材に、自然言語の指示で SKILL.md を生成する」専門ツールに作り直す。既存の auto-commit / verified タグ / 巻き戻し / 状態診断機構は全廃止し、コミット運用には一切関与しないシンプルな skill 1 個 + slash command 1 個の構成にする。

## ビジネスコンテキスト

- **対象ユーザー**: 自分（plugin 作者）。Claude Code で日々大量の試行錯誤を行い、後から「あの作業をスキル化したかった」と気づくケースが頻発する人
- **提供価値**: コミット駆動・verified タグ駆動という「事前準備が必要な抽出フロー」を捨て、jsonl 自体が網羅的な作業記録である事実を活用して「後付け・自然言語起動」でスキル化できる体験を提供する
- **成功指標**: 
  - 旧 e2s は 1 度も実用されなかった事実に対して、新 e2s は「動画作成後の振り返り」のような実シナリオで少なくとも 1 件の SKILL.md を生成できる
  - 旧 e2s が常駐していた「コミットごとの skill 起動」によるコンテキスト消費が消える

## 技術要件

- **スタック**: 
  - Skill / Slash Command（Markdown + frontmatter）
  - 補助ロジックは Bash（jsonl ファイル一覧取得・キーワード grep・ファイル削除など）
  - jsonl の parse は `jq` または `python3 -c "import json; ..."` を必要に応じて利用
- **参照パターン**: 
  - 既存 e2s-reflect / e2s-distill の sanitize ルール（PII / secret 除外）はロジックとして再利用
  - 既存 `~/.claude/skills/distilled/<name>/SKILL.md` の配置パターン
  - `~/.claude/projects/<cwd-encoded>/` 配下の jsonl パス規約
- **制約**: 
  - 既存 e2s プラグインのファイルは全て削除して新規構築する（コードの「上書き」ではなく削除→新規作成）
  - skill のロジックは Claude 自身が jsonl を読んで判断するため、決定論的なシェル関数で書けない部分が多い
  - PII / secret サニタイズを Layer 1/2 で実施（既存 e2s-reflect の方針を流用）
- **テストフレームワーク**: Bats (Bash Automated Testing System)
  - shell 補助関数（jsonl 列挙、キーワード grep、ファイルパス絞り込み）のユニットテスト
  - Claude 判断部分は手動 E2E 検証として動作確認方法に明記
- **テスト実行コマンド**: `bats plugins/experience-to-skill/tests/*.bats`

## スコープ

### 含むもの

- 既存 experience-to-skill プラグインの全コマンド・skill 削除
  - `experience-to-skill` skill（auto-commit）
  - `/e2s:commit` `/e2s:status` `/e2s:ok` `/e2s:rewind` `/e2s:reflect` `/e2s:distill`
- 新しい単一エントリーコマンド `/e2s:distill` の実装（対話完結型）
- 新しい `experience-to-skill` skill の実装（auto-trigger は「スキル化依頼」の自然言語パターンに対してのみ反応）
- jsonl 探索ロジック（cwd → `~/.claude/projects/<encoded-path>/` への解決、ファイル一覧、日付絞り込み、キーワード grep）
- PII / secret サニタイズ（既存 e2s の Layer 1/2 ロジックを流用）
- 出力配置先選択フロー（プロジェクトローカル / ユーザーグローバル）
- グローバルルール `~/.claude/rules/git-commit-policy.md` の見直し（auto-commit 許可記述の撤回）
- README / marketplace.json / plugin.json の更新
- Bats による補助スクリプトのユニットテスト
- バージョン bump

### 含まないもの

- 旧コードのアーカイブ保持（理由: コードを残さず削除する。git 履歴から復元可能で十分）
- 他プラグイン（cooking 等）からの自然言語呼び出し統合（理由: スコープ拡大を避け、まず e2s 単独で完結）
- jsonl の長期保存ポリシー / インデックス DB 構築（理由: 都度スキャンで十分軽量。最適化は実利用してから）
- 「スキル化以外の派生機能」（過去作業の振り返り、retrospective 生成等）（理由: 純化路線。別プラグインに委ねる）
- claude-mem MCP との連携（理由: 別関心事。将来別 longrun で検討）

## Changes 分解

### change-A: e2s リファクタ（既存削除＋新設計実装）

- **スコープ**: 
  - 既存 `plugins/experience-to-skill/` 配下を全削除（commit/status/ok/rewind/reflect/distill コマンド + experience-to-skill skill）。**削除前に下記 config.yaml rules で指定するサニタイズロジックのコピーを完了させること**
  - 新 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` を実装（auto-trigger は「スキル化依頼」のみ）
  - 新 `plugins/experience-to-skill/commands/e2s-distill.md` を実装（対話完結型）
  - jsonl 探索の補助スクリプト `plugins/experience-to-skill/scripts/jsonl-finder.sh` 作成（cwd→encoded-path 正規化関数を含む）
  - PII / secret サニタイズロジック `plugins/experience-to-skill/scripts/sanitize.sh`（Layer 1 正規表現）+ skill 内 Layer 2 プロンプト
  - Bats テスト `plugins/experience-to-skill/tests/jsonl-finder.bats`, `plugins/experience-to-skill/tests/sanitize.bats` 作成
  - テスト fixture `plugins/experience-to-skill/tests/fixtures/sample-session.jsonl` を 1 件作成（事前にサニタイズ済みのもの）
  - `plugins/experience-to-skill/.claude-plugin/plugin.json` の skills/commands 配列を新構成に更新 + version bump
  - `plugins/experience-to-skill/README.md` を新設計で全面書き直し
  - `.claude-plugin/marketplace.json` の experience-to-skill エントリ version 同期
  - 他プラグイン・スキル・docs から `/e2s:commit` `/e2s:ok` 等の旧コマンド参照を grep して削除 or 言い換え
- **使用スキル**: なし（純粋に Markdown + Bash 実装）
- **依存関係**: 独立
- **config.yaml rules**:
  - "**サニタイズロジックのスナップショット先行**: 既存 e2s-reflect.md (Step 5 sanitize 絶対ルール) と experience-to-skill SKILL.md (Step 3-5 の Layer 1 正規表現セット + Layer 2 意味判定方針) の内容を、削除実行前に新ファイル（`plugins/experience-to-skill/scripts/sanitize.sh` および新 skill 内）にコピーし、コピー完了を確認してから旧ファイル削除に進むこと（流用元の喪失を防ぐ）"
  - "**jsonl ディレクトリ名エンコーディングの検証**: `jsonl-finder.sh` の cwd→encoded-path 正規化関数は、`~/.claude/projects/` 内の実エントリ 3 件以上で出力を検証すること。さらに規約未知の文字に備えて逆引きフォールバック（cwd の prefix が一致するエントリを優先順位付きで返す）を併設すること（実例: `/Users/oratta/.claude-mem` → `-Users-oratta--claude-mem` のように `.` も `-` に変換され連続ハイフン化する）"
  - "**jsonl スキャン順序**: `jsonl-finder.sh` は (1) ディレクトリ存在確認 → (2) mtime による日付範囲フィルタ → (3) ファイルサイズ上限フィルタ（デフォルト 50MB） → (4) キーワード grep の順で適用し、初期スキャン対象を絞ること（パフォーマンス防衛策）"
  - "**ファイル削除と参照修正の同時実行**: 旧 e2s ファイルは削除前にリポジトリ内の参照を全列挙し、参照元も同時に修正すること（マルチプラットフォーム参照漏れ防止）"
  - "**auto-trigger 限定**: 新 skill の auto-trigger description は『スキル化依頼』のフレーズに限定し、コミット完了等では起動しないこと（コンテキスト消費抑制）"
  - "**PII / secret サニタイズの二重実装**: Layer 1（正規表現）+ Layer 2（LLM 意味判定）の二重で実装すること（jsonl 原文は credentials を含み得る）"

### change-B: グローバルルール / 周辺ドキュメント更新

- **スコープ**:
  - **実行タイミング**: change-A の worktree が main にマージされた後に実施する。マージ前は実施しない（worktree 外のユーザーグローバルファイル `~/.claude/rules/git-commit-policy.md` を先に書き換えると、本番セッションで `/e2s:commit` が無効化される前にルールだけ消える不整合期間が発生するため）
  - `~/.claude/rules/git-commit-policy.md` を読み、e2s 廃止に整合する形で書き換え:
    - 「auto-commit 許可」の節を削除
    - 通常の「明示承認なしのコミット禁止」運用に戻す
  - 既存 openspec change `experience-to-skill-plugin` の取り扱い（superseded 扱いにする / archive する）
  - backlog.md に他関連項目があれば確認・整理
- **使用スキル**: なし
- **依存関係**: change-A の main マージ完了後（実装が main に統合されてからドキュメントを整合させる）
- **config.yaml rules**:
  - "**グローバルルール書き換えの記録**: `~/.claude/rules/git-commit-policy.md` を編集する際は、書き換え前の内容と変更日時 + change-A のマージコミット SHA を decisions.md に記録すること（ユーザー環境への影響が大きいため痕跡を残し、ロールバック可能にする）"

## 画面・UI設計

UI は Claude Code の terminal 対話。具体的な対話フロー（`/e2s:distill` 起動時）:

```
ユーザー: /e2s:distill 先週どこかで動画の生成を行ったと思う。
          最終的に成功したプロセスをスキルにしてほしい

LLM (e2s-distill):
  → 現在 cwd: /Users/oratta/foo/bar
  → jsonl ディレクトリ: ~/.claude/projects/-Users-oratta-foo-bar/
  → 期間ヒント「先週」: 2026-05-04 〜 2026-05-10 で絞り込み
  → キーワードヒント「動画」「生成」で grep
  
  該当 jsonl 候補:
  1) 2026-05-06 14:23 (3.2MB) — turn 47 で「動画」初出、turn 89 で「ffmpeg 成功」
  2) 2026-05-08 09:15 (1.8MB) — turn 12 で「動画」初出、turn 33 で「クライアント納品」
  
  どちらの作業ですか？（または両方の通し作業ですか？）

ユーザー: 1 番

LLM:
  → jsonl 1 番の turn 30-95 を読み込み（成功ターン 89 を含む前後）
  → 分析:
    - 失敗試行: turn 47-62（解像度設定で失敗）
    - 成功手順: turn 65-89（プリセット A 適用→ffmpeg コマンド X→検証）
  
  抽出した成功手順をスキル化します:
  
  - スキル名候補: `video-generation-ffmpeg` （e2s-prefix 付与）
  - 配置先候補:
    1) プロジェクトローカル: <repo>/.claude/skills/distilled/video-generation-ffmpeg/SKILL.md
    2) ユーザーグローバル: ~/.claude/skills/distilled/video-generation-ffmpeg/SKILL.md
  
  どちらに配置しますか？

ユーザー: 2

LLM:
  → サニタイズ実施: PII / API key / 個人名 を抽象化
  → SKILL.md 生成完了
  → 場所: ~/.claude/skills/distilled/video-generation-ffmpeg/SKILL.md
```

## データモデル

ファイルベースのみ、永続化 DB なし。

| 種類 | パス | 用途 |
|---|---|---|
| Skill 本体 | `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` | スキル化依頼の自然言語トリガー、対話統括 |
| Slash Command | `plugins/experience-to-skill/commands/e2s-distill.md` | 明示起動エントリーポイント |
| jsonl ソース | `~/.claude/projects/<cwd-encoded>/*.jsonl` | Claude Code 本体が書き出す。読み取り専用 |
| 補助スクリプト | `plugins/experience-to-skill/scripts/jsonl-finder.sh` | jsonl 列挙・grep の Bash 関数群 |
| Bats テスト | `plugins/experience-to-skill/tests/jsonl-finder.bats` | 補助スクリプトのユニットテスト |
| 出力 SKILL.md | `<repo>/.claude/skills/distilled/<name>/SKILL.md` か `~/.claude/skills/distilled/<name>/SKILL.md` | 生成物 |

cwd → jsonl ディレクトリのマッピング:

`~/.claude/projects/` 配下のディレクトリ名は cwd の絶対パスに対して以下の変換を施したもの:

- `/` → `-`
- `.` → `-`（連続ハイフンも保持）
- その他の文字（`_` 等）の扱いは Claude Code 本体の実装に依存するため、**実装時に `~/.claude/projects/` 配下の実エントリ 3 件以上で正規化関数の出力を検証する**

実例:
- `/Users/oratta/foo/bar` → `-Users-oratta-foo-bar`
- `/Users/oratta/.claude-mem` → `-Users-oratta--claude-mem`（`.claude-mem` のドットが `-` になり連続ハイフン化）
- `/Users/oratta/.superset/worktrees/ef0031fc.../e2s-skill-llm-logs-2` → `-Users-oratta--superset-worktrees-ef0031fc---e2s-skill-llm-logs-2`

規約未知の文字に備えて、`jsonl-finder.sh` は cwd の prefix が一致するエントリを優先順位付きで返す逆引きフォールバックを併設する。

## 受け入れ条件

**必須条件（常に含める）:**

1. [ ] 全 change の OpenSpec 仕様が作成・レビュー済み
2. [ ] 全 change のテストが作成され、全て PASS している（Bats）
3. [ ] ビルドエラーなし（Markdown lint / plugin.json schema 検証 / marketplace.json 整合性）
4. [ ] 統合テストが PASS（worktree マージ後、プラグインが正しくロードされ `/e2s:distill` が起動できる）

**機能固有の条件:**

5. [ ] 旧 e2s のファイル（commit/status/ok/rewind/reflect/distill コマンドおよび旧 experience-to-skill skill）が 1 つも残っていない（`find plugins/experience-to-skill -name "e2s-*.md"` の結果が新コマンド `e2s-distill.md` のみ）
6. [ ] 他プラグイン / docs / rules から旧コマンド名への参照がリポジトリ内に残っていない。以下の 3 サブ条件を全て満たす:
   - (a) `grep -rE '/e2s:(commit|ok|rewind|status|reflect)\b' .` でヒットが 0 件
   - (b) `find . -name 'e2s-commit.md' -o -name 'e2s-ok.md' -o -name 'e2s-rewind.md' -o -name 'e2s-status.md' -o -name 'e2s-reflect.md'` でヒットが 0 件
   - (c) `plugins/experience-to-skill/.claude-plugin/plugin.json` の commands 配列に `e2s-distill` のみが含まれている
   - 意図的な歴史的記述（CHANGELOG, decisions.md, openspec/changes/archive/ 等）に旧名を残す場合は、change-A の実装時に「許可リスト」として decisions.md に明示すること
7. [ ] 新 skill の auto-trigger description が「スキル化依頼」フレーズ（例: 「スキル化して」「スキルにして」「過去の作業からスキルを作って」）のみで反応し、コミット完了フレーズでは反応しないことが description の文言で明確に表現されている
8. [ ] `/e2s:distill` を引数なしで起動すると、cwd に対応する jsonl ディレクトリの存在確認と、利用可能な jsonl 一覧（日付・サイズ）が表示される（手動 E2E 確認）
9. [ ] `/e2s:distill <自然言語指示>` を起動すると、対話的に jsonl 候補を絞り込み、SKILL.md を生成できる（手動 E2E 確認）。テスト用 fixture jsonl `plugins/experience-to-skill/tests/fixtures/sample-session.jsonl` を 1 件コミットし、手動 E2E はこの fixture に対して再現可能な形で実施すること（fixture は事前にサニタイズ済みで PII / secret を含まない）
10. [ ] PII / secret サニタイズが 2 層実装されている（Layer 1: 正規表現除外、Layer 2: LLM 意味判定）
11. [ ] 生成された SKILL.md の frontmatter `name:` に `e2s-` または `distilled-` prefix が付与されている
12. [ ] `~/.claude/rules/git-commit-policy.md` の auto-commit 許可記述が削除され、通常運用（明示承認必須）に戻されている
13. [ ] 既存 openspec change `experience-to-skill-plugin` が superseded 扱いまたは archive 済みになっている

## 意思決定ガイドライン

- **優先順位**: シンプルさ > 機能網羅性 > パフォーマンス
  - 「使われない多機能」より「使われる単機能」を優先（旧 e2s が使われなかった反省を踏まえる）
- **リスク許容度**: 中程度
  - 既存コード全削除は BREAKING だが、利用実績ゼロなので影響範囲は実質ゼロ
  - グローバルルール変更はユーザー環境に影響するが decisions.md に書き換え前の内容を残せばロールバック可能
- **不明点の扱い**: シンプルな方を選ぶ
  - 対話フローの詳細（質問回数、表示形式）は実装中の longrun-builder 判断に委ねる
  - SKILL.md のテンプレート微調整は既存 e2s-distill のフォーマットを基本踏襲

## 動作確認方法

- **開発サーバー**: なし（CLI plugin のため）
- **テスト**: `bats plugins/experience-to-skill/tests/*.bats`
- **lint / 検証**:
  - `npx -y markdownlint-cli2 plugins/experience-to-skill/**/*.md` （任意。なくても OK）
  - plugin.json は手 schema 検証（必須 field の存在チェック）
- **確認手順**:
  1. worktree マージ後、ローカルで `/plugin uninstall experience-to-skill@oratta-claude-harness` → `/reload-plugins` → `/plugin install experience-to-skill@oratta-claude-harness` を実行
  2. `/e2s:distill --help`（または引数なし起動）で help テキストが表示されることを確認
  3. cwd を任意のプロジェクトに変えて `/e2s:distill 過去の何らかの作業をスキル化して` を実行
  4. 対話で jsonl 候補が提示され、選択→ SKILL.md 生成まで通ることを確認
  5. 生成された SKILL.md を開き、frontmatter / 内容 / サニタイズが妥当であることを目視確認
  6. 旧コマンド `/e2s:ok` `/e2s:commit` 等が存在しなくなっていることを `/help` 系で確認
  7. `~/.claude/rules/git-commit-policy.md` を開き、auto-commit 許可記述が消えていることを確認

## Brain Dumpからの原文メモ

> e2sスキルの存在意義を見失ってきた。スキル化でいうとLLMディレクトリの生ログを見た方が情報が網羅的で、LLM生ログやコミット履歴を元にスキルを作るって方向にした方が良い気がしたけどどうだろう？

> 結局このe2s全然使ってないですと。使ってない理由として、Verified Tagを仕込んでないとか、そういうイメージなのね。スキルにしようと思ったときに、LLMディレクトリにすべてのログが入っているから、ここをスキルにしたいなと思ったときに、こういう作業をしたんだけどスキル化してって依頼するときに、verifyタグの区間をスキル化してじゃなくて、後で自然言語的に思いついたことを、このシーン これスキルにしたかったなみたいな子供に対して、LLMディレクトリがあれば十分なんじゃないかなと思ったの。

> 大して機能ないのにコミットの度に呼び出されるこのスキルっていうのがコンテキストを食うから、一回コミットに紐付けたスキル作成「Experiments to Skills」っていうのはもう一回なくしたっていいかなと思っている。例えば、何か1個動画を作ったとして、LLM、Claude Codeの中で作業して1個、動画をクロービングして作ったとして、作る過程にもいろいろプロパティを変えたり、素材を変えたりと、いろいろするわけじゃん。で、終わって作った動画はクライアントに渡して、その後に思うんだよ。今のやりとりを、ここで苦労したものをスキルにしとけばよかったなと思うわけじゃん。そこで、こっちでExperiments to SKILLを使って聞いてください。先週どこかで動画の生成を行ったと思いますが、その最終的に成功したプロセスをスキルにしてほしいです。みたいなことを依頼したら、実行しているディレクトリのLLMディレクトリの中から作業して、LLMとやり取りした履歴をチェックして何かを導き出すみたいなイメージです。
