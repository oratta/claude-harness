# Tasks

## 1. 失敗ループのラダーを格で書く（テンプレート）

- [ ] 1.1 `templates/escalation-tripwires.md` の「2.【失敗ループ】」のラダーの表を、design.md「ラダーの表は格と `--failure` の値で書く」の 4 列（段階・`--failure`・決める役の格・実行役の格）に書き換え、モデル名は `references/model-tier-map.json` で引く値と書き、Claude の値は括弧書きにする。「本体が opus 以上ならその場で」「本体が fable ならその場で」を消し、「fable が決めて opus が実行しても」「Opus が決めて Opus が実行しても」を格の言葉（最上位・上位）にする。`dev-workflow:decider` に固定する文と実行役の上限の文は格の言葉で残す。確認: 1.2 の bats が通る。触る範囲: plugins/dev-workflow/templates/escalation-tripwires.md:40-65（「2.【失敗ループ → 決める役 / 実行役の分離ラダー】」）
- [ ] 1.2 `tests/develop-skill.bats` に、テンプレートの失敗ループの節に `--failure` の 3 値（`first`・`executor`・`judgment`）・格の語（上位・最上位）・`model-tier-map.json` があり、`model: opus` / `model: fable` を段の値として書いた旧表の行（`| \`sonnet\` で再試行 |` など）が無いことを確かめるテストを足す。hook 注入の既存テスト（`tests/tripwire-hook.bats` の `dev-workflow:decider` と `opus 止まり` の確認）が通ることも確かめる。確認: `bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/tripwire-hook.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:335-351（「model: the escalation tripwire survives as a one-side-only ladder」の近く）、plugins/dev-workflow/tests/tripwire-hook.bats:80-92（読むだけ）

## 2. codex-develop.md に失敗ループの手順と profile の固定を書く

- [ ] 2.1 `references/codex-develop.md`「本体が行う操作」に、失敗ループの手順を実行側・判断側それぞれ書く（実行側は `request` に W の phase と `--failure executor`、判断側は `request --phase decider --failure judgment` の構成の `decider` entry。どちらも返った model だけを使い、profile の作り直し・`--profile` / `--profile-file` の差し替え・model の明示・effort の変更をしない。Codex の実装役の model が変わらないのは対応表で引いた結果、と書く）。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/references/codex-develop.md:17-23（「本体が行う操作」の冒頭 3 段落）
- [ ] 2.2 同じ節の再開前の比較の段落に、返った `tier` が thread の格より高く `model` が thread の applied model と違うときは SendMessage せず fresh thread に手渡し、`model` が同じなら SendMessage してよい、を足す。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/references/codex-develop.md:23（再開前に `request` を呼び直す段落）、plugins/dev-workflow/references/codex-develop.md:39（「Claude role の再開には上記の `tier` の比較」の文）
- [ ] 2.3 「起動と role 解決」に、develop 開始時の profile の指定（`--profile`・`--profile-file`・旧形式・無指定）を工程の途中で変えないこと、変えるなら主の承認を求め記録先に `profile 変更: <変更前の指定> → <変更後の指定>` の行と主の承認の発言を引いたコメントを残すこと、機械的な拒否は #615 の範囲であることを書く。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/references/codex-develop.md:15（「role をどこへ投げるかを決める場所は profile だけである」の段落）
- [ ] 2.4 `tests/develop-skill.bats` に、codex-develop.md の上の 3 点（`--failure executor` と `--failure judgment` の手順、profile・model・effort を差し替えない文、model が変わる昇格は fresh thread、`profile 変更:` の行の書式）を確かめるテストを足す。確認: `bats plugins/dev-workflow/tests/develop-skill.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/develop-skill.bats（末尾に新しい @test。setup に codex-develop.md の変数が無ければ足す: plugins/dev-workflow/tests/develop-skill.bats:20-30）

## 3. SKILL.md と W の指示書の昇格の段落を合わせる

- [ ] 3.1 `skills/develop/SKILL.md`「モデル」節の「昇格トリップワイヤーは失敗の原因側だけを上げるラダーとして残す」の段落を、`--failure first` = 1 回目の失敗・`executor` = 2 回目の実行側・`judgment` = 2 回目の判断側の対応、決める役と実行役の model は `request` の返り値を使うこと、実行側で model が変わるなら fresh thread に手渡すこと（細目は `references/codex-develop.md`）に書き換える。「decider の `model` の段は `templates/escalation-tripwires.md` を Read して従う」を消し、判断側・実行側の定義を読む先として同テンプレートを指す。W の表の行の「上限は `opus`」は変えない。確認: 3.3 の bats。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:316（「モデル」節の昇格の段落）
- [ ] 3.2 `skills/develop/references/roles/worker/common.md`「昇格トリップワイヤー」の失敗ループの項の「W を `opus` で再開」を、実行側なら本体が `--failure executor` の `request` が返した model の W を起こす（model が変われば新しい W に手渡し）、に書き換え、「Opus が決めて Opus が実行しても」を格の言葉にする。確認: `bats plugins/dev-workflow/tests/develop-roles.bats` が exit 0。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/common.md:30
- [ ] 3.3 `tests/develop-skill.bats` の「model: the escalation tripwire survives as a one-side-only ladder」の `W を \`opus\`` と `templates/escalation-tripwires.md\` を Read` の確認を、新しい文（`--failure` の 3 値と段の対応、`request` が返した model、fresh thread、`references/codex-develop.md`）の確認に置き換え、「decider の `model` の段は」の文が無いことを確かめる。確認: `bats plugins/dev-workflow/tests/develop-skill.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:335-351

## 4. 変更の記録と全体の確認

- [ ] 4.1 `plugins/dev-workflow/changes/424.md` に、何を変えたか・なぜか・#615 に寄せたもの（上位格の実行役の拒否、profile 差し替えの機械的な拒否）を書く。確認: ファイルがある。触る範囲: plugins/dev-workflow/changes/424.md（新規）
- [ ] 4.2 `git fetch origin && git merge origin/main` で main を取り込んでから `bats plugins/dev-workflow/tests` と `bats tests/injection-budget.bats` を流す。確認: どちらも exit 0。触る範囲: なし（確認のみ）

## Workflow follow-up

- archive（`openspec archive tier-based-failure-escalation`）と Draft PR、仕様宣言は (3b) で行う
