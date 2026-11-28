# manual-codex-develop Specification

## Purpose
TBD - created by archiving change codex-develop-role-profiles. Update Purpose after archive.

## Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動開発は旧形式の Codex account/model、または名前付き profile の役割別 executor/account/effort と `model-tier-resolution` の格から引いた model を委譲ごとに解決しなければならない（MUST）。role resolver は要求の値（`requested_tier`・`requested_model`）と適用の値（`tier`・`executed_tier`・`model`）を分けて返さなければならない（MUST）。前景実行では、Claude role は account=current で、resolver が返した `model` で Agent を起動する。Codex role は account 名を呼び出し側の設定から CODEX_HOME へ解決して依頼ファイルへ固定しなければならない（MUST）。profile と旧 account/model の同時指定を拒否し、どちらの executor が失敗しても他方へ fallback してはならない（MUST NOT）。Codex account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返し指定、または同じ対応を書いた JSON ファイルで与え、対応に無い Codex account は拒否しなければならない（MUST）。

#### Scenario: 旧形式の手動依頼
- **WHEN** 人間が Codex の単一 account/model を指定する
- **THEN** burn 窓を要求せず同 account/model で全 Codex 委譲を行い、effort を後付けしない

#### Scenario: 混在設定セットの手動依頼
- **WHEN** 人間が混在 profile を指定して複数の role を順に委譲する
- **THEN** 各委譲は当該 role の executor/account/model/effort だけを解決し、Claude role は Agent、Codex role は前景 request/run を使う

#### Scenario: 前景実行で Codex role の設定を解決する
- **WHEN** executor=codex の role について前景依頼を組み立てる
- **THEN** その role の executor/account/model/effort を依頼ファイルへ固定し、account 名を呼び出し側の対応から解決した CODEX_HOME を同じ依頼に載せ、他 role の設定を持ち込まない

#### Scenario: 解決できない Codex account 名を指定する
- **WHEN** profile の Codex role が指す account 名が、呼び出し側が与えた対応に含まれていない
- **THEN** 依頼ファイルを作らずに拒否し、既定の CODEX_HOME や別 account の CODEX_HOME へ倒さない

### Requirement: 品質工程を維持する
工程管理は develop の正本を使用し、W/R1/G/追加レビュアー/decider の各役割を解決済み executor へ委譲しなければならない（MUST）。executor が Claude でも Codex でも、レビューは作業者と別 thread かつ read-only でなければならない（MUST）。一時書き込みが必要で読み取り役では完了できないレビューは、要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従い、未実行を合格扱いしてはならない（MUST NOT）。

#### Scenario: 仕様に差し戻し
- **WHEN** 独立仕様レビューが修正を要求する
- **THEN** 本体が正本の回数上限を確認し、profile の spec-write executor へ修正を委譲する

#### Scenario: 独立レビューへ到達する
- **WHEN** G が別レビューを要求し、読み取り役で実行できる
- **THEN** 本体は profile の impl-review executor で新しい read-only thread を作り、Claude と Codex のどちらを選んでも同じレビュー契約を適用する

### Requirement: provider指定で品質ワークフローを分岐させない
仕様要否・レビュー・検証・工程順序は既存 develop の正本に一元化しなければならない（MUST）。adapter は解決済み executor に応じた起動・停止・結果の受け取りだけを担当し、独自の仕様必須条件、品質 gate、永続 transport state を設けてはならない（MUST NOT）。phase は役割指示選択ラベルであり工程順序の強制ではない。

#### Scenario: 仕様不要の通常判断
- **WHEN** W が既存 develop に従い仕様化判断をしないと理由付きで返す
- **THEN** 本体はその記録を使って既存 develop の実装工程へ進み、adapter は仕様 artifact や R1 承認を追加要求しない

#### Scenario: 仕様が必要な通常判断
- **WHEN** W が既存 develop に従い仕様化すると判断する
- **THEN** 本体は正本の仕様作成・R1 レビュー・承認条件を適用し、adapter は指示された役割を解決済み executor へ委譲する

