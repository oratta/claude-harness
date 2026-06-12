# Plan: inherit fixture

## Changes分解

### change-A: feature-x

## モデル割り当て

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| feature-x | builder | inherit | 複雑な TDD 実装 | |
| feature-x | verifier | haiku | 定型的な静的検証 | |

## 受け入れ条件
1. [ ] テストPASS
