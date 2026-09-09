# dev-workflow-execution-strategy Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
### Requirement: 残量モードによる閾値調整
役割のモデル選択は環境変数 `FABLE_BUDGET_MODE`（`abundant` / `conserve` / `reserve` / `exhausted`）を参照しなければならない（SHALL）。定義表は develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` に置く（SHALL）。未設定時は usage snapshot からの自動導出結果を用い、snapshot も無ければ `conserve` として扱う。明示的に設定された `FABLE_BUDGET_MODE` は自動導出より優先されなければならない（SHALL）。モードが変えるのは役割（W / R1 / G）の昇格上限のみであり、1 ループの構造・トリップワイヤーは変えない。`abundant` はどの役割の既定モデルも押し上げてはならない（MUST NOT）。Fable が使えるのは決める役（`dev-workflow:decider` として spawn される役）だけであり、実行役（W）の上限はどのモードでも `opus` である（SHALL）。`exhausted` は Fable 週次枠を実質使い切った状態を表し、`reserve` と異なり interactive を含む全経路で Fable をいかなる役割でも使わず、決める役も `opus` に落とす。Fable 残量モードは Fable と Opus のあいだで役割を付け替える装置であり総量を絞る装置ではないため、総量の下限は共有枠モード（別 Requirement）が決める。

#### Scenario: 未設定かつ snapshot 無しは conserve
- **WHEN** `FABLE_BUDGET_MODE` が未設定で usage snapshot も存在しないまま役割のモデルを決める
- **THEN** conserve（役割表の既定どおり。W = Sonnet、R1 = Opus、G = Sonnet。Fable は決める役の種別で spawn されるときだけ）として判定する

#### Scenario: 明示 env は自動導出より優先
- **WHEN** `FABLE_BUDGET_MODE` が明示設定されており、かつ usage snapshot も存在する
- **THEN** 自動導出結果を無視して明示された値を用いる

#### Scenario: abundant は既定を上げない
- **WHEN** `FABLE_BUDGET_MODE=abundant` で役割のモデルを決める
- **THEN** W / R1 / G の既定は役割表のまま（Fable は決める役の種別だけ）。結果が変わらない機械的な大量仕事（fan-out ワーカー・機械的編集）も安いモデルのまま

#### Scenario: exhausted は全経路で Fable を使わない
- **WHEN** `FABLE_BUDGET_MODE=exhausted`（明示または自動導出）のセッションで役割・昇格を判定する
- **THEN** interactive / unmanned を問わず Fable をいかなる役割でも使わず、決める役も `subagent_type: dev-workflow:decider` のまま `model: opus` に切り替える（種別は変えない）

#### Scenario: ガードは残量モードを見ない
- **WHEN** `FABLE_BUDGET_MODE=exhausted` の環境で `dev-workflow:decider` に `model: "fable"` を渡す
- **THEN** ガードは許可する（残量による抑制は develop 側の役割選択が行い、ガードは種別だけを見る）

### Requirement: reserve モードでは自動実行が Fable を使わない
`FABLE_BUDGET_MODE=reserve` のとき、自動実行（unmanned モード・cron・loop 経由の無人セッション）は Fable をいかなる役割（W / R1 / G）でも使ってはならない（MUST NOT）。無人時の昇格ラダーは Opus を上限とし、Opus でも解決しない問題は needs-approval で人間に返す。interactive セッションでは conserve と同じ扱いとし、人間の Fable 利用は妨げない。

#### Scenario: reserve 中の unmanned 昇格
- **WHEN** `FABLE_BUDGET_MODE=reserve` の unmanned サイクルで失敗ループのトリップワイヤーを踏む
- **THEN** W は Opus までしか昇格せず、Opus でも2連続失敗が続く場合は記録先に needs-approval を付けて経緯をコメントしサイクルを終了する

#### Scenario: reserve 中の interactive は制限されない
- **WHEN** `FABLE_BUDGET_MODE=reserve` の interactive セッションでユーザーが作業する
- **THEN** 判定は conserve と同一に振る舞い、ユーザー自身の Fable 利用（/model 切替等）を妨げる指示を出さない

### Requirement: Step B 基準の重心移動
develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性はいかなる判定でも緩めてはならない（MUST NOT）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

### Requirement: usage snapshot からの残量モード自動導出
`FABLE_BUDGET_MODE` が明示設定されていないとき、残量モードは usage snapshot（`fable_weekly_pct` / `fable_active` / 週次リセット時刻を含む）から自動導出されなければならない（SHALL）。導出ルールは develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` に定義し、次の優先順位に従う: ① `fable_weekly_pct` が読めない/snapshot 無し → `conserve` ② `fable_weekly_pct > 90` → `exhausted` ③ `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant` ④ それ以外 → `conserve`。導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較であることを明記する。

#### Scenario: 消費が週経過より遅ければ abundant
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは abundant に導出される

