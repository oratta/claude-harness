# 手動 develop provider adapter

これは `skills/develop/SKILL.md` の provider 操作の差分。工程順、仕様化判断、レビュー回数、テスト、PR 宣言、ゲート条件の正本は develop と roles のまま。本体は工程管理だけを行う。

## 起動と role 解決

引数なしの追加依頼でも各 phase で profile なしの request を使って自動選択する。明示 profile・旧形式を引き継ぐ場合は初回の設定を再推測せず、実行先オプションと account-home の対応の両方を改めて明示する。

develop 開始コメントには「実行モード」の節の `実行モード:` の行と、channel のときは channel.md の規則による `チャンネルの返事の確認:` の行を残す。開始・dispatch・消費の印を書く前に `skills/develop/references/pr-token-budget.md` を必ず Read し、起動アカウントの印 `[消費記録 アカウント=claude:<登録名>]` もその規約に従って記録する。

`/dev-workflow:develop --profile hybrid-standard <issue URL または依頼>`

`request` は無指定の自動選択のほか、明示 profile（`--profile NAME [--profile-file PATH]`）と旧形式（`--account NAME --model MODEL`）を取る。明示指定のときは検証規則と外部 profile の書式を `references/codex-develop-explicit.md` で読む。各 role は設定を解決した直後に `executor` で一度だけ分岐する。`claude` は要求 tuple を保持して `request` が返した `model` で Agent ツールを使い、`codex` は request を作って前景コマンドを使う。effort は両 provider で監査値として保持するが、Claude Agent の option には変換しない。`request` にはどの形式でも格の入力（以下「格の入力」と呼ぶ。当たる事前分類の `--pre-class sacred|merge|contract|billing`（繰り返し可。順に聖域パス・マージ権限・層間契約・課金/法務）、記録先が設計判断を含むときの `--design-judgment`、失敗のラダーの段を示す `--failure first|executor|judgment`、自動実行のときの `--unmanned`）を渡す。旧形式は受けて無視する。事前分類の正本は `skills/develop/references/pre-classification.md`。事前分類に当たる R1 または G が要求したレビュアーは、`--pre-class` を渡した `request` が `role: decider` と構成の `decider` entry の投げ先/account を返すので、`subagent_type: dev-workflow:decider` として起動する。

Claude 本体は `--coordinator claude`（既定）で Agent ツールを使用できるため、PATH の claude の有無では実行不能としない。CLI が必要な本体はすべての request に `--coordinator cli` を渡す。この場合は PATH の実行可能な claude を検査し、不在なら通常の選択表より先に専用分岐を適用する。Codex の margin が 0 以上なら Codex 単独構成、負・欠測・未登録・オフなら理由を示して起動前に blocked・exit 2 で止まり、役も実行可能な依頼ファイルも作らない。明示 profile・旧形式の指定は上書きせず、解決した Claude の役が実行不能なら起動前に止める。Claude の役が実行可能な場合の通常の選択表は次のとおり維持する。

無指定では各 canonical phase の開始時に Claude 起動 account と登録済み Codex accounts を再評価する。margin（週経過率 − 週次使用率）は headroom の行の値で、Codex は週次 snapshot、Claude はセッション記録と snapshot の実効値から取り、取得からの経過時間では捨てず、リセットを過ぎた窓は 0% で読む。Codex の margin が基準（`DEVELOP_ALL_CODEX_MIN_MARGIN_PCT`、既定 10、不正値は blocked）以上か、0 以上で Claude が負か欠測なら `codex-standard`、0 以上で Claude も 0 以上なら `claude-write-codex-review`、他は Claude 既定構成。開始済み role は途中で切り替えない。返された selection evidence（構成、reason、両 margin / fetched_at、代表 account）を最初の開始コメントと各 dispatch 記録に残し、欠測値は `missing` と書く。登録簿（`CLAUDE_ACCOUNTS_FILE`、未設定なら `${CLAUDE_CONFIG_DIR:-~/.claude}/accounts.json`）のトップレベルの `codex.enabled` が JSON の `false` のとき（Codex オフ）は使用量を読まずに `claude-default` を reason `codex-off` で選び、selection evidence の `codex` に `enabled: false` を載せる。

