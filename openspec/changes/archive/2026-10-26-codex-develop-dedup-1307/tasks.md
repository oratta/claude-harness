## 1. C12（対応表の規則）

- [x] 1.1 `commands/develop.md` の「前景実行のCodexオプションは…」の段落を、`references/codex-develop.md` を指す参照にする（併用拒否・既定 `current`・拒否の規則の本文を書き直さない）。触る範囲: plugins/dev-workflow/commands/develop.md:14
- [x] 1.2 規則の本文が `references/codex-develop.md` の 1 か所にあることを確かめる（足りない文があれば codex-develop.md に寄せる）。触る範囲: plugins/dev-workflow/references/codex-develop.md:13

## 2. C5（レビュー経路: adapter）

- [x] 2.1 `references/codex-develop.md` の needs-reviewer の行の「そのすべての起動指示…常に書く」の義務を、SKILL.md『Role profile の選択』節と gate-runner.md『レビュー経路の判別』を指す参照にする。bats が固定する文言は残す。触る範囲: plugins/dev-workflow/references/codex-develop.md:59

## 3. 正本の置き場所の文

- [x] 3.1 `commands/develop.md` の「手順の正…は SKILL.md の 1 箇所にのみ存在する」を、エピックの扱いは `skills/develop/references/epic.md` と書く文にする。触る範囲: plugins/dev-workflow/commands/develop.md:16

## 4. 確認

- [x] 4.1 `scripts/test.sh` が変更前と同じく通る。変更前後のファイルごとの字数（wc -m。変更前は commands/develop.md 6199、references/codex-develop.md 7205）を PR 本文に書く