#### Scenario: 消費が週経過を上回れば conserve
- **WHEN** snapshot の `fable_weekly_pct` が週経過% を超え、かつ 90 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは conserve に導出される

#### Scenario: 90% 超は exhausted
- **WHEN** snapshot の `fable_weekly_pct` が 90 を超え、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは exhausted に導出される

### Requirement: 共有枠モードが役割の既定モデルの下限を決める
`scripts/session-tripwires.sh` は usage snapshot の `weekly_all_pct`（全モデル共通の週次枠の消化率）から共有枠モード `SHARED_BUDGET_MODE` を導出し、Fable 残量モードと並べてセッション文脈に注入しなければならない（SHALL）。導出の優先順位: ① 明示 env `SHARED_BUDGET_MODE` ② `weekly_all_pct` が読めない / snapshot 無し → `ok` ③ `weekly_all_pct > 90` → `depleted` ④ `weekly_all_pct` が週経過%（週次リセット時刻から算出）より大きい → `throttled` ⑤ それ以外 → `ok`。効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に置く（SHALL）: `ok` は制約なし、`throttled` は W / R1 / G の既定を Sonnet に落とし昇格上限 Opus・`abundant` の押し上げ無効、`depleted` は全役割 Sonnet 固定・昇格なし（事前分類に当たっても Fable / Opus を使わない）。Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝たなければならない（MUST）。導出は Fable 残量モードの導出を変えてはならない（MUST NOT）。

#### Scenario: Fable が余っていても全モデル枠が速く減っていれば throttled
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下（abundant）で、`weekly_all_pct` が週経過% より大きく 90 以下
- **THEN** `FABLE_BUDGET_MODE` は abundant、`SHARED_BUDGET_MODE` は throttled と注入され、役割の既定は Sonnet 起点になる

#### Scenario: 全モデル枠 90% 超は depleted
- **WHEN** snapshot の `weekly_all_pct` が 90 を超え、`SHARED_BUDGET_MODE` が未設定
- **THEN** 共有枠モードは depleted に導出される

#### Scenario: データが無ければ ok
- **WHEN** snapshot が無い、または `weekly_all_pct` が読めない
- **THEN** 共有枠モードは ok（制約なし）に導出され、Fable 残量モードの導出は従来どおり conserve に倒れる

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh <agent-name>` は、名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）の最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。

手渡し規則の本文（上限超過を検知したときに送ってよい SendMessage と送ってはならない SendMessage、手渡しを行ってよい条件、W / G の return の 1 行目の宣言、前任が動作中のまま交代させるときの手順）は、`plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節にだけ置かなければならない（MUST。以下この節を正本と呼ぶ）。正本は次の 4 点を規定しなければならない（SHALL）: ①上限超過（exit 2）を検知したときに送ってよい SendMessage と送ってはならない SendMessage、②手渡し（前回の return と記録先を渡して同じ役割の新しいエージェントを spawn すること）を行ってよい条件、③W / G の return の 1 行目の宣言書式と、どちらの宣言を選ぶかの義務（固定された 2 つの書式のどちらにも当てはまらない return をどう扱うかを含む）、④前任が動作中のまま交代させる必要があるときの手順と、その待ち方。**この spec は①〜④の答えを再掲してはならない（MUST NOT）**。同じ規則の言い換えが 10 前後の面に散らばっていたことが、2026-09 に 3 周続けて書き換え漏れを出した原因であり、言い回しの多様性そのものを構造的に無くすことがこの要件の目的である。

W / G の return の 1 行目の書式リテラルは `工程完了: <工程名>` と `工程中断: <理由>` の 2 つとし、変更してはならない（MUST NOT）。この 2 つだけは、別エピックの子 issue がこの書式を前提に設計されているため spec が固定する（リテラルの固定であって規則の再掲ではない。どちらを選ぶか・何を伴うかの本文は正本にある）。

