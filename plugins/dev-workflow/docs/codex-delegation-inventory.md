# Codex に委譲している箇所の一覧

Codex を呼ぶ、または呼び方を書いている手順書・スクリプトの一覧（issue #324）。表は参照と分類だけを持つ。工程の順序、レビューの回数、ゲートの条件などの正本は複製せず、各行のファイルと `references/codex-develop.md` が持つ。

置き場を `references/codex-develop.md` の表の拡張にしなかった理由は、そのファイルが develop の起動のたびに読まれ、リポジトリのルートの `tests/develop-startup-budget.txt` の予算で測られているため。呼び出し元の列を足すと、起動ごとの読み込み量が増える。

## 区分

| 区分 | 意味 |
|---|---|
| 移行済み | adapter 経由の前景実行（`codex-develop.py request` で投げ先を解決し、`codex-worker.py run` を前景コマンドとして動かす経路）の手順、または入口 |
| 残置 | adapter を通らず、G や手順書が `codex exec`・companion を直接呼ぶ従来の経路。移行はこの表の範囲に入れない |
| 実装 | 経路を実現するスクリプトの本体 |
| 言及のみ | Codex の呼び出しの語を含むが、自分では呼ばず、手順の正本は別のファイルにある（説明・参照・コメント・分類表・出力例） |
| 委譲外 | Codex（App Server）を起動するが、作業を委ねない（使用量の取得・読み取りだけの試作） |

## 表

パスはリポジトリのルートからの相対パス。検査は `plugins/dev-workflow/tests/codex-delegation-inventory.bats`。

| ファイル | 役割 | 区分 |
|---|---|---|
| `plugins/dev-workflow/commands/develop.md` | develop の入口。実行先オプションを `codex-develop.py request` へ渡す | 移行済み |
| `plugins/dev-workflow/references/codex-develop.md` | 手動 develop provider adapter の正本。委譲 3 手順と、委譲箇所と phase と role の表 | 移行済み |
| `plugins/dev-workflow/docs/codex-develop.md` | 手動で Codex 経路を試す人向けの使い方 | 移行済み |
| `plugins/dev-workflow/scripts/CODEX-WORKER.md` | 前景コマンド `codex-worker.py run` の使い方 | 移行済み |
| `plugins/dev-workflow/skills/develop/SKILL.md` | 本体が role ごとに `request` を呼び、投げ先を選ぶ。従来経路の G の説明も含む | 移行済み |
| `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` | R1 のモデルを `request --phase spec-review` で得る | 移行済み |
| `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` | レビュー failed からの昇格で `request --failure` を呼ぶ | 移行済み |
| `plugins/dev-workflow/skills/pr-review-gate/stages/triage-escalation.md` | failed の原因分類と `request --failure` の正本（triage.md から移動） | 移行済み |
| `plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md` | 従来経路で G が `codex exec` と companion を直接呼ぶ | 残置 |
| `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` | G の経路の判別。`レビュー経路: 従来` のとき G が Codex を直接呼ぶ | 残置 |
| `plugins/dev-workflow/references/subagent-waiting.md` | `codex exec` 直叩きと companion の完了待ちの書き方（従来経路が使う） | 残置 |
| `plugins/dev-workflow/scripts/codex-develop.py` | `request` の本体。role・格・account の解決と依頼ファイルの作成。使用量の取得で App Server も起動する | 実装 |
| `plugins/dev-workflow/scripts/codex-worker.py` | 前景コマンドの本体。App Server を起動して 1 ターンを実行する | 実装 |
| `plugins/dev-workflow/scripts/headroom.py` | 残量の判定で `codex-develop.py` を読み込む | 実装 |
| `plugins/dev-workflow/scripts/tier_caps.py` | 格の上限（`codex-develop.py` と共有）。コメントで言及 | 言及のみ |
| `plugins/dev-workflow/scripts/usage_view.py` | 使用量の実効値（`codex-develop.py` と共有）。コメントで言及 | 言及のみ |
| `plugins/dev-workflow/scripts/agent-model-guard.sh` | Fable の起動を止める hook。コメントで言及 | 言及のみ |
| `plugins/dev-workflow/README.md` | プラグインの説明 | 言及のみ |
| `plugins/dev-workflow/references/model-tiers.md` | 格とモデルの対応の説明 | 言及のみ |
| `plugins/dev-workflow/skills/develop/references/decision-criteria.md` | 残量モードの判定基準 | 言及のみ |
| `plugins/dev-workflow/skills/develop/references/pre-classification.md` | `--pre-class` に渡す分類の表 | 言及のみ |
| `plugins/dev-workflow/skills/develop/references/roles/worker/common.md` | 残量モードの適用を `request` に任せる旨の 1 行（昇格トリップワイヤー） | 言及のみ |
| `plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md` | レビュアー向けの指示。Codex が返す形の読み替え | 言及のみ |
| `plugins/dev-workflow/templates/escalation-tripwires.md` | 昇格の段と格の表 | 言及のみ |
| `plugins/dev-workflow/docs/provider-compat-update.md` | Claude / Codex の更新時の確認手順。呼び出しの語は手順の説明に出るだけ（#325） | 言及のみ |
| `plugins/worktree/references/wt-clean-orphan-detection.md` | 居残りプロセスの判定。`ps` の出力例に `codex app-server` が出る | 言及のみ |
| `plugins/statusline/scripts/statusline-codex.py` | ステータスラインの Codex 行。使用量の取得で App Server を起動する | 委譲外 |
| `scripts/poc/codex-appserver/poc.py` | App Server の読み取りだけの試作 | 委譲外 |

## 検査の読み方

`plugins/dev-workflow/tests/codex-delegation-inventory.bats` は、リポジトリの追跡ファイルから次の語を含むものを探し、この表に無ければ落ちる。表にあるのに語を含まなくなったファイルも落ちる。

`codex exec`・`codex-companion`・`codex-worker.py`・`codex-develop.py`・`codex-rescue`・`codex:adversarial-review`・`codex review`・`codex app-server`・引用符で囲んだ `'app-server'`（`['codex', 'app-server', ...]` や `[binary, 'app-server']` のような App Server の起動の引数）

検索から外すもの: 変更の記録（`changes/`・CHANGELOG）、テスト（`tests/`）、要件の本文（`openspec/`）、過去の記録のアーカイブ（`archive/` と、過去の自律実行の成果物の置き場）、この表。いずれも呼び出しの手順ではなく記録・検査・要件の本文で、手順の正本は上の表の行が指す。新しい呼び出し元を足したら、表に 1 行足す。
