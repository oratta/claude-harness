# capability-registry-browser-guard

## ADDED Requirements

### Requirement: ブラウザツール呼び出しで PreToolUse hook が発火する
プラグインは `hooks/hooks.json` に PreToolUse hook を定義し、`mcp__claude-in-chrome__*` 等のブラウザ操作ツールの呼び出しにマッチして発火しなければならない（SHALL）。プラグイン同梱 hooks はインストールだけで有効になるため、settings.json や CLAUDE.md の追加編集を必要としないこと。

#### Scenario: ブラウザツール呼び出し時の発火
- **WHEN** エージェントが `mcp__claude-in-chrome__navigate` 等のブラウザツールを呼び出す
- **THEN** PreToolUse hook が発火し、CLI 代替の検討を促すメッセージがコンテキストに注入される

#### Scenario: 非ブラウザツールでは発火しない
- **WHEN** エージェントが Bash や Read などブラウザ以外のツールを呼び出す
- **THEN** hook は発火しない（matcher がブラウザツールのみにマッチする）

### Requirement: hook は deny ではなく注意喚起から始める
hook の応答はツール実行を拒否（deny）せず、「CLI で不可能な理由」の明示を促す注意喚起でなければならない（SHALL）。メッセージには capability-registry スキルの索引参照と `fmtoken.sh` の存在を含め、正当なブラウザ操作（レジストリのブラウザ必須例外に該当する場合）は妨げないこと。

#### Scenario: 注意喚起の内容
- **WHEN** hook が発火する
- **THEN** 出力には (1) CLI 代替が無いか索引を確認したか、(2) トークンは fmtoken.sh で取れないか、(3) CLI で不可能な理由の明示、を促す文言が含まれ、ツール実行自体はブロックされない
