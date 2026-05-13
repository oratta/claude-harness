## Context

Claude Code でのプロジェクト開発では、ユーザーとLLMのやり取り（会話履歴 + tool call 履歴 + 編集差分）が膨大に蓄積されるが、それを再利用可能な知識資産に変換する仕組みは未整備である。既存エコシステムに3系統の先行実装がある：

1. **Aider**: 変更ごとに auto-commit、weak model でメッセージ生成、ただし skill 抽出は未実装
2. **claude-mem**: Stop hook でセッション記録、semantic search、ただしコミットとは独立
3. **affaan-m/everything-claude-code の `/skill-create`**: git log からパターン検出で SKILL.md 自動生成、ただしセッション詳細は使わない

本プラグインは **「都度コミット（素材蓄積）＋ verified タグ（区間定義）＋ commit/jsonl 突き合わせ（skill抽出）」** という3段の統合を新規性として提供する。事前のユーザー議論で以下の前提が確定している：

- マルチセッション並行実行時、Stop hook 方式では他セッションの変更を巻き込む race condition が回避不能
- LLM駆動コミット方式なら、セッション context から自編集ファイルを判定できるため衝突しない
- コミットメッセージは Conventional Commits（imperative subject）を維持しつつ、body で Intent/Result/Prompted-by を構造化するハイブリッドが業界収束点
- プロンプト本文を trailer に埋め込むと secret 混入リスクがあるため、session-id + turn 番号のポインタのみにする
- ユーザーのグローバルルール `~/.claude/rules/git-commit-policy.md` の「明示承認なしコミット禁止」方針は本プラグインで撤廃する（push は引き続き承認必須）

## Goals / Non-Goals

**Goals:**

- 作業完了単位で LLM が自動的にコミットを実行し、Intent/Result を含む高品質なメッセージを残す
- マルチセッション並行時も各セッションが自分の成果のみをコミットし、衝突しない
- ユーザーが動作確認した点に `verified/` タグを付与し、安全な巻き戻し先を確立する
- verified タグ区間のコミット群と session jsonl を突き合わせて skill 候補を抽出し、SKILL.md として蒸留する
- secret / credentials / PII のコミット混入を防ぐ二重チェック（正規表現 + LLM判断）を提供する
- 本家 `skill-creator` プラグインと機能・ネーミング両面で住み分けする（`skill-creator` は新規スキル作成、本プラグインは体験からの蒸留）

**Non-Goals:**

- 自動 push / 自動マージ（push は常にユーザーの明示承認が必要）
- リモートリポジトリへのセッションログ共有（jsonl はローカル限定、チーム共有は将来課題）
- Stop hook による機械的コミット（race condition 回避不能のため採用しない）
- 外部状態ファイルによる編集ファイル追跡（LLM 自身の context から判定するため不要）
- 全コミットの LLM 品質評価・リファクタリング機能
- 既存コミット履歴への遡及的 Intent/Result 付与
- weak model（Haiku）呼び出しによるコスト最適化（セッション内の既存 LLM を使うため別 API コール不要）

## Decisions

### D1: Stop hook ではなく auto-trigger スキルで LLM駆動コミットを実装

**選択肢:**
- (A) Stop hook による shell script コミット
- (B) auto-trigger スキル（LLM駆動）

**選択: (B) auto-trigger スキル**

**根拠:**
- Stop hook は原理的にマルチセッション race condition を解決できない（どのファイルが自セッションの成果か知らない）
- LLM駆動なら自セッション context から編集ファイルを特定可能、衝突ゼロ
- コミットメッセージ品質が高い（Intent/Result を文脈から導出できる）
- 意味単位での分割が将来可能（初期はやらないが、拡張余地がある）
- 実装がシンプル（スキル1枚、外部状態不要）
- 信頼性の差は auto-trigger description の工夫、archive トリガー必須化、`/e2s:commit` 手動コマンドで埋められる

**却下理由 (A):**
- race condition が設計的に解決不能
- コミットメッセージ品質が低い（文脈を知らない shell script で生成するしかない）
- 並行セッションで互いを上書きし合う事故が発生しうる

### D2: 自編集ファイルの追跡は LLM context のみで行い、外部状態ファイルを持たない

**選択肢:**
- (A) `memory/e2s/sessions/<id>/edited-files.txt` に各 Edit/Write 後に追記
- (B) `.git/e2s/sessions/<id>/` に git ref として記録
- (C) 外部追跡なし、LLM の session context から都度判定

**選択: (C) 外部追跡なし**

**根拠:**
- セッション context は LLM 自身の tool call 履歴を含む（Edit/Write/MultiEdit/Bash）
- マルチセッションでは context が分離されているため、自然に「自分の成果」が特定できる
- 外部ファイル方式は context との二重管理になり、劣化コピーを作るだけ
- context 圧縮時の挙動: 要約は残るので「どのファイルを編集したか」レベルの情報は失われない。判断に迷うファイルは `git diff` を見て LLM が内容から判定、またはユーザーに確認
- 実装が極限までシンプル（状態管理ゼロ）

