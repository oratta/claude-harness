# Proposal

## Why

Codex に Claude 用 hook をそのまま渡すと、入力経路や未対応の `ask` によって実行前の拒否が成立しない。#1862（元 #1858 の G002）で、既存の破壊的 git・秘密表示・無人質問の判定を Codex の入力と `deny` 契約へ適合させる。

## What Changes

- `plugins/dev-workflow/hooks/codex/` に Codex 専用の定義と adapter を追加し、既存 Claude 判定を再利用する。
- Codex の Bash・編集・質問の入力を区別し、対象だけを拒否する正負 fixture を追加する。未確認の質問名を実測済みと扱わない。
- 拒否時は `deny`、非対象時は無出力とし、Claude の確認画面・一回許可・`continue:false` に依存しない。
- 同じ一覧の対象3登録に判定の移植先と検証段階を追記し、共用の `changes/1858.md` に G002 の成果を記す。

## Capabilities

### New Capabilities

- `codex-pretool-guards`: Codex の PreToolUse 入力に対する拒否判定と、文書・fixture・実機の確認状態の区別。

### Modified Capabilities

なし。既存 `destructive-git-hook`・`capability-registry-secret-guard`・`unattended-ask-hook` の Claude 契約、および `codex-hook-coverage` の一覧契約は維持する。

## Impact

- 追加する hook 定義・adapter は聖域。既存 Claude hook 本体は参照だけとし、`CLAUDE.md`、権限設定、注入予算、版は変更しない。
- 前提 #1861 は dispatch HEAD `0f5c744334f2b3bf7ad1673368e44c2fdfa69591` に含まれる。#1863 の配布・信頼・一時 CODEX_HOME・3対象の実機証拠は本 change に含めない。
- 当初の [単一group計算](https://github.com/oratta/claude-harness/issues/1862#issuecomment-7234989209) は、追加読取を反映した [更新入力・出力と停止記録](https://github.com/oratta/claude-harness/issues/1862#issuecomment-7235037971) で無効になった。更新値は C=121635>120000、S=34008000<=48000000、exit 2 / unplaced。親の既存の子PR権限60Mを使い、設定・上限は変更していない。
- その後、本体の [再計画完了記録](https://github.com/oratta/claude-harness/issues/1862#issuecomment-7235062756) で読取範囲を再設計し、exit 0 / 1 group / unplaced なし、C=98505<=120000、S=34008000<=48000000 に収まった。上限は変更していない。容量による停止は解消済みで、現在は R1 指摘を反映した仕様案の再レビュー待ち。実装開始には R1 の承認が必要であり、実装工程の最初に design の入力確認ゲートを満たす。
