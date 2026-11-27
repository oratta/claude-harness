## ADDED Requirements

### Requirement: 失敗の段は `--failure` で request に渡し、返った model を使う
SKILL.md「モデル」節の失敗ループの段落は、`request` の `--failure` の各値がどの失敗の段に当たるか（`first` = 1 回目の失敗、`executor` = 2 回目で実行側が原因、`judgment` = 2 回目で判断側が原因）を書かなければならない（MUST）。決める役と実行役の model は、その段の `--failure` を渡した `request` が返した値を使うと書かなければならず（MUST）、決める役の model を `templates/escalation-tripwires.md` の文面から読み取る指示を書いてはならない（MUST NOT。判断側・実行側の分類の定義を読む先として同テンプレートを指すことは許す）。実行側の昇格は「W を上位で再開」ではなく、格が上がって model が変わるなら新しい thread に手渡す、と書かなければならない（MUST。細目の正本は `references/codex-develop.md`）。

#### Scenario: `--failure` の値と段の対応が書かれている
- **WHEN** SKILL.md「モデル」節の失敗ループの段落を読む
- **THEN** `--failure first`・`--failure executor`・`--failure judgment` のそれぞれが、1 回目の失敗・2 回目の実行側・2 回目の判断側に当たると書かれている

#### Scenario: decider の model を文面から読まない
- **WHEN** SKILL.md「モデル」節の失敗ループの段落を読む
- **THEN** 「decider の `model` の段は `templates/escalation-tripwires.md` を Read して従う」の形の文が無く、`request` が返した model を使うと書かれている

#### Scenario: 実行側の昇格は新しい thread
- **WHEN** SKILL.md「モデル」節の失敗ループの段落を読む
- **THEN** 実行側の昇格で model が変わるときは SendMessage で再開せず新しい thread に手渡すと書かれ、`references/codex-develop.md` を細目の正本として指している