次の面は、手渡し規則について正本への参照だけを書かなければならず、条件・書式・手順を自分の言葉で言い換えてはならない（MUST NOT）: `plugins/dev-workflow/README.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/dev-workflow/scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文、`plugins/dev-workflow/scripts/subagent-context.sh` のヘッダコメント、`openspec/specs/dev-workflow-execution-strategy/spec.md`、`openspec/specs/dev-workflow-develop/spec.md`。`plugins/dev-workflow/.claude-plugin/plugin.json` の `description` はこの制約の対象外とし、正本とのズレを許容する（SHALL。配布メタデータでエージェントが読まないため。検査からも除外する。後述の除外③）。

参照だけになった面には、正本を読むまで手渡さない旨のガード 1 行を置いてよい（MAY）。`plugins/dev-workflow/scripts/session-tripwires.sh` が注入する常駐ルール文については、このガード 1 行を置かなければならない（MUST）。この注入文はエージェントがファイルを開かずに受け取る唯一の面であり、純粋なポインタにすると「上限超過に気づいたが条件を知らないまま即興する」状態が生まれる（2026-09 の二重 spawn 事故の直接原因は即興だった）。ガードは規則の内容ではなく正本を読む義務を述べるものなので、言い換えの禁止には抵触しない（SHALL）。

「手渡しに言及する箇所」の判定は、次に列挙するトリガー語のいずれかを含むかで行う（SHALL）。トリガーは語彙に依存することを前提とし、取りこぼしより誤検出に倒す（再現率優先。SHALL。誤検出は当該の面に参照 1 行を足せば解消でき、副作用が無いため）:

- **語彙 A（手渡しに固有の語。リポジトリの追跡ファイル全体に適用する）**: `手渡` / `工程完了` / `工程中断` / `subagent-context` / `DEV_WORKFLOW_CONTEXT_CAP` / `コンテキスト上限`
- **語彙 B（他の文脈でも使う一般語。`plugins/dev-workflow/` 配下と `openspec/specs/dev-workflow-*/spec.md` にだけ適用する）**: `引き継` / `交代` / `後任` / `乗り換え` / `新しい W` / `新しい G` / `新規 spawn` / `再 spawn`

判定と参照の単位はファイルとする（SHALL）。参照はその面を読む者が正本に辿り着けることを保証するためのもので、同じファイルの箇所ごとに書かせると再掲の圧力が戻るため、段落単位では判定しない。正本への参照とは、`decision-criteria.md` というファイル名、または正本の節見出し `コンテキスト上限（サブエージェントの手渡し）` のいずれかの文字列をそのファイルが含むこととする（SHALL）。テストは落ちたファイルと、そのファイル内でトリガーに掛かった行を示さなければならない（MUST）。

語彙 A で発火した面は正本への参照を持たなければならず（MUST）、後述の除外表に載せてはならない（MUST NOT）。語彙 B だけで発火した面は、正本への参照を足すか、テスト内の除外表にその面がトリガー語をどの文脈で使っているかを述べた理由コメント 1 行を添えて載せるかのいずれかとする（SHALL）。除外表の各行は、その面が現に語彙 B のトリガー語を含むことを検査し、含まなくなった行があればテストを落とさなければならない（MUST。stale な除外を残さないため）。この除外表は、実装者が検査範囲を暗黙に狭めることを防ぐために可視化する仕掛けであり、語彙 A の面に使うことはできない。

検査する面はテスト内に手で列挙した一覧ではなく、リポジトリの追跡ファイル（`git ls-files`）からの機械的な列挙とし、除外は次の 3 種だけとする（SHALL）: ①歴史記録（`plugins/dev-workflow/CHANGELOG.md` 全体、この change 以外の過去 change の archive、`_longruns/`）、②change の `proposal.md` と `tasks.md`（決定の理由と作業手順の記録であって、読んで従う規範ではないため）、③`plugins/dev-workflow/.claude-plugin/plugin.json`（前段で正本とのズレを許容した配布メタデータ）。`CHANGELOG.md` は項単位ではなくファイル単位で除外する（リリース時点の記録であり、新しい項も過去項と同じく歴史記録であるため）。

`plugins/dev-workflow/tests/` 自身は検査対象に含める（SHALL）。ただし正本の中身を固定するテストが正本の断片を `grep` の引数として引用することは、この要件が禁じる「言い換え」に当たらない（SHALL）。テストは規則を述べて読ませる面ではなく、正本の本文が壊れていないことを機械的に検査する面であるため。この引用の除外は**行単位**とし、検査を実装している 2 ファイル（`plugins/dev-workflow/tests/lib/handoff-scan.py`・`plugins/dev-workflow/tests/handoff-declaration.bats`）の、行末に `handoff-scan: fixture` の印を持つ行だけを後述の再掲の走査から外す（SHALL）。この 2 ファイルをファイル単位で外してはならない（MUST NOT。ファイル全体を外すと、印の無い行に規則を書き足しても検出されない穴になる）。

**再掲の走査（補助の網）**。ホワイトリストは面ごとに参照の有無しか見ないので、参照を書いたうえで規則を言い換えた面は素通りする。これを拾うために、正本以外の面が①〜④を自分の言葉で述べていないかを文単位で見る走査を併せ持つ（SHALL）。ただしこの走査は**この spec が列挙した言い回しに対する検査**であって、任意の言い換えを検出するものではない（SHALL）。自由な言い換えを正規表現で網羅的に検出することは原理的に不可能で、検出力を上げようとするたびに別の言い回しに抜けられる。機械層が担うのは、①ホワイトリストによる**正本への到達可能性**（トリガー語に掛かった面から正本に辿り着けること）と、②この走査による**列挙した言い回しの検出**の 2 つだけであり、本文が 1 箇所にあることそのものを担保するのは、前段で名指しした面への MUST NOT と仕様レビューである（SHALL）。参照を持つ面の中の再掲はホワイトリストからは原理的に見えず、それがこの走査を足した理由である。トリガーと同じく、取りこぼしより誤検出に倒す（再現率優先。SHALL）。

誤検出は 2 種類あり、解消の道はそれぞれ別である（SHALL）。①〜④の答えを述べている文は、正本への参照に書き換えれば解消する（本文をそこに置かない設計なので、この書き換えは常に可能である）。①〜④の答えを述べていない文（手渡しと無関係な文が語彙に掛かった場合や、答えではなく正本の置き場所を定めているこの要件本文そのもの）は、内容として参照に書き換えられないので、テスト内の除外表に載せて解消する。除外表の各行は〈面のパス・その文に現れる断片・理由コメント 1 行〉の 3 つ組とし、その断片を含む文だけを外す（SHALL）。面単位で外してはならない（MUST NOT。ファイル全体を外すと、その面に規則を書き足しても検出されない穴になる）。除外表の各行は、その断片が現に走査に掛かることを検査し、掛からなくなった行があればテストを落とさなければならない（MUST。stale な除外を残さないため）。

走査が見る言い回しはこの spec が列挙し、実装が語彙を勝手に決めてはならない（MUST NOT）。各規則は「話題語（その文が①〜④のどれについて述べているか）」と「規範の述語（禁止・限定・義務・手順）」の組み合わせで、同じ文にすべて現れたときに拾う。①②③については、述語が**文末**（残り 15 文字以内）に来ることを求める（SHALL）。日本語の規範文は述語で終わるので、名詞句を並べただけの話題の列挙は述語で終わらず、これで規則の再掲と区別できる。

走査の単位となる 1 文は、ファイルの 1 行を `。` で区切ったものとする（SHALL。**文末**とはこの区切りの終端を指す）。行をまたいで書かれた 1 文は別々の文として扱い、そのため改行で分かれた再掲は検出されない（上に述べた再現率の限界の一部である）。判定の前に、`【` と `】` で囲まれた注記を取り除く（SHALL。走査の限界を注記した本文が自分の走査に掛かるのを避けるため）。③の述語の判定にだけ、書式リテラル（`工程完了: <工程名>` / `工程中断: <理由>`）を取り除いた文を使う（SHALL。リテラルの引用は再掲に当たらないため。話題語と足切りの判定は取り除く前の文に当てる）。この前処理も語彙と同じくこの spec 側の決定であり、実装が勝手に決めてはならない（MUST NOT）。

同じ文が正本への参照を含んでいても、その文を検査から外してはならない（MUST NOT）。参照を文の末尾に添えたうえで規則を再掲する形が最も自然な書き方であり、この設計の動機になった実物（PR #253 の修正前の `SKILL.md`）がその形だったので、参照を含む文を外すと穴が一番当たりやすい所に開く。前段で MAY として認めたガード 1 行は、正本を読む義務だけを述べる文であって、話題語と規範の述語が同じ文に揃わないため、この走査には掛からない（揃う書き方をした面は、規則の再掲としてこの走査が拾う）。

- **①再開の禁止**
  - 状況（話題語。上限超過の状況）: `上限…超` / `超過` / `exit 2` / `over_cap` / `CONTEXT_CAP` / `キャップ…超`
  - 指示（話題語。続行の指示）: `再開` / `続き` / `続行` / `継続` / `作業を続` / `SendMessage`
  - 述語（続行の指示の直後 15 文字以内、かつ文末）: `ない` / `禁止` / `禁じ` / `不可` / `するな` / `せず` / `やめ` / `控え` / `避け`
- **②手渡しの許可条件**
  - 行為（話題語。手渡しの行為）: `手渡` / `後任` / `交代` / `spawn` / `新しい W` / `新しい G` / `新しいエージェント` / `新しい担当` / `新しい実行役` / `新しいゲート役` / `新しいサブエージェント`
  - 状態（話題語。許可条件になる状態）: `前任` / `工程完了` / `工程の終わり` / `完了宣言` / `停止確認` / `直近の return`
  - 述語（文末）: `ときだけ` / `ときのみ` / `場合だけ` / `場合のみ` / `に限る` / `に限り` / `だけとする` / `だけである` / `だけ` / `のみ` / `てよい` / `してよい` / `できるのは` / `よいのは`
- **③宣言の書式と選び方**
  - 話題（話題語。宣言の置き場所）: `1 行目` / `一行目` / `先頭行` / `先頭の 1 行` / `冒頭の 1 行` / `冒頭行` / `工程完了` / `工程中断`
  - 述語（文末）: `完全一致` / `に一致` / `にする` / `にすること` / `にせよ` / `にしなければ` / `としなければ` / `でなければ` / `を選ぶ` / `どちらか` / `宣言する` / `宣言してはならない` / `宣言義務`
  - 文脈（足切り。同じ文が次のいずれかを含むこと）: `工程` / `手渡` / `return` / `後任` / `交代` / `前任`
  - 足切りを置く理由: 仕様化判断・仕様レビュー・仕様宣言など、別の規則が定める 1 行目書式の文を巻き込まないため
- **④停止指示と停止確認**
  - 停止（話題語）: `停止` / `止ま` / `止める` / `止めて` / `中止`
  - 確認（話題語。停止したことの確認）: `確認` / `返事` / `報告` / `応答`
  - 文脈（話題語。手渡しの文脈）: `前任` / `手渡` / `交代` / `後任` / `spawn` / `新しい`
  - 述語（手順。文末は求めない）: `受け取` / `してから` / `る前に` / `待ってから` / `得てから`

この列挙は書式リテラルの固定と同じくこの spec 側の決定であり、広げるときも狭めるときも spec を先に直す（SHALL）。

一覧の各行は〈グループ名（説明）: バッククォートで囲んだ語を ` / ` で区切って並べたもの〉の形とする（SHALL）。グループ名には `状況` / `指示` / `行為` / `状態` / `話題` / `文脈` / `停止` / `確認` / `述語` の 9 語だけを使い、規則の番号と組にして 13 グループを一意に指す。語はすべて文字どおりの文字列とし、記法は `…`（6 文字以内の任意の文字）の 1 つだけとする（SHALL）。この形を定めるのは、次の段落でテストがこの一覧を機械的に読み取るためである。

テストは語彙の一覧をテスト内に写して持ってはならず、live spec のこの一覧を読み取って使わなければならない（MUST NOT / MUST）。写しを持つと、spec の一覧を残したまま実装とテストの両方から同じ語を消しても全テストが緑になる（実測: `工程の終わり` を実装とテストの写しから消しても 36/36 緑だった）。読み取れたグループが 13 個に満たないとき、またはどれかのグループが空のときは、テストを落とさなければならない（MUST。読み取りが黙って何も返さないと、語彙に関する検査がまとめて消えるため）。

再掲の走査が実際に発火することを確かめるテストは、①〜④のサンプルを 1 回のスキャンにまとめてはならない（MUST NOT）。1 規則につき 1 回スキャンし、そのサンプルがその規則**だけ**で報告されることを検査しなければならない（MUST）。まとめて「4 つの規則名が出力に全部含まれるか」だけを見ると、あるサンプルが 2 つの規則に掛かる取り違えを見逃す。サンプルは各規則につき、正本の語をそのまま使った文と、正本の語をひとつも使わない言い換えの 2 本を含めなければならない（MUST。後者が無いと、実装が正本の語をそのまま照合しているだけでも緑になる）。

前段で名指しした参照面と正本が、現に検査対象（機械的な列挙から除外を引いた集合）に入っていることを検査しなければならない（MUST）。除外を広げれば任意の面を検査から外せて全テストが緑のまま通るので、除外が上の 3 種を超えて広がっていないことの下限をここで固定する（実測: 名指しした 7 つの面と 2 つの live spec を除外に足しても全テストが緑だった）。

検査対象のうち、トリガー語で発火して正本への参照を持つ面が書いた正本へのパスは、実在するファイルに解決しなければならない（MUST）。対象は名指しした参照面だけでなく、参照 1 行を足して合格した任意の面を含む（SHALL。ホワイトリストは任意の面に参照を求めるので、名指しの面だけを見ると、あとから参照を足した面のポインタが壊れても素通りする）。解決の基準はリポジトリルート・その面自身のディレクトリ・プラグインルート・正本が置かれたスキルのディレクトリの 4 つとし、`${CLAUDE_PLUGIN_ROOT}` と `${PLUGIN_DIR}` はプラグインルートに置き換えてから見る（スキルの文書は自分のスキルルートからの相対でパスを書くため）。参照とみなす判定は文字列を含むかしか見ないため、パスが壊れていても参照として合格する。参照だけになった面はポインタが壊れるとその面で機構が失効し、「規則を知らないまま即興する」状態に戻る。

検査が実際に違反を報告することを、使い捨てのリポジトリに違反を置いた負のコントロールで固定しなければならない（MUST）。実リポで 0 件を期待するアサーションだけでは、緑が「違反が無い」のか「検査が何も見ていない」のかを区別できない（実測: 参照の有無を常に真にしても、語彙 A を絶対マッチしない正規表現に変えても、全テストが緑だった）。

この spec が列挙した語彙の各要素は、それ単独で走査を発火させることを検査しなければならない（MUST）。要素ごとに合成した文を走らせ、その文がその規則だけで報告されることを確かめる。ある要素を実装から消しても別のサンプルが他の語で拾ってしまい、全テストが緑のまま通る形を避けるため（実測: `工程の終わり` を削除しても全テストが緑だった）。

正本が①〜④のそれぞれを規定していることを検査するテストを、`plugins/dev-workflow/tests/` に維持しなければならない（MUST）。この spec は①〜④の答えを再掲しないので、正本の答えが逆に書き換わったときに落ちるのはこのテストだけである（`openspec validate` は索引としての充足しか見ない）。ホワイトリスト化の対象は参照面であって正本ではなく、正本の中身を固定するアサーションをホワイトリスト化に伴って落としてはならない（MUST NOT）。

#### Scenario: 上限超のサブエージェントは exit 2
- **WHEN** トランスクリプトの最後の assistant usage の合算が `DEV_WORKFLOW_CONTEXT_CAP` を超える
- **THEN** `over_cap: true` の JSON を出力して exit 2 で終わる

#### Scenario: 列挙した言い回しでの再掲は正本以外に無い
- **WHEN** 正本を対象から外して追跡ファイルを走査し、この spec が列挙した話題語（上限超過の状況・手渡しの行為・宣言の置き場所・停止とその確認）と規範の述語（禁止・限定・義務・手順）の組み合わせに掛かる文を数える
- **THEN** 0 件（正本が①〜④を現に述べていることは `criteria:` 系のアサーションが担保しており、この走査が見るのは「正本以外に無い」ことだけである）
- **AND** これは列挙した言い回しに対する検査であって、任意の言い換えを検出するものではない（機械層が担うのは正本への到達可能性と列挙した言い回しの検出の 2 つで、本文が 1 箇所にあることそのものは名指しした面への MUST NOT と仕様レビューが担う）
- **AND** 正本への参照を同じ文に添えた再掲も、参照を理由に検査から外れない

#### Scenario: 走査の 1 文は行を「。」で区切ったもの
- **WHEN** 再掲の走査が述語の位置（文末）を判定する
- **THEN** 1 文はファイルの 1 行を `。` で区切ったものであり、判定の前に `【` と `】` で囲まれた注記を取り除く（③の述語の判定にだけ、書式リテラルを取り除いた文を使う）
- **AND** 行をまたいで書かれた 1 文は別々の文として扱われる（改行で分かれた再掲は検出されない）

#### Scenario: ①〜④の答えでない誤検出は文単位で除外する
- **WHEN** ①〜④の答えを述べていない文（手渡しと無関係な文、または正本の置き場所を定めている要件本文）が走査の語彙に掛かる
- **THEN** テスト内の除外表に〈面のパス・その文に現れる断片・理由コメント 1 行〉を載せることで、その断片を含む文だけが外れる（面単位では外れない）
- **AND** 断片が走査に掛からなくなった除外行があれば、テストは落ちる

#### Scenario: 検出器のファイルは行単位でしか外れない
- **WHEN** 検査を実装している 2 ファイル（`tests/lib/handoff-scan.py`・`tests/handoff-declaration.bats`）の、印を持たない行に手渡し規則の再掲を書いて走査する
- **THEN** その行は検出される（`handoff-scan: fixture` の印を持つ行だけが外れ、ファイル全体は外れない）

#### Scenario: 発火の確認は 1 規則ずつ行う
- **WHEN** 再掲の走査が実際に発火することを確かめるテストを読む
- **THEN** ①〜④のサンプルを 1 回のスキャンにまとめず、1 規則につき 1 回スキャンし、そのサンプルがその規則だけで報告されること（他の規則としては報告されないこと）を確かめている
- **AND** サンプルは各規則につき、正本の語をそのまま使った文と、正本の語をひとつも使わない言い換えの 2 本を含む

#### Scenario: 参照だけの面は言い換えを持たない
- **WHEN** `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`session-tripwires.sh` の注入文・`subagent-context.sh` のヘッダコメント・2 つの live spec のいずれかで手渡しに言及している箇所を読む
- **THEN** そこには正本への参照（どのファイルのどの節か）があり、手渡しの条件・宣言の書式の意味・停止確認の手順を自分の言葉で述べた文は無い

