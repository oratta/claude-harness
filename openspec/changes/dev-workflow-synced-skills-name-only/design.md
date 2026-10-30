## Context

`skillOverrides` は `settings.json` のトップレベルのオブジェクトで、キーがスキルの名前、値が `name-only` などの表示モード。公式文書（https://code.claude.com/docs/en/skills）はキーをスキル名とし、ワイルドカードの記載がなく、プラグインのスキルには効かないと読める。同期スキルへ効くことは公式文書に書かれていない（issue #1470 の実測で効くことは確認済み）。プラグインの設定で配れるのは `agent` と `subagentStatusLine` だけなので（https://code.claude.com/docs/en/plugins-reference#settings）、利用者の `settings.json` へ書く設定コマンドにする。ひな型は、書き込みの進め方（スクリプトで `--dry-run` と適用を分け、コマンドが確認を挟む形）は `plugins/statusline/commands/setup.md`、プラグインルートの探索ループ（`plugin_root="${CLAUDE_PLUGIN_ROOT}"` の形。`${CLAUDE_PLUGIN_ROOT:-}` の形は `develop-command.bats` の検査で落ちる）は `plugins/dev-workflow/commands/memory-refresh.md`。

## 同期スキルの名前の取り方（根拠）

キーは `anthropic-skills:<ディレクトリ名>` とし、`<ディレクトリ名>` は `<設定ディレクトリ>/skills/synced/<バケット>/<ディレクトリ名>/SKILL.md` から取る。`<設定ディレクトリ>` は `CLAUDE_CONFIG_DIR`、未設定なら `~/.claude`。`<バケット>` は `<組織ID>_<アカウントID>` 形式のディレクトリ（`.bucket-*` など先頭が `.` のものは除く）。根拠は 2 つあり、どちらも Claude Code 2.1.314 の実機で確かめた。

1. 実行時の名前: `claude -p --output-format stream-json --verbose` の最初の `init` イベントの `skills` 配列に、同期された 13 本が `anthropic-skills:built-in-browser` … `anthropic-skills:xlsx` として並ぶ。この 13 個は `skills/synced/<バケット>/` 直下のスキルのディレクトリ 13 個、および `manifest.json` の `skillId`・`name` と一致する
2. 接頭辞の出どころ: 本体の実行ファイルの中に `anthropic-skills` という固定の接頭辞と、`name` が `anthropic-skills:` で始まらなければ付ける処理（`anthropic-skills:${name}`）がある。同じ実行ファイルに「同期スキルは、他のスキルと名前がぶつからないと確認できない間は `anthropic-skills:<name>` でしか呼べない」旨の文言もあり、完全修飾名が常に有効なキーであることと整合する

採用しなかった案: `manifest.json` の `skills[].skillId` を読む案。ディレクトリ名と一致するが、`manifest.json` の書式は文書化されていない。ディレクトリ列挙は `SKILL.md` の存在だけに頼り、実行時に実際に読まれるものと同じ根拠になる。接頭辞なしの裸の名前（`deep-research` など）も `init` に現れるが、それは同名の別のスキルとの衝突判定の結果であり、同期スキルであることの保証にならないのでキーに使わない。

複数のバケットがあれば（アカウントを切り替えた環境）、全バケットの和集合を取る。使われていない分のキーが足されても、実在しないスキルへの上書きは無害（効かないだけ）とみなす。これが実在しないスキルに対して本当に無害かは文書に書かれていないので、実機の動作確認で見る。`manifest.json` の `staleDirs`（使われなくなったディレクトリ）が残っていると、実在しないスキルのキーが余分に足されうる。この確認も同じ動作確認に含め、問題があれば `staleDirs` を除く規則を足す。

## Decisions

- **配布はコマンドとスクリプトの 2 つ**: jq の統合規則をコマンドの文章に埋めると bats で確かめられないので、書き込みと判定は `scripts/synced-skills-name-only.sh` に置き、コマンドは「`--dry-run` を見せる → 確認 → 適用」の進行だけを持つ。スクリプトの引数は `--dry-run` だけ
- **既存値は常に勝つ**: `skillOverrides` に同じキーがあれば、値が `name-only` でも `on` でも `off` でも変えない（利用者が意図して決めた値かもしれない）。足すのはキーが無いものだけ。他のトップレベルのキーは jq でそのまま通す
- **判定の順**: 先に同期スキルを列挙し、0 本ならその旨を出して `settings.json` を読まずに exit 0（`settings.json` が壊れていても exit 0 になる。読む必要が無いため）。1 本以上あれば `settings.json` を読む
- **変えないものは書かない**: 足すキーが 0 本なら `settings.json` もバックアップも作らない（mtime も変わらない）。足すときは、既存の `settings.json` があればそれを `settings.json.bak-<日時>` にコピーしてから書く（無ければバックアップは作らない）
- **symlink と権限**: `settings.json` が symlink なら、指す先の実体を書き換え、symlink は残す。一時ファイルは実体と同じディレクトリに `mktemp` で作り、先に `cp -p` で実体の権限を写してから jq の出力をリダイレクトで流し込み（権限が一時ファイルの 0600 に変わらない）、`mv` で実体に置き換える。所有者や ACL の維持までは扱わない（`cp -p` が維持する範囲）。小さな実装の選択で、機能は足さない
- **壊れた入力では書かない**: `settings.json` が JSON として読めない、最上位がオブジェクトでない（`[]`、`null`、数値など）、または `skillOverrides` がオブジェクトでないときは、何も書かず非 0 で終わる。`settings.json` が無いときは `{}` から作る
- **前提と引数**: `jq` が無ければ非 0 で失敗する（statusline の `install.sh` と同じ）。`--dry-run` 以外の引数は非 0 で拒否する（`--dry-rnu` の打ち間違いが確認なしの書き込みになるのを防ぐ）
- **元に戻す**: コマンドの案内に 2 通りを書く。バックアップのファイルを `settings.json` に戻す、または `jq 'del(.skillOverrides[...])'` で今回足したキーだけを消す（足したキーはスクリプトの出力に列挙する）。`--uninstall` は足さない
- **確認の置き場**: 確認はコマンド（AskUserQuestion）の仕事で、スクリプトは `--dry-run` なしで呼ばれたら書く。`SessionStart` などの hook からは呼ばない

## Risks / Trade-offs

- 同期スキルへの `skillOverrides` の効き方は公式文書に無く、将来の版で変わりうる。実測した版（2.1.314）をコマンドの案内と PR 本文に書く
- `name-only` にしても、名前を指定しない依頼でスキルが自動的に選ばれるかは比較していない。コマンドの案内に「自動で選ばれにくくなる可能性がある。名前で指定すれば使える」と書く
- 同期スキルが後から増えたら、もう一度実行して足す（自動では足されない）
