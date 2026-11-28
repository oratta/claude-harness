# Proposal

## Why

Codex の本体が Claude の役を選んでも、Agent ツールを前提とする起動・再開・消費集計では `claude -p` を扱えない。#1857 の G001（PR #1876、HEAD `59d50d326ccb258b3722a05f5c7ccfc87d38ff4e` に取り込み済み）の役マーカーによる hook 強制層を使い、G002 で起動から終了・計測までを接続する。

## What Changes

- Claude の役を前景の `claude -p` で起こすスクリプトを追加する。`tier_caps.py` による model 検査、孫禁止、`DEVELOP_ROLE`、正整数の `--max-turns` を必須にする。
- session ID と自身の会話ログを明示して返し、同じ session の再開前には `subagent-context.sh --file` で測る。終了理由・役の return・プロセス回収の結果を区別して本体へ返す。
- 自分が起動したプロセスグループだけを通常終了・turn 上限・強制停止・シグナル時に回収する。
- 明示した Claude role session と進行中の Codex 本体 thread を PR トークン集計に加え、既存の記録と重複排除する。履歴・usage の欠損を 0 消費の証拠にしない。
- 役の印を継承してテストを行う場合の fixture 境界を定め、通常セッション用テストへの誤適用と役の制約の解除を防ぐ。
- 実装工程で AC1・AC4・AC5・AC6 の実機部分を観測し、issue に記録する。`plugins/dev-workflow/changes/1857.md` に G002 を追記する。

## Capabilities

### New Capabilities

- `claude-role-launch`: Codex 本体からの Claude 役の print モード起動、役制限、再開前計測、終了理由と所有プロセスの回収、実機検証契約。

### Modified Capabilities

- `dev-workflow-pr-token-budget`: 明示 session/log 登録で Claude 役と進行中の Codex 本体を計上し、二重計上と欠測の 0 扱いを避ける。

## Impact

追加する起動スクリプト・専用 reference と Bats、既存の `pr-token-budget.sh` / `pr-token-measure.sh`・対応テスト・PR トークン手順書・変更記録が対象。G001 の hook、閾値表・model 対応表・注入予算・版は変更しない。会話ログ・登録ファイル・実機証跡はリポジトリ外に置く。

仕様化・分割の根拠は [仕様化判断](https://github.com/oratta/claude-harness/issues/1857#issuecomment-7234040196)、[粒度計算と検証契約](https://github.com/oratta/claude-harness/issues/1857#issuecomment-7234070595)、[本体の G001 → G002 判断](https://github.com/oratta/claude-harness/issues/1857#issuecomment-7234084447)。再判定・再投稿はしない。#1850 の Orca 検証、#1856 の本体手順と provider 操作の分離、#1858 の Codex hook は対象外。既存の Claude 本体による Agent 経路は維持し、本 change では Codex 本体が呼べる起動・計測の契約だけを追加する。
