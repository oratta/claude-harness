## ADDED Requirements

### Requirement: セッション途中のプラグイン更新を CLAUDE_PLUGIN_ROOT の変化で検知して再注入する

`plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh`（UserPromptSubmit hook）は、プラグインの更新の検知に `plugin.json` の `version` を使ってはならない（MUST NOT。issue #447 で撤去したため）。代わりに `CLAUDE_PLUGIN_ROOT` の値（キャッシュの版名＝commit SHA をディレクトリ名に含むパス）をセッションごとの状態ファイルに記録し、記録済みの値と異なるときだけ昇格トリップワイヤー＋残量モードの本文を再注入しなければならない（MUST）。毎プロンプト走る一致時の経路では、今と同じく python3 と find を起動せず、`plugin.json` を読むための処理も足さずに無出力で終わらなければならない（MUST）。`plugin.json` に `version` が無くても、あっても、動作は同じでなければならない（MUST）。既存の契約（セッションの初回は記録だけで注入しない・状態のセッション単位の分離・30 日より古い状態の掃除・全経路 fail-soft で exit 0）は変えない。

#### Scenario: version の無い plugin.json で初回は記録だけする

- **WHEN** `version` の無い `plugin.json` を持つ `CLAUDE_PLUGIN_ROOT` で、状態ファイルの無いセッションの最初のプロンプトを送る
- **THEN** 無出力で exit 0 し、状態ファイルに `CLAUDE_PLUGIN_ROOT` の値が記録される

#### Scenario: 同じ CLAUDE_PLUGIN_ROOT の間は無出力

- **WHEN** 記録済みと同じ `CLAUDE_PLUGIN_ROOT` で次のプロンプトを送る
- **THEN** 無出力で exit 0 する

#### Scenario: CLAUDE_PLUGIN_ROOT が変わったら再注入する

- **WHEN** プラグインの更新で `CLAUDE_PLUGIN_ROOT` が別のディレクトリ（例: `.../dev-workflow/<旧SHA>` から `.../dev-workflow/<新SHA>`）に変わった後にプロンプトを送る
- **THEN** `hookSpecificOutput.additionalContext` に本文を出力し、状態ファイルが新しい値に更新される

#### Scenario: 旧方式の状態ファイルからの移行

- **WHEN** 状態ファイルに旧方式の版番号（例: `2.13.38`）が記録されているセッションでプロンプトを送る
- **THEN** 記録と一致しないので 1 回だけ再注入し、以後は `CLAUDE_PLUGIN_ROOT` の値で比較する
