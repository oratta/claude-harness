## MODIFIED Requirements

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
R1 は本体が `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が `references/roles/worker.md` の「重要実装の事前分類」表のマージ権限・層間契約・課金/法務に当たる場合は、`model: fable` を付けた `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn しなければならない（MUST。聖域パスだけでは上げない。分類表の正本は worker.md であり、この要件に再掲しない）。`general-purpose` などの実行役の種別に `model: fable` を付ける spawn は `scripts/agent-model-guard.sh` に拒否される（SHALL）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md の「モデル」節または `references/roles/spec-reviewer.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、マージ権限・層間契約・課金/法務に当たれば `dev-workflow:decider` で spawn し、聖域パスだけでは上げないことが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている

### Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する
仕様レビューは初回と修正後の差分再レビュー 1 回の計 2 周を上限とし（MUST）、3 周目の例外は設けない（MUST NOT）。2 周目終了時点でも BLOCKER が残る場合は記録先に `needs-approval` ラベルを付けて経緯をコメントし（MUST）、interactive モードでは本体が AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する（MUST）。判定結果は記録先のコメントとして記録しなければならず（MUST）、その書式は `references/roles/spec-reviewer.md` に置く（SHALL）。コメントの 1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致し、2 行目以降に周回数・レビュアーのモデル・残課題を書く（MUST）。

投稿者は R1 の spawn 方法で分かれる（SHALL）。`general-purpose` に `model` を明示して spawn した R1 は、従来どおり自分で `gh issue comment` / `gh pr comment` を実行して投稿する。`subagent_type: dev-workflow:decider` で spawn した R1 は `Bash` を持たず投稿できないため、**本体が R1 の return を同じ書式で代理投稿しなければならない**（MUST）。代理投稿でも書式・記録先・「APPROVE が記録されるまで実装に進まない」の判定は変わってはならない（MUST NOT）。同様に decider として起こした R1 は記録先を `gh` で読めないため、**呼び出し側が記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録）を入力文に貼り付けなければならない**（MUST）。`references/roles/spec-reviewer.md` は、レビュアーへの入力と結果の記録の節にこの 2 経路（自分で投稿する場合と本体が代理投稿する場合）を書き分けなければならない（MUST）。

#### Scenario: 2 周キャップと needs-approval が書かれている
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` を読む
- **THEN** 上限 2 周・差分限定の再レビュー・2 周目でも BLOCKER が残れば `needs-approval` を付けて interactive は AskUserQuestion / unmanned はサイクル終了、が書かれている

#### Scenario: 結果コメントの書式と投稿手順が spec-reviewer.md にある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の書式と、周回数・モデル・残課題を含めて記録先にコメントする手順が書かれている

#### Scenario: decider として起こした R1 は本体が代理投稿する
- **WHEN** 本体が R1 を `subagent_type: dev-workflow:decider` で spawn し、R1 が判定を return する
- **THEN** R1 は `gh` を実行せず判定と理由を return し、本体が同じ 1 行目書式で記録先にコメントする

#### Scenario: decider として起こした R1 には記録先の本文が入力で渡る
- **WHEN** `references/roles/spec-reviewer.md` の「レビュアーへの入力」を読む
- **THEN** decider 経路では記録先の本文と関連コメントを呼び出し側が入力文に貼ること、`gh` で自分で取りに行かないことが書かれている
