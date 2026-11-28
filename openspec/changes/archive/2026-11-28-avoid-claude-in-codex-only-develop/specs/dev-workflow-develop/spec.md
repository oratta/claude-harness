## MODIFIED Requirements

### Requirement: 画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす
本体は、V が必要なとき、開始時と同じ実行先指定・account-home を付けて `codex-develop.py request` に画面確認の依頼を渡さなければならない（MUST）。Claude を使わない構成では V を起こさず、起動不可の理由を (3b) の W に渡し、画面証拠を作らず既存の動作確認の保留経路へ進まなければならない（MUST）。判定の守備範囲は `manual-codex-develop` の要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従う。以下の V の起動・return の規則は、request が起動を許可した場合に適用する。

本体は W の (3a) の return の `画面確認:` の行が `要る` のときだけ、(3b) を指示する前に画面確認役 V を spawn しなければならない（MUST）。`不要` のときは V を起こしてはならない（MUST NOT）。V は `subagent_type: general-purpose`・`model: sonnet` で起こし（SHALL。ブラウザの道具を持つ既存の種別を使い、新しい種別を作らない）、名前は `V-<記録先番号>-<n>`、description は `V: screen check for #N` とする（SHALL。先頭に役の略号を置く W / R1 / G の description の形に揃える。`scripts/subagent-context-audit.sh` の役割別集計は今は V を `unknown` に数え、V を集計の役に足すことはこの change の範囲外）。V の指示書は `skills/develop/references/roles/screen-checker.md` に置かなければならない（MUST）。

本体は V に、W の `画面確認:` の行と W の worktree のパスを渡し、`isolation` を付けずに起こさなければならない（MUST。V は W が実装した作業ツリーをそのまま見る）。V が dev server を起動するときは `rules/dev-server.md` に従い、同じプロジェクトのサーバーを二重に起動せず、他のプロジェクトのプロセスを止めてはならない（MUST NOT）。V が dev server を起動したときは、return に起動したポートを書く（SHALL）。

V はファイルを編集してはならず、commit・push・記録先への投稿もしてはならない（MUST NOT）。V の return の 1 行目は `^画面確認結果: (合格|不合格|実行不能)$` に一致しなければならない（MUST）。

- `合格`: 2 行目以降に、開いた URL・見た要素・観測した値を書く（MUST）。本体はその return を (3b) の W に渡し（MUST）、(3b) の W はそれを動作確認の証拠の入力にする（SHALL）
- `不合格`: 2 行目以降に、期待と違った観測を書く（MUST）。本体は (3b) に進まず、W を (3a) で再開して直させなければならない（MUST）。`不合格` の回数は本体が、同じ `画面確認:` の行（見る点が同じもの）ごとに数える（SHALL）。2 回目の `不合格` を受けたら、本体は昇格トリップワイヤーの失敗ループ（同じテストが 2 連続で落ちた）と同じ扱いにし、原因が判断側か実行側かの分類も従来どおり本体が行う（SHALL）
- `実行不能`: Chrome 拡張が繋がらない・無人実行で拡張が無いなど、観測できなかった理由を書く（MUST）。本体は (3b) の W に「画面確認は実行不能」と理由を渡し、(3b) の W は画面確認の証拠を書かない（SHALL）。そのあとは pr-review-gate の既存の保留経路（自力で検証できない動作確認を主に依頼する経路）に委ねる（SHALL）。V は待ったり、主に直接依頼したりしてはならない（MUST NOT）

V は数ターンで終わる役なので、SendMessage で再開してはならない（MUST NOT）。もう一度確認が要るときは新しい V を起こす（SHALL）。

#### Scenario: 画面確認が要るときだけ V を起こす
- **WHEN** request が V の起動を許可し、W の (3a) の return に `画面確認: 要る — http://localhost:3000/settings / 保存ボタンを押すとトーストが出る` がある
- **THEN** 本体は (3b) の前に V を `general-purpose`・`model: sonnet`・`isolation` 無しで起こし、W の `画面確認:` の行と worktree のパスを渡し、V の return を (3b) の W に渡す

#### Scenario: 画面確認が要らないときは V を起こさない
- **WHEN** W の (3a) の return に `画面確認: 不要` がある
- **THEN** 本体は V を起こさずに (3b) を指示する

