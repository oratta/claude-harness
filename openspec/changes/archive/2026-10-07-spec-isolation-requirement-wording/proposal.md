## Why

要件「スキルは隔離されたコンテキストで実行する」の最初の文が「`context: fork` を指定し、会話コンテキストから隔離して実行するものとする（SHALL）」のままで、同じ段落の後半とシナリオは現行経路では隔離されないと認めており、読み方が割れる（PR #773 独立レビュー F2、issue #785）。

## What Changes

- 最初の文を「スクリプト実行を含むスキルは、frontmatterで `context: fork` を指定するものとする（SHALL）。スキル本体が直接実行される経路では、これにより会話コンテキストから隔離して実行される。」に置き換える。SHALL の対象は「指定すること」で、隔離は経路の条件付きの説明とする
- archive 側 delta spec（2026-10-07-wt-setup-fork-frontmatter-decision）の同じ文も同じ文にする

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `skill-execution-isolation`: 要件「スキルは隔離されたコンテキストで実行する」の最初の文

## Impact

`openspec/specs/skill-execution-isolation/spec.md` と archive 側 delta spec の文言のみ。コード・設定・hook への影響なし。
