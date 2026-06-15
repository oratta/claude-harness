# Plan: sonnet fixture

## Changes分解

### change-A: feature-x
- スコープ: フィクスチャ

## モデル割り当て

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| feature-x | builder | inherit | 複雑な TDD | |
| feature-x | verifier | sonnet | ブラウザ検証を伴う | |
| feature-x | reviewer | inherit | アーキレビュー | |

## 受け入れ条件
1. [ ] テストPASS
