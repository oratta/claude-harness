## MODIFIED Requirements

### Requirement: 検出項目数の表記と実装の一致

検出項目数を数字で書いている文書（`plugins/casting/README.md`・`plugins/casting/skills/casting/SKILL.md`・`plugins/casting/scripts/casting-check.sh` の冒頭コメント・`plugins/casting/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の description）の「N項目」は、`casting-check.sh` が実際に報告する検出カテゴリ（`report` の第1引数）の異なり数と一致しなければならない (MUST)。この一致は人手のレビューではなくテストで機械的に突き合わせなければならない (MUST)（検出が後から足されたときに文書だけ取り残される事故が起きたため）。

検出カテゴリの数え上げは、シェルのコード領域にある `report` 呼び出しだけを対象にしなければならない (MUST)。ヒアドキュメント本文・行末コメント・文字列リテラルの中に現れる `report` を呼び出しとして数えてはならない (MUST NOT)（`report` の語を含む使い方出力やエラーメッセージを `casting-check.sh` に足しただけで、数え方と無関係なテストが落ちて原因が分かりにくくなるため）。判定に迷う形は多めに数える側（偽陽性）へ倒し、数え落とし側へ倒してはならない (MUST NOT)（検出カテゴリが黙って減ると、文書の「N項目」との突き合わせと「第1引数はリテラル」の検査の両方がすり抜けるため）。

#### Scenario: コードではない report は呼び出しとして数えない

- **WHEN** ヒアドキュメント本文・行末コメント・文字列リテラルの中に `report "..."` を書いたスクリプトから検出カテゴリを数える
- **THEN** どれも呼び出しとして数えられず、同じスクリプトに本物の `report` 呼び出しを1件足すとカテゴリ数が1になる

#### Scenario: 検出カテゴリを増やすと文書を直すまでテストが落ちる

- **WHEN** `casting-check.sh` の検出カテゴリ数と文書の「N項目」表記が食い違っている状態でテストスイートを実行する
- **THEN** 該当テストが失敗し、実装側のカテゴリ数と文書側の表記の両方が失敗メッセージに出る

#### Scenario: 数え方から漏れる report 呼び出しは無言で通らない

- **WHEN** 第1引数がリテラルでない `report` 呼び出し（`report "$var"` 等）を、既存のリテラル呼び出しと同一行に並べた状態でテストスイートを実行する
- **THEN** 呼び出しの数え方が行単位ではなく出現単位であるため食い違いが検出され、該当テストが失敗する

