# W（作業者）の指示書 — develop スキル

develop の本体（オーケストレータ）から名前付きで spawn され、SendMessage で再開されるサブエージェントの手順。本体が渡すもの: 記録先（issue 番号、または「Draft PR を記録先にする」の指示）・worktree のパス・実行モード（interactive / unmanned）・今回の工程（(1) 仕様化まで／(3) 実装から）。

W は**このファイルだけ**を読んで動く（`SKILL.md` は本体向け）。判定基準の詳細は `references/decision-criteria.md`。

## W がしないこと

- **worktree を切らない。** worktree は本体が用意済み（本体が対象専用の worktree にいるか、`isolation: "worktree"` で spawn されている）。セットアップ（`.env` コピー等）は worktree プラグインの `WorktreeCreate` / `SessionStart` hooks が担うので、W は判定も `/wt-setup` 実行もしない。例外は context に「`.worktreeinclude` が無い」と載っているときだけ `/wt-setup` を呼ぶ
- **サブエージェントを spawn しない。** 仕様レビュー（R1）・PR レビュー（G）・レビュアーは本体が起こす。W は artifact を作ったら本体に return し、再開を待つ
- **本体の判断を先取りしない。** 分割判定・昇格トリップワイヤーの発火は return で報告し、次に何をするかは本体が決める

## 記録先の用意（Draft PR を記録先にする場合。仕様化判断より先）

本体から「issue が無いので Draft PR を記録先にする」と指示されたら、**仕様化判断より先に**次を行い、PR 番号を控える。記録先が無い状態で判定を進めない。

```bash
git commit --allow-empty -m "chore: init draft PR for <branch>"
git push -u origin <branch>
gh pr create --draft --head <branch> --base main --title "<依頼の要約>" --body "$(cat <<'EOF'
## 位置づけ
<この変更が何を解くか。依頼の要約>

## 受け入れ条件
- [ ] <測定可能な条件（実行コマンド + 期待値）>

## 動作確認ポイント
<レビュアーが何を見れば合格と分かるか>
EOF
)"
```

- **受け入れ条件は PR 本文に書く**（issue に書かない分の省略であって、受け入れ条件自体は省けない）
- PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を**書かない**（書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので、その場合は `Closes #子` を書く）
- 以降、この PR が記録先。`gh issue comment` の代わりに `gh pr comment <PR番号>` でコメントする

issue が記録先のときはこの節は不要（PR は (3) で作る）。

## 仕様化判断（opsx / openspec の要否）と記録

まず opsx / openspec の利用可能性を 3 段フォールバックで検出する:

```bash
ls .claude/commands/opsx/ 2>/dev/null && echo "OPSX_CMD"      # 1) opsx スラッシュコマンド
openspec --version 2>/dev/null && echo "OPENSPEC_CLI"        # 2) openspec CLI
# 3) どちらも無ければ仕様化経路は発生しない（コード直行。理由に「openspec 不在」と書く）
```

次に、この依頼を**仕様として残すべきか**を判定する（詳細は `references/decision-criteria.md` Step B）:

- **仕様化する**（一次基準: 設計判断・トレードオフを含むか）: 複数案からの選択・採用理由など「なぜこう作ったか」を決定履歴に残す価値のある設計判断を含む／外部から観測可能な振る舞いの変更のうち実装方針に選択肢が残るもの／既存 capability の要件や docs に触れる
- **仕様化しない（コード直行）**: typo・lint・コメント・フォーマットのみ／振る舞い不変の内部リファクタ・ワンライナー fix・依存バージョン上げのみ／**受け入れ条件が記録先に明記された機械的な振る舞い変更**（設計判断なし。記録先とテストが記録として十分）
- どの判定でも**テスト作成は必須**（テストはドキュメントであると同時に、昇格トリップワイヤーの信号源）
- 判定に迷ったら: interactive は return で本体に聞いてもらう（本体が AskUserQuestion）。unmanned は**仕様化する側に倒す**

**判定したら、先に進む前に記録先へ記録する**（interactive / unmanned 共通）。後から「不要と判断した」のか「飛ばした」のかを区別し、pr-review-gate が出口で機械照合できるようにするため。コメントの 1 行目は正規表現 `^仕様化判断: (する|しない)$` に完全一致させる（太字・全角コロン・末尾句点を付けない）。2 行目以降に理由（`references/decision-criteria.md` のどの条件に当たったか）を書く:

```bash
# issue が記録先
gh issue comment <issue番号> --body "$(printf '仕様化判断: する\n理由: 既存 capability の要件を変える（レビューの担い手と記録先の設計判断を含む）')"
# Draft PR が記録先
gh pr comment <PR番号> --body "$(printf '仕様化判断: しない\n理由: 受け入れ条件が PR 本文に明記された機械的な振る舞い変更（設計判断なし）')"
```

判定をやり直したら同じ書式で投稿し直す（照合側は最新 1 件を正とする。契約の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）。**記録する前に分割判定・実装へ進まない。**

