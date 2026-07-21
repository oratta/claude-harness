# Plan: fable fixture

## Changes分解

### change-A: feature-x
- スコープ: フィクスチャ

## モデル割り当て

| change | ロール | ティア(haiku/sonnet/fable/inherit) | 理由 | 上書き |
|--------|--------|------------------------------------|------|--------|
| feature-x | builder | sonnet | 実装は安いモデル | |
| feature-x | verifier | haiku | 定型検証 | |
| feature-x | reviewer | fable | 判断集中点 | |
| feature-x | browser-verifier | inherit | 確信度低 | |

## 受け入れ条件
1. [ ] テストPASS
