## Why

flatmate の burn-mode 論点ゲート（genetta-inc/flatmate PR #368）が `casting-check.sh resolve` の出力を自走可否の判定根拠に使い始めたが、resolve サブコマンドは合成表を出して直ちに exit 0 し、check モードの検証（malformed-row・unknown-vocab・version-mismatch）を一度も通らない。壊れた配役表・カタログ更新後の古い override があっても「正常な解決結果」として扱われ、担い手を誤ってエージェント側に解決し自律実行を許可しうる（oratta/claude-harness#117、Codex レビュー high・confidence 0.94）。

## What Changes

- **resolve を fail-closed 化**: 合成表の出力前に、合成の入力になる project.md / local.md へ check モードと同じ検証（行形式・語彙・catalog_version）を実行する。失敗時は stdout に部分表も含めて何も出さず、理由（検出カテゴリ・ファイル・該当行/観点）を stderr に出して exit 1 する
- **止めるのは配役表の欠陥3項目だけ**: malformed-row / unknown-vocab / version-mismatch。起案シグナル2項目（「カタログ外」判例・同一観点の「論点じゃなかった」2件以上）と precedents.md は resolve の検証対象にしない（観点追加を提案した瞬間にその repo の自走が全面停止するのを避ける。check モードでは従来どおり見る）
- **バイパスフラグ（--force 等）は追加しない**: 壊れているときの調査は check モードが行と理由を出すので足りる

## Capabilities

### Modified Capabilities

- `casting-project-files`: Requirement「resolve による有効な配役表の合成表示」に検証必須の MUST を追加

## Impact

- `plugins/casting/scripts/casting-check.sh` — resolve 分岐を検証後に移動、check_layer_files を check/resolve 共通化
- `plugins/casting/tests/casting-resolve.bats` — fail-closed 5 フィクスチャ＋起案シグナル非停止 2 件を追加。既存の「malformed 行はカタログ既定にフォールバック」テストは非 0 終了を期待する形に置き換え（table_rows が5列未満行を有効値にしない防御は維持）
- `plugins/casting/.claude-plugin/plugin.json` — version 0.2.0 → 0.2.1
- `plugins/casting/skills/casting/SKILL.md`・`plugins/casting/README.md` — resolve の fail-closed 挙動を追記
