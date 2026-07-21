---
name: github-issue
description: 開発 repo で GitHub issue に取り組む時の標準ワークフロー。issue 番号・URL・「このissue対応して」「issue#12 実装して」等の自然文で起動する。worktree なら wt-setup 未実行を検出して先に実行し、仕様として残すべき変更なら opsx（openspec）フローに乗せ、複数 change に割れる規模なら change ごとに分けて実装する。TDD（テスト先行）を全経路で徹底する。人間の直接依頼でも loop-dev-agent の無人サイクルからでも同じ手順を通す（--unmanned で無人モード）。
version: 1.0.0
---

# github-issue — GitHub issue 対応の標準開発ワークフロー

GitHub issue に取り組む一連の手順を毎回同じに通すためのスキル。「issue に触る」という行為そのものが起動トリガーであり、**それを人間が今すぐ頼んだのか、loop-dev-agent が無人で拾ったのかは問わない**。どちらの入口でも `wt-setup 判定 → 仕様化要否（opsx）→ 単一/複数 change 判定 → TDD 実装` という同じパイプラインを通す。

このスキルの目的は、開発者が毎回プロンプトで手打ちしていた「worktree を用意して、仕様として残すべきなら opsx を使い、テストを先に書いて実装する」を、issue 着手時に自動で乗る標準手順として固定することにある。

## このスキルの立ち位置（loop-dev-agent との責務分割）

このスキルと `loops` プラグインの loop-dev-agent（無人常設ループ）は**競合ではなく分業**である。

- **このスキル**が担うのは「開発の中身」: wt-setup 判定・仕様化要否・change 分割・TDD 実装。
- **loop-dev-agent** が担うのは「無人運用の外形」: `agent-ready` ラベルの周期的な拾い上げ、`agent-wip`/`agent-blocked` ラベル操作、Draft PR 作成、Review Queue 連携、GUARDRAILS。

loop-dev-agent の憲法（`docs/agent-loop.md`）の実装モード（Step 3）は、実装の実体をこのスキルに `--unmanned` 付きで委譲する。ラベル・PR・worktree の外枠は憲法側が持ち、このスキルは中身の開発手順だけを担う。二重管理を避けるため、このスキルはラベル操作や Draft PR 作成を**自分では行わない**（対話モードでの単発利用時を除く。後述）。

## 実行モード

| モード | 起動 | 対話の可否 | change 分割時の振る舞い |
|---|---|---|---|
| **interactive**（デフォルト） | 人間が `/work-issue` や自然文で依頼 | AskUserQuestion で聞ける | その場で change を順番に実装 |
| **unmanned**（`--unmanned`） | loop-dev-agent の Step 3 から呼ばれる | 聞けない（1サイクル1仕事） | change 単位でサブ issue に分割し次サイクルへ委ねる |

無人モードで判断に迷った時は Discord 経由でユーザーに質問できる（後述）。

## パイプライン

### Step A: worktree 判定と wt-setup

1. **worktree かどうか判定する**:
   ```bash
   git rev-parse --git-common-dir 2>/dev/null | grep -q "/worktrees/" && echo "WORKTREE" || echo "MAIN"
   ```
   （`--git-common-dir` が `.../worktrees/<name>` を含めば worktree。メインリポなら `.git` を返す）

2. **worktree でない場合**: 「1 issue = 1 worktree = 1 ブランチ」がこのハーネスの標準。まだ専用 worktree にいなければ、実装着手時（Step D）で worktree を作る前提で Step B に進む。
   - **unmanned モード**では worktree 作成・ブランチ命名は憲法側（loop-dev-agent Step 3）の責務なので、このスキルは worktree を作らず、既に憲法が用意した worktree 内で呼ばれる前提で進む。

3. **worktree の場合、wt-setup 済みか判定する**:
   ```bash
   # wt-setup.sh は .claude/<subdir> を symlink する（.claude 丸ごとではない）。
   # commands か skills が symlink でも git 追跡でもなければ未セットアップの強いシグナル。
   ls -la .claude/ 2>/dev/null
   ```
   - `.claude/` が無い、または中身が空 → **未セットアップ**
   - 判断がつかない時は `/wt-setup` を実行してよい（wt-setup.sh は冪等で、既にリンク済みならスキップする）。

