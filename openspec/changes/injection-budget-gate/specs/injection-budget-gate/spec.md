## ADDED Requirements

### Requirement: 常時注入される固定分の合計サイズに予算テストを置く

`scripts/test.sh` の全件実行に、常時注入される固定分の合計サイズを測る bats スイート `tests/injection-budget.bats` が含まれなければならない（MUST）。測定対象は次の 3 種の合計とし、単位はバイト（`wc -c` 相当）とする。ロケールに依存する文字数計測（`wc -m`）を使ってはならない（MUST NOT）。

1. **rules**: `rules/*.md` のうち `scripts/sync.sh` が `~/.claude/rules/` へ symlink するもの。すなわち basename が `README.md` のファイルを除いた全件
2. **CLAUDE.md**: リポジトリ直下の `CLAUDE.md`。同期複製である `AGENTS.md` を合計に含めてはならない（MUST NOT）
3. **SKILL.md description**: `plugins/*/skills/*/SKILL.md` の frontmatter の `description` の値の合計

合計が予算を超えない限りテストは pass しなければならない（MUST）。

#### Scenario: 現状の main で予算テストが pass する

- **WHEN** リポジトリのルートで `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 で、TAP 出力に `not ok` が含まれない

#### Scenario: 予算テストが全件実行の経路に載っている

- **WHEN** `git ls-files '*.bats'` の出力を見る
- **THEN** `tests/injection-budget.bats` が含まれ、`scripts/test.sh` を引数なしで実行したときの `▶ bats suites:` の一覧にも現れる

#### Scenario: rules の README.md は合計に含まれない

- **WHEN** `rules/README.md` にだけ文字を追加してテストを実行する
- **THEN** 測定される rules の合計バイト数が変化せず、テストは pass のままである

#### Scenario: AGENTS.md は合計に含まれない

- **WHEN** テストが測定した内訳の一覧を見る
- **THEN** `CLAUDE.md` は 1 回だけ数えられており、`AGENTS.md` は測定対象に現れない

### Requirement: 予算値は独立ファイルに置き、値の変更だけで判定が変わる

予算値は `tests/injection-budget.txt` に数値のみを含む形で置かなければならない（MUST）。テストはこのファイルを読んで比較し、判定の閾値をテストスクリプト内に直書きしてはならない（MUST NOT）。予算値を引き上げると、テストコードを変更せずに fail から pass へ戻らなければならない（MUST）。

予算の初期値は、この change を適用した時点の実測合計に小さな余裕を足した値とし、導入直後に超過が出ない値でなければならない（MUST）。

#### Scenario: 予算超過を予算値の変更だけで解消できる

- **WHEN** `rules/` 配下の注入対象ファイルに予算を超える量の文字を足してテストを実行し、その後 `tests/injection-budget.txt` の数値だけを超過量以上に引き上げて再実行する
- **THEN** 1 回目は exit code が非 0 で fail し、2 回目は exit code 0 で pass する（`tests/injection-budget.bats` は 1 文字も変更していない）

#### Scenario: 予算値の変更が単独の diff として現れる

- **WHEN** 予算値を引き上げた PR で `git diff --stat` を見る
- **THEN** `tests/injection-budget.txt` が 1 行の変更として単独で現れる

#### Scenario: 導入時点の予算に余裕がある

- **WHEN** `tests/injection-budget.txt` の値と、テストが測定した現状の合計値を比べる
- **THEN** 予算値が現状の合計値より大きく、その差が現状値の 10% 以内である

### Requirement: 超過時の出力は超過量・内訳・2 つの選択肢を示す

合計が予算を超えたときのテストの失敗メッセージには、次の 3 つがすべて含まれなければならない（MUST）。

1. 予算値・実測合計・超過量（バイト）
2. 測定対象 3 種（rules / CLAUDE.md / SKILL.md description）それぞれの実測値の内訳
3. 「削る」か「`tests/injection-budget.txt` を上げて PR 本文に理由を書く」かの 2 つの選択肢

#### Scenario: 超過時に超過量と内訳が出る

- **WHEN** 予算を超える量の文字を注入対象に足してテストを実行し、標準エラー出力を読む
- **THEN** 予算値・合計・超過量の 3 つの数値と、rules / CLAUDE.md / SKILL.md description の内訳 3 行が出力されている

#### Scenario: 超過時に取りうる 2 つの選択肢が出る

- **WHEN** 上と同じ失敗出力を読む
- **THEN** 「削る」旨と「`tests/injection-budget.txt` を上げて PR 本文に理由を書く」旨の両方が書かれている

### Requirement: 予算ファイルの変更手続きを CLAUDE.md に定める

予算ファイル `tests/injection-budget.txt` の変更を聖域（`CLAUDE.md`・`rules/` と同じ扱い）とし、引き上げる PR の本文に理由（何を削ろうとして、なぜ超えるままにするか）を書くことを求める記述を、リポジトリ直下の `CLAUDE.md` に置かなければならない（MUST）。`AGENTS.md` は `tests/agents-md-sync.bats` が要求する同期を保たなければならない（MUST）。

この記述を `rules/*.md` に置いてはならない（MUST NOT）。`rules/` は全プロジェクトのセッションに注入されるため、このリポジトリ固有の規約をそこに置くと固定分を増やすことになる。

#### Scenario: CLAUDE.md に予算引き上げの規約がある

- **WHEN** `grep -n 'injection-budget' CLAUDE.md` を実行する
- **THEN** 1 件以上一致し、その行の周辺に「PR 本文に理由を書く」旨が書かれている

#### Scenario: AGENTS.md との同期が保たれている

- **WHEN** `scripts/test.sh agents-md-sync` を実行する
- **THEN** exit code が 0 である

#### Scenario: 規約は rules に置かれていない

- **WHEN** `grep -rn 'injection-budget' rules/` を実行する
- **THEN** 一致件数が 0 件である
