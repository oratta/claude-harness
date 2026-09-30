# auto-merge 配備済みリポ一覧（正本）

テンプレート（`../templates/auto-merge/`）をどのリポに配備済みかの唯一の正本。
**テンプレ本体（workflow・スクリプト・不変条件テスト）を改修したら、この表の「テンプレ由来」の
全リポへ同じ変更を展開する**（伝播漏れは「リポごとに違う安全条件」という最悪の状態を生む）。

テンプレート本体にこの一覧を置かないのは、テンプレ配下がリポ非依存であることを
テストが強制しているため（`tests/automerge-templates.bats` の portability テスト）。

| リポ | 実装の出自 | 配備 | PAT（AUTOMERGE_PAT） |
|---|---|---|---|
| genetta-inc/flatmate | テンプレ由来 | 2026-08-03（PR #234） | 登録済み（無期限） |
| genetta-inc/suimei | flatmate 版の写し（flatmate コミット db78a986）。2 層 SACRED を維持し、不変条件テストは vitest（`tests/auto-merge-workflow.test.ts`） | 2026-07-12 独自実装（PR #41）→ 2026-09-24 flatmate 版へ置換（suimei PR #395・issue #393） | 登録済み（無期限） |
| oratta/claude-harness | テンプレ由来 | 2026-08-18（PR #118） | 登録済み（失効 2026-11-17） |
| oratta/marketing-harness | テンプレ由来 | 2026-08-18（PR #36） | 登録済み（失効 2026-11-17） |

- **伝播の順序はテンプレ → flatmate → suimei**（suimei は flatmate の workflow を写す。flatmate 側が追いついていないものは suimei にも入らない）。suimei は 2026-09-24 にテンプレ以前の独自実装（152 行・素の `pull_request` トリガー）から flatmate 版へ置き換え済みで、テンプレの安全不変条件（素の `pull_request` を使わない・検証した HEAD SHA にマージをピンする）は充足している
- **テンプレ改修の未伝播（2026-09-30 実測。テンプレ origin/main `3fa4044f`、flatmate main `98dca33f`、suimei main `0423966c`）**:

  | 改修 | テンプレ | flatmate | suimei |
  |---|---|---|---|
  | 合格ラベルの HEAD 束縛（#120・#158。「対象 HEAD: <SHA>」の照合） | 有る | 未伝播（`auto-merge.yml` に「対象 HEAD」が 0 件） | 未伝播（同 0 件） |
  | `revert-pr.yml` の base / ancestor 検証（#121） | 有る | 未伝播（`revert-pr.yml` に `baseRefName`・`is-ancestor`・`merge-base` が 0 件） | 未伝播（`revert-pr.yml` 自体が無い） |

  suimei は flatmate 版の写しなので、先に flatmate へ伝播してから suimei に写す。suimei 固有部分は `auto-merge.yml` 冒頭の `suimei-local` 一覧が持ち越し対象
- claude-harness / marketing-harness の PAT は **2026-11-17 失効 → 11 月中旬にローテーションが必要**
- 新規展開したらこの表に 1 行足す。展開の見送り判断（クライアント案件は実験段階のため時期尚早・
  PR 実績なしは見送り）の正本: [flatmate#371 の A2 確定コメント](https://github.com/genetta-inc/flatmate/issues/371#issuecomment-5338797866)
- 停止中の genetta-inc/shukan は**プロジェクト再開のタイミングで展開する**（2026-08-19 主の判断）