#### Scenario: 常駐ルール文は正本を読む義務を持つ
- **WHEN** `scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文を読む
- **THEN** 正本への参照と、正本を読むまで手渡さない旨のガード 1 行があり、手渡しの条件・書式・手順を自分の言葉で述べた文は無い

#### Scenario: 配布メタデータのズレは違反ではない
- **WHEN** `.claude-plugin/plugin.json` の `description` の要約が正本と食い違っている
- **THEN** それはこの要件の違反ではなく、テストの検査対象にも入らない（エージェントが読まない配布メタデータであるため）

#### Scenario: 宣言の書式リテラルは変えない
- **WHEN** W / G の return の 1 行目の書式を変更しようとする
- **THEN** `工程完了: <工程名>` と `工程中断: <理由>` の 2 つは変更しない（別エピックの子 issue がこの書式を前提にしているため）

#### Scenario: 参照を持たない言及はテストが落とす
- **WHEN** 正本以外の面に、トリガー語を含みながら正本への参照を含まない状態でテストを実行する
- **THEN** テストは落ち、そのファイルとトリガーに掛かった行を示す（トリガー語に掛かった面である限り、その先の言い回しが既知かどうかに関係しない）

#### Scenario: 固有語を使わない言及も一般語のトリガーで拾う
- **WHEN** `plugins/dev-workflow/references/workflow-execution.md` のように、`手渡` の語を使わずに「乗り換え時の成果引き継ぎ」と述べている面を検査する
- **THEN** 語彙 B のトリガーで拾われ、正本への参照を足すか、理由コメント 1 行を添えて除外表に載せるかのどちらかが要求される
- **AND** 語彙 A で発火した面は除外表に載せることができない

#### Scenario: テストは禁止語の列挙で判定しない
- **WHEN** テストの実装を読む
- **THEN** 判定は「トリガー語に掛かった面が正本への参照を含むか」であり、禁じたい言い回しの列挙ではない
- **AND** 検査する面は `git ls-files` からの機械的な列挙で、手で書いた面の一覧ではない（除外は歴史記録・change の `proposal.md` / `tasks.md`・`plugin.json` の 3 種だけ）
- **AND** `plugins/dev-workflow/tests/` 自身も検査対象に入っている

#### Scenario: 書式に当てはまらない return の扱いも正本が決める
- **WHEN** W / G の return の 1 行目が、固定された 2 つの書式のどちらにも当てはまらない
- **THEN** その扱いは正本が規定しており、この spec も他の面もその答えを書かない（本体が内容から読み替える余地を残さない）

#### Scenario: 名指しした面は検査対象から外せない
- **WHEN** 除外の条件を広げて、名指しした参照面や正本を検査対象から落とす
- **THEN** テストは落ちる（除外が 3 種を超えて広がっていないことの下限を固定しているため）

#### Scenario: 正本へのパスは実在するファイルに解決する
- **WHEN** トリガー語で発火して正本への参照を持つ面が、正本を指すパスを書く
- **THEN** そのパスはリポジトリルート・その面自身のディレクトリ・プラグインルート・正本が置かれたスキルのディレクトリのいずれかから実在するファイルに解決する（`${CLAUDE_PLUGIN_ROOT}` と `${PLUGIN_DIR}` はプラグインルートに置き換えて見る）
- **AND** 解決しないパスがあればテストは落ちる（文字列を含むかだけを見る参照の判定では素通りするため）
- **AND** 検査する面は名指しの 9 面ではなく、発火して参照を持つ面すべてである

#### Scenario: 検査が何も見ていない状態を負のコントロールが落とす
- **WHEN** 参照の有無の判定やトリガー語の判定を無効化してテストを実行する
- **THEN** 使い捨てのリポジトリに置いた違反が報告されなくなり、テストは落ちる

#### Scenario: 語彙の要素はひとつずつ発火を確かめる
- **WHEN** この spec が列挙した語彙から要素をひとつ実装で削る
- **THEN** その要素だけで組んだ合成文が報告されなくなり、テストは落ちる

#### Scenario: 語彙の一覧はテストが spec から読み取る
- **WHEN** この spec の一覧はそのままにして、実装とテストの両方から語彙の要素をひとつ削る
- **THEN** テストは落ちる（テストは spec の一覧を読み取って使うので、実装から消えた要素の発火が確かめられなくなる）
- **AND** 読み取れたグループが 13 個に満たない、またはどれかが空のときもテストは落ちる

#### Scenario: 正本の中身はテストが固定する
- **WHEN** 正本の「コンテキスト上限（サブエージェントの手渡し）」節が①〜④のどれかを答えなくなる、または答えが逆に書き換わった状態でテストを実行する
- **THEN** テストは落ちる（この spec は①〜④の答えを再掲しないため、規範の中身を担保するのはこのテストだけである）

#### Scenario: トランスクリプトが無くても作業は止まらない
- **WHEN** `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **THEN** `error` を含む JSON を出力して exit 1 で終わり、本体は従来どおり再開してよい（上限判定が効かないだけ）

