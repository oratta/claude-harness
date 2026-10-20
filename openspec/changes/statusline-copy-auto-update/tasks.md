## 1. 記録を書く（install.sh）

- [ ] 1.1 ハッシュを取る関数（`shasum -a 256`、無ければ `sha256sum`。どちらも無ければ空を返す）を足し、`--dry-run` でない実行の最後（コピーと settings.json の処理のあと）で `<config>/.statusline-installed` を一時ファイル経由で書く。コピーを書き換えなかった実行でも書く。ハッシュが取れなければ警告 1 行を出して記録を書かずに続ける。記録を書いたあと `<config>/.statusline-update-available` があれば消す（`--dry-run` では消さない）。冒頭のコメントの「更新時は再実行する」を、フックが自動で揃えることに合わせて直す。触る範囲: plugins/statusline/scripts/install.sh:1-20（冒頭コメント）、plugins/statusline/scripts/install.sh:85-134（書き込み部と完了表示）

## 2. SessionStart フック

- [ ] 2.1 `hooks/hooks.json` を作り、SessionStart（matcher `startup|resume|clear`、timeout 10）で `"\"${CLAUDE_PLUGIN_ROOT}/scripts/statusline-update-hook.sh\""` を呼ぶ。`plugin.json` は変えない。触る範囲: plugins/statusline/hooks/hooks.json（新規）
- [ ] 2.2 `statusline-update-hook.sh` を bash だけで書く: `CLAUDE_PLUGIN_ROOT` が空、または実体のパス（`realpath` ではなく `cd -P … && pwd -P` で解決）が `<config>/plugins/` の実体のパスの下にないなら何もせず exit 0。2 つのコピーそれぞれを design の表どおりに判定し（無い／本体と同じ／記録どおり→置き換え／それ以外→印の対象）、記録を一時ファイル経由で書き直し、印を置くか消す。印を置いたとき `<config>/statusline.sh` が文字列 `.statusline-update-available` を含まなければ `{"systemMessage":...}` を 1 行出す。どの失敗でも exit 0、標準エラーは出さない。実行権限を付ける。触る範囲: plugins/statusline/scripts/statusline-update-hook.sh（新規）

## 3. 表示（statusline.sh）

- [ ] 3.1 1 行目の `printf` の直前で `[ -f "$CONFIG_DIR/.statusline-update-available" ]` のときだけ、1 行目の末尾に `  ${YELLOW}更新あり /statusline:setup${RESET}` を足す。印が無いときの出力は 1 バイトも変えない。2 行目以降・1 行目の既存部分・冒頭コメントの行の説明以外は触らない。触る範囲: plugins/statusline/scripts/statusline.sh:3-8（冒頭の「1行目:」の説明）、plugins/statusline/scripts/statusline.sh:981-988（1 行目の出力）

## 4. テスト

- [ ] 4.1 新しい bats を作る。setup で `CLAUDE_CONFIG_DIR` と `HOME` を一時ディレクトリに向け、`<config>/plugins/cache/x/statusline/1/` にプラグインの `scripts/` を複製したものを `CLAUDE_PLUGIN_ROOT` にする（本体を「別の内容」にするときはこの複製を書き換える。リポジトリのファイルは触らない）。spec の全シナリオを 1 つずつテストにする: install.sh の記録（導入・内容が同じ・dry-run は記録を書かず印も残す・打ち直した直後に印が無い）、記録どおりの古いコピーが `cmp` で本体と一致（statusline.sh と helper）、1 行書き足したコピーは変わらず描画の 1 行目に `更新あり` が出る、記録ファイルが無いコピーは上書きしない、コピーを手で本体と同じ内容に戻すとフックが印を消す、印が無ければ `更新あり` が出ない、古いコピーには systemMessage が出て新しいコピーには出ない、`<config>/plugins/` の外の CLAUDE_PLUGIN_ROOT と空の CLAUDE_PLUGIN_ROOT では何も変わらず exit 0、未導入なら何も作らない。触る範囲: plugins/statusline/tests/statusline-copy-update.bats（新規）、plugins/statusline/tests/statusline.bats:1-40（setup の書き方を流用するために読むだけ）
- [ ] 4.2 `bats plugins/statusline/tests/` と、hooks.json を検査するリポジトリ側のテスト（`tests/lint-plugin-validate.bats`・`tests/hook-python-isolation.bats`）と `tests/injection-budget.bats` を走らせ、exit 0 を確かめる。触る範囲: なし（実行のみ）

## 5. 案内文と変更の記録

- [ ] 5.1 README の「導入」節の「プラグインを更新したら `/statusline:setup` を再実行する」を、手を入れていないコピーはセッション開始時に自動で揃い、手を入れたコピーは 1 行目に `更新あり /statusline:setup` が出ること・記録が無い既存のコピーは一度打ち直すと以後自動になること・打ち直すと「更新あり」がすぐ消えることに書き換える。「本体のセッションコストの記録」節の「プラグインを更新したあと `/statusline:setup` を再実行すると記録が始まる」も、自動で揃うこと（手を入れたコピーは打ち直しが要ること）に合わせて直す。「カスタマイズ」節の「プラグイン更新では消えない」の注記を、手を入れたコピーは自動では上書きされないことに合わせて直す。「テスト」節に新しい bats の 1 文を足す。触る範囲: plugins/statusline/README.md:47-58（導入）、plugins/statusline/README.md:65（本体のセッションコストの記録）、plugins/statusline/README.md:182-184（カスタマイズ）、plugins/statusline/README.md:202-209（テスト）
- [ ] 5.2 `/statusline:setup` の報告の案内のうち「プラグイン更新で消えない」の行を、手を入れたコピーは自動では上書きされず `更新あり` が出ることに合わせて直す。触る範囲: plugins/statusline/commands/setup.md:74-79
- [ ] 5.3 変更の記録を書く（既存の `changes/*.md` と同じ形: 見出しに issue 番号、何が変わったか・利用者側の初回の打ち直し・戻し方）。触る範囲: plugins/statusline/changes/1113.md（新規）

## 6. 実機確認（本体の担当）

- [ ] 6.1 主の Mac で新しいセッションを開き、ステータスラインが最新版になるか「更新あり」（古いコピーならセッション開始時の案内）が出ることを確かめ、エピック genetta-inc/flatmate#1656 にコメントする。W は担当しない。触る範囲: なし（実機確認のみ）
