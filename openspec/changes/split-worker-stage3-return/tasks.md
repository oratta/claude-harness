## 1. 検査を先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/develop-skill.bats` に、1 ループの (3) が (3a)/(3b) の 2 段に分かれ、(3a) に apply(TDD)・verify、(3b) に archive・PR Ready・仕様宣言が入っていることを固定する検査を足す
- [ ] 1.2 同ファイルに、(3a) の return のあと (3b) の指示の前に `subagent-context.sh` で測る旨と、上限超の扱いを `decision-criteria.md`「コンテキスト上限」に委ねる旨が (3) の記述にあることを固定する検査を足す（閾値・環境変数名の再掲が無いことも併せて確認する）
- [ ] 1.3 `plugins/dev-workflow/tests/develop-roles.bats` に、`worker.md` が (3a)/(3b) それぞれの return 内容を列挙していること（(3a) はテストコマンドと exit code、(3b) は PR 番号と仕様宣言のコメント URL）を固定する検査を足す
- [ ] 1.4 同ファイルに、`worker.md` のコンテキスト上限の節が工程の単位を「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙していることと、(3) をこれより細かく切らない旨とその理由が書かれていることを固定する検査を足す
- [ ] 1.5 ここまでの検査が現状の文書に対して落ちる（Red）ことを `env -u CLAUDE_SECURESTORAGE_CONFIG_DIR bash scripts/test.sh` で確認する

## 2. 文書を直す（Green）

- [ ] 2.1 `plugins/dev-workflow/skills/develop/SKILL.md` の 1 ループの (3) を、(3) の行を残したまま (3a)/(3b) の 2 段に書き換え、あいだの計測手順を書く
- [ ] 2.2 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の実装の節・PR と仕様宣言の節を (3a)/(3b) の見出しに改め、それぞれの return 内容を列挙する（(3a) にテストコマンドと exit code を必須と書く）
- [ ] 2.3 同ファイルのコンテキスト上限と手渡しの節の「工程の終わりに必ず return する」の単位を 3 つに改め、これより細かく切らない理由を 1 行足す（手渡しの規則の本文は増やさない）
- [ ] 2.4 `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の `工程完了:` の例（`工程完了: 実装から`）を分割後の工程名に差し替える（例の更新のみ。規則の本文は増やさない）
- [ ] 2.5 `plugins/dev-workflow/README.md` の 1 ループの 1 行説明を (3a)/(3b) の形に直す
- [ ] 2.6 `plugins/dev-workflow/.claude-plugin/plugin.json` の description を (3a)/(3b) の形に直し、version を上げる
- [ ] 2.7 `plugins/dev-workflow/CHANGELOG.md` に今回のエントリを足す

## 3. 検証（Refactor / verify）

- [ ] 3.1 `env -u CLAUDE_SECURESTORAGE_CONFIG_DIR bash scripts/test.sh` を全出力ファイル経由で走らせ、`^not ok` が 0 件であることを確認する
- [ ] 3.2 既存 bats が文言照合で落ちた場合は、その検査が拾っている意図を読んでから文書側を直す（assert の書き換えは最後の手段とし、書き換えたら理由を PR 本文に書く）
- [ ] 3.3 `openspec validate split-worker-stage3-return --strict` が通ることを確認する