#### Scenario: 既存の検証で失敗する
- **WHEN** 正本が要求する検証で失敗する
- **THEN** 本体と担当役割は既存 develop の差戻し規則に従い、adapter に別の検証手順や承認 store を作らない

### Requirement: 輸送結果を品質承認にしない
worker の completed を品質合格として扱ってはならない（MUST NOT）。本体は最終回答と error_kind を確認して既存 develop のレビュー記録/判断契約へ渡さなければならない（MUST）。worker の認証固定と read-only の強制を維持しなければならない（MUST）。前景実行が結果を返さず終了した場合は、保存依頼の replay や別 provider/account への fallback を行わず、記録先と worktree からその工程を fresh phase としてやり直さなければならない（MUST）。

#### Scenario: 途中APPROVEと最終差戻し
- **WHEN** commentary に APPROVE があり最終回答は REQUEST_CHANGES である
- **THEN** worker は最終回答を返し、本体は既存レビュー契約で差戻しを扱う

#### Scenario: 実行エラーを伴う結果
- **WHEN** 結果に認証変更や未対応要求の error_kind がある
- **THEN** 本体は品質承認として記録せず、実行失敗として扱う

#### Scenario: 前景実行の結果が得られないまま終わる
- **WHEN** 前景実行が結果の JSON を返す前に終了する
- **THEN** 本体は保存 request を再送せず、記録先と worktree を見てその工程を fresh phase としてやり直す

### Requirement: 委譲は前景実行の 3 手順で行う
手動 adapter 手順書は、role の設定を解決した直後に executor で一度だけ分岐しなければならない（MUST）。新規の Claude role は canonical role の Agent 呼び出しを使う。Codex role の 1 回の委譲は「その工程に限定した指示を UTF-8 ファイルに書く → `codex-develop.py request` で依頼ファイルを作り `codex-worker.py run` を前景コマンドとして起動する → 完了通知で結果の JSON を読む」の 3 手順で行わなければならない（MUST）。account 名から CODEX_HOME への登録境界は `request` に渡す `--account-home NAME=PATH` または `--account-home-file PATH` だけとし、独立した register command や永続 account registry を設けてはならない（MUST NOT）。手順書に job の受領・再送・run directory・worker state・継続記録の操作を戻してはならない（MUST NOT）。停止は Claude では起動した Agent、Codex では起動した foreground command の停止操作で行わなければならない（MUST）。

Claude role の Agent 呼び出しの `subagent_type` は、canonical role で決めなければならない（MUST）。作業者 W（仕様化判断・仕様作成・仕様差戻し、実装・TDD・verify・修正、archive・Draft PR・仕様宣言）は `dev-workflow:worker`、ゲート実行者 G（ゲートの照合・記録）は `dev-workflow:gate-runner`、G が必要とする独立 PR レビューは `dev-workflow:reviewer`、仕様レビュー R1 は `general-purpose`、`decider` role は `dev-workflow:decider` とする（SHALL）。事前分類に当たる R1 または G が要求したレビュアーを profile の `decider` entry で起こす場合は、従来どおり `dev-workflow:decider` を使う（SHALL）。

名前付き profile では thread の新規作成と再開を profile role 単位で決めなければならない（MUST）。同じ profile role の Claude thread を canonical develop が再開する前には毎回、同じ phase と、今回の再開に当たる格の入力（失敗ループの段なら、その段の `--failure` の値を含む）で `request` を呼び直し、返った `tier` と `model` を、動いている thread の格（起動時に記録した `tier`）と applied model（起動時に記録した `model`）と比べなければならない（MUST）。呼び直しの結果は `tier` と `model` だけを読み、executor・account・依頼ファイルは使わず、構成の選び直しにも使ってはならない（MUST NOT）。返った `tier` が thread の格より低くなく、かつ返った `model` が thread の applied model と同じ場合に限って、既存の名前付き thread を SendMessage で再開する。それ以外（返った `tier` が低い場合と、返った `model` が applied model と違う場合。後者は失敗ループの昇格で格が上がった場合を含む）は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、同じ role の fresh thread を返った `model` で起こして前任の return と成果物を手渡し、要求値・適用値・変更理由を記録しなければならない（MUST）。SendMessage の再開では model を変えられないため、格が上がった場合を SendMessage にすると昇格が起きないまま再開される。profile role が変わる境界、独立レビュー、または executor=codex の委譲では fresh thread を使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

