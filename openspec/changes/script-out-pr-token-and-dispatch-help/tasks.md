# Tasks

行番号は仕様づくりの時点（基準 HEAD `353b5393`）の値。編集前に該当範囲を読み直す。テストが先、実装があと。

## 1. PR トークン計測のラッパー

- [ ] 1.1 `plugins/dev-workflow/tests/pr-token-measure.bats` を新規に書く。上の 4 つのシナリオ（連結・取得失敗で集計を呼ばない・exit 2 のまま・CODEX_HOME の追加）と引数エラーを、`gh` と 2 つのスクリプトを差し替えて検査し、実装前に失敗することを確かめる。触る範囲: plugins/dev-workflow/tests/pr-token-measure.bats（新規）、plugins/dev-workflow/tests/pr-token-budget.bats:1-60（差し替えの書き方の手本）
- [ ] 1.2 `plugins/dev-workflow/scripts/pr-token-measure.sh` を新規に書く。触る範囲: plugins/dev-workflow/scripts/pr-token-measure.sh（新規）、plugins/dev-workflow/scripts/codex-records.sh:1-40（呼び方と exit code）
- [ ] 1.3 `pr-token-budget.md` の「計測」の bash を 1 コマンドの呼び方に置き換え、`codex-records.sh` が失敗したときの段落を「ラッパーが exit 1 を返す」に合わせて縮める。`develop-skill.bats` の該当断言（706・765 行目付近）と `tests/develop_startup_contract.py:21,59` を付け替える。触る範囲: plugins/dev-workflow/skills/develop/references/pr-token-budget.md:21-30、plugins/dev-workflow/tests/develop-skill.bats:669-800、tests/develop_startup_contract.py:15-65

## 2. epic-dispatch.sh --help

- [ ] 2.1 `epic-dispatch.bats` に `--help` のテスト（出力語・exit 0・副作用なし・既存の使い方が不変・出力語の一覧と実装の突き合わせ）を足し、実装前に失敗することを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（末尾に追加。使い方の既存テストは 606・1421・1580・1925 行目付近）
- [ ] 2.2 `epic-dispatch.sh` に `--help` / `-h` を足し、3 行目のコメントの `epic.md「回し方」` を `epic-loop.md` に直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-5、plugins/dev-workflow/scripts/epic-dispatch.sh:250-275（usage）
- [ ] 2.3 `epic-loop.md` の出力語の説明（手順 1〜4 と「同時に動く子の上限」）を消し、`--help` への参照と「止まって主に報告する／進む」の分類表にする。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:19、57-63、75

## 3. 予算と記録

- [ ] 3.1 手順書の字数を前後で測り（`wc -m`・`wc -c`）、`tests/develop-orchestrator-reference-budget.txt` と `tests/develop-epic-scene-budget.txt` の該当行を実測に合わせて下げる。`tests/injection-budget.txt` は常時注入に触れないので変えない（変わるなら理由を PR 本文に書く）。触る範囲: tests/develop-orchestrator-reference-budget.txt:1、tests/develop-epic-scene-budget.txt:1-11
- [ ] 3.2 `plugins/dev-workflow/changes/1686.md` に変更の記録を書く（出した 2 候補・出さない 3 候補と理由・字数の前後）。触る範囲: plugins/dev-workflow/changes/1686.md（新規）
- [ ] 3.3 `./scripts/test.sh` と `./scripts/lint.sh` を通す（検証のみ）。触る範囲: scripts/test.sh、scripts/lint.sh