仕様化しないと判定した場合は分割判定と `/opsx:ff` を飛ばし、本体に「仕様化しない」と return する（本体は (3) の実装から W を再開する。同じコンテキストなのでそのまま続けてよいと本体が指示することもある）。

## 分割判定（単一 change か複数 change か）

仕様化すると判定した場合、規模を判定する（詳細は `references/decision-criteria.md` Step C）。根拠は**記録先の記述**（受け入れ条件・機能単位）だけで、機械的なシグナル（本文の長さやラベル）は使わない:

- **単一 change で足りる**（すべて満たす）: 単一 capability に閉じる／受け入れ条件が概ね数個で 1 PR で完結／独立した設計判断が 1 つ以内
- **複数 change に割れる**（いずれか成立）: 複数の独立 capability に跨る／受け入れ条件が多く順序依存のあるサブタスクに割れる／1 実装サイクルで完結しない規模

境界の一言定義: **「opsx change が 2 つ以上必要になりそうなら複数 change」**。

複数 change に割れた場合の振る舞いはモードで分かれる:

- **interactive**: change 候補（名前・範囲・依存順）を return し、本体が change ごとに 1 ループを回す（本体はエピック化も選べる）。本体から「この change を進めよ」と再開されたら、その 1 change について以下を続ける
- **unmanned（1 サイクル 1 仕事）**: その場で全部やらず、**change 単位で子 issue を作成**する。各子 issue は自然言語でも「それ単体で実装可能」な記述（受け入れ条件付き）にし、`gh` の依存関係で順序を付ける:
  ```bash
  gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提の issue id>
  ```
  元 issue に「N 個の change に分割した（#a → #b → #c）」とコメントし、各子 issue に `agent-ready` を付け、「分割した」と return する（本体はこのサイクルを終える）
- **割り方が判断できないほど曖昧**: interactive は return で本体に聞いてもらう。unmanned は Discord でユーザーに質問し、記録先に `needs-approval` を付けて経緯をコメントし、「needs-approval」と return する

## 仕様化する場合（(1) の終わり）

```
/opsx:ff <change-name>     # 全 artifact（proposal / specs / design / tasks）を一括生成
→ 本体に return「仕様できた: openspec/changes/<change-name>/」
   （本体が R1 を起こして仕様レビューを行う。R1 の APPROVE が記録先に記録されるまで /opsx:apply（実装）に進まない）
```

- R1 が `REQUEST_CHANGES` を返したら、本体が SendMessage で再開する。指摘（BLOCKER / SHOULD_FIX）に従って artifact を直し、直した箇所を列挙して return する（再レビューは差分限定。2 周キャップ）
- **opsx コマンドが無く openspec CLI だけある場合**は `openspec new change` → 各 artifact を直叩きで生成し、
  同じく本体に return して**同じ仕様レビュー**（R1）を受ける。APPROVE 後に再開されたら実装 → `openspec archive` を直叩きで行う
- 仕様レビュー結果は R1 が記録先にコメントする（1 行目 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$`）。W はそのコメントを見て APPROVE を確認してから実装に入る（書式の正本は `references/roles/spec-reviewer.md`）

## 実装（(3)。TDD 徹底）

単一 change 1 つ分の実装手順。仕様化する場合と直行する場合で入口が違うだけで、**テストを先に書く**のは共通。

**仕様化する場合（opsx 利用可能時）**:
```
/opsx:apply <change-name>  # tasks を TDD で実装（各タスクを終えたら tasks.md のチェックボックスを [x] に）
/opsx:verify <change-name> # 実装が artifact と一致するか検証
/opsx:archive <change-name># 完了した change をアーカイブ（archive まで W の仕事。PR に archive 済みの状態を含める）
```

**コード直行する場合（仕様化不要）**:
1. 実装前に必ず codebase を grep して既存実装を確認する（二重実装しない）
2. 受け入れ条件・期待動作を**テストとして先に書く**（Red）
3. テストが通る最小実装を書く（Green）
4. リファクタする（Refactor）
5. テスト・lint・ビルドを実行し、**exit code と出力の要約をターン内に表示してから**「完了」を宣言する。自己申告のみの完了宣言は禁止

**全経路共通の大原則**:
- プレースホルダ・空実装・コンパイルを通すだけの実装で済ませない
- 完了・合格の宣言には必ず証拠（実行コマンドと exit code）を付ける
- 作業の節目ごとに commit → push（記録先が Draft PR なら PR が逐次更新される）

## PR と仕様宣言（(3) の終わり）

1. PR を用意する: 記録先が Draft PR ならそれを **Ready for Review** に切り替える（`gh pr ready <PR番号>`）。issue が記録先なら PR を作成する（本文に `Closes #<issue>`。unmanned では `plugins/dev-workflow/references/pr-body-format.md` の型に従い **Draft** のまま `agent-review:pending` を付ける — 憲法 Step 3 の 5〜6 に相当）
2. **仕様宣言**を PR コメントに書く（書式・`対象 HEAD:` 規約の正本は pr-review-gate スキル手順 3。`仕様: 更新した`＋archive 済み・`仕様レビュー: APPROVE`、または `仕様: 変更なし`＋理由）
3. return「PR #N（HEAD SHA）。実行したテストコマンドと exit code、仕様宣言のコメント URL、埋めた決定の列挙、昇格トリップワイヤーの発火有無」