**却下理由 (A)(B):**
- 同じ情報を context と外部ファイルで二重管理
- マルチセッション・セッション再開時の初期化ロジックが必要になる
- 追加の失敗モード（ファイル破損、書き込み権限）を導入

### D3: コミットメッセージは Conventional Commits + 構造化 body のハイブリッド

**選択肢:**
- (A) 従来の Conventional Commits のみ
- (B) LLM時代向けに新フォーマット発明
- (C) Subject に Conventional Commits（imperative）、body に Intent/Result/Prompted-by

**選択: (C) ハイブリッド**

**根拠:**
- 業界収束点（Anthropic公式、Aider、ICSE 2025 研究）と整合
- 従来ツール（GitHub UI、changelog generator 等）との互換性を損なわない
- Body の構造化情報は `/e2s:reflect` 時の機械パースで skill 抽出の素材として機能
- Subject は人間向け、body は LLM/skill-distill 向けという役割分離が明確

**フォーマット:**
```
<type>(<scope>): <imperative subject 50字以内>

Intent: <ユーザーが達成したかったこと 1-2行>
Result: <何が起きたか・どう解決したか 1-3行>
Prompted-by: <session-id>#turn-<N>

🤖 via experience-to-skill
```

### D4: Prompted-by はポインタのみ、プロンプト本文を埋め込まない

**選択肢:**
- (A) 完全なプロンプト本文を trailer に埋め込む
- (B) プロンプトを sanitize して短縮要約を埋め込む
- (C) session-id + turn 番号のみのポインタ

**選択: (C) ポインタのみ**

**根拠:**
- secret/API key/PII がプロンプトに混入している可能性を根絶できない（正規表現は取りこぼす）
- session jsonl はローカル限定なので、ポインタ経由で必要時に参照可能
- コミットサイズが肥大化しない
- チーム共有時は Prompted-by が解決不能になるが、個人ループでは機能する（割り切り）

**却下理由 (A)(B):**
- secret 流出リスクが完全には排除できない
- LLM による sanitize は信頼できない（保守的に振る舞う保証がない）
- Anthropic 公式も「プロンプト本文を commit に積むのは非推奨」

### D5: verified タグ戦略とタグ命名規則

**タグフォーマット: `verified/<YYYYMMDD-HHMMSS>-<短いラベル>`**

- lightweight tag（annotated ではなく）
- 時系列ソート可能
- ラベルは LLM が commit 群から生成、ユーザーが修正可

**auto-trigger 条件:**
- `longrun:archive` / `openspec:archive` の完了時（確実な終端イベント）
- ユーザーからの完了示唆フレーズ受信後、LLM側から `/e2s:ok` 実行を提案
- ユーザーが明示的に `/e2s:ok` 実行

**`/e2s:rewind` は destructive なので必ず backup タグを先に打つ:**
```
backup/<YYYYMMDD-HHMMSS>-before-rewind  ← reset 直前の HEAD
↓ git reset --hard verified/<target>
```

### D6: secret filter の二重防衛

**Layer 1: 正規表現ベースの決定論的フィルタ**
- `.env*` / `*.key` / `credentials.*` / `*_secret*` / `id_rsa*` はそもそも add 対象外
- `gitleaks` 相当の正規表現で `AKIA[0-9A-Z]{16}` / `sk-[a-zA-Z0-9]{48}` / JWT / PEM 等を検出
- 検出時は **commit 中断、ユーザーに報告**

**Layer 2: LLM による意味的チェック**
- 差分全体を LLM が一度レビューし、「これは secret に見える」ものを検出
- 正規表現が取りこぼす独自形式（社内 token 等）への備え

**Layer 1 単独では取りこぼすが、Layer 2 が人間の常識で補強する構成。**

### D7: push 戦略と本家 skill-creator との住み分け

**push 戦略: ローカル専用運用から開始**
- 当面 push 自動化は提供しない
- 将来 `/e2s:prep-push`（verified 区間で squash するヘルパー）を追加する余地を残す
- push 自体は引き続き明示承認必須

**本家 skill-creator との住み分け:**
- **`skill-creator`**: ゼロからの新規スキル作成（設計・ドキュメント書き・評価）
- **本プラグイン `experience-to-skill`**: 既にやった作業履歴からの蒸留（過去の行動のパターン化）
- 短縮形 `e2s` を slash command prefix に採用し、コマンド空間の衝突を回避
- ユーザー向け説明でも両者を明確に区別したドキュメンテーション

### D8: auto-trigger の発火条件と信頼性担保