#### Scenario: V がブラウザの道具を使える
- **WHEN** Chrome 拡張が繋がった環境で V を起こし、1 ページを開かせる
- **THEN** V は `mcp__claude-in-chrome__*` の道具でページを開き、`画面確認結果: 合格` または `不合格` と観測した内容を返す

#### Scenario: 拡張が繋がらないときは既存の保留経路に落とす
- **WHEN** V が `画面確認結果: 実行不能` を返す
- **THEN** 本体は (3b) の W に実行不能とその理由を渡し、(3b) の W は画面確認の証拠を書かず、動作確認は pr-review-gate の保留経路で主に依頼される

#### Scenario: 不合格なら (3a) に戻す
- **WHEN** V が `画面確認結果: 不合格` を返す
- **THEN** 本体は (3b) を指示せず、V の観測を渡して W を (3a) で再開する

#### Scenario: 同じ画面確認の 2 回目の不合格は失敗ループに当てる
- **WHEN** 同じ `画面確認:` の行について、W を (3a) で再開したあとに起こした新しい V が再び `画面確認結果: 不合格` を返す
- **THEN** 本体はこれを失敗ループとして扱い、原因を判断側か実行側かに分類して、昇格トリップワイヤーの手順で次の担い手を決める

#### Scenario: Claude を使わない構成では画面確認が要っても V を起こさない
- **WHEN** codex-standard で W が `画面確認: 要る` を返す
- **THEN** 本体は同じ指定で request を通し、起動不可を受けて V を起こさず、理由を (3b) の W に渡す。画面確認済みとは記録せず、既存の動作確認の保留経路に進む

### Requirement: Codex がオフのとき自動選択は Claude だけの構成を返し、明示指定は拒否する
`plugins/dev-workflow/scripts/codex-develop.py` は、レジストリの `codex.enabled` が `false`（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」）のとき、次のとおり動かなければならない（SHALL）。

Claude の役が実行可能な場合の自動選択（profile も旧形式も無指定）は、Codex の週次の余裕の値にかかわらず、構成 `claude-default`・reason `codex-off` を返す。Codex の使用量を取得せず（app-server の起動もキャッシュの更新もしない）、selection evidence の `codex` ブロックは `account`・`margin`・`fetched_at` を `null`、`enabled` を `false` とする。Claude の余裕の評価と、`claude` ブロックの形は変えない。`select_configuration` は、`codex_enabled` を引数に取り（既定は真）、偽なら余裕の値にかかわらず `('claude-default', 'codex-off')` を返す。

`codex-role-profiles` の要件「claude が無い環境では Codex のみを選ぶか起動前に止まる」の実行可否判定を先に適用しなければならない（MUST）。CLI が必要な本体で claude が無く、Codex もオフなら、Claude 既定構成を返さず起動前に blocked・exit 2 とし、依頼ファイルを作ってはならない（MUST NOT）。実行可否判定の入力と守備範囲は同要件に従う。

明示指定は、オフのとき黙って Claude に差し替えてはならない（MUST NOT）。旧形式（`--account` / `--model`）と、いずれかの role の executor が `codex` の profile（`--profile`）は、依頼ファイルを作らず、`status: blocked` と exit 2 で拒否する。エラー文にはオフであること、戻し方（`codex.enabled` を `true` にするか `codex` のキーを消すこと）、読んだ登録簿のパスを入れる。この拒否は、アカウント対応表の検査（`account is not registered` など）より先に行う。executor が `codex` の role を 1 つも持たない profile は拒否しない。

`codex.enabled` の読み方（入力の出どころ、オフになる条件が `false` との一致 1 つであること、書き損じを防ぎ切ることを完了条件にしないこと）は `usage-account-registry` の要件「Codex を codex.enabled でオフにできる」の守備範囲に従い、ここで独自の検査を足さない（SHALL）。

Claude の役が実行可能な環境で、`codex.enabled` が無い、または `false` 以外のとき、選ばれる構成・reason・selection evidence・依頼ファイルは変更前と同一でなければならない（SHALL）。