**守備範囲（再開か fresh thread かの判定）**: ①入力の出どころは、本体が再開の直前に呼び直した `request` の結果 JSON の `tier` と `model`、および本体が起動時に dispatch 記録へ残した thread の `tier` と applied model だけである。②拾いたい誤りは、model が変わるのに SendMessage して昇格や降格が黙って起きないこと、呼び直しの結果で executor・account・構成を選び直すこと、失敗ループの段の `--failure` を付けずに呼び直して昇格を取りこぼすことである。③通してよい入力の例: 格は上がったが model が変わらない場合（codex の中位から上位、`tier_cap` で同じ格に下がる構成）は SendMessage で再開してよい。格も model も変わらない通常の再開も同じ。④dispatch 記録の欠けや改ざん、本体が `--failure` の値を誤って選ぶことなど、入力の穴をすべて見つけて塞ぐことはこの要件の完了条件にしない（失敗の原因の分類の守備範囲は `dev-workflow-escalation-tripwires` の要件「昇格トリップワイヤー3本の定義」に従う）。

#### Scenario: 手順書から旧状態操作が消えている
- **WHEN** adapter の通常手順を機械的に検索する
- **THEN** register、job の受領・再送、run directory、worker state、継続記録を操作する手順がいずれも見つからない

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、`requested_model`、`model`、effort を返す
- **THEN** Codex request を作らず、返された `requested_model` を要求 model として保持し、返された `model` で canonical role を Agent に委譲する。本体は残量モードの上限を計算し直さない。W は `subagent_type: dev-workflow:worker`、G は `dev-workflow:gate-runner`、独立 PR レビューは `dev-workflow:reviewer`、R1 は `general-purpose`、`decider` role は `dev-workflow:decider` とし、`exhausted` で `model` が `opus` に下がっても `decider` の subagent_type は変えない。effort は監査情報として保持するだけで Agent の引数に変換しない

#### Scenario: 手順書が canonical role ごとの種別を書く
- **WHEN** `plugins/dev-workflow/references/codex-develop.md` の Claude role の新規起動の段落を読む
- **THEN** W に `dev-workflow:worker`、G に `dev-workflow:gate-runner`、レビュアーに `dev-workflow:reviewer`、`decider` role に `dev-workflow:decider` が書かれ、W / G とレビュアーを `general-purpose` で起こす記述が無い

#### Scenario: Codex role を委譲する
- **WHEN** role resolver が executor=codex を返す
- **THEN** 指示ファイル、request、foreground run の経路を使い、job id や永続 transport state を使わない

#### Scenario: 同じ Claude profile role を再開する
- **WHEN** canonical develop が差戻しまたは次段のため、同じ profile role の名前付き Claude thread を再開する
- **THEN** 再開前に同じ phase と今回の格の入力で `request` を呼び直し、返った `tier` が thread の格より低くなく、返った `model` が thread の applied model と同じ場合に限って、要求 tuple と適用 model を変えず SendMessage で再開する。呼び直しで構成は選び直さない

#### Scenario: 実行側の失敗で Claude の W の格が上がる
- **GIVEN** 中位（applied model=`sonnet`）で起動した名前付きの Claude の W があり、残量モードと構成の上限が無い
- **WHEN** W の 2 回目の失敗が実行側と分類され、本体が `request --phase implement --failure executor` を呼び直すと上位（`opus`）が返る
- **THEN** 既存 thread に SendMessage せず、工程完了または停止確認後に applied model=`opus` の fresh thread を起こして前任の return と成果物を手渡し、変更理由を記録する

