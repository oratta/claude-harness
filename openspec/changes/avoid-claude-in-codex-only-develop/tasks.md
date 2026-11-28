## 1. 4 例外の依頼と非起動

- [ ] 1.1 4 例外を識別できる request 入力と起動不可の結果を実装する。先に codex-standard の各例外が実行可能な依頼を作らず、Claude/Codex の起動呼び出しが 0 で、通常の書き込み不要レビューが継続するテストを書き、同テストの成功で確認する。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:24-62（PHASES）、plugins/dev-workflow/scripts/codex-develop.py:737-869（request）、plugins/dev-workflow/tests/test_codex_develop.py:112-180、plugins/dev-workflow/tests/test_codex_develop.py:1083-1203
- [ ] 1.2 V・一時書き込みレビュー・引き継ぎ判定・論点なし確認の呼び出しを request 結果に従わせる。起動不可時の未完了／実行不能／判断できないの既存経路と dispatch 記録を手順に書き、各呼び出し元が直に Claude を起こさないことを同テストの文書契約で確認する。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:137-138、plugins/dev-workflow/skills/develop/SKILL.md:205-219、plugins/dev-workflow/skills/develop/references/gate-result.md:66-85、plugins/dev-workflow/references/codex-develop.md:54-77、plugins/dev-workflow/tests/test_codex_develop.py:1888-1968

## 2. Claude の実行可否と自動選択

- [ ] 2.1 CLI が必要な本体の claude 不在を明示的に評価し、余裕が 0／正の Codex は単独構成、負／欠測／未登録／オフなら起動前 blocked・exit 2 とする。先に PATH 不在・記録上の Claude margin が正の fixture を含む回帰を書き、依頼ファイルと起動が無いこと、Claude 本体の従来選択が同じこと、明示 profile を上書きしないことを確認する。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:144-165、plugins/dev-workflow/scripts/codex-develop.py:363-387、plugins/dev-workflow/scripts/codex-develop.py:737-869、plugins/dev-workflow/tests/test_codex_develop.py:390-480、plugins/dev-workflow/tests/test_codex_develop.py:884-906、plugins/dev-workflow/tests/test_codex_develop.py:1280-1395
- [ ] 2.2 adapter に Claude 本体の実行可否と CLI 不在専用分岐・停止理由を記し、テストの文書契約で通常の選択表を維持していることを確認する。触る範囲: plugins/dev-workflow/references/codex-develop.md:15-21、plugins/dev-workflow/tests/test_codex_develop.py:1900-1918

## 3. 記録と統合確認

- [ ] 3.1 変更の記録を作り、python3 plugins/dev-workflow/tests/test_codex_develop.py と openspec validate avoid-claude-in-codex-only-develop --type change --strict の exit 0 を記録する。対象変更に必要な既存検査を収集して実行し、未導入・失敗も報告する。変更量が増えたら #1859 の粒度入力を更新してから進む。触る範囲: plugins/dev-workflow/changes/1859.md（新規）、plugins/dev-workflow/tests/test_codex_develop.py:1-2070、openspec/changes/avoid-claude-in-codex-only-develop/（本 change の検証）