4. **未セットアップなら `/wt-setup` を先に実行する**。後続の作業指示があれば引数で渡す（例: `/wt-setup issue#12 の対応`）。
   - 補足: `docs/agent-loop.md` の有無は loop-dev-agent 用の判定材料であって、**wt-setup 済みの判定材料ではない**。混同しないこと。

### Step B: 仕様化要否（opsx / openspec）の判定

まず opsx/openspec の利用可能性を**3段フォールバック**で検出する:

```bash
# 1) opsx スラッシュコマンドがあるか（.claude/commands/opsx/ が存在するか）
ls .claude/commands/opsx/ 2>/dev/null && echo "OPSX_CMD"
# 2) openspec CLI があるか
openspec --version 2>/dev/null && echo "OPENSPEC_CLI"
# 3) どちらも無ければ opsx ステップはスキップ（コード直行）
```

次に、この issue を**仕様として残すべきか**を判定する（判定基準の詳細は `references/decision-criteria.md`）:

- **仕様化する**（一次基準: 設計判断・トレードオフを含むか）: 複数案からの選択・採用理由など「なぜこう作ったか」を決定履歴に残す価値のある設計判断を含む／外部から観測可能な振る舞いの変更のうち実装方針に選択肢が残るもの／既存 capability の要件や docs に触れる。
- **仕様化しない（コード直行）**: typo・lint・コメント・フォーマットのみ／振る舞い不変の内部リファクタ・ワンライナー fix・依存バージョン上げのみ／**受け入れ条件が issue に明記された機械的な振る舞い変更**（設計判断なし。issue とテストが記録として十分）。
- どの判定でも**テスト作成は必須**（テストはドキュメントであると同時に、昇格トリップワイヤーの信号源）。

このとき同じ流れの中で**実行戦略**（solo / delegate+verify / workflow 型）も仮決めする。4象限モデル・決定論的シグナルの収集コマンド・判定表・残量モード（`FABLE_BUDGET_MODE`: abundant / conserve / reserve）は `references/decision-criteria.md` の「実行戦略の判定」節を参照。実行戦略の判定は独立 Step にしない（Step B/C への相乗り）。事前判定は仮決めであり、誤分類は実行中の昇格トリップワイヤーが修正する。

仕様化しないと判定した場合は Step C を飛ばし、Step D（TDD 実装）へ直行する。

### Step C: 単一 change か複数 change か

仕様化すると判定した場合、規模を判定する（詳細は `references/decision-criteria.md`）:

- **単一 change で足りる**（すべて満たす）: 単一 capability に閉じる／受け入れ条件が概ね数個で 1 PR で完結／独立した設計判断が 1 つ以内。
- **複数 change に割れる**（いずれか成立）: 複数の独立 capability に跨る／受け入れ条件が多く順序依存のあるサブタスクに割れる／1 実装サイクルで完結しない規模（loop-dev-agent の `size:large` 相当）。

境界の一言定義: **「opsx change が 2 つ以上必要になりそうなら複数 change」**。

**複数 change に割れた場合の振る舞いはモードで分かれる**:

- **interactive モード**: change を機械的に分割し、その場で 1 つずつ `/opsx:ff → apply → verify → archive`（Step D の単一 change 手順）を順番に回す。独立していて並列可能なものは並列に進めてよい。longrun:plan は呼ばない（後述）。
- **unmanned モード（1サイクル1仕事を守る）**: その場で全部やらず、**change 単位でサブ issue を作成**する。各サブ issue は自然言語でも「それ単体で実装可能」な記述（受け入れ条件付き）にし、`gh` の依存関係で順序を付ける:
  ```bash
  # 後続 issue が前提 issue に blocked_by されるよう依存を張る
  gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提のissue id>
  ```
  元 issue に「N 個の change に分割した（#a → #b → #c）」とコメントし、このサイクルはここで終了する。次サイクル以降で loop-dev-agent が各サブ issue を 1 つずつ拾い、それぞれで再びこのスキルを通す（各サブ issue は単一 change に収まるはずなので Step D 直行になる）。

**割り方が判断できないほど曖昧な場合**:

- **interactive モード**: AskUserQuestion でその場で聞く。
- **unmanned モード**: Discord でユーザーに質問する（このセッションで Discord reply ツールが使えれば投げる）。返信を待つ間は issue に `needs-approval` を付けて経緯をコメントし、そのサイクルは終了する。返信が来たら次サイクル以降で再開する。