#### Scenario: オフなら Codex の余裕が大きくても Claude だけを選ぶ
- **WHEN** Claude の役が実行可能で、`codex.enabled` が `false` で、Codex の週次の余裕が Claude より大きい（両方 0 以上）状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off` で、`codex.enabled` は `false`。Codex の使用量の取得は呼ばれない

#### Scenario: オフで Claude にも余裕が無いとき
- **WHEN** Claude の役が実行可能で、`codex.enabled` が `false` で、Claude の余裕が負（または欠測）の状態で自動選択する
- **THEN** 構成は `claude-default`、reason は `codex-off`（`no-provider-has-headroom` ではない）

#### Scenario: オフで Codex の profile を明示すると拒否する
- **WHEN** `codex.enabled` が `false` で、`--profile codex-standard` を指定して `request` を実行する
- **THEN** exit 2 で終わり、`status` は `blocked`、エラー文にオフであることが出る。依頼ファイルは作られない

#### Scenario: オフで旧形式を明示しても拒否する
- **WHEN** `codex.enabled` が `false` で、`--account NAME --model MODEL` を指定して `request` を実行する
- **THEN** exit 2 で終わり、エラー文にオフであることが出る

#### Scenario: オフの拒否は対応表の検査より先
- **WHEN** `codex.enabled` が `false` で、`--account-home` を渡さずに `--profile codex-standard` を指定する
- **THEN** エラー文は `account is not registered` ではなくオフであることを示す

#### Scenario: 設定が無い環境では変わらない
- **WHEN** Claude の役が実行可能で、`codex` を書いていないレジストリ、レジストリ無し、`codex.enabled` が `true` のレジストリのそれぞれで、同じ使用量の入力で自動選択する
- **THEN** 3 つとも、選ばれる構成・reason・selection evidence が同一で、`codex` ブロックに `enabled` のキーは無い

#### Scenario: CLI 不在かつ Codex オフなら Claude 既定構成に倒さない
- **WHEN** CLI が必要な本体で PATH に実行可能な claude が無く、`codex.enabled` が `false` である
- **THEN** claude 不在と Codex オフの理由を含む blocked を返して exit 2 で止まる。Codex の使用量取得や役の起動、実行可能な依頼ファイルの作成をせず、claude-default を返さない

### Requirement: G の needs-carryover-judge を受けた本体の動き

本体は判定役の起動前に、開始時と同じ実行先指定・account-home を付けて `codex-develop.py request` に引き継ぎ判定の依頼を渡さなければならない（MUST）。Claude を使わない構成で起動不可なら、判定役を起こさず、既存書式の `引き継ぎ判定: 判断できない` と非起動の理由を PR に代理投稿し、その URL を渡して合格処理の G を新しく起こさなければならない（MUST）。主への確認は G の既存手順に従う。分類・非起動の守備範囲は `manual-codex-develop` の要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従う。以下の通常起動の義務は、request が起動を許可し、共有枠が depleted でない場合に適用する。同じ組での再要求に起こし直さない規則と depleted 時の非起動は維持する。

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の Status `needs-carryover-judge` を受けた本体の動きを書かなければならない（MUST）: 本体は PR トークン上限を測ってから、pr-review-gate の `stages/carryover-judge.md` 手順 3-c の依頼の書き方で `subagent_type: dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に代理投稿し、判定と記録の URL を渡して合格処理の G を新しく起こさなければならない（MUST）。`SHARED_BUDGET_MODE=depleted` のときは判定役を起こさず、3-c の書式の `引き継ぎ判定: 判断できない` の記録を投稿して同じく合格処理の G を起こす（MUST）。本体は判定を受けて自分で宣言を投稿したり、ラベルを付けたり、主に聞いたりしてはならない（MUST NOT。引き継ぐか主に聞くかは合格処理の G が決める）。ただし、判定を受けて起こした合格処理の G が同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返したときは、判定役を起こし直してはならず（MUST NOT）、投稿した記録の URL を添えて主に聞かなければならない（MUST）。

#### Scenario: needs-carryover-judge で返った

