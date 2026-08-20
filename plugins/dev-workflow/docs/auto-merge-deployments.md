# auto-merge 配備済みリポ一覧（正本）

テンプレート（`../templates/auto-merge/`）をどのリポに配備済みかの唯一の正本。
**テンプレ本体（workflow・スクリプト・不変条件テスト）を改修したら、この表の「テンプレ由来」の
全リポへ同じ変更を展開する**（伝播漏れは「リポごとに違う安全条件」という最悪の状態を生む）。

テンプレート本体にこの一覧を置かないのは、テンプレ配下がリポ非依存であることを
テストが強制しているため（`tests/automerge-templates.bats` の portability テスト）。

| リポ | 実装の出自 | 配備 | PAT（AUTOMERGE_PAT） |
|---|---|---|---|
| genetta-inc/flatmate | テンプレ由来 | 2026-08-03（PR #234） | 登録済み（無期限） |
| genetta-inc/suimei | **テンプレ以前の独自実装**（152 行・2 層 SACRED・不変条件テスト無し） | 2026-07-12（PR #41） | 登録済み（無期限） |
| oratta/claude-harness | テンプレ由来 | 2026-08-18（PR #118） | 登録済み（失効 2026-11-17） |
| oratta/marketing-harness | テンプレ由来 | 2026-08-18（PR #36） | 登録済み（失効 2026-11-17） |

- **suimei への伝播はコピーではなく移行**（素の `pull_request` トリガー・`gh pr merge` を使う旧実装で、
  テンプレの安全不変条件のうち 2 つを満たしていない）。移行 issue: genetta-inc/suimei#301
- claude-harness / marketing-harness の PAT は **2026-11-17 失効 → 11 月中旬にローテーションが必要**
- 新規展開したらこの表に 1 行足す。展開の見送り判断（クライアント案件は実験段階のため時期尚早・
  PR 実績なしは見送り）の正本: [flatmate#371 の A2 確定コメント](https://github.com/genetta-inc/flatmate/issues/371#issuecomment-5338797866)
- 停止中の genetta-inc/shukan は**プロジェクト再開のタイミングで展開する**（2026-08-19 主の判断）