### Step D: 実装（TDD 徹底）

単一 change 1 つ分の実装手順。仕様化する場合と直行する場合で入口が違うだけで、**テストを先に書く**のは共通。

**実行戦略による分岐**（Step B/C で仮決めしたラベルに従う）:

- **solo**: 以下の手順をメインセッションがそのまま実行する（現行どおり。大多数の issue はこれ）。
- **delegate+verify**: 以下の手順（テスト先行含む）を安い実行役（Sonnet subagent または codex:rescue）に委譲する。実行役とは**別の**賢いモデル（既定 Fable。`FABLE_BUDGET_MODE=reserve` の自動実行では Opus）が、受け入れ条件とテスト・lint の exit code を確認して verify してから完了を宣言する。実行役の自己申告だけで完了にしない。
- **workflow 型**: `/lr:e` 系のスキル呼び出しで Workflow 実行に委ねる（builder=安いモデル、checkpoint/verify=Fable）。常駐ルールや Step D から Workflow ツールを直接呼ばない。

**昇格ルール**（全戦略共通。詳細は `templates/escalation-tripwires.md`）:

- 同じテストが2連続で落ちた、または同じ箇所を2回書き直した → 実行役を1段昇格（Sonnet → Opus → Fable）
- `FABLE_BUDGET_MODE=reserve` の自動実行では昇格上限は Opus。Opus でも2連続失敗が続く場合は issue に `needs-approval` を付けて経緯をコメントし、サイクルを終了する
- 昇格・乗り換え時は、ここまでの成果（編集済みファイル・通ったテスト・判明した事実）を破棄せず引き継ぐ

**仕様化する場合（opsx 利用可能時）**:
```
/opsx:ff <change-name>     # 全 artifact（proposal/specs/design/tasks）を一括生成
/opsx:apply <change-name>  # tasks を TDD で実装
/opsx:verify <change-name> # 実装が artifact と一致するか検証
/opsx:archive <change-name># 完了した change をアーカイブ
```
opsx コマンドが無く openspec CLI だけある場合は `openspec new change` → 各 artifact 生成 → 実装 → `openspec archive` を直叩きで行う（longrun-plan の縮退モードと同じ思想）。

**コード直行する場合（仕様化不要）**:
1. 実装前に必ず codebase を grep して既存実装を確認する（二重実装しない）。
2. 受け入れ条件・期待動作を**テストとして先に書く**（Red）。
3. テストが通る最小実装を書く（Green）。
4. リファクタする（Refactor）。
5. テスト・lint・ビルドを実行し、**exit code と出力の要約をターン内に表示してから**「完了」を宣言する。自己申告のみの完了宣言は禁止。

**全経路共通の大原則**:
- プレースホルダ・空実装・コンパイルを通すだけの実装で済ませない。
- 完了・合格の宣言には必ず証拠（実行コマンドと exit code）を付ける。

## longrun:plan を呼ばない理由

このスキルは規模が大きくても `longrun:plan`（`/lr:p`）を**内部から呼ばない**。理由:

`longrun:plan` は「まだ形になっていない曖昧な要望（brain dump）を、対話で質問しながら実装可能な単位に分解し、相互矛盾がないか確認する」ための上流工程である。一方、このスキルが扱う GitHub issue は——特に loop-dev-agent のテンプレート（概要・触るファイル・測定可能な受け入れ条件）を通ったものは——**既にその「ほぐす作業」が終わり、誤解なく specific に指示された状態**にある。ここで再び plan の壁打ちに戻す意味はない。複数 change が必要なら、issue の記述を根拠に機械的に分割すれば足りる（並列可能なものは並列に）。

したがって `longrun:plan` は「issue の体裁を成す前の、大きな構想を練る上流専用」として切り離す。issue に着手した後の分解はこのスキルが担う。

## 参照

- 判定基準の詳細表（Step B/C + 実行戦略・残量モード）: `references/decision-criteria.md`
- 昇格トリップワイヤーの常駐ルールテンプレート: `plugins/dev-workflow/templates/escalation-tripwires.md`
- 呼び出す既存スキル/コマンド: `wt-setup`（worktree プラグイン）、`/opsx:*`（openspec 生成物）、`openspec` CLI
- 棲み分け相手: `loops` プラグインの loop-dev-agent（`recipes/loop-dev-agent.md`、憲法テンプレート `templates/agent-loop-template.md`）