### Requirement: model 未指定の Agent spawn は hook が拒否する
`hooks/hooks.json` は PreToolUse（matcher: `Agent`）に `scripts/agent-model-guard.sh` を登録しなければならない（MUST）。hook は stdin の payload（`tool_name` / `tool_input`）を読み、`tool_name` が `Agent` 以外なら何もしない。`tool_input.subagent_type` が `fork` なら `model` の有無にかかわらず共有枠モード（明示 env `SHARED_BUDGET_MODE`、無ければ usage snapshot の `weekly_all_pct` から導出。90 超は `depleted`、週経過% 超は `throttled`）が `ok` のときだけ許可し、それ以外は拒否する（MUST。fork は model パラメータを無視して親モデルで動くため）。

fork 以外で `model` が Fable（エイリアス `fable`、または `claude-fable-*` の完全 ID。大文字小文字と前後の空白を無視して判定する）を指す場合は、`subagent_type` が決める役の allowlist（`dev-workflow:decider`。将来増えたらスクリプト内の allowlist に足す）に載っているときだけ許可し、それ以外（`general-purpose` / `Explore` / `Plan` / 未指定 / 他のプラグイン種別）は拒否しなければならない（MUST）。拒否理由には決める役の種別名 `dev-workflow:decider` と、実行役の代替（`sonnet` / `opus`）と、規範（`rules/subagent-model-selection.md`）を含める（SHALL）。この判定はセッションの種類（対話 / 住人 / cron / loop）で変えてはならない（MUST NOT）。Fable 判定は残量（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` / usage snapshot）をいっさい参照してはならない（MUST NOT。ガードは「誰が Fable になりうるか」の構造上の上限を見る層で、「今 Fable を使ってよいか」の助言は従来どおり develop 側の残量モードが担う。ガードが snapshot を読むと判定が鮮度と fail-open に依存してしまう）。既存の `fork` 判定が `SHARED_BUDGET_MODE` を見ることと、全解除の `DEV_WORKFLOW_MODEL_GUARD=off` はこの制限の対象外で、従来どおり残す（SHALL）。

Fable 以外の `model` があれば許可し、定義側に model を持つエージェント種別（`plugin:agent` 形式・casting 系）も許可する。`subagent_type` が空・`general-purpose`・`Explore`・`Plan`・`claude`・`claude-code-guide`・`statusline-setup` で `model` が無ければ拒否する（MUST）。拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とし、理由に規範（rules/subagent-model-selection.md）と選ぶべきティアを含める（SHALL）。`model` 未指定の拒否理由に列挙するティアは `haiku`（機械的）/ `sonnet`（通常実装・調査）/ `opus`（設計・レビュー）とし、`fable` は決める役の種別でだけ使えることを添える（SHALL）。payload は環境変数や引数に載せず stdin から読む（MUST。長い prompt で ARG_MAX を超えると hook が非 0 で落ちて素通りになるため）。stdin が読めない・python3 が無い・snapshot が読めないときは fail-open（exit 0・無出力）とし、`DEV_WORKFLOW_MODEL_GUARD=off` で全許可できる（SHALL）。

#### Scenario: model 無しの general-purpose は拒否される
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}` を hook に渡す
- **THEN** `permissionDecision: deny` の JSON が出力され、理由に `subagent-model-selection` と `sonnet` が含まれる

