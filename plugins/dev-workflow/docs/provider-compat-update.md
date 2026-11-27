# Claude / Codex の更新時に互換性を確かめて追従する手順

Claude Code または Codex CLI の版が上がったときに、develop の手順が両方で動き続けることを確かめる手順と、確かめた結果の記録の形式（issue #325。エピック genetta-inc/flatmate#698 の子）。この文書は手順と責任範囲だけを持つ。工程の順序・ゲートの条件・Codex を呼ぶ箇所の中身は複製せず、下の正本を指す。

## 責任範囲

共通ルールは provider によらず同じ文面で効く。provider 固有は、投げ先と呼び方だけを持ち、共通ルールを言い換えない。

| 持ち主 | 持つもの | 正本 |
|---|---|---|
| 共通ルール | 工程の順序、W / R1 / G の役割と return の書式、昇格トリップワイヤー、ゲートの条件、手渡しの規則 | `skills/develop/SKILL.md`、`skills/develop/references/roles/`、`skills/pr-review-gate/` |
| provider 固有 | role をどこへ投げるか、model と格の対応、account の解決、前景実行の呼び方 | `references/codex-develop.md`、`scripts/codex-develop.py`、`scripts/codex-worker.py`、`references/codex-role-profiles.json`、`references/model-tier-map.json` |

- Codex を呼ぶ・呼び方を書く箇所の一覧は `docs/codex-delegation-inventory.md`（#324）。更新で壊れる範囲を絞るときは、この表の区分（移行済み・残置・実装）から当たる
- 共通ルールの文を provider 固有のファイルに書き写さない。手渡し規則の本文が正本 1 箇所にあることの逐語一致は `tests/handoff-single-source.bats`（#265）が見る。この検査は逐語の複製だけを拾い、任意の言い換えまでは拾わない
- 手渡しのテンプレートと規則の正本化（#263）は再利用の候補で、この文書では扱わない

## 更新時に確かめる代表ワークフロー

版が上がったら、次を上から順に確かめる。Claude の更新では 1〜3、Codex の更新では 1〜4 を見る。

1. `bash scripts/test.sh` が全件 green（bats と Python のテスト。provider の実呼び出しを含まない）
2. `codex-develop.py request` が代表の phase（`spec-review`、`decider` など）で投げ先と model を返す（`tests/test_codex_develop.py` が覆う）
3. 手動の develop（`/develop` を Claude 構成で 1 件）が、仕様化判断の記録から PR のゲートまで通る
4. 手動の develop を Codex 構成（`docs/codex-develop.md` の手順）で 1 件通し、`codex-worker.py run` が前景で 1 ターンを完了する

1 と 2 は費用なしで毎回回せる。3 と 4 は実モデルを呼ぶので、版の変更が呼び出しの形（引数、出力の形式、認証、App Server の応答）に及ぶと分かったときに回す。回さなかった項目は「未実施」と書き、通ったことにしない。

## 記録の形式

記録先は `plugins/dev-workflow/changes/` の、その更新に対応する issue 番号のファイル（例: `<番号>.md`）。追従が不要だった更新は、下の表だけを該当 issue にコメントする。表は次の列で書く。

| 確認日 | provider | 確認した版 | 項目 | 結果 | 失敗時の扱い |
|---|---|---|---|---|---|
| YYYY-MM-DD | claude / codex | `claude --version` と `codex --version` の出力そのまま | 上の 1〜4 の番号 | 通った / 失敗 / 未実施 | 下の表の行き先 |

版の列は、その作業で実際にコマンドを実行して読んだ値だけを書く。確かめていない版、他の端末の値、更新の告知にあった値は書かない。

## 失敗時の扱い

| 失敗の出方 | 行き先 |
|---|---|
| 1 または 2 が落ちる | 版の変更が原因なら provider 固有のファイルを直す PR を起こす。共通ルールの側が原因に見えるときは、直す前に主に聞く |
| 3 または 4 が落ちる | 落ちた箇所と版を記録し、更新ごとの詳細対応として個別 issue を立てる。この文書の範囲では直さない |
| 4 だけが落ちる | Codex 構成を停止する。role の投げ先を暗黙に別 provider へ切り替えない。再開や構成の変更は `references/codex-develop.md` の「起動と role 解決」に従う |
| 直せずに版を戻せない | その版を使わない旨を issue に残す。版の列には実測値を残し、「失敗時の扱い」の列に「非対応」と書く |

## 不要になった補助処理の見直し

更新で provider 自身が機能を持つようになると、harness 側の補助処理（待ち方の工夫、出力の整形、再試行など）が要らなくなることがある。更新のたびに次を行う。

1. 更新の変更点から、補助処理が埋めていた不足が解消されたかを確かめる（変更履歴を読む。推測で消さない）
2. 該当しそうな補助処理を、`docs/codex-delegation-inventory.md` の「実装」「残置」の行と、共通ルールの側の対応する手順から探す
3. 補助処理を外した状態で、上の代表ワークフローの 1 と 2 を回す。通っても 3 と 4 を回していなければ、消さずに個別 issue にして残す
4. 消すときは、補助処理を呼ぶ側と、一覧表・検査（`tests/codex-delegation-inventory.bats`）の行を同じ PR で直す

## 範囲の外

- 版の更新を自動で検知して追従することの保証はしない。この文書は、人が更新に気づいたときの手順である
- 更新ごとの個別の対応は、その更新の issue で扱う
