## Why

issue #900（PR #636 のレビュー指摘の後始末）。第三者 action の SHA 固定検査（`plugins/infra/tests/infra-fixes.bats` の `check_third_party_pins`）は、#240 で「`find` が失敗したら fail する」「`.yml.template` のシンボリックリンクは違反にする」を実装したが、`infra-actions-freshness` の spec にはこの 2 つの条件が書かれていない。加えて、`find` は既定でシンボリックリンクのディレクトリに降りないので、ディレクトリへのリンク（名前が `*.yml.template` でないもの）は列挙されず、その下の違反テンプレートが走査されないまま合格する。

## What Changes

- 要件「Third-party actions in workflow templates MUST be pinned to a commit SHA」の Scenario「Every third-party `uses:` in the templates carries a SHA and a version comment」に、THEN の条件を 2 行足す（既存の行は 1 文字も変えない）
  - テンプレートの列挙（`find`）が 0 以外で終了したら fail する（既に実装とテスト S16a-25 がある振る舞いを spec に書く）
  - 走査対象の下のシンボリックリンクは、名前とリンク先を問わず、リンク自体を違反にする（ファイルへのリンクは既に実装とテスト S16a-26 がある。ディレクトリへのリンクと、名前が `*.yml.template` でないリンクは、この change で検査を広げる。テスト S16a-27）
- 同じ要件に「守備範囲」の段落を足す（入力の出どころ・拾いたい誤り・通ることを許す入力。MUST は増やさない）
- 残りの 3 通り（名前が違うリンク・リンク切れ・名前が `*.yml.template` のディレクトリへのリンク）のテスト S16a-28 を足す
- `check_third_party_pins` の `find` を、シンボリックリンクは名前を問わず列挙する形に変える

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `infra-actions-freshness`: 「Third-party actions in workflow templates MUST be pinned to a commit SHA」（Scenario の条件を 2 行足す）

## Impact

- `openspec/specs/infra-actions-freshness/spec.md`
- `plugins/infra/tests/infra-fixes.bats`（検査の本体とテスト。配布される実行物は変えない）
- `plugins/infra/changes/900.md`（変更の記録）・`plugins/infra/changes/240.md`（テスト ID の訂正）
