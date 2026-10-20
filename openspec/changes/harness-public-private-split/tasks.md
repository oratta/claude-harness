## 1. テストを先に書く

- [ ] 1.1 `tests/public-private-split.bats` を書く。`rules/*.md`・`output-styles/*.md`・`.claude-plugin/marketplace.json` の `plugins[].name`・直下の `scripts/` の項目がすべて `docs/public-private-split.md` の表に 1 行ずつあること、分類が「公開版」「個人版」「保留（#1123 の後）」「分割」のどれかで「分割」の直後に部品の行があること、理由の欄が空でないこと、固有記述の一覧の各パスが実在すること、を確かめる。文書がまだ無いので落ちることを確かめる。触る範囲: tests/public-private-split.bats（新規）、tests/repo-hygiene.bats:1-30（書き方の手本）、.claude-plugin/marketplace.json:1-201（plugins の並び）

## 2. 仕分けの表を書く

- [ ] 2.1 部品を読んで行き先を決める。rules と output-styles は flatmate #1618 本文「仕分けの下書き（2026-10-19 の調査）」の表を起点にし、「配る」「開発用」は公開版、「出さない」は個人版の候補として、#1128 の判断の基準で確かめ直す。下書きに無い部品（`rules/README.md`・各プラグイン・直下の `scripts/`）も同じ基準で決める。触る範囲: rules/*.md（各 7-46 行）、output-styles/readable.md:1-87、.claude-plugin/marketplace.json:1-201（各プラグインの description）、plugins/*/hooks/hooks.json、scripts/lint.sh・scripts/sync.sh・scripts/test.sh・scripts/test-auto-merge-workflow.sh・scripts/poc/
- [ ] 2.2 行き先が割れるプラグインを部品の行に分ける。dev-workflow はエピック実行まわり（`scripts/epic-dispatch.sh` の Orca の起動部品など）を「保留（#1123 の後）」にし、#1123 の結果のどこを見て決めるかを理由に書く。それ以外にオーナーのアカウント・業務に依存する部品（アカウントのレジストリや usage まわりなど）があれば部品の行で分ける。触る範囲: plugins/dev-workflow/scripts/（一覧）、plugins/dev-workflow/scripts/epic-dispatch.sh:1-1378（Orca の起動部品の箇所）、plugins/dev-workflow/hooks/hooks.json:1-115、plugins/statusline/hooks/hooks.json:1-16
- [ ] 2.3 capability-registry を design.md「capability-registry は分割する」のとおり部品の行に分け、選ばなかった案（丸ごと個人版・丸ごと公開版）と理由を書く。触る範囲: plugins/capability-registry/skills/capability-registry/SKILL.md:1-74（「原則」「資格情報の階層」の節）、plugins/capability-registry/skills/capability-registry/1password.md:1-17、plugins/capability-registry/scripts/fmtoken.sh:1-25（冒頭の説明）、plugins/capability-registry/scripts/browser-guard.sh:1-44、plugins/capability-registry/hooks/hooks.json:1-15、rules/browser-infra-env-capture.md:1-10（capability-registry への参照）
- [ ] 2.4 `docs/public-private-split.md` に、冒頭（判断の基準・3 つの分類と「分割」の意味・保留の行は #1129 の移す対象から外れること・`docs/`・`tests/`・`openspec/` は表に載せず説明している部品に従うこと）と表を書く。触る範囲: docs/public-private-split.md（新規）

## 3. 固有記述の一覧を書く

- [ ] 3.1 公開版に残る部品を候補語（オーナーのリポジトリ名・プロジェクト名・`oratta`・`/Users/`・保管庫名・Obsidian・Fieldy・Orca など）で grep し、当たった行を固有名／環境依存／載せない（書式の説明の例など）に仕分ける。触る範囲: 2.4 の表で公開版になった部品（ファイルは表で確定）
- [ ] 3.2 `docs/public-private-split.md` に一覧（`<パス>:<行>`・種別・内容・直す issue）と候補語と除外の基準を足す。直す issue は capability-registry の索引の二重案内に関わる行を #1105、それ以外を #1098 にする。触る範囲: docs/public-private-split.md（3.1 の結果を足す節）
- [ ] 3.3 `bats tests/public-private-split.bats` と `bash scripts/test.sh` が通ることを確かめる。触る範囲: tests/public-private-split.bats（新規）、scripts/test.sh

## 4. flatmate #1615 に判断をコメントする

- [ ] 4.1 flatmate #1615 の 2026-10-20 のコメント https://github.com/genetta-inc/flatmate/issues/1615#issuecomment-6279954960 の表の保留の子（flatmate #1618・#1637・#1633・#1631・#1616・#1628・#1629・#1634・#1630・#1636、claude-harness #1098・#1105）それぞれの本文を読み、表のどの行を根拠に「閉じる／作り直す／そのまま進める」かを決める。触る範囲: genetta-inc/flatmate の各 issue 本文（読むだけ）、docs/public-private-split.md（根拠の行）
- [ ] 4.2 子ごとに 1 行（子の番号・判断・根拠にした表の行・表の文書の URL）で genetta-inc/flatmate #1615 にコメントする。子の close や本文の書き換えはしない。後続の子（#1098・#1105・#1129・#1130）の作業に手を出さない。触る範囲: genetta-inc/flatmate#1615 のコメント（新規 1 件）
