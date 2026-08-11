# Tasks: loops-respond-mode

## 1. テンプレートの移植

- [x] 1.1 `templates/agent-loop-inbox.sh` を新設する — 行頭一致限定・投稿者を見ない・状態ファイル無し・fail-open の設計意図コメントごと移植し、`{{AGENT_MENTION}}` / `AGENT_INBOX_MARKER` / `AGENT_INBOX_DONE_REACTION` / `GH_REPO` で project 固有値を外出しする
- [x] 1.2 `templates/agent-loop-reply.sh` を新設する — 投稿前の行頭マーカー検査 + 投稿 + rocket 付与の実測確認を 1 コマンドに束ねる
- [x] 1.3 `templates/select-target.sh` に Step 0.9 の respond 分岐を追加する（他モードより前・副作用より前・即 emit）
- [x] 1.4 移植元（flatmate）固有の repo 名・アカウント名・issue 番号をテンプレートに持ち込んでいないことを確認する

## 2. 憲法テンプレートと導入スキル

- [x] 2.1 `templates/agent-loop-template.md` の Step 0.9 に `respond` / `comment_id` / respond の `candidates` と優先順位を追記する
- [x] 2.2 同テンプレに応答モードの手順（Step 0.9b）を追加する — 未対応/対応済みの定義・行頭限定の理由・`agent-loop-reply.sh` 経由の必須化・除外ラベル・エージェント自身が行頭にマーカーを書く禁止
- [x] 2.3 `loops-dev-agent-install` の Step 4 を 3 本セット設置に変更し、置換漏れと `bash -n` の実測確認を手順に含める
- [x] 2.4 Step 1 のヒアリングに `{{AGENT_MENTION}}` を追加し、完了レポートで人間への呼びかけ方を伝えるようにする
- [x] 2.5 導入済みリポジトリへの後追い配線手順（未配線の検出 → 3 本の配り直し → 憲法の更新）を追加する

## 3. テストと検証

- [x] 3.1 `tests/helper.bash` の `LOOPS_SCRIPT_ALLOWLIST` に新テンプレ 2 本を意図付きで追加する（S23 / S124）
- [x] 3.2 `tests/dev-agent-respond-mode.bats` を新設する（存在・構文・設計意図コメント・respond 優先順位・既存モードの回帰・install 手順）
- [x] 3.3 プレースホルダ置換後のスクリプトを偽 `gh` で実行し、検出・除外・fail-open・respond emit・自己発火ガードを実測する
- [x] 3.4 `plugin.json` 0.21.0 / `marketplace.json`（loops entry + top-level 2.37.0）を bump する
- [x] 3.5 `scripts/test.sh` 全件 Green を確認する
