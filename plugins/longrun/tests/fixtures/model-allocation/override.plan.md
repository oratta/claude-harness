# Plan: override fixture

## Changes分解

### change-A: feature-x

## モデル割り当て

ユーザーが上書き欄を編集した状態。上書き欄がティア欄より優先される。

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| feature-x | builder | haiku | 当初は定型と判断 | sonnet |
| feature-x | verifier | haiku | 定型的な静的検証 | |

## 受け入れ条件
1. [ ] テストPASS
