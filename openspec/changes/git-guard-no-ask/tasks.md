# Tasks

R1 の APPROVE が記録先 #1582 に投稿されてから実装する。この change の実装対象は以下の 4 ファイルのみ。rules・README・起動スクリプト・実行モード判定・版・注入予算は変更しない。行番号は仕様作成時点の案内であり、編集前に該当範囲を読み直す。

## 1. NO_ASK の契約・テスト・案内

- [ ] 1.1 hook の説明と決定部・理由文へ NO_ASK を追加し、bats の setup から実行環境の NO_ASK を除く。`no-ask:` 名のテストで、対象 9 種 × default / bypassPermissions × FORCE 未設定 / ask を確認する。さらに acceptEdits / plan / auto / dontAsk / 未知 / 欠落、FORCE=deny、印の未設定・空・空白のみ・0・空白付き 0・1・true・yes、agent_id 無し・空・非文字列、NO_ASK+UNATTENDED、対象外コマンド・off を検査する。理由の必須項目と禁止語、主は回数を数えず continue:false を返さないことも検査する。確認: `bats plugins/dev-workflow/tests/git-destructive-guard.bats --filter 'no-ask:'` が exit 0。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:23-45（説明）、plugins/dev-workflow/scripts/git-destructive-guard.sh:879-965（決定・理由）、plugins/dev-workflow/tests/git-destructive-guard.bats:7-20（setup）、plugins/dev-workflow/tests/git-destructive-guard.bats:579-701（call_env・印・理由のテスト）
- [ ] 1.2 NO_ASK の子の拒否理由・拒否記録・2 回目の continue:false と、主には許可が効かず子には有効な許可が 1 回だけ効くことを `no-ask:` の回帰テストで確認する。印なし・UNATTENDED だけの既存動作も全スイートで維持する。確認: `bats plugins/dev-workflow/tests/git-destructive-guard.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:703-833（子の拒否）、plugins/dev-workflow/tests/git-destructive-guard.bats:988-1161（許可の helper・主と子のテスト）
- [ ] 1.3 epic.md 手順 5 の注意へ印の名前と検知の条件を追記する。印のある別セッションの子が拒否後に承認を求めてターンを終え、親が会話ログを読めるときに検知できると書く。確認画面やログを読めない子の限界は残す。launch の自動設定は書かない。bats に手順 5 を対象にした文書検査を足し、`no-ask:` のフィルタで通ることと本文の目視確認をもって完了とする。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:83-83（手順 5 の注意）、plugins/dev-workflow/tests/git-destructive-guard.bats:960-986（文書検査の近傍）
- [ ] 1.4 変更の記録を作成し、印の契約・起動側が付ける責務・launch とモード判定を変更しないこと・版上げなしを記す。確認: `plugins/dev-workflow/changes/1582.md` が存在し、実装と記載を照合する。触る範囲: plugins/dev-workflow/changes/1582.md（新規）

## 2. 統合確認

- [ ] 2.1 `bash -n plugins/dev-workflow/scripts/git-destructive-guard.sh`、`bats plugins/dev-workflow/tests/git-destructive-guard.bats`、`bats tests/injection-budget.bats`、`openspec validate git-guard-no-ask --type change --strict` を実行しすべて exit 0 とする。git diff で上記 4 ファイルと本 change 以外に編集がないこと、rules・予算・版・起動側に差分がないことを確認する。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:1-980（読取検証のみ）、plugins/dev-workflow/tests/git-destructive-guard.bats:1-1849（読取検証のみ）、plugins/dev-workflow/skills/develop/references/epic.md:83-83（読取検証のみ）、plugins/dev-workflow/changes/1582.md（新規・読取検証のみ）

## Workflow follow-up

- 実装と verify が完了したら coordinator に返す。archive・PR・ゲートは次の工程で扱う。
- マージは主の承認。この change の作業者はマージや auto-merge の有効化を行わない。
