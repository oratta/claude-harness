## ADDED Requirements

### Requirement: claude-harness の展開先は hook が実行するスクリプトを聖域に含める

claude-harness の展開先の `SACRED` は、全 `plugins/*/hooks/hooks.json` の `command` が `${CLAUDE_PLUGIN_ROOT}/` からの相対で指すスクリプトと、許可を判定する hook が判定の本体として直接読み込む `plugins/dev-workflow/scripts/git-guard-scratchpad.py`・`plugins/dev-workflow/scripts/usage_view.py`・`plugins/capability-registry/scripts/secret-guard.py` に、ファイル名ちょうどで一致しなければならない（MUST）。`plugins/*/scripts/` を丸ごと聖域にしてはならない（MUST NOT）。`MERGE_CONDITION` と原本（`plugins/dev-workflow/templates/auto-merge/`）の正規表現は変えない（SHALL）。

#### Scenario: hook の本体だけを変えた PR は human-merge で止まる

- **WHEN** 変更ファイルが `plugins/dev-workflow/scripts/git-destructive-guard.sh` だけの PR を claude-harness の展開先の auto-merge.yml が判定する
- **THEN** `SACRED` に一致し、`human-merge` が付いて見送られる。`MERGE_CONDITION` には一致しないので、親の判断の印があれば `human-merge` を外せる

#### Scenario: 補助ファイルと他のプラグインの hook も聖域に一致する

- **WHEN** `plugins/dev-workflow/scripts/git-guard-scratchpad.py`・`plugins/capability-registry/scripts/secret-guard.py`・`plugins/worktree/scripts/wt-create-hook.sh` を `SACRED` に当てる
- **THEN** どれも一致する

#### Scenario: hook の経路に無いスクリプトは聖域に一致しない

- **WHEN** `plugins/dev-workflow/scripts/ci-watch.sh`・`plugins/dev-workflow/scripts/epic-dispatch.sh` を `SACRED` に当てる
- **THEN** どちらも一致せず、これらだけを変えた PR は従来どおり自動マージの対象になる

#### Scenario: 運用ガイドに範囲と残る限界が書かれている

- **WHEN** 展開先の `docs/auto-merge.md` の聖域パスの表を読む
- **THEN** hook が実行するスクリプトと補助ファイル 3 本の行があり、補助ファイルは 1 段だけで手で選ぶこと、補助がさらに読み込むものと、hook が実行しない許可を書くスクリプトは聖域に入らないことが書かれている

### Requirement: claude-harness の展開先のテストは hooks.json が指すスクリプトがすべて聖域に一致するかを検査する

claude-harness の展開先の `scripts/test-auto-merge-workflow.sh` は、全 `plugins/*/hooks/hooks.json` の `command` を集め、`${CLAUDE_PLUGIN_ROOT}/` からの相対で指すパスを `plugins/<name>/` の下のパスとして `SACRED` に当てなければならない（MUST）。一致しないパスがある、`command` がその形で読めない、または hooks.json や `command` を 1 件も拾えないときは、失敗にしなければならない（MUST）。補助ファイルはこの検査の対象外とする（SHALL）。

#### Scenario: hooks.json に足した hook を聖域に書き忘れると CI が落ちる

- **WHEN** どれかの `plugins/*/hooks/hooks.json` に、`SACRED` に無いスクリプトを指す `command` を足した状態で、展開先の `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** そのスクリプトのパスを挙げて失敗し、終了コードが 0 以外になる

#### Scenario: 読めない command は通さない

- **WHEN** hooks.json の `command` が `${CLAUDE_PLUGIN_ROOT}/` で始まる 1 本のパスとして読めない形で書かれている
- **THEN** その `command` を挙げて失敗する

#### Scenario: 今の hooks.json はすべて聖域に一致する

- **WHEN** 変更後の claude-harness で `scripts/test-auto-merge-workflow.sh` を実行する
- **THEN** hooks.json が指す全スクリプトが `SACRED` に一致し、終了コードが 0 になる