- **WHEN** request が起動を許可し、共有枠が depleted でなく、G が Status `needs-carryover-judge`・`次の段: 合格処理` で return する
- **THEN** 本体は PR トークン上限を測ってから `dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に投稿し、判定とその URL を渡して合格処理の G を新しく起こす

#### Scenario: 共有枠が depleted のとき

- **WHEN** G が `needs-carryover-judge` で返し、`SHARED_BUDGET_MODE=depleted` である
- **THEN** 本体は判定役を起こさず `引き継ぎ判定: 判断できない` の記録を投稿して合格処理の G を新しく起こし、G が手順 6 で主に聞く

#### Scenario: 判定のあとの G が同じ組で再び返した

- **WHEN** 本体が判定の記録を投稿して起こした合格処理の G が、同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返す
- **THEN** 本体は判定役を起こし直さず、投稿した記録の URL を添えて主に聞く

#### Scenario: Claude を使わない構成では判定役を起こさず G に戻す
- **WHEN** codex-standard で G が `needs-carryover-judge` を返す
- **THEN** 本体は同じ指定で request を通し、起動不可を受けて判定役を起こさず、`引き継ぎ判定: 判断できない` と理由を PR に投稿する。その URL を渡して合格処理の G を新しく起こし、主への確認は G が扱う

### Requirement: G の needs-no-point-check を受けた本体の動き

本体は判定役の起動前に、開始時と同じ実行先指定・account-home を付けて `codex-develop.py request` に論点なし確認の依頼を渡さなければならない（MUST）。Claude を使わない構成で起動不可なら、判定役を起こさず、既存書式の `論点なしの確認: 判断できない` と非起動の理由を PR に代理投稿し、その URL を渡して合格処理の G を新しく起こさなければならない（MUST）。主への確認は G の既存手順に従う。分類・非起動の守備範囲は `manual-codex-develop` の要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従う。以下の通常起動の義務は、request が起動を許可し、共有枠が depleted でない場合に適用する。同じ組での再要求に起こし直さない規則と depleted 時の非起動は維持する。

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の Status `needs-no-point-check` を受けた本体の動きを書かなければならない（MUST）: 本体は PR トークン上限を測ってから、`subagent_type: dev-workflow:decider`・`model: opus` の決める役を起こし、宣言の本文と PR の差分だけを渡して論点なしかを判定させ、dev-workflow-pr-review-gate の要件「論点なしの確認の記録を PR に残す」の形の記録を PR に投稿し、記録の URL を渡して合格処理の G を新しく起こさなければならない（MUST）。`SHARED_BUDGET_MODE=depleted` のときは決める役を起こさず、`論点なしの確認: 判断できない` の記録を投稿して同じく合格処理の G を起こす（MUST）。

#### Scenario: Status の一覧に needs-no-point-check がある

- **WHEN** SKILL.md の G の Status → 読むファイルの表と `references/roles/gate-runner.md` の段と Status の表を読む
- **THEN** どちらにも `needs-no-point-check` がある

#### Scenario: needs-no-point-check で返った

- **WHEN** request が起動を許可し、共有枠が depleted でなく、G が Status `needs-no-point-check`・`次の段: 合格処理` で return する
- **THEN** 本体は PR トークン上限を測ってから `dev-workflow:decider`・`model: opus` の決める役を起こし、記録を PR に投稿し、記録の URL を渡して合格処理の G を新しく起こす

#### Scenario: 共有枠が depleted のとき

- **WHEN** G が `needs-no-point-check` で返し、`SHARED_BUDGET_MODE=depleted` である
- **THEN** 本体は決める役を起こさず `論点なしの確認: 判断できない` の記録を投稿して合格処理の G を新しく起こし、G が手順 6 で主に聞く

#### Scenario: 確認のあとの G が同じ宣言で再び返した

- **WHEN** 本体が記録を投稿して起こした合格処理の G が、同じ宣言の URL と同じ HEAD で再び `needs-no-point-check` を返す
- **THEN** 本体は決める役を起こし直さず、投稿した記録の URL を添えて主に聞く

#### Scenario: Claude を使わない構成では判定役を起こさず G に戻す
- **WHEN** codex-standard で G が `needs-no-point-check` を返す
- **THEN** 本体は同じ指定で request を通し、起動不可を受けて判定役を起こさず、`論点なしの確認: 判断できない` と理由を PR に投稿する。その URL を渡して合格処理の G を新しく起こし、主への確認は G が扱う
