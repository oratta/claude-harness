# Tasks

## 1. Codex 更新と隔離検証

- [ ] 1.1 既存 rules-sync.bats の HOME/CODEX_HOME も一時領域へ向け、未登録の Codex を通じて実ホームに触れない状態にする。既存配線テストの成功を確認する。触る範囲: tests/rules-sync.bats:9-16（setup）
- [ ] 1.2 sync.sh に manifest 名と Git 登録の照合、対象限定 upgrade、JSON/コマンド失敗の rc 集約を追加し、--no-pull のコメントを実動作に合わせる。fake CLI の bats で正常・CLI不在・対象なし/localのみ・list/upgrade非0・不正JSON・exit 0/errors非空・--no-pull・既存配線継続と無関係な登録/設定の保持を確認する。触る範囲: scripts/sync.sh:3-44（利用説明）、scripts/sync.sh:48-75（初期化とpull）、scripts/sync.sh:259-261（rc出口）、tests/codex-sync.bats（新規）
- [ ] 1.3 ローカル Git remote の main、marketplace clone、旧 Codex snapshot/cache を一時 HOME に作る実 CLI の bats を追加する。main の native develop と command 本文の更新・別commandの削除後に sync を実行し、snapshot/cache のバイト一致、移行スキルの更新/削除、再実行を確認する。実 CLI 未導入時は skip と明示し、受け入れ完了には実 CLI 成功の証拠を必須とする。触る範囲: tests/codex-sync.bats（新規）
- [ ] 1.4 `plugins/dev-workflow/changes/1865.md` に更新方式、--no-pull の扱い、一時 HOME の検証結果、実ホーム確認はマージ後で未実施という状態を記録する。`sh -n scripts/sync.sh` と一時 HOME / CODEX_HOME / CLAUDE_CONFIG_DIR を設定した `bats tests/codex-sync.bats tests/rules-sync.bats tests/marketplace-sync.bats` を実行し、exit 0 と実 CLI ケース非skipを確認する。触る範囲: plugins/dev-workflow/changes/1865.md（新規）、scripts/sync.sh:1-261、tests/codex-sync.bats（新規）、tests/rules-sync.bats:1-135、tests/marketplace-sync.bats:1-133

## Workflow follow-up

- R1 の APPROVE が issue #1865 に記録されてから実装を開始する。PR の Closes は #1865 のみ。
- マージ後、運用側で実ホームの sync と main/cache 一致を確認し issue #1865 に記録する。この worker の実ホーム書換禁止は維持する。触る範囲: リポジトリ内の追加編集なし（issue記録）