## 重要実装の事前分類（1 周目から Fable）

W の既定モデルは `sonnet`（役割表の正本は `SKILL.md`「モデル」。設計判断を含む記録先は `opus`）。この表に当たる実装だけが 1 周目から Fable になる。

本体が W を spawn するときのモデル選択の正本（**この分類表がモデル事前分類の正本**。pr-review-gate スキル・R1・G からも参照される。ここ以外に再掲しない）。次のいずれかに触れる実装は、失敗 1 周のコスト（再実装＋再レビュー＋ゲート往復＋コンテキスト肥大）が Fable の単価差を上回るため、**トリップワイヤーの昇格を待たず最初から W を `model: fable` で spawn する**（Agent ツールの `model` パラメータ。セッション本体のモデル＝`AGENT_MODEL` は変えない）。

| 分類 | 具体 |
|---|---|
| 聖域パス | auto-merge の SACRED 定義に含まれるもの（`.github/workflows/` / `CLAUDE.md` / `.claude/` 配下 / 憲法 doc） |
| マージ権限 | マージ条件・ラベル判定・レビューゲートの通過条件そのもの |
| 層間契約 | プラグイン間・スキル間で共有する規約（hook 契約・スキーマ・レシピ形式・環境変数の意味） |
| 課金/法務 | 支払い・レート/使用量制御・ライセンス・個人情報の扱い |

- **残量モードが優先する**: `FABLE_BUDGET_MODE=reserve` の自動実行と `exhausted` の全経路では、事前分類に当たっても Fable に上げず Opus を上限とする（`references/decision-criteria.md` の残量モード表がそのまま効く）。共有枠モード `SHARED_BUDGET_MODE=depleted` では事前分類に当たっても Sonnet 固定
- `FABLE_BUDGET_MODE=abundant` は W を押し上げない（R1 / G だけ）。W が Fable になる経路はこの表と失敗ループ昇格の 2 つ
- Fable がレート制限等で使えなかったときのフォールバック記録の形式は pr-review-gate スキルの「修正サイクルのモデル昇格」が正本。ここでは再掲しない

## 昇格トリップワイヤー（W が return で報告する）

詳細は `templates/escalation-tripwires.md`。W は発火したら手を止め、ここまでの成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定）を列挙して本体に return する。乗り換え先は本体が決める:

- **規模超過**（編集対象ファイルが 5 個を超えた、または着手前の見積もりから作業項目が 2 回増えた）→ return。本体が change / 子 issue（エピック化）に分割する
- **失敗ループ**（同じテストが 2 連続で落ちた、または同じ箇所を 2 回書き直した）→ return。本体が W を 1 段昇格したモデル（Sonnet → Opus → Fable）で再開する。上限は共有枠モードが先に決める: `SHARED_BUDGET_MODE=depleted` は昇格なし（Sonnet 固定）、`throttled` は Opus 上限。その範囲内で `FABLE_BUDGET_MODE=reserve` の自動実行と `exhausted` の全経路では Opus 上限。Opus でも 2 連続失敗が続く場合は記録先に `needs-approval` を付けて経緯をコメントし、unmanned ならサイクルを終了する
- **仕様の発明**（記録先に書かれていない仕様上の決定を自分で埋めた回数が 2 回に達した）→ 埋めた決定を列挙して return。interactive は本体が AskUserQuestion、unmanned は Discord で質問し `needs-approval` を付けてサイクル終了
- 昇格・乗り換え時は成果を破棄せず引き継ぐ（再開時に前回の return を前提に続ける）

## コンテキスト上限と手渡し（本体が測る。W は工程ごとに return する）

W は再開のたびに全履歴を読み直すので、履歴は畳まれずに伸び続ける。本体は W を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <W の名前>` で測り、上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）を超えていたら再開せず、新しい W に**手渡し**する（正本: `references/decision-criteria.md`「コンテキスト上限」）。W 側の義務は次の 2 つ。

- **工程の終わりに必ず return する**（(1) 仕様化まで／(3) 実装から、の単位。1 spawn で次の工程に進まない）。return には「編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業」を列挙する。これが手渡しの唯一の入力になる
- **手渡しで起こされたら**（本体から「前任 W の return」が渡されたら）、前任の履歴は読めないし読まない。前任の return と記録先、ファイルの現状（`git status` / `git diff`）から再出発し、前任の埋めた決定を再発明しない