account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返しか、平らな JSON を `--account-home-file PATH` で与える。2方式の併用は拒否し（合成も優先もしない）、値は既存の絶対ディレクトリでなければならない。profile も旧形式も対応表も無い自動選択だけは、`CODEX_HOME`（未設定なら `~/.codex`）が既存の絶対ディレクトリなら `current` の対応として評価し、存在しなければ Codex を欠測のままにする。明示対応表に無い名前を既定値や別 account へ倒さない。対応に無い名前は依頼ファイルを作る前に拒否する。

この入口は人間が手動で使うためのもので、burn 窓や cron/tick を要求しない。Codex worker の認証失敗、利用上限による拒否、権限拒否は、そのまま停止理由とする。role の投げ先を暗黙に別 provider で代行してはならない。`codex` に解決した role で Codex が失敗しても Claude へ切り替えず、`claude` に解決した role で Claude が失敗しても Codex へ切り替えない。role をどこへ投げるかを決める場所は profile だけである。

develop 開始時の profile の指定（`--profile NAME`・`--profile-file PATH`・旧形式の account/model・無指定のどれか）は、develop の終わりまで同じ値で `request` に渡し、工程の途中で変えない。無指定のときに phase ごとに構成を選び直す上の規則は変わらない（無指定から明示へ、明示から別の明示へ変えることを禁じる）。変える必要があるときは主に承認を求め、記録先に `profile 変更: <変更前の指定> → <変更後の指定>` の行と主の承認の発言を引いたコメントを残してから変える。この規則を `request` が機械的に拒否する仕組みは #615 の範囲で、ここでは文の規則だけを置く。

### 本体が行う操作

develop 入口 0 で記録先を確定し、対象 repo のルールで専用 worktree を用意する。CLI 自身は worktree を作らない。上記の入力で解決した account/model/effort と対象 HEAD を監査情報として保持する。Claude role でも同じ `request`（`--input` と `--out` は必須だが、Claude role ではどちらも読み書きしない）を呼び、`status: agent-required` を読む。

