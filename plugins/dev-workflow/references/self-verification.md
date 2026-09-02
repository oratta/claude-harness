# 自己検証の共通原則（self-verification）

ターンベースのループ最適化——「スキルに検証ステップを組み込み、自己検証能力を高める」——を、このリポジトリの成果物を出す主要スキルに適用するための共通原則（#205 で dev-workflow の共有契約に移設）。各スキルの `## 自己検証` 節はこのファイルを参照し、スキル固有の検証手順だけを書く。

## 中核原則

**完了は主張であり証明ではない。evidence を提示してから完了を宣言する。**

エージェントに「成功した」と主張させてはならない。完了を宣言する前に、成果物が期待どおりであることを示す evidence を必ず提示・確認する。これはターンベースループの品質を決める最重要の設計点であり、全スキル・全ループに共通する。

## evidence の種別

自己検証で提示する evidence は、少なくとも次の 4 種のいずれか（複数可）で構成する。

1. **テスト出力** — テストスイートの実行結果（例: bats の `ok`/`not ok`、PASS 件数）。
2. **exit code** — 検証コマンドの終了コード（例: `exit 0` を確認する）。
3. **生成物の実在と形式チェック** — 生成したファイルが実在し、期待する形式・必須要素を満たすこと（例: `jq` による JSON パース、必須見出しの grep、frontmatter の有無）。
4. **実行結果ログ** — 実行した手順とその出力の記録（例: コマンドと標準出力、ブラウザ操作の結果、コンソールエラーの有無）。

「テストが通ったはず」「たぶん動く」ではなく、上記いずれかの具体的な evidence を提示してから完了とする。

## スキル側への記載ルール

各スキルの `SKILL.md` には次の 2 要素だけを書く。

- **本リファレンスへの 1 行参照**（`plugins/dev-workflow/references/self-verification.md` へのパス参照）。
- **スキル固有の検証手順**（そのスキルが実際に出す成果物に即した、何を・どのコマンドや確認で・どうなれば PASS か）。

**共通原則の本文（中核原則・evidence 種別の説明）を SKILL.md にコピーしてはならない。** 原則はこのファイル 1 箇所にのみ置き、スキル側は 1 行参照 + 固有手順のみとする。汎用文言のコピペ追加は禁止し、原則を改訂したときの散在ドリフトを構造的に防ぐ。

## 対象スキル一覧

`plugins/*/skills/*/SKILL.md` を「成果物を出すか」「完了前の検証が本文に明示されているか」で監査した結果（2026-08 の 3 プラグイン解散後は 6 スキルが対象）。パスはすべてスキル実体の実パスで記載する（コマンド名からパスを組み立てない）。

### 対象（`## 自己検証` 節を追加する）

| 実パス | 主な成果物 | 検証手段の要点 |
|--------|-----------|----------------|
| `plugins/worktree/skills/wt-setup/SKILL.md` | worktree・Draft PR | `git worktree list`・`gh pr view` |
| `plugins/worktree/skills/wt-clean/SKILL.md` | worktree の削除・LLM 退避物 | `git worktree list`・退避ファイル実在（詳細は references 分離） |
| `plugins/daily-report/skills/daily-report/SKILL.md` | `diary.md`（Obsidian Vault） | 生成ファイル実在・見出し確認 |
| `plugins/weekly-report/skills/weekly-report/SKILL.md` | 週次ノート `02 - PERIODIC/Weekly/{week}.md` | 週次ノート実在・frontmatter 確認 |
| `plugins/infra/skills/infra-setup/SKILL.md` | `vercel.json`・GitHub Actions ワークフロー・環境変数配線 | `jq` パース・deploy チェック |
| `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` | 蒸留 `SKILL.md`（`e2s-`/`distilled-` prefix） | frontmatter 検証・サニタイズ確認（`[REDACTED:...]`） |

補足: `e2s-distill` はスラッシュコマンド名（`/e2s:distill`）であり、スキル実体は `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`。コマンド名 `e2s-distill` と同名のスキルディレクトリは存在しないため、上記の実パスで参照する（コマンド名からパスを組み立てない）。

### 対象外（理由を付す）

| 実パス | 判定理由 |
|--------|----------|
| `plugins/dev-workflow/skills/develop/SKILL.md`・`skills/pr-review-gate/SKILL.md`・`skills/issueify/SKILL.md` | 対象外。オーケストレータ／ゲート／起票の手順そのもので、成果物の検証（テスト・lint の exit code、宣言コメントの API 実測、承認後の `gh issue create`）が本文の手順に既に組み込まれている。 |
| `plugins/casting/skills/casting/SKILL.md` | 対象外。配役表・判例の書き方の手順で、生成物の lint は `scripts/casting-check.sh` が担い、コマンド側（`/casting:init`）が実行結果を確認する。 |
| `plugins/skill-pack/skills/skill-pack/SKILL.md` | 対象外。`skillOverrides`/`enabledPlugins` の設定編集のみを行い、成果物は設定ファイルであって、反映確認は Claude Code の設定パースと `/reload-plugins` 後のスキル一覧に委ねる。 |
