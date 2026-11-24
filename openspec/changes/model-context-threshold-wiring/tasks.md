# Tasks

実装予定は proposal の 5 ファイルに限る。行番号は dispatch HEAD `5cf82a882f0b367569617a72063041d2cbcd31cc` 時点の案内で、編集前に該当箇所を読み直す。共通処理・表・利用手順・累計経路は編集しない。一時 fixture と stdout / stderr の捕捉先は `$TMPDIR` / `mktemp -d` の repo 外に作る。以下は仕様レビューの APPROVE 後に実施する。

## 1. 文脈計測の 2 経路を接続する

- [ ] 1.1 CLI の既存走査で採用 usage と `message.model` を対にし、同梱共通処理から `context_cap` を取得する。モデルの欠落 / 非文字列 / 空白・未知 / 別名・複数モデル・末尾 API エラー、`--file` と名前探索を既存計測ルールのまま扱う。`--cap` の env 遮蔽、空白 env の共通解釈、0 許容、無関係 env の除外、stderr 診断と失敗時 exit 1 を実装する。同じタスクで `subagent-context.bats` の既知 ID fixture / 出力別捕捉を整え、一時プラグインの異なるモデル行 / fallback 値、既知だが根拠違い、env / 引数 / 境界、不正 env / 欠損・不正表 / 共通部品欠損、配布先の手順パスを検査する。既存の探索・停止確認 exit 3・API エラーのテストも含め `bats plugins/dev-workflow/tests/subagent-context.bats` が通ることで確認する。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:32-179（引数・ログ走査・出力）、plugins/dev-workflow/tests/subagent-context.bats:8-453（fixture と全回帰ケース）
- [ ] 1.2 hook の末尾計測で採用した usage と `message.model` を対にして文脈 2 指標を解決する。同じ Python プロセス・`-I`・実体基準ロード・書込み無しを保ち、stderr の診断と理由付き fail-open、両値の正数条件、既存の Post 通知 / Pre 拒否を実装する。同じタスクで `context-tripwire.bats` の既知 ID fixture / 出力別捕捉を整え、異なるモデル行 / fallback、モデル不明時の非補完、未知モデルの cap 内 / 通知 / 拒否、既知だが根拠違い、上書き・両閾値の 0・大小・ちょうどの境界、無関係 env、不正 env / 欠損・不正表 / 共通部品欠損、配布先からの手順パスと診断の反復を検査する。`bats plugins/dev-workflow/tests/context-tripwire.bats` で既存の早期終了・Unicode キー・探索・worktree・Bash 全拒否・5MB / 100ms も維持できることで確認する。触る範囲: plugins/dev-workflow/scripts/context-tripwire.sh:23-233（早期終了・末尾計測・しきい値・出力）、plugins/dev-workflow/tests/context-tripwire.bats:11-605（fixture と全回帰ケース）
- [ ] 1.3 正本の未配線期間の文を文脈 2 経路の接続済み・累計の未接続へ改め、モデル取得元、上書き順、CLI と hook の 0 の差、stderr 診断 / 絶対手順パス、解決失敗の扱いを同節へ簡潔に書く。既存の数値・停止の意味・手渡し権限を変えず、利用手順の注記は change 3 に残す。`git diff -- plugins/dev-workflow/skills/develop/references/decision-criteria.md` と両スクリプト / delta spec を照合して確認する。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:32-65（コンテキスト上限の節）

## 2. 統合を確認する

- [ ] 2.1 repo 外の一時配置と別 cwd で両経路が同じ同梱表を使うこと、片方だけのモデル / override 解釈が残らないことを、`bats plugins/dev-workflow/tests/subagent-context.bats plugins/dev-workflow/tests/context-tripwire.bats` で確認する。共通部品の回帰は `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_token_thresholds.py'`、構文は `bash -n plugins/dev-workflow/scripts/subagent-context.sh plugins/dev-workflow/scripts/context-tripwire.sh`、差分は `git diff --check` で確認する。テストは各タスクで追加済みのケースを使い、この項目だけに作成を先送りしない。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:32-179、plugins/dev-workflow/scripts/context-tripwire.sh:23-233、plugins/dev-workflow/tests/subagent-context.bats:8-453、plugins/dev-workflow/tests/context-tripwire.bats:11-605、plugins/dev-workflow/skills/develop/references/decision-criteria.md:32-65（照合と既存ケースの統合実行）

## Workflow follow-up

- 本 spec phase は artifact の validate・commit・push までで return し、PR は作らない。仕様化判断は #1800 の既存記録を使い再投稿しない。
- coordinator が仕様レビューを dispatch し、APPROVE 後の別 phase で実装・verify を行う。実セッションの Claude 起動が要る検証は本 worker では実行しない。
- archive・仕様同期・PR は coordinator が指定する後工程。change 3 が利用手順と累計の注記を更新する。
