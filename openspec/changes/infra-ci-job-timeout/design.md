## Context

雛形は `{{NODE_VERSION}}` などのプレースホルダを infra-setup の Phase 4 が置換して `.github/workflows/` に書き出す。`runs-on` だけは repo variable `CI_RUNNER` で切り替えられる。上限時間にも同じ「variable で切り替え」を使うか、数値の直書きにするかを決める。

## Decisions

### 値は数値の直書きにし、利用者が雛形または生成後のファイルで書き換える

- 採用: `timeout-minutes: 10` のように直書きし、直上のコメントで決め方を書く
- 却下: `timeout-minutes: ${{ fromJSON(vars.CI_TIMEOUT_MINUTES || '10') }}`。repo variable で変えられるが、式の中で文字列を数値に直す必要があり、actionlint の検査も通りにくくなる。上限は「そのリポジトリの普段の所要時間」で 1 回決めて見直す頻度が低く、コミットで変えて履歴に残る方が追える。flatmate も直書き（`timeout-minutes: 40`）
- 受け入れる制約: 値を変えるにはファイルを編集してコミットする必要がある

### 既定値

- `ci.yml.template`: 10 分。この雛形の設計目標が「Tier 1 は 5 分以内」で、その約 2 倍
- `weekly-full.yml.template`: 30 分。フルスイートは PR 用より長い。普段の所要時間は雛形からは分からないため、利用者が測って書き換える前提のコメントを付ける
- どちらも、利用者のリポジトリの普段の所要時間（Actions の実行履歴）が分かるなら、その約 2 倍に書き換える

### weekly-full.yml.template にも置く

`full` ジョブは build・全テスト・`npm audit` を走らせる。固まれば ci.yml と同じく既定で最大 360 分走る。`report-failure` ジョブは `gh issue` を呼ぶだけなので上限を置かない。

### 反映のしかた（SKILL.md に書く）

infra-setup の Phase 4 は既存のワークフローを見つけると「上書き／スキップ／差分を見てから判断」を聞く。再実行して「上書き」を選ぶと、利用者が雛形から変えた箇所（`PROJECT-SPECIFIC OVERRIDE` など）も雛形に戻る。そのため、既に CI を入れたリポジトリには、手で `timeout-minutes` の 1 行を `test` ジョブに書き足すことを勧める。再実行は、ほかの雛形の更新も取り込みたいときに「差分を見てから判断」を選ぶ。

## Risks / Trade-offs

- 既定値が実際の所要時間より短いと、正常なジョブが打ち切られる。コメントと SKILL.md で「普段の所要時間の約 2 倍に書き換える」ことを案内して緩和する