Claude role の新規起動では、`request` が返した `requested_model`・`model`・`tier_reason` を requested model / applied model / reason として別々に記録し、`tier`・`executed_tier`・`tier_cap` も dispatch 記録に残して、返った `model` で Agent を起動する。新しい起動の `model` を文章の規則で計算し直さない。`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の適用は `request` が済ませているので、本体は上限を計算し直さない。`tier_reason` は `tier` の変化だけを表すので、`tier_cap` で値が変わった起動は `executed_tier` と `tier_cap` の記録で見分ける。W の phase `spec`／`implement`／`finish` は `dev-workflow:worker`、G の phase `gate` は `dev-workflow:gate-runner`、返った `role` が `decider` なら `subagent_type: dev-workflow:decider`、レビュアーは `dev-workflow:reviewer`、R1 は `general-purpose`、`explore`・`summarize` role は `general-purpose` として起動する。すべての上限の正本は `skills/develop/references/decision-criteria.md` の優先順位の表。`request` が上限を適用しても、返った `role: decider` の subagent_type は変えない。

同じ Claude role を再開する前にも毎回、同じ phase と、今回の再開に当たる格の入力（失敗ループの段なら、その段の `--failure` の値を含む。実行先オプションも同じ）で `request` を呼び直し、返った `tier`（上限を適用済み）と `model` を、動いている thread の格（起動時に記録した `tier`）と applied model（起動時に記録した `model`）と比べる。呼び直しの結果は `tier` と `model` だけを読み、投げ先・account・依頼ファイルは使わず、構成の選び直しにも使わない（`tier` は構成によらないので、役の途中切り替えにはならない）。呼び直しで書かれた依頼ファイルは使わず捨てる。SendMessage 再開前の `subagent-context.sh` によるコンテキスト上限計測は、profile 経路でも従来どおり適用する。返った `tier` が thread の格より低くなく、かつ返った `model` が thread の applied model と同じときだけ SendMessage で再開し、requested tuple と applied model を変えない。それ以外（返った `tier` が低いときと、返った `model` が applied model と違うとき。後者は失敗ループの昇格で格が上がったときを含む）は SendMessage せず、既存の工程完了または停止確認条件を満たしてから、requested tuple と成果物・必要な要約を fresh thread へ渡し、返った `model` を applied model として reason とともに記録する。SendMessage の再開では model を変えられないので、格が上がったときに SendMessage すると昇格が起きないまま再開される。格が上がっても model が変わらないとき（`tier_cap` で同じ格に下がる構成など）は SendMessage で再開してよい。applied model は返った `tier` を `references/model-tier-map.json` の claude で引いた値（起動時に `tier_cap` を記録していれば、その格まで下げた値）で、reason は返った `tier_reason` である。たとえば fable thread の再開前に exhausted へ変われば fresh opus、depleted へ変われば fresh sonnet、sonnet の W に実行側の失敗の `--failure executor` で上位が返れば fresh opus とする。profile role の境界、独立レビュー、Codex 委譲も fresh thread とし、会話履歴全体を渡さない。

失敗ループ（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した。段と格の表は `templates/escalation-tripwires.md`）では、本体は Claude と Codex のどちらの profile でも同じ手順で動く。1 回目の失敗は `request --phase decider --failure first` で決める役を立て、実行役は格を変えずに再試行する。2 回目の失敗で原因が実行側（指示どおりやって結果が違う）なら、実行役の phase に `--failure executor` を足した `request` を呼び、返った model で実行役を起こす（Claude の thread は上の再開の条件で SendMessage か fresh thread かを決める）。原因が判断側（指示を解釈できなかった・指示自体が外れていた）なら、`request --phase decider --failure judgment` が返す構成の `decider` entry の投げ先・account・model で決める役を立てて修正方針を作らせ、実行役の格は変えない。決める役と実行役のどちらか一方だけを上げる（両方同時に上げない）。どの段でも、本体は昇格の手段として profile を作り直さず、`--profile` / `--profile-file` を開始時と違う値にせず、`request` が返した model と違う model を独自に指定・上書きしない（返った model を Agent の `model` に渡すのは既存の契約どおりで、これに当たらない）。effort を profile の entry の値から変えない（`request` は格の入力で effort を動かさない）。Codex の実行役では、上位を対応表で引いた結果が中位と同じ model なので、実行側の失敗でも実装役の model は変わらない。

Codex role は次の3手順で1回の委譲を行う。

1. 正本が次に呼ぶ role と工程を決め、その工程に限定した指示を UTF-8 ファイルに書く。依頼、完了条件、記録先 URL、対象 artifact、固定 HEAD を渡し、秘密情報や実装者の会話履歴を入れない。
2. role 別の account/model/effort と CODEX_HOME を固定した private request を作り、worker を前景コマンドとして起動する。

   ```sh
   python3 <plugin>/scripts/codex-develop.py request --phase PHASE --input <指示ファイル> \
     --cwd <worktree-root> --profile NAME [--profile-file /absolute/profiles.json] \
     --account-home current=/absolute/codex-home [<格の入力>] --out <依頼ファイル>
   python3 <plugin>/scripts/codex-worker.py run --request <依頼ファイル>
   ```

3. 標準出力の1行 JSON（`text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind` / `started_at` / `ended_at`）を読む。成功は exit 0、失敗は exit 2。transport state は残らないので、照会・受領・live resume は行わない。記録先に委譲結果を書くときは、要求した model（`execution.model_resolution.requested`）と解決後のモデル ID（`execution.model_resolution.resolved`）を両方書き、観測できた `execution.effective.model` も添える。

Codex への委譲をセッションをまたいで引き継ぐ仕組みはないため、途中で切れた委譲はその工程の最初からやり直し、停止または中断時点の成果物と結果 JSON を記録する。再開には上の条件を適用する。

| 正本の委譲箇所 | phase | role |
|---|---|---|
| W: 仕様化判断・仕様作成・仕様差戻し | spec | spec-write |
| R1: 独立仕様レビュー・再レビュー | spec-review | spec-review（read-only） |
| W: 実装・TDD・verify・修正 | implement | implement |
| W: archive・Draft PR・仕様宣言 | finish | implement |
| G: ゲートの照合・記録 | gate | implement |
| G が必要とする独立 PR レビュー | review | impl-review（read-only） |
| 判断側の修正方針 | decider | decider（read-only） |

## 品質と transport 差分

- 仕様要否、review、必須検査、archive、差戻し、次工程への進行は develop と roles の正本で管理する。adapter に別の承認台帳や品質 gate を置かない。phase は role 指示選択ラベルであり、工程順を強制しない。
- read-only reviewer は GitHub に書かず、本体が既存正本の書式で結果を代理投稿する。投稿成功前に後続へ進まない。write role は親環境で GitHub 読み書き、commit、push、Draft PR 作成まで自分で完了する。
- completed は transport 完了だけを表す。最終回答と error_kind を確認し、仕様承認・テスト証拠・独立 review・gate を省略しない。merge / auto-merge は禁止する。
- Claude hooks は Codex に自動適用されない。対象 repo の必須検査を指示と結果に明記し、実行不能を合格扱いしない。read-only policy 以外に sandbox 保証を推定しない。
- 停止は Agent または起動した前景 command を止める。結果 JSON を受け取れず終了した場合は、記録先と worktree から同じ工程を fresh phase としてやり直す。
- request は private directory に置く。worker は静的検証後、thread/start 前に model/list で系統名を解決するか完全 ID を照合し、そのモデルに対して effort を検証する。結果 JSON は要求値と実効値・観測元を分け、未観測値を推測しない。
- G が通常経路で `codex exec`、companion、または Claude reviewer を呼ぶ場面では、それを実行せず `needs-reviewer` を返す。本体は「起動と role 解決」で phase `review` を開始し、その結果を新しい G に渡す。review phase は `skills/develop/references/roles/gate-runner.md` と `skills/pr-review-gate/stages/reviewer-brief.md` を正本として request に含めるため、fresh reviewer も手順 2-1 の三表を含むレビュアー向け指示ブロックを参照する。G は返す前に、ゲート自身の着手確認と同一 PR/HEAD の重複防止を実施する。本体は G を段ごとに新しく起こし（Claude の G も再開しない）、起動指示に `レビュー経路: adapter` の 1 行を書く。この義務は `skills/develop/SKILL.md` の「Role profile の選択」節が、行による経路の判別は `skills/develop/references/roles/gate-runner.md`「レビュー経路の判別」が正本である（ここには再掲しない）。起動指示に行が無い G は従来経路として扱う（Claude の G は Codex を直接呼ぶ。Codex の G は prompt の禁止により呼ばない）。手渡しで起こされた後任 G は fresh G に含む（`skills/develop/references/roles/gate-runner.md`「レビュー経路の判別」）。
- 一時書き込みが必要な関連テスト（bats、`mktemp`、`TMPDIR` / `BATS_TMPDIR`、pytest 等）の再実行レビューは、呼び出し側が分類し、開始時と同じ実行先指定・account-home・coordinator を付けて `request --phase review --request-kind temp-write-review` を通す。読み取り専用レビュアーが再実行できなかった場合も同じ request を通す。起動許可なら返った model で Claude のレビュアー（`dev-workflow:reviewer`）を同じ固定 HEAD で起こし、書き込める一時領域を TMPDIR / BATS_TMPDIR に渡して取り直す（補足済み回数を増やさず、`review-incomplete` で止めない）。起動不可なら Claude も代替の Codex 役も起こさず、レビュー未完了と理由を記録して一時書き込みレビュー待ちで保留する。主の再実行証拠による復帰は下の同名節に従う。CI/W の結果で代用せず、read-only role に writableRoots を追加しない。
- 4 例外は通常の依頼（`--request-kind normal`）と区別し、V は `--phase implement --request-kind visual-check`、引き継ぎ判定と論点なし確認は `--phase decider --request-kind carryover-judge` / `--request-kind no-point-check` を使う。開始時の指定を保持して request を通し、`status: blocked` / `launchable: false`（exit 2）なら起動しない。codex-standard 等の Claude を使わない構成では 4 例外を非起動とし、通常の書き込み不要レビューは独立した Codex 読み取り役で継続する。dispatch 記録には phase・request_kind・role・非起動の理由（error）・selection を残し、構成があれば execution_config とその hash も残す。未実行を合格にしない。
- `needs-reviewer` の補足要求と terminal `review-incomplete` は、処理前に `skills/develop/references/gate-result.md` の該当 Status を必ず Read して従う。
- burn 接続、全 account の配分、使用量集計は別 issue の範囲とする。
- Codex が選ばれたことを理由に仕様を必須化しない。正本どおり W が理由付きで「仕様化判断: しない」を返した場合、本体は実装工程へ進む。仕様が必要な場合は正本の R1 承認条件を適用する。
- 仕様化が必要な場合、opsx Skill 操作は対象 repo の openspec CLI 相当へ変換し、正本の仕様フォーマットを別テンプレートへ写さない。CLI 不在時の判断も既存 develop 正本に従う。
- G には操作結果の証拠を渡し、照合させる。

同じ worktree に2本の job を同時に投げてはならない。これは本体の責任である。前景経路は同時実行の枠管理も作業ディレクトリの排他も行わない。


## 主の再実行証拠による復帰

この節は Claude を使わない構成での一時書き込みレビュー待ちだけに適用する。主の結果だけで合格にしない。一時書き込みテストの自己再実行のみを限定例外とし、Claude を使える場合の reviewer 自身の再実行・Claude 取り直しと、一時書き込み不要の関連テスト・lint の自己再実行義務は維持する。同一固定 HEAD・read-only 権限を保ち、writableRoots は追加しない。

1. 本体は主に固定 HEAD・関連テストの正確なコマンド/範囲・環境/一時領域・期待結果を示して独立再実行を依頼する。CI/W の結果では代用しない。
2. 証拠には対象 HEAD・正確なコマンド/範囲・環境/一時領域・実施日時・出力・終了コード・回答の出典が必要。本体は照合して PR に記録し、証拠 URL を残す。回答の出典は回答リンク、会話ならセッション ID・日時・原文、親経由なら既存の hold-resume の復帰手順の出典情報とする。必須記録が不足する間は保留を続け、既存結果への補足のみを求める。同じ実行の再依頼はしない。主の結果が失敗なら証拠を記録して既存の修正サイクルへ戻し、成功や独立レビュー完了とは扱わない。
3. 同じ HEAD・同じ範囲の有効な証拠があれば再依頼しない。既存の証拠 URL を次の reviewer / G に渡す。HEAD または対象範囲が変わったときだけ新しい対象での再実行を求める。
4. 成功結果と必須記録が揃ったら、W と別 thread の通常の read-only Codex reviewer に固定 HEAD と証拠 URL を渡す。この起動は `request --phase review --request-kind normal` を通し、残るコード/三表レビュー・可能な再実行・主の結果評価を完了させる。独立レビュー完了結果と証拠 URL が揃うまで保留し、主の結果だけで一般の動作確認代行の手順 5 に直行しない。本体は独立レビュー完了結果と証拠 URL を fresh G に渡し、G は既存の合格条件を再確認する。