#### Scenario: general-purpose への fable は拒否される
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"fable"}}` を hook に渡す
- **THEN** `permissionDecision: deny` の JSON が出力され、理由に `dev-workflow:decider` と `sonnet` / `opus` の代替が含まれる

#### Scenario: 完全 ID の Fable も同じ扱い
- **WHEN** `model` が `claude-fable-5-1` の `general-purpose` 呼び出しを渡す
- **THEN** エイリアス `fable` と同じく拒否される

#### Scenario: subagent_type 未指定・Explore・Plan・他プラグイン種別への fable も拒否される
- **WHEN** `subagent_type` を省いた、あるいは `Explore` / `Plan` / `casting:casting-arbiter` を指定した `model: "fable"` の呼び出しを渡す
- **THEN** いずれも拒否される

#### Scenario: 決める役の種別への fable は通る
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:decider","model":"fable"}}` を渡す
- **THEN** 無出力・exit 0 で許可される

#### Scenario: 実行役のモデルは従来どおり通る
- **WHEN** `general-purpose` に `model` が `opus` / `sonnet` / `haiku` の呼び出しを渡す
- **THEN** いずれも無出力・exit 0 で許可される

#### Scenario: fork は共有枠モードで決まり model を渡しても変わらない
- **WHEN** `SHARED_BUDGET_MODE=depleted` で `{"tool_name":"Agent","tool_input":{"subagent_type":"fork","model":"sonnet"}}` を渡す
- **THEN** 拒否される。`SHARED_BUDGET_MODE` 未設定かつ snapshot 無しなら許可される

#### Scenario: 3MB の prompt でも判定される
- **WHEN** `prompt` が 3,000,000 文字の model 無し payload を stdin から渡す
- **THEN** exit 0 で拒否の JSON が出る（ARG_MAX で落ちない）

#### Scenario: 全解除は従来どおり効く
- **WHEN** `DEV_WORKFLOW_MODEL_GUARD=off` で `general-purpose` への `model: "fable"` を渡す
- **THEN** 無出力・exit 0 で許可される

#### Scenario: hooks.json に配線されている
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `PreToolUse` に matcher `Agent`・command `${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh` のエントリがある