#### Scenario: 格が上がっても model が変わらない
- **WHEN** 呼び直しで返った `tier` は thread の格より高いが、返った `model` は thread の applied model と同じである
- **THEN** 本体は SendMessage で再開してよい

#### Scenario: exhausted へ変更後に同じ Claude profile role を再開する
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した名前付き Claude thread がある
- **WHEN** `FABLE_BUDGET_MODE=exhausted` へ変わった後に同じ profile role を再開し、共有枠は depleted でない
- **THEN** 既存 thread に SendMessage せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread を applied model=`opus` で起動し、変更理由=`FABLE_BUDGET_MODE=exhausted` を記録する

#### Scenario: depleted へ変更後に同じ Claude profile role を再開する
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した名前付き Claude thread がある
- **WHEN** `SHARED_BUDGET_MODE=depleted` へ変わった後に同じ profile role を再開する
- **THEN** 既存 thread に SendMessage せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread を applied model=`sonnet` で起動し、変更理由=`SHARED_BUDGET_MODE=depleted` を記録する

#### Scenario: profile role が変わる
- **WHEN** canonical develop の次の委譲で profile role が spec-write から implement のように変わる
- **THEN** 次の role の tuple を解決して fresh thread を起動し、前の thread から会話履歴全体ではなく成果物と必要な要約だけを渡す

#### Scenario: 走行中の委譲を止める
- **WHEN** 本体が走行中の委譲を止める必要がある
- **THEN** 解決済み executor で起動した Agent または foreground command を停止し、別の状態操作を要求しない

### Requirement: 失敗ループの昇格で profile と実装役の設定を差し替えない
`references/codex-develop.md` は、失敗ループでの本体の手順を実行側と判断側それぞれ格の言葉で書かなければならない（MUST）。実行側は `request` に W の phase と `--failure executor` を渡し、返った（上限適用後の）`model` で実行役を起こす（MUST）。判断側は `request --phase decider --failure judgment` が返す投げ先・account・model で決める役を立てる（MUST）。本体は昇格の手段として、profile の作り直し・`--profile` / `--profile-file` の差し替え・返った model と違う model の独自指定や上書き・effort の変更をしてはならない（MUST NOT。返った model を Agent に渡すのは禁止に当たらない）。

#### Scenario: Codex profile で実行側の失敗が起きる
- **WHEN** `codex-standard` の構成で、W の 2 回目の失敗が実行側と分類される
- **THEN** 本体は `request --phase implement --failure executor` を同じ profile の指定で呼び、返った model で実装役を起こし、別の profile を作らず、effort を変えない。残量モードと構成の上限が無いとき、返る model は対応表の上位（codex では中位と同じ値）である

#### Scenario: 判断側の失敗で決める役を立てる
- **WHEN** W の 2 回目の失敗が判断側と分類される
- **THEN** 本体は `request --phase decider --failure judgment` が返した投げ先・account・model で決める役を立て、実行役の格は変えない

#### Scenario: 返った model を Agent に渡すのは独自指定ではない
- **WHEN** 本体が Claude の W を、`request` が返した `opus` を Agent の `model` に渡して起こす
- **THEN** これは既存の契約どおりの起動で、model の独自指定・上書きの禁止に当たらない。`request` が `sonnet` を返したのに `opus` を渡すことは禁止に当たる

#### Scenario: 手順が文書にある
- **WHEN** `references/codex-develop.md` を読む
- **THEN** 失敗ループの実行側と判断側の手順、`--failure` の値、profile の差し替え・model の独自指定や上書き・effort の変更をしないことが書かれている

