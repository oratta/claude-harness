# Plan: minimal fixture（1 change / 1 タスク）

受け入れ条件 8(b) の最小完走確認用 fixture。Review → Build → Verify が 1 周で完走する
最小構成。Workflow ツールの実走は orchestrator（メインループ）が行う（builder サブエージェントは
Workflow を起動できないため）。本 fixture は exec のテンプレート充填と静的検証の素材を提供する。

## ゴール

`echo hello` を返す 1 関数を TDD で実装する、という想定上の最小タスク。

## スコープ

### 含むもの
- change-1（fixture-hello）のみ

## Changes分解

実行構造: 単一 change。依存なし。

### change-1: fixture-hello
- **対象リポジトリ**: （fixture・実体なし）
- **スコープ**: `hello()` が文字列 "hello" を返すことを TDD で実装する
- **使用スキル**: なし
- **依存関係**: 独立
- **バージョン**: n/a（fixture）

## 受け入れ条件
1. [ ] `hello()` が "hello" を返すテストが PASS する

## 動作確認方法
- テスト: `bats`（fixture のため実走は orchestrator が判断）
