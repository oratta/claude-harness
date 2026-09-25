## MODIFIED Requirements

### Requirement: W の (3) は 2 回の return に分かれる
本体がサブエージェントのコンテキスト量を測れるのは、W を SendMessage で再開する直前（＝ W が return した直後）だけである。したがって return の区切りの数がそのまま計測点の数になる。W の実装以降の工程 (3) は、次の 2 つの return に分けなければならない（MUST）。

- **(3a) 実装＋verify**: `/opsx:apply`（または直叩きの TDD）と `/opsx:verify` までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `/opsx:archive`（仕様化した場合）・PR を Draft のまま用意すること（記録先が Draft PR ならそのまま使い、issue が記録先なら `gh pr create --draft` で作る。Ready には切り替えない）・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。**(3a) は実装後、テスト・lint・ビルドの手順で、`.github/workflows/*.yml` の `run:` から CI が流す検査コマンドを機械的に収集し、収集したコマンドをすべて実行しなければならない（MUST）**。コマンド名をこのリポジトリ固有の値（`scripts/test.sh` など）に固定してはならない（MUST NOT。develop は複数リポジトリで使われ、CI の構成はリポジトリごとに異なるため）。workflow ファイルが存在しない、または `run:` から検査コマンドを収集できないときは、慣例コマンド（`scripts/test.sh` 等）へのフォールバックを許容する（MAY）。**(3a) の return には、収集した検査コマンドの一覧・実行したテストコマンドと exit code、および `/opsx:verify` の合否を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`/opsx:verify` の合否が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。CI 由来の検査コマンドをすべて return に含めることで、G がゲートを合格にしたあとに CI の一部（このリポジトリでは shellcheck）が落ち、W・レビュー・G をもう 1 周回す再発を防ぐ。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば、(3b) を指示せず (4) へ進まなければならない（MUST）。古いキャッシュの `worker.md` を読んだ W は (3a) の指示を受けても (3) を通しで終えて返してくるため、文字列照合で routing すると PR の作成と仕様宣言の投稿が二重に走るためである。

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker.md` の実装以降の節を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) が CI workflow 定義から検査コマンドを収集してすべて実行する義務と、return に収集した検査コマンド一覧・実行したテストコマンドと exit code・`/opsx:verify` の合否を含める義務が書かれ、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: CI の定義から検査コマンドを収集する
- **WHEN** `references/roles/worker.md` の (3a) 手順 5 を読む
- **THEN** `.github/workflows/*.yml` の `run:` から検査コマンドを拾うこと、コマンド名をリポジトリ固有の値に固定しないこと、拾った検査コマンドをすべて実行すること、workflow が無い場合の慣例コマンドへのフォールバックが許容されることが書かれている

#### Scenario: 旧世代の W が (3) を通しで返してきても (3b) を再指示しない
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** 本体は次に指示する工程を自分が指示した工程で決めると書かれており、工程名の文字列照合では決めないことと、(3a) の return に PR 番号と仕様宣言のコメント URL が揃っていれば (3b) を指示せず次へ進むことが書かれている

#### Scenario: worker.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとに払う固定分と、実装の途中で切ると後任が Red のまま止まったテストから再出発すること）が書かれている
