# 指定アカウントのCodexで手動developを回す

## Why
バーン完成前にもClaude CodeのdevelopからCodexへ仕事を委譲したい。CLI単発呼出しとは別に、共通App Server workerを使う明示的な入口が必要。

## What Changes
`/develop --executor codex --account NAME --model MODEL <依頼>` を追加する。Claudeは既存develop正本に従い工程管理、全委譲役は#706 workerへ送る。手動モードはburn窓を参照しない。暗黙のexec/Claude fallbackは禁止。

## Impact
Flatmate #707、依存 #706。既存のClaude developは維持。品質基準は既存のroles/decision-criteria/pr-review-gateを参照し複製しない。導入READMEと隔離テストを追加する。mergeは行わない。
