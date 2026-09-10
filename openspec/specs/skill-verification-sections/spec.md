# skill-verification-sections Specification

## Purpose
TBD - created by archiving change skill-verification. Update Purpose after archive.
## Requirements
### Requirement: 対象スキルの SKILL.md は「## 自己検証」節を持つ

棚卸しリスト（`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」）で対象と判定された各スキルの SKILL.md は、見出しリテラル「## 自己検証」の節を持たなければならない (MUST)。節は (a) `plugins/dev-workflow/references/self-verification.md` への参照 1 行、(b) スキル固有の検証手順、の 2 要素で構成し、固有手順には検証コマンド（実行可能なコマンド文字列）または検証対象の成果物パスを最低 1 つ含めなければならない (MUST)。

#### Scenario: 7 スキルの SKILL.md に「## 自己検証」節が存在する

- **WHEN** ユーザーが `plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` の各ファイルで「## 自己検証」を grep する
- **THEN** 7 ファイルすべてで見出しがちょうど 1 件ヒットする

#### Scenario: 各節が共通原則リファレンスへの参照 1 行を含む

- **WHEN** ユーザーが対象スキルの「## 自己検証」節で `dev-workflow/references/self-verification.md` を grep する
- **THEN** 各対象スキルの節にリファレンスへのパス参照が 1 行含まれ、旧パス `loops/references/self-verification.md` は 0 件である

#### Scenario: 各節に検証コマンドまたは成果物パスが最低 1 つある

- **WHEN** ユーザーが対象スキルの「## 自己検証」節の固有手順を読む
- **THEN** 各節に、実行可能な検証コマンド（例: テスト実行・lint・`jq` による形式チェック）または検証対象の成果物パス（例: 生成されるファイルのパス）が最低 1 つ記載されている

### Requirement: 検証手順はスキル固有で具体的に書く（汎用文言のコピペ追加を禁止）

各対象スキルの「## 自己検証」節の固有手順は、そのスキルが実際に出す成果物（コード・ファイル・レポート・設定）に即した検証手段（何を・どのコマンドや確認で・どうなれば PASS か）を具体的に記載しなければならない (MUST)。参照 1 行を除いた節本文が、他の対象スキルの節本文と完全一致してはならない (MUST NOT)。

#### Scenario: 節本文の完全一致ペアが存在しない

- **WHEN** ユーザーが全対象スキルの「## 自己検証」節から参照 1 行を除いた本文を相互に比較する
- **THEN** 完全一致する本文のペアは 0 組である

#### Scenario: 検証手段がそのスキルの成果物を名指ししている

- **WHEN** レビュアーが任意の対象スキルの「## 自己検証」節を読む
- **THEN** そのスキル固有の成果物（例: daily-report なら生成される diary ファイル、wt-setup なら作成された worktree と Draft PR）が検証対象として名指しされており、どのスキルにも当てはまる汎用文言だけの節が 0 件である

### Requirement: 既存スキルの機能・発火条件を変えない（追加は検証節のみ）

対象スキルの SKILL.md への変更は「## 自己検証」節の追加（および 500 行ルールによる references 分離ファイルの新規追加）のみでなければならない (MUST)。frontmatter（name・description 等の発火条件）を変更してはならず、既存本文行の削除・変更を行ってはならない (MUST NOT)。

> **スコープ注記（後日縮小）**: 本要件は「自己検証セクションを追加する作業が、ついでに発火条件や本文を書き換えてしまわないこと」を守るための**この change 限りのポイントインタイム制約**である。恒久ガードとして解釈すると、対象スキルの description が未来永劫変更できなくなり、新オプションの追加や発火フレーズの改善を恒久的にブロックしてしまう。
>
> そのため検査側は次のとおり縮小済み（S48 が同じ理由で先に縮小されたのと同じ扱い）:
>
> - **S47** … `name:`（スキルの同一性・ルーティングキー）のみ merge-base から凍結する。`description:` の意図的な改訂は許可し、PR の diff レビューで担保する
> - **S47b** … description が空・欠落していないことだけを機械的に検査する
> - **S48** … 「## 自己検証」節が書き換えられていないことのみを検査する（ファイル全体ではない）
>
> 縮小のきっかけ: wt-clean が `--unattended` / `--repo` の追加（issue #87）で description の更新を必要とした。

#### Scenario: frontmatter が変更されていない

- **WHEN** ユーザーが本 change の実装前後で各対象 SKILL.md の frontmatter を diff する
- **THEN** name・description を含む frontmatter の変更行は 0 件である

#### Scenario: 変更が節の追加のみである

- **WHEN** ユーザーが本 change の実装前後で各対象 SKILL.md を `git diff` で比較する
- **THEN** 削除行・既存行の変更は 0 件であり、追加行は「## 自己検証」節（見出し・参照 1 行・固有手順）のみである

### Requirement: 検証節の追加で SKILL.md が 500 行を超える場合は references へ分離する

「## 自己検証」節の追加後に SKILL.md が 500 行を超える場合（追加前から 500 行を超えている場合を含む）、スキル固有の検証詳細を同プラグインの `references/` 配下のファイルに分離し、SKILL.md 内の「## 自己検証」節は 15 行以内（見出し行を含む）に収めなければならない (MUST)。追加後に 500 行以下に収まる場合は、節を SKILL.md 内に完結させてよい。

#### Scenario: 追加後 500 行以下のスキルは節が SKILL.md 内に完結している

- **WHEN** ユーザーが「## 自己検証」節の追加後に `wc -l` が 500 行以下の対象 SKILL.md を確認する
- **THEN** 検証手順が SKILL.md の節内に完結しており、references への分離は要求されない

#### Scenario: 追加後 500 行を超えるスキルは詳細が references に分離されている

- **WHEN** ユーザーが「## 自己検証」節の追加後に 500 行を超える対象 SKILL.md（例: 追加前から 506 行ある `plugins/worktree/skills/wt-clean/SKILL.md`）を確認する
- **THEN** 検証詳細が同プラグインの `references/` 配下のファイルに存在し、SKILL.md 内の「## 自己検証」節は見出し行を含めて 15 行以内である

### Requirement: 棚卸しリストは実在する全スキルを対象か対象外のどちらかに載せる

`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」は、リポジトリに実在する `plugins/*/skills/*/SKILL.md` の全件を、対象表か対象外表のどちらかに実パスで載せなければならない (MUST)。対象外表の各行には判定理由を付けなければならない (MUST)。網羅性はテスト（`plugins/dev-workflow/tests/self-verification-sections.bats`）で機械検査し、載っていないスキルがあればテストが落ちる。

#### Scenario: 実在する全 SKILL.md が棚卸しリストに現れる

- **WHEN** ユーザーが `ls plugins/*/skills/*/SKILL.md` の各パスを `plugins/dev-workflow/references/self-verification.md` で grep する
- **THEN** 全件が 1 回以上ヒットし、ヒットしないパスは 0 件である

#### Scenario: 新しいスキルを載せ忘れるとテストが落ちる

- **WHEN** 棚卸しリストに載っていない `plugins/<plugin>/skills/<skill>/SKILL.md` が追加された状態で `bash scripts/test.sh dev-workflow` を実行する
- **THEN** 網羅性のテストが `not ok` となり、載っていないパスがテスト出力に表示される

