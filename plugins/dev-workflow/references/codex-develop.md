# 手動 develop provider adapter

これは `skills/develop/SKILL.md` の provider 操作の差分。工程順、仕様化判断、レビュー回数、テスト、PR 宣言、ゲート条件の正本は develop と roles のまま。本体は工程管理だけを行う。

## 起動と role 解決

`/dev-workflow:develop --profile hybrid-standard <issue URL または依頼>`

`request` は `--profile NAME [--profile-file PATH]`、旧形式の `--account NAME --model MODEL`、または無指定の自動選択を取る。明示 profile と旧形式の併用、旧形式の片方欠落、profile-file だけの指定は依頼ファイルを作らず拒否する。明示指定は自動選択より優先し、usage snapshot を読まない。Version 1 profile は全 canonical role の `executor` / account / model / effort を検証し、role の設定を解決した直後に一度だけ分岐する。`claude` は要求 tuple を保持して既存の残量上限を適用した model で Agent ツールを使い、`codex` は request を作って前景コマンドを使う。事前分類に当たる R1 または G が要求したレビュアーは、対象 role の設定ではなく profile の `decider` entry（投げ先/account/model）で `subagent_type: dev-workflow:decider` として起動する。

組み込み profile は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review`。外部設定は全 canonical role を含み、Codex role の account は呼び出し側の対応表に存在し、Claude role は account=current、model は `haiku|sonnet|opus|fable`、`fable` は decider だけに指定できる必要がある。Codex role の model は系統名（英小文字だけの値。組み込み profile は `sol` / `luna` / `astra`）か完全なモデル ID（`gpt-6-sol` 等。版を固定したいとき）で書き、adapter は変換せずに request へ写す。系統名は worker が呼ぶ直前にその account の model/list から最新版へ解決する。新しいモデルが一覧に出るには Codex CLI の更新が要る（CLI が古いと旧世代に解決される）。effort は両 provider で監査値として保持するが、Claude Agent の option には変換しない。歴史的な `references/codex-role-profiles.json` というファイル名は互換性のため維持するが、中身は provider-neutral な role table である。

無指定では各 canonical phase の開始時に Claude 起動 account と登録済み Codex accounts を再評価する。freshness は age `<=300` 秒（`>300` は欠測）で、`margin = 週経過率 - 週次使用率`。両 provider が margin 0 以上なら `claude-write-codex-review`、Codex だけなら代表 account に束縛した `codex-standard`、それ以外は Claude 既定構成を選ぶ。開始済み role は途中で切り替えない。返された selection evidence（構成、reason、両 margin / fetched_at、代表 account）を最初の開始コメントと各 dispatch 記録に残し、欠測値は `missing` と書く。

account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返しか、平らな JSON を `--account-home-file PATH` で与える。2方式は併用せず、値は既存の絶対ディレクトリでなければならない。profile も旧形式も対応表も無い自動選択だけは、`CODEX_HOME`（未設定なら `~/.codex`）が既存の絶対ディレクトリなら `current` の対応として評価し、存在しなければ Codex を欠測のままにする。profile 全体を先に検証するため、選択 role が Claude でも明示 profile 内の Codex account はすべて明示対応表に必要である。明示 profile・旧形式、または明示対応表に無い名前を既定値や別 account へ倒さない。

account 名から CODEX_HOME への対応の導入方法は `docs/codex-develop.md` に示す。この入口は人間が手動で使うためのもので、burn 窓や cron/tick を要求しない。Codex worker の認証失敗、利用上限による拒否、権限拒否は、そのまま停止理由とする。role の投げ先を暗黙に別 provider で代行してはならない。`codex` に解決した role で Codex が失敗しても Claude へ切り替えず、`claude` に解決した role で Claude が失敗しても Codex へ切り替えない。role をどこへ投げるかを決める場所は profile だけである。

## 本体が行う操作

develop 入口 0 で記録先を確定し、対象 repo のルールで専用 worktree を用意する。CLI 自身は worktree を作らない。各委譲の直前に role を解決し、返された account/model/effort と対象 HEAD を監査情報として保持する。Claude role でも同じ `request`（`--input` と `--out` は必須だが、Claude role ではどちらも読み書きしない）を呼び、`status: agent-required` を読む。

Claude role の新規起動では、profile の model を requested model として変更せず保持する。Agent 起動直前に既存の `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` を適用し、requested model / applied model / reason を別々に記録する。`decider` role は `subagent_type: dev-workflow:decider`、他の role は `general-purpose` として起動する。すべての上限の正本は `skills/develop/references/decision-criteria.md` の残量モード表であり、以下の列挙は例である。`FABLE_BUDGET_MODE=exhausted` で applied=opus に下がっても `decider` の subagent_type は変えない。`FABLE_BUDGET_MODE=reserve` の自動実行では Fable を使わず、Opus を上限とする。`SHARED_BUDGET_MODE=throttled` は Sonnet 起点、Opus 上限とする。制限が無ければ applied=requested、reason=unchanged。`FABLE_BUDGET_MODE=exhausted` は requested=fable を applied=opus にし、`SHARED_BUDGET_MODE=depleted` は requested にかかわらず applied=sonnet に固定して前者より優先する。

同じ Claude profile role を再開する前にも毎回現在の上限を再計算する。SendMessage 再開前の `subagent-context.sh` によるコンテキスト上限計測は、profile 経路でも従来どおり適用する。既存 thread の applied model が上限内のときだけ requested tuple と applied model を変えず SendMessage する。上限を超えるときは SendMessage せず、既存の工程完了または停止確認条件を満たしてから、requested tuple と成果物・必要な要約を fresh thread へ渡し、上限内の applied model と reason を記録する。たとえば fable thread の再開前に exhausted へ変われば fresh opus、depleted へ変われば fresh sonnet とする。profile role の境界、独立レビュー、Codex 委譲も fresh thread とし、会話履歴全体を渡さない。

Codex role は次の3手順で1回の委譲を行う。

1. 正本が次に呼ぶ role と工程を決め、その工程に限定した指示を UTF-8 ファイルに書く。依頼、完了条件、記録先 URL、対象 artifact、固定 HEAD を渡し、秘密情報や実装者の会話履歴を入れない。
2. role 別の account/model/effort と CODEX_HOME を固定した private request を作り、worker を前景コマンドとして起動する。

   ```sh
   python3 <plugin>/scripts/codex-develop.py request --phase PHASE --input <指示ファイル> \
     --cwd <worktree-root> --profile NAME [--profile-file /absolute/profiles.json] \
     --account-home current=/absolute/codex-home --out <依頼ファイル>
   python3 <plugin>/scripts/codex-worker.py run --request <依頼ファイル>
   ```

3. 標準出力の1行 JSON（`text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind`）を読む。成功は exit 0、失敗は exit 2。transport state は残らないので、照会・受領・live resume は行わない。記録先に委譲結果を書くときは、要求した model（`execution.model_resolution.requested`）と解決後のモデル ID（`execution.model_resolution.resolved`）を両方書き、観測できた `execution.effective.model` も添える。

書込 role は一度に1つずつ動かし、担当中の role が完了してから次を開始する。Codex への委譲をセッションをまたいで引き継ぐ仕組みはないため、途中で切れた委譲はその工程の最初からやり直し、停止または中断時点の成果物と結果 JSON を記録する。Claude role の再開には上記の上限再計算と fresh thread への手渡し規則を適用する。

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
- G が通常経路で `codex exec`、companion、または Claude reviewer を呼ぶ場面では、それを実行せず `needs-reviewer` を返す。本体は phase `review` の fresh thread を開始し、その結果を新しい G に渡す。review phase は `skills/develop/references/roles/gate-runner.md` と `skills/pr-review-gate/SKILL.md` を正本として request に含めるため、fresh reviewer も手順 2-1 の三表を含むレビュアー向け指示ブロックを参照する。G は返す前に、ゲート自身の着手確認と同一 PR/HEAD の重複防止を実施する。
- `needs-reviewer` が一周目照合の補足要求である場合、phase `review` の request に固定 HEAD・元の三表・残差・補足済み回数を含める。fresh reviewer は同じレビューの不足分だけを補い、結果を `補足済み回数: 1` として fresh G に渡す。G の Status が terminal `review-incomplete` なら新しい review phase を開始せず、`agent-review:pending` のまま残差を報告して止める。
- burn 接続、全 account の配分、使用量集計は別 issue の範囲とする。
- Codex が選ばれたことを理由に仕様を必須化しない。正本どおり W が理由付きで「仕様化判断: しない」を返した場合、本体は実装工程へ進む。仕様が必要な場合は正本の R1 承認条件を適用する。
- 仕様化が必要な場合、opsx Skill 操作は対象 repo の openspec CLI 相当へ変換し、正本の仕様フォーマットを別テンプレートへ写さない。CLI 不在時の判断も既存 develop 正本に従う。
- G には操作結果の証拠を渡し、照合させる。

同じ worktree に2本の job を同時に投げてはならない。これは本体の責任である。前景経路は同時実行の枠管理も作業ディレクトリの排他も行わない。