### Requirement: develop 開始時の profile の指定を工程の途中で変えない
本体は develop 開始時の profile の指定（`--profile NAME`・`--profile-file PATH`・旧形式の account/model・無指定のどれか）を、develop の終わりまで同じ値で `request` に渡さなければならない（MUST）。無指定のときに phase ごとに構成を選び直す既存の規則は変えない。指定を変える必要があるときは、主に承認を求め、記録先に `profile 変更: <変更前の指定> → <変更後の指定>` の行と主の承認の発言を引いたコメントを残してから変えなければならない（MUST）。この要件は文書の規則であり、`request` による機械的な拒否はこの要件の範囲に含めない（#615 の範囲）。

#### Scenario: 途中で外部 profile を作りたくなる
- **WHEN** develop の途中で、本体が別の `--profile-file` を作って渡そうとする
- **THEN** 文書の規則に従い、主の承認と記録先の `profile 変更:` の行が無ければ渡さない

#### Scenario: 規則が文書にある
- **WHEN** `references/codex-develop.md` を読む
- **THEN** 開始時の指定を途中で変えないこと、変えるときの承認の記録の書式が書かれている

### Requirement: 例外 4 役も共通 resolver を通す
本体は、一時領域への書き込みが必要なテスト再実行レビュー、画面確認 V、引き継ぎ判定、論点なし確認のいずれも、起動前に `codex-develop.py request` を通さなければならない（MUST）。開始時の実行先指定と account-home を保持し、依頼の種類を識別できなければならない（MUST）。本体は resolver が返す起動不可を無視して Claude を直接起動してはならない（MUST NOT）。

依頼の分類と起動可否の守備範囲は、要件「Claude を使わない構成では例外 4 役を起動せず主への確認に回す」に従う。

#### Scenario: 4 例外の各呼び出し元が resolver の結果に従う
- **WHEN** 本体が 4 例外のいずれかを要求する
- **THEN** その依頼と同じ実行先指定を request に渡し、起動不可なら役を起動せず理由を記録する。Claude を使える構成・環境での既存の確認内容と、depleted 時の判定役を起こさない条件は維持する

### Requirement: Claude を使わない構成では例外 4 役を起動せず主への確認に回す
`codex-standard` を含む Claude を使わない構成では、resolver は例外 4 役に起動不可と役ごとの理由を返し、実行可能な依頼ファイルを作ってはならない（MUST NOT）。本体は Claude も代替の Codex 役も起動せず、既存の主への確認・保留経路に接続しなければならない（MUST）。未実行を品質合格と扱ってはならない（MUST NOT）。

**守備範囲（例外の分類と非起動）**: ①入力元は、本体が W の画面確認要求・G の Status・関連テストの再実行条件から組み立てる request の依頼種別と、開始時の指定から解決した構成である。テストが一時書き込みを要するかは呼び出し側が調べて渡し、resolver がテスト本文を解析して推測する契約ではない。②拾いたい誤りは、この 4 例外だけが指定を迂回して Claude を起こすこと、および起動不可をレビュー済み・確認済みと扱うことである。③通してよい入力は、一時書き込み不要の通常レビュー（Codex で継続）と、Claude を使える構成・環境での例外依頼（従来の確認へ進む）である。呼び出し側が一時書き込みを不要と誤分類した依頼は resolver 単独では検知せず、実行不能が分かった時点で未完了として扱う。④分類の穴や呼び出し側の誤申告をすべて塞ぎ切ることを完了条件にしない。

#### Scenario: 一時領域が必要なレビュー
- **WHEN** codex-standard で、一時領域への書き込みを必要とするテストの独立再実行が要求される
- **THEN** reviewer を起動せず、レビュー未完了と理由を記録して主の確認待ちとする。要件「主の再実行証拠を独立レビューしてから G に復帰する」に従い、CI・W の実行で代用せず、主の結果だけで合格処理に進まない

#### Scenario: 画面確認が必要
- **WHEN** codex-standard で W が画面確認を必要とする
- **THEN** V を起動せず、実行不能の理由を次の W に渡し、画面証拠を作らず既存のゲートの保留経路へ進む

