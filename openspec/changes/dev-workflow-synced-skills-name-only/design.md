## Context

`skillOverrides` は `settings.json` のトップレベルのオブジェクトで、キーがスキルの名前、値が `name-only` などの表示モード。公式文書（https://code.claude.com/docs/en/skills）はキーをスキル名とし、ワイルドカードの記載がなく、プラグインのスキルには効かないと読める。同期スキルへ効くことは公式文書に書かれていない（issue #1470 の実測で効くことは確認済み）。プラグインの設定で配れるのは `agent` と `subagentStatusLine` だけなので（https://code.claude.com/docs/en/plugins-reference#settings）、利用者の `settings.json` へ書く設定コマンドにする。ひな型は `plugins/statusline/commands/setup.md`（スクリプトで `--dry-run` と適用を分け、コマンドが確認を挟む形）。

## 同期スキルの名前の取り方（根拠）

キーは `anthropic-skills:<ディレクトリ名>` とし、`<ディレクトリ名>` は `<設定ディレクトリ>/skills/synced/<バケット>/<ディレクトリ名>/SKILL.md` から取る。`<設定ディレクトリ>` は `CLAUDE_CONFIG_DIR`、未設定なら `~/.claude`。`<バケット>` は `<組織ID>_<アカウントID>` 形式のディレクトリ（`.bucket-*` など先頭が `.` のものは除く）。根拠は 2 つあり、どちらも Claude Code 2.1.314 の実機で確かめた。

1. 実行時の名前: `claude -p --output-format stream-json --verbose` の最初の `init` イベントの `skills` 配列に、同期された 13 本が `anthropic-skills:built-in-browser` … `anthropic-skills:xlsx` として並ぶ。この 13 個は `skills/synced/<バケット>/` 直下のスキルのディレクトリ 13 個、および `manifest.json` の `skillId`・`name` と一致する
2. 接頭辞の出どころ: 本体の実行ファイルの中に `anthropic-skills` という固定の接頭辞と、`name` が `anthropic-skills:` で始まらなければ付ける処理（`anthropic-skills:${name}`）がある。同じ実行ファイルに「同期スキルは、他のスキルと名前がぶつからないと確認できない間は `anthropic-skills:<name>` でしか呼べない」旨の文言もあり、完全修飾名が常に有効なキーであることと整合する

採用しなかった案: `manifest.json` の `skills[].skillId` を読む案。ディレクトリ名と一致するが、`manifest.json` の書式は文書化されていない。ディレクトリ列挙は `SKILL.md` の存在だけに頼り、実行時に実際に読まれるものと同じ根拠になる。接頭辞なしの裸の名前（`deep-research` など）も `init` に現れるが、それは同名の別のスキルとの衝突判定の結果であり、同期スキルであることの保証にならないのでキーに使わない。

複数のバケットがあれば（アカウントを切り替えた環境）、全バケットの和集合を取る。使われていない分のキーが足されても、実在しないスキルへの上書きは無害（効かないだけ）とみなす。これが実在しないスキルに対して本当に無害かは文書に書かれていないので、実機の動作確認で見る。

## Decisions

- **配布はコマンドとスクリプトの 2 つ**: jq の統合規則をコマンドの文章に埋めると bats で確かめられないので、書き込みと判定は `scripts/synced-skills-name-only.sh` に置き、コマンドは「`--dry-run` を見せる → 確認 → 適用」の進行だけを持つ。スクリプトの引数は `--dry-run` だけ
- **既存値は常に勝つ**: `skillOverrides` に同じキーがあれば、値が `name-only` でも `on` でも `off` でも変えない（利用者が意図して決めた値かもしれない）。足すのはキーが無いものだけ。他のトップレベルのキーは jq でそのまま通す
- **変えないものは書かない**: 足すキーが 0 本なら `settings.json` もバックアップも作らない（mtime も変わらない）。足すときは `settings.json.bak-<日時>` を取り、同じディレクトリの一時ファイルに書いてから `mv` で置き換える
- **壊れた入力では書かない**: `settings.json` が JSON として読めない、または `skillOverrides` がオブジェクトでないときは、何も書かず非 0 で終わる。`settings.json` が無いときは `{}` から作る
- **同期スキルが無い環境**: `skills/synced` が無い、または `SKILL.md` を持つディレクトリが 0 本なら、その旨を標準出力に出して何も書かず exit 0
- **元に戻す**: コマンドの案内に 2 通りを書く。バックアップのファイルを `settings.json` に戻す、または `jq 'del(.skillOverrides[...])'` で今回足したキーだけを消す（足したキーはスクリプトの出力に列挙する）。`--uninstall` は足さない
- **確認の置き場**: 確認はコマンド（AskUserQuestion）の仕事で、スクリプトは `--dry-run` なしで呼ばれたら書く。`SessionStart` などの hook からは呼ばない

## Risks / Trade-offs

- 同期スキルへの `skillOverrides` の効き方は公式文書に無く、将来の版で変わりうる。実測した版（2.1.314）をコマンドの案内と PR 本文に書く
- `name-only` にしても、名前を指定しない依頼でスキルが自動的に選ばれるかは比較していない。コマンドの案内に「自動で選ばれにくくなる可能性がある。名前で指定すれば使える」と書く
- 同期スキルが後から増えたら、もう一度実行して足す（自動では足されない）
