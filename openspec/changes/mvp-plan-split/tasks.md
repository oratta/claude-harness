# Tasks: mvp-plan-split

## 1. 新スキル `longrun-mvp-plan` の作成

- [ ] 1.1 `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` を新規作成する。frontmatter（`name: longrun-mvp-plan` / description / `version: 6.1.0` / allowed-tools）を定義し、現行 `longrun-plan` SKILL.md 末尾の MVP モードセクション（MVP Step 1〜8 + Step 4.5）を**ロジック変更なし**で自己完結したステップ群として移設する（REUSE/REPLACE/SKIP マッピング表は廃止し、各ステップを直接記述する）
- [ ] 1.2 移設した本文に以下が保持されていることを確認する: `longrun-mvp-research` 起動（プロンプト雛形に 2 セクション + Search Audit 指示）/ `<!-- mvp-mode -->` マーカー先頭埋め込み / 軽量 Validation 7 セクションチェックリスト + マーカー確認 / `longrun-mvp-plan-reviewer` + `longrun-mvp-bestpractice-reviewer` の単一メッセージ並列起動（別メッセージ分割禁止の明記）/ レビュー最大 2 ラウンド / backlog・OpenSpec 書き込みなしのハンドオフ
- [ ] 1.3 Gap Analysis / Interview 方法論の提供方式を判断する（design.md Open Questions 参照）: 共有プローズが小さければ新 SKILL.md に複製 + 相互 divergence 防止コメント、大きければ `plugins/longrun/references/` 配下に切り出して `longrun-plan` / `longrun-mvp-plan` 両 SKILL.md から Read 参照に変更する。いずれの場合も新スキルが `skills/longrun-plan/SKILL.md` を実行時に Read しないことを確認する
- [ ] 1.4 `plugins/longrun/.claude-plugin/plugin.json` の `skills` 配列に `./skills/longrun-mvp-plan` を追加する

## 2. コマンド新設（/longrun:mvp と /lr:m）

- [ ] 2.1 `plugins/longrun/commands/mvp.md` を新規作成する（Skill tool で `longrun:longrun-mvp-plan` に `$ARGUMENTS` を委譲、Agent tool 使用禁止の明記。既存 `commands/plan.md` の委譲パターンを踏襲）
- [ ] 2.2 `plugins/longrun/.claude-plugin/plugin.json` の `commands` 配列に `./commands/mvp.md` を追加する
- [ ] 2.3 `plugins/lr/commands/m.md` を新規作成する（既存 `p.md` と同じ Skill tool 委譲パターンで `longrun:longrun-mvp-plan` を起動、Agent tool 使用禁止の明記）
- [ ] 2.4 `plugins/lr/.claude-plugin/plugin.json` の `commands` 配列に `./commands/m.md` を追加し、description の対応コマンド一覧に `/lr:m` を追記する

## 3. `longrun-plan` からの MVP モード撤去と移行案内

- [ ] 3.1 `plugins/longrun/skills/longrun-plan/SKILL.md` の冒頭モード分岐ブロックを書き換える: `--mode=mvp` 検出時は「MVP プラン作成は `/longrun:mvp`（短縮 `/lr:m`）に移動した」旨の移行案内を出力して終了（Step 1〜8 を実行しない・plan.md を生成しない・サイレント無視しない）。フラグなし / `--mode=full` は従来どおりフルモード続行
- [ ] 3.2 同 SKILL.md 末尾の「MVP モード（--mode=mvp）」セクション全体を削除する
- [ ] 3.3 `git diff` でフルモード本文（Step 1〜Step 8）に意図しない差分がないことを確認する
- [ ] 3.4 `plugins/lr/commands/p.md` から `--mode=mvp` 透過転送の説明・使用例を削除し、MVP は `/lr:m` を使う旨に更新する。`plugins/longrun/commands/plan.md` も同様に確認・更新する

## 4. 帰属整理（agent 3 種・テンプレート）

- [ ] 4.1 `plugins/longrun/agents/longrun-mvp-research.md` / `longrun-mvp-plan-reviewer.md` / `longrun-mvp-bestpractice-reviewer.md` の description と呼び出し元記述を `/longrun:plan --mode=mvp` から `longrun-mvp-plan` スキル（`/longrun:mvp`）に更新する。出力契約（セクション構成 / Search Audit / APPROVE・REQUEST_CHANGES 形式 / 検索回数上限）には差分を入れない
- [ ] 4.2 `plugins/longrun/templates/plan-template-mvp.md` の生成情報「モード: MVP（`--mode=mvp`）」を `/longrun:mvp` 表記に更新する。先頭マーカー・divergence 防止コメント・8 つの H2 セクション構成は変更しない

## 5. ドキュメント更新

- [ ] 5.1 `plugins/longrun/README.md` の MVP モードセクションを書き換える: エントリポイントを `/longrun:mvp`（`/lr:m`）に変更、`--mode=mvp` の deprecation と移行案内挙動を明記、フルモードとの差分（Build Contract / TDD / Verifier / OpenSpec archive スキップ）と汎用性（特定プロジェクト非依存・短時間人間実装向け）の記述を維持する
- [ ] 5.2 `plugins/longrun/README.md` の冒頭更新履歴に v6.1.0 の変更概要（MVP 独立スキル化）を追記する

## 6. バージョン同期（3 箇所 × 2 プラグイン）

- [ ] 6.1 `plugins/longrun/.claude-plugin/plugin.json` の version を `6.1.0` に更新し、description を MVP 独立スキル化を反映した内容に更新する
- [ ] 6.2 `plugins/lr/.claude-plugin/plugin.json` の version を `6.1.0` に更新する
- [ ] 6.3 `.claude-plugin/marketplace.json` の plugins[] の longrun / lr エントリを `6.1.0` に、top-level version を bump する
- [ ] 6.4 `plugins/longrun/skills/longrun-plan/SKILL.md` と `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` の frontmatter `version` を `6.1.0` に揃える

## 7. 検証

- [ ] 7.1 構文検証: `jq . plugins/longrun/.claude-plugin/plugin.json plugins/lr/.claude-plugin/plugin.json .claude-plugin/marketplace.json` がエラーなしで通る
- [ ] 7.2 残存参照チェック: `grep -rn -- "--mode=mvp" plugins/` の結果が「移行案内・deprecation 記述としての意図的言及」のみであること（旧フラグでの起動手順としての記述が 0 件）
- [ ] 7.3 動作確認（受け入れ条件 12）: `/longrun:mvp <テーマ>` と `/lr:m <テーマ>` で従来の MVP フロー（Gap Analysis → Interview → リサーチ → 並列レビュー → ハンドオフ）が完走し、`<!-- mvp-mode -->` マーカー付き plan.md が `_longruns/YYYY-MM-DD_slug/` に生成されることを確認する
- [ ] 7.4 動作確認（受け入れ条件 13）: `/longrun:plan --mode=mvp` および `/lr:p --mode=mvp` で移行案内が表示され、plan.md が生成されずに終了することを確認する
- [ ] 7.5 regression 確認: `/longrun:plan`（フラグなし）でフルモードが従来どおり動作する（テンプレ読み込み → Step 7 で longrun-reviewer 起動）ことを確認する
- [ ] 7.6 archive 互換確認: 7.3 で生成した MVP plan.md に対し `/longrun:archive` がマーカーを検知して OpenSpec change 生成をスキップし、ディレクトリのみアーカイブすることを確認する