#### Scenario: 引き継ぎ判定または論点なし確認が必要
- **WHEN** codex-standard で needs-carryover-judge または needs-no-point-check を受ける
- **THEN** 判定役を起動せず、本体が既存書式の「引き継ぎ判定: 判断できない」または「論点なしの確認: 判断できない」と起動しなかった理由を投稿する。その URL を渡して合格処理の G を新しく起こし、主への確認は G の既存手順に従う

#### Scenario: 書き込み不要な通常レビュー
- **WHEN** codex-standard で一時領域への書き込みを必要としない通常レビューを依頼する
- **THEN** 既存の独立した Codex 読み取り役へ委譲し、例外の起動不可を適用しない

### Requirement: 主の再実行証拠を独立レビューしてから G に復帰する
Claude を使わない構成で一時書き込みレビューを保留した場合、本体は主の固定 HEAD での独立再実行証拠を照合・記録し、W と別 thread の read-only Codex reviewer が残るレビューと証拠評価を完了してから fresh G へ戻さなければならない（MUST）。以下の Scenario を reviewer-brief・hold-resume・adapter の復帰契約に対応づけ、主の結果だけで合格にしてはならない（MUST NOT）。

**守備範囲（復帰証拠の照合）**: ①入力元は主の再実行証拠と回答の出典、本体の固定 HEAD/対象範囲、独立 reviewer の結果。②拾う誤りは必須記録不足、HEAD/範囲不一致、CI/W の流用、独立レビュー省略、同じ有効な証拠への再依頼。③同じ HEAD/範囲の既存証拠や、再実行せず不足記録を補足した証拠は通す。実行内容の評価は独立 reviewer が担い、すべての正誤を機械判定しない。④誤申告や範囲解釈の穴をすべて塞ぎ切ることを完了条件にしない。

#### Scenario: 主に固定 HEAD の独立再実行を依頼する
- **WHEN** Claude を使わない構成で一時書き込みが必要な関連テストのレビューが未完了で、対象 HEAD/範囲の主の証拠を未受領である
- **THEN** 本体は固定 HEAD・正確なコマンド/範囲・環境/一時領域・期待結果を示して主に依頼し、証拠に対象 HEAD・正確なコマンド・環境/一時領域・実施日時・出力・終了コード・回答の出典が揃うことを照合し、PR に記録して証拠 URL を残すまで保留する。回答の出典は回答リンク、会話ならセッション ID・日時・原文、親経由なら既存復帰手順の出典情報とする。CI/W の結果では代用しない

#### Scenario: 主の証拠を別 thread で評価して G に戻す
- **WHEN** 同じ固定 HEAD/範囲の主の成功結果と必須記録が揃う
- **THEN** 本体は W と別 thread の通常の read-only Codex reviewer に証拠 URL と HEAD を渡し、残るコード/三表レビュー・可能な再実行・主の結果評価が完了した結果と証拠 URL を fresh G に渡す。一時書き込みテストの自己再実行のみを限定例外とし、writableRoots は追加しない。一般の手順 4 の動作確認代行から手順 5 に直行する経路と区別し、G は主の結果だけで合格にせず、既存の合格条件を再確認する。Claude を使える場合の reviewer 自身の再実行・Claude 取り直しは維持する

#### Scenario: 同じ有効な証拠があれば主に二度頼まない
- **WHEN** 本体が同じ HEAD/同じテスト範囲の有効な主の証拠を受領済みで、fresh reviewer または G へ復帰する
- **THEN** 本体は主の再実行を再依頼せず、既存の証拠 URL を渡す。HEAD または対象範囲が変わったときだけ新しい対象での再実行を求める

#### Scenario: 証拠が不足している
- **WHEN** 主の結果に必須記録が不足する
- **THEN** 本体は保留を続けて既存結果への補足を求め、同じ実行を再依頼せず、独立レビュー完了や合格として扱わない

#### Scenario: 主の再実行が失敗する
- **WHEN** 主が対象 HEAD の関連テストの失敗を報告する
- **THEN** 本体は結果を証拠として記録して既存の修正サイクルへ戻し、成功結果や独立レビュー完了とは扱わない
