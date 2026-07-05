---
name: experience-to-skill
description: Claude Code セッションの jsonl ログを素材に、ユーザーからの「スキル化」依頼を受けたときだけ起動して SKILL.md を蒸留する。**起動条件は「スキル化して」「スキルにして」「スキルを作って」「過去の作業からスキルを作って」「振り返ってスキル抽出して」のような明示的なスキル化依頼フレーズに限定する。** 「完了」「commit して」「done」「archive」のような汎用完了フレーズや、コミット完了・archive 系コマンド完了では絶対に起動しない（コンテキスト消費を抑制するため）。起動後は `/e2s:distill` のフローに従い、cwd に対応する `~/.claude/projects/<encoded-cwd>/` 配下の jsonl を探索し、対話で候補を絞り込み、Layer 1 正規表現 + Layer 2 意味判定の二重サニタイズを通して SKILL.md を生成する。frontmatter の `name:` には必ず `e2s-` または `distilled-` prefix を付ける。
allowed-tools: Read, Write, Bash, Glob, Grep
---

# experience-to-skill — jsonl 起点のスキル蒸留専門スキル

このスキルは「後付け・自然言語起動」でスキル化を行う。**コミット運用には一切関与しない。**

## 起動タイミング（厳格）

以下のような **明示的なスキル化依頼フレーズ** をユーザーが含めたメッセージにのみ反応する：

- 「〜をスキル化して」
- 「〜をスキルにして」
- 「〜をスキルとして残して」
- 「過去の作業からスキルを作って」
- 「振り返ってスキル抽出して」
- 「先週の〜の作業をスキルにしておいて」
- ユーザーが明示的に `/e2s:distill` を起動した場合

**絶対に起動しないケース:**

- 「完了です」「終わった」「done」「finished」のような汎用完了フレーズ
- 「commit して」「コミットして」のようなコミット依頼
- `longrun:archive` / `openspec:archive` の完了通知
- ファイルを編集した直後の assistant 報告

この限定は、旧 e2s が全コミット境界で起動してコンテキストを浪費した反省を踏まえている。

## メインフロー

ユーザーがスキル化依頼を出したら、内部的に `/e2s:distill` コマンドと同じステップを順に実行する。詳細は `commands/e2s-distill.md` を参照すること。要約すると：

1. **jsonl ディレクトリ解決**: `plugins/experience-to-skill/scripts/jsonl-finder.sh` の `e2s_resolve_jsonl_dir` で cwd に対応する `~/.claude/projects/<encoded>/` を解決（逆引きフォールバック付き）
2. **候補絞り込み**: `e2s_list_jsonl` で 4 段スキャン（dir 確認 → mtime → サイズ 50MB → grep）を走らせ、日付・キーワードヒントから候補を提示
3. **ユーザー選択**: 1 つまたは複数の jsonl を選んでもらう
4. **ターン抽出**: 該当 jsonl の成功手順周辺（fail/retry ターンも含む文脈）を読み込む
5. **Layer 1 サニタイズ**: 抽出テキストを `plugins/experience-to-skill/scripts/sanitize.sh` の `e2s_sanitize` に通し、API key / PEM / メール等の正規表現マッチを `[REDACTED:<kind>]` に置換
6. **Layer 2 サニタイズ（LLM 意味判定）**: 下記「Layer 2 セマンティックレビュー」節に従い、独自形式トークン・PII（個人名・住所・電話）・URL embedded credentials・TODO/FIXME 内の仮 credentials を再レビューして抽象化または削除する
7. **SKILL.md 草案生成**: `e2s-<kebab>` を frontmatter `name:` に置き、手順・根拠・Source を含む SKILL.md 草案を構築
8. **配置先選択**: プロジェクトローカル (`<repo>/.claude/skills/distilled/<name>/SKILL.md`) かユーザーグローバル (`~/.claude/skills/distilled/<name>/SKILL.md`) かをユーザーに尋ねる
9. **書き出し**: `mkdir -p` + Write で作成。既存衝突時はバージョン suffix を尋ねる

## Layer 2 セマンティックレビュー

Layer 1（正規表現）通過後も、LLM（=自分）が**SKILL.md に書き出す全テキスト**を一度レビューし、次を確認する：

- **独自形式トークン**: 社内 API token、カスタム認証 string、personal access token 相当（Layer 1 の正規表現が捉えない形式）
- **PII**: 個人名と組み合わさった識別子、メールアドレス、電話番号、住所
- **URL embedded credentials**: `https://user:password@...` の形
- **TODO/FIXME 仮 credentials**: 「後で直す」系の placeholder に embed された credentials

疑わしい箇所は **抽象化** または **削除** する。自信が持てない場合は **必ずユーザーに確認** する（安全側に倒す）。判断結果は SKILL.md の Source セクションに痕跡を残さない（自由文として吸収）。

## SKILL.md 出力フォーマット

```markdown
---
name: e2s-<kebab-case-name>
description: <一行説明。session 原文を直接転記しない>
---

# <Human-readable title>

## このスキルを起動する条件

<どんなときに役立つかを自然言語で>

## 手順

1. <step>
2. <step>
3. <step>

## 注意事項 / 落とし穴

<試行錯誤の中で発見した「やってはいけないこと」>

## Source

蒸留元 jsonl: ~/.claude/projects/<encoded>/<session-id>.jsonl (turns N-M)
蒸留日時: <ISO timestamp>
蒸留コマンド: /e2s:distill <自然言語指示>
```

## Guardrails

- jsonl 原文をそのまま転記しない。必ず抽象化して書く
- `e2s-` または `distilled-` prefix を必ず付ける（本家 skill-creator との衝突回避）
- `~/.claude/skills/` 直下（`distilled/` サブディレクトリ外）には書き込まない
- git 操作（add / commit / tag）は一切行わない
- コミット運用には関与しない。コミットすべき変更があるとユーザーが言及しても、本スキルからは何もしない（ユーザー自身に委ねる）

## 関連参照

- メインコマンド: `commands/e2s-distill.md`
- jsonl 探索: `scripts/jsonl-finder.sh`
- サニタイズ: `scripts/sanitize.sh`（Layer 1）
- README: `plugins/experience-to-skill/README.md`

## 自己検証

完了宣言の前に、生成物の evidence を確認する（原則: `plugins/loops/references/self-verification.md`）。

- 生成した `SKILL.md` の frontmatter `name:` が `e2s-` または `distilled-` prefix を持つことを確認する: `grep -E '^name: (e2s-|distilled-)' <出力先>/SKILL.md`。
- Layer 1/2 サニタイズを通過し、秘匿情報が `[REDACTED:<kind>]` に置換されて残存していないことを確認する。
- 選択した配置先（プロジェクトローカル / ユーザーグローバル）に SKILL.md が実在することを確認する。