**発火条件:**
- Agent tool の description で auto-trigger するフレーズ：「完了」「終わった」「動作確認して」「確認お願いします」「archive して」
- `longrun:archive` / `openspec:archive` の完了後は**必須発火**（archive 系コマンドが完了時に明示呼び出しする）

**信頼性担保:**
- スキル description を強く書き、auto-trigger 率を最大化
- `/e2s:commit` 明示コマンドをフォールバック用に提供
- `/e2s:status` で未コミット差分の診断（ユーザーがいつでも確認可能）
- archive 系コマンドに「未コミット差分があれば中断してコミット先行」のゲート機構

**`~/.claude/rules/git-commit-policy.md` の書き換え:**
- 「明示承認なしのコミット絶対禁止」条項を撤廃
- 代わりに「作業完了単位の自動コミット許可 + push/reset/amend の自動実行禁止」を明記
- BREAKING CHANGE として扱い、ユーザーが承認済みの変更として実装する

## Risks / Trade-offs

- **[LLM が auto-trigger を見逃す]** → 信頼性100%にはならない。`/e2s:commit` 手動コマンド + archive 系ゲートで埋める。万一抜けても次セッションの最初のコミットで回収可能
- **[secret filter の取りこぼし]** → Layer 1 + Layer 2 の二重構造で低減。さらに commit 実行直前に LLM が差分全体を一度要約して「怪しいものはないか」と最終確認するステップを必須化
- **[マルチセッションで同じファイルを両方が編集]** → 後にコミットした側が前のセッションの差分も巻き込む。これは git の通常動作と同じなので受容する。ユーザーには `/e2s:status` で可視化する
- **[context 圧縮で編集履歴が要約化]** → 要約レベルの情報は残るので通常運用に影響なし。極端なケースは LLM が `git diff` を読んで判定
- **[Prompted-by ポインタが jsonl 削除時に解決不能になる]** → 個人ループでは問題小、チーム共有には不向き。現時点では受容、将来「重要セッションは archive して長期保管」という運用提案を README に記載
- **[本家 skill-creator ユーザーの混乱]** → ドキュメントで明確に住み分けを説明、slash command prefix を分離（e2s:*）することで衝突を回避
- **[BREAKING: git-commit-policy.md 書き換え]** → ユーザー合意済み。ただしプラグインをアンインストールしたらポリシーを元に戻すべきかは要検討。現時点ではユーザー自身でロールバック可能として扱う
- **[コミット頻度増加によるログ肥大]** → 通常の work tree でコミットするので履歴が長くなる。`/e2s:reflect` や `/e2s:prep-push`（将来）で squash 整理、または squash merge 運用を README で推奨

## Migration Plan

**Phase 1: プラグイン本体の実装**
1. `.claude-plugin/marketplace.json` に `experience-to-skill` を登録
2. `plugins/experience-to-skill/` スケルトン + plugin.json
3. メインスキル `skills/experience-to-skill/SKILL.md` 実装
4. 4つの slash command 実装
5. README 作成

**Phase 2: グローバルルール書き換え**
6. `~/.claude/rules/git-commit-policy.md` を新ポリシーに書き換え（BREAKING）

**Phase 3: 試験運用**
7. 本プラグイン開発自体で dogfooding（自分の作業履歴でコミットを走らせる）
8. verified タグを適切なタイミングで打ち、`/e2s:reflect` の挙動を確認
9. 実運用で発覚した問題を issue として記録

**Rollback 戦略:**
- プラグイン無効化: `/plugin uninstall experience-to-skill@oratta-claude-harness`
- ポリシー復旧: `git-commit-policy.md` を旧バージョンに git revert
- タグ削除: `git tag -d verified/*` / `git tag -d backup/*`
- コミット履歴: squash merge 運用であれば顕在化しない、直 commit 運用なら interactive rebase で整理

## Open Questions

- **Q1**: session-id の取得方法は Claude Code の `$CLAUDE_SESSION_ID` 環境変数等を使うか、スキル内で UUID 生成するか？ → 実装時に環境変数の可用性を確認し、取れなければ jsonl パスから推定、さらにダメなら UUID 生成のフォールバック階段を組む
- **Q2**: `/e2s:reflect` が参照する jsonl ファイルの場所は `~/.claude/projects/<project-hash>/*.jsonl` で固定か？ プロジェクトによって異なる場合の検出方法は？ → 実装時に `~/.claude/projects/` のディレクトリ構造を確認して決める
- **Q3**: 蒸留された SKILL.md の保存先はどこが適切か？ `.claude/skills/` か、専用の `.claude/skills/distilled/` サブディレクトリか？ → 専用ディレクトリ推奨。本家 `skill-creator` との住み分けも明確になる
- **Q4**: `verified/` タグが100個を超えた際の整理戦略は？ → 当面は放置、将来 `/e2s:gc` で古いタグをアーカイブブランチに退避する機能を検討
