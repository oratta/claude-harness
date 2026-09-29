## Context

`plugins/dev-workflow/skills/develop/references/roles/worker.md` は 13,416 字（180 行）で、W の全工程の手順を 1 ファイルに持つ。W のエージェント定義 `agents/worker.md` の本文は「このファイルを読み、その指示に従う」だけを書いており、W はどの工程で起こされても全部を読む。

節ごとの大きさ（字。`#553` 以降の main、2850fe32 時点）:

| 節 | 字数 | 使う工程 | 主な読み手 |
|---|---|---|---|
| 冒頭（本体が渡すもの・このファイルだけを読む） | 380 | 全部 | W |
| W がしないこと | 391 | 全部 | W |
| 記録先の用意（Draft PR を記録先にする場合） | 749 | (1)（Draft PR 経路だけ） | W |
| 仕様化判断と記録 | 1,563 | (1) | W |
| 分割判定 | 1,087 | (1)（仕様化する場合） | W |
| 仕様化する場合（(1) の終わり） | 881 | (1)・R1 差し戻しの修正 | W |
| (3a) 実装＋verify | 2,760 | (3a)・G の failed / CI の fix の修正 | W |
| (3b) archive＋PR＋仕様宣言 | 973 | (3b) | W |
| 重要実装の事前分類 | 1,691 | なし（W は自分のモデルを選ばない） | 本体・R1 と G の起動・pr-review-gate |
| 昇格トリップワイヤー | 1,130 | (3a)（規模超過・失敗ループ・実装中の仕様の発明） | W・本体 |
| コンテキスト上限と手渡し | 1,811 | 全部（return の書式と手渡し） | W（うち「(3) をこれより細かく切らない」295 字は本体向けの理由） |

参照元: 事前分類表は develop の `SKILL.md`（(1) の spawn の行・「モデル」の役割表）・`references/roles/spec-reviewer.md`・`references/decision-criteria.md`（残量モード表）・pr-review-gate の `stages/triage.md`・`references/model-tiers.md`・`README.md` から「worker.md が正本」として参照される。worker.md の他の節は `SKILL.md`（(3) の理由の正本）・`decision-criteria.md`（読んだコードの要点の書式）・`templates/escalation-tripwires.md`・pr-review-gate の `declarations.md`（仕様化判断の記録）から参照される。`scripts/codex-develop.py` は Codex の W の phase（spec / implement / finish / explore / summarize）に worker.md 全体を正本として付ける。既存 spec は `dev-workflow-develop` を中心に約 70 か所で worker.md の節を指す。

前提: #555（W の引き継ぎに読んだコードの要点と tasks.md に触る範囲を書く）と #553（pr-review-gate を索引と段のファイルに分ける）はマージ済み。移すのは #555 の追記を含む本文。

## Goals / Non-Goals

**Goals:**

- W が 1 回の起動で読む指示書（共通の部分とその段のファイル）の合計を、どの段でも 7,000 字以下にする。
- worker.md を、中身を持たない索引にする。
- 同じ手順を 2 か所に書かない。
- 事前分類表の参照元がすべて新しい置き場所を指す。

**Non-Goals:**

- 手順の中身（規則・書式・コマンド・閾値）の変更。移すだけ。
- W の工程の切り方（(1)・(3a)・(3b)）と、本体が W を名前付き spawn して SendMessage で再開する流れの変更。
- W が return の前に読む `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」（6,619 字）や、(3b) で読む `declarations.md`（3,784 字）の縮小。
- 既存 spec の要件本文の書き換え（作業者の定義本文の 1 要件を除く）。

## Decisions

### 段の構成（確定案）

ファイルは `plugins/dev-workflow/skills/develop/references/roles/worker/` の下に置く。段の名前は Codex の phase 名（`spec` / `implement` / `finish`）と同じにし、ファイル名もそれに合わせる。

| 段（`段:` の値） | 日本語名 | 工程 | ファイル | 持つ節（見出しは現行のまま） | 見積もり（字） | 共通と合わせた合計（字） |
|---|---|---|---|---|---|---|
| （全段） | 共通 | 全部 | `worker/common.md` | 冒頭の「本体が渡すもの」（`段:` の行を足す）・W がしないこと・コンテキスト上限と手渡し（「(3) をこれより細かく切らない」を除く） | 約 2,300 | — |
| `spec` | 仕様づくり | (1)・R1 の差し戻しの修正 | `worker/spec.md` | 記録先の用意（Draft PR）・仕様化判断と記録・分割判定・仕様化する場合 | 約 4,350 | 約 6,650 |
| `implement` | 実装と検証 | (3a)・G の failed と CI の fix の修正 | `worker/implement.md` | (3a) 実装＋verify・昇格トリップワイヤー | 約 3,900 | 約 6,200 |
| `finish` | 仕上げ | (3b) | `worker/finish.md` | (3b) archive＋PR＋仕様宣言 | 約 1,000 | 約 3,300 |

判断の理由:

- **事前分類表は共通に置かず、W が読まない `skills/develop/references/pre-classification.md` に移す。** issue の概要は事前分類を共通の部分に挙げていたが、この表を使うのは W を起こす本体と、R1・レビュアーの種別を決める側で、W は自分のモデルを選ばない。共通に置くと共通が約 4,000 字になり、仕様づくりの段は約 8,350 字で 7,000 字を超える。置き場所を develop の `references/` 直下にするのは、読み手が develop の本体・R1・G・pr-review-gate にまたがり、W の指示書の下（`roles/worker/`）に置くと「W が読むもの」と誤読されるため。`decision-criteria.md` に入れる案は、W が return の前にそのファイルの節を読むので採らない。
- **昇格トリップワイヤーは共通に置かず、実装と検証の段に置く。** issue の概要は「昇格の報告」を共通に挙げていたが、3 つの条件（編集対象が 5 ファイル超・同じテストの 2 連続失敗や同じ箇所の 2 回の書き直し・記録先に無い仕様上の決定を 2 回埋めた）はどれも実装中に起きる。仕様づくりの段の決定は R1 のレビューを受ける artifact そのもので、仕上げの段は実装に手を入れない。共通に置くと仕様づくりの段は約 7,750 字で上限を超える。節の本文（本体の乗り換え先の説明を含む）は削らずにそのまま移す。**この判断は R1 1 周目の B4 で差し戻されており未決**（仕様づくりと仕上げの段で条件が効かなくなる。Open Questions の 2 つ目）。
- **「(3) をこれより細かく切らない」の箇条は develop の `SKILL.md` の (3) に移す。** これは本体が工程の区切り方を決めるときの理由で、W は区切り方を選ばない。いまの SKILL.md の (3) は短い理由と「理由の正本は worker.md」を書いているので、その 2 行を移した箇条の本文で置き換え、正本を SKILL.md にする。移した先では手渡しの固定分の説明をそのまま使う。
- **索引は W が読まない。** W が読むのは `common.md` とその段のファイルだけで、どちらを読むかはエージェント定義と起動指示の `段:` で決まる。索引 worker.md は、本体・参照元・人間が段の割り当てを引くためのもの。索引も読ませると仕様づくりの段は約 8,000 字を超えるになる。
- 代案として検討したもの: (a) Draft PR の記録先の用意を別ファイルにして、その経路の W だけに読ませる案。Draft PR 経路の仕様づくりの段の合計は変わらないので上限の問題を解かず、ファイル数だけ増えるので採らない。(b) 分割判定と仕様化する場合を「仕様化すると判定したら読む」別ファイルにする案。最悪の場合の合計は変わらず、条件付きで読むファイルが増えると bats で上限を検査する単位がぼやけるので採らない。

### 段をまたぐ参照

移した節の中の「下の『コンテキスト上限と手渡し』」「上の『仕様化する場合』」のような位置の参照は、ファイル名と節名（例: `common.md`「コンテキスト上限と手渡し」）に直す。同じファイルの中の参照は位置の書き方のままでよい。中身を言い換えて再掲しない。

仕様化しないと判定して本体が「そのまま (3a) に進んでよい」と指示したときは、W は `worker/implement.md` を読んでから続ける。これを `spec.md` の仕様化しない場合の段落に 1 文足す（いまは 1 ファイルなので書く必要が無かった）。

### 本体が W に段を伝える

本体は W の起動指示・SendMessage による再開指示・手渡しの起動指示に `段: spec` / `段: implement` / `段: finish` の 1 行を必ず書く。G の起動指示の `段: <段の名前>` と同じ書式で、値は英小文字の段の名前（ファイル名と同じ）にする。対応は次のとおり。

| 本体の場面（develop の SKILL.md） | `段:` |
|---|---|
| (1) の spawn、(2) で R1 が REQUEST_CHANGES を返したときの再開 | `spec` |
| (3a) の再開、(4) の failed のあと W に直させる再開、CI の見張りの一手が `fix` のとき W に直させる再開 | `implement` |
| (3b) の再開 | `finish` |
| 手渡しで、前任が工程の途中で止まり（return の 1 行目が `工程完了:` でない）後任に同じ工程を続けさせる | 前任が担っていた段 |
| 手渡しで、前任が工程を終えて（1 行目が `工程完了:`）return したあとに後任へ次の工程を指示する | 本体が次に指示する工程の段（(3a) を終えた前任の後任に (3b) を指示するなら `finish`） |

手渡しでも `段:` の値は「本体がその起動で指示する工程」で決まる、という 1 つの規則にそろえる。前任が担っていた段をそのまま引き継ぐ規則にすると、既存要件「W の (3) は 2 回の return に分かれる」で (3a) の return のあとに手渡して (3b) を指示する経路が `implement` になり、後任が (3b) の手順を読まない。次に指示する工程は、既存要件のとおり本体が自分の指示した工程から決め、前任の return の工程名の文字列からは決めない。

エージェント定義 `agents/worker.md` の本文は、`skills/develop/references/roles/worker/common.md` と、起動指示の `段:` の行が指す `worker/<段>.md` を読むこと、`段:` が無いか値が `spec` / `implement` / `finish` のどれでもなければ読まずに本体へ聞き返すことを書く。この判定の守備範囲（入力は本体の指示の本文、拾うのは `段:` の書き忘れ、値の食い違いは通る）は `dev-workflow-role-agent-types` の delta spec に書く。SendMessage で再開された W は、共通の部分を読み直さず、新しい段のファイルだけを読む。

### 事前分類表の参照元の付け替え

`pre-classification.md` には「重要実装の事前分類」節をそのまま移し、「この分類表がモデル事前分類の正本。pr-review-gate スキル・R1・G からも参照される。ここ以外に再掲しない」の文もそのまま持たせる。参照元は、「worker.md の事前分類表」「worker.md が正本」「`references/roles/worker.md` の『重要実装の事前分類』表」と書いている行のパスを `references/pre-classification.md` に直す（develop の `SKILL.md` の (1) と「モデル」の役割表・`references/roles/spec-reviewer.md`・`references/decision-criteria.md`・pr-review-gate の `stages/triage.md`・`plugins/dev-workflow/references/model-tiers.md`・`plugins/dev-workflow/README.md`）。

### 既存 spec の本文は書き換えず、読み替えの要件を足す

既存要件は worker.md の節を「`references/roles/worker.md` の X の節を読む」「worker.md に Y がある」の形で約 70 か所指す。#553 と同じく、全部を MODIFIED にせず、読み替えの要件を足す。既存要件が worker.md に置く・含む・書く・明記すると定めた内容は、下の対応表の移し先を指すものとして読む。否定の要件（「worker.md に `/wt-setup` を呼ぶ記述が無い」「`/opsx:` が出てよいのは…の行だけ」など）は、索引と `worker/` の 4 本と `pre-classification.md` の全部に掛ける。

| 旧 worker.md の節 | 移し先 |
|---|---|
| 冒頭（本体が渡すもの） | `worker/common.md` |
| W がしないこと | `worker/common.md` |
| 記録先の用意（Draft PR を記録先にする場合） | `worker/spec.md` |
| 仕様化判断と記録 | `worker/spec.md` |
| 分割判定 | `worker/spec.md` |
| 仕様化する場合（(1) の終わり） | `worker/spec.md` |
| (3a) 実装＋verify（全経路共通の大原則・順 3 の一覧の段落・(3a) の return を含む） | `worker/implement.md` |
| (3b) archive＋PR＋仕様宣言 | `worker/finish.md` |
| 重要実装の事前分類 | `references/pre-classification.md` |
| 昇格トリップワイヤー | `worker/implement.md` |
| コンテキスト上限と手渡し（「(3) をこれより細かく切らない」を除く） | `worker/common.md` |
| 「(3) をこれより細かく切らない」の箇条 | develop の `SKILL.md` の (3) |

読み替えの要件は、要件の所在に合わせて `dev-workflow-develop`（対応表の正本）と、worker.md を指す既存要件を持つ `dev-workflow-spec-review`・`dev-workflow-pr-review-gate`・`dev-workflow-subagent-waiting` の delta に置く。後の 3 つは対応表を写さず、該当する節と移し先だけを書く。`dev-workflow-role-agent-types` の作業者の定義本文の要件は、読み先そのものが変わるので MODIFIED にする。`dev-workflow-execution-strategy`・`manual-codex-develop`・`loops-longrun-retirement` の worker.md への言及は、W という役割やディレクトリ名としての言及か、PR 本文の型の参照先の検査（worker.md の後継のどのファイルにも古い参照が無いこと）で、`dev-workflow-develop` の読み替えで足りる。

### Codex に渡す正本の一覧

`scripts/codex-develop.py` の `PHASES` と `prompt()` は、W の phase に次を付ける: `spec` は `worker/common.md` と `worker/spec.md`、`implement` は `worker/common.md` と `worker/implement.md`、`finish` は `worker/common.md` と `worker/finish.md`、`explore` と `summarize` は `worker/common.md` だけ（読み取り専用で、段の手順を実行しない）。`decision-criteria.md` を付けるのはいまのまま。`tests/test_codex_develop.py` の `CANONICAL SOURCE` の期待値を合わせる。

### 検査（bats）

- 新規 `plugins/dev-workflow/tests/develop-worker-stages.bats`:
  - 索引 worker.md にコードブロック（```）が無く、段の表の `spec` / `implement` / `finish` の各行がちょうど 1 つの段のファイルを指し、そのファイルと `worker/common.md` が実在する。
  - 段ごとに `worker/common.md` とその段のファイルの字数（改行を含む Unicode の文字数。`python3` で数える）の合計が 7,000 以下。
  - `worker/` の 4 本と `pre-classification.md` の `## ` 見出しが、この 5 本と索引のうち 1 ファイルにだけある（同じ節を 2 か所に書かない）。
  - `pre-classification.md` に事前分類表の 4 行（聖域パス・マージ権限・層間契約・課金/法務）があり、`worker/` の 4 本と索引には無い。
  - `agents/worker.md` の本文が `worker/common.md` と `段:` を含む。
  - develop の `SKILL.md` に `段: spec`・`段: implement`・`段: finish` がそれぞれある。
  - 事前分類の参照元（上の 6 ファイル）が `pre-classification.md` を指し、事前分類について `roles/worker.md` を指していない。
- 構造の検査の守備範囲は `dev-workflow-develop` の delta spec「W の指示書は索引・共通・段のファイルに分かれている」に書く（#553 の `pr-review-gate-index.bats` と同じ形）。入力は索引・`worker/` の 4 本・`pre-classification.md` の中身で、拾うのは索引のコードブロック・段の表が指すファイルの不在・段ごとの 7,000 字超・`## ` 見出し行の重複。見出しを変えて同じ節を書いたもの・本文で規則を言い換えて再掲したもの・移すときの文言の変更・段のファイル以外を読む分は素通りするので PR レビューで見る。塞ぎ切ることは完了条件にしない。
- 既存 bats（`develop-roles`・`spec-decision-and-review`・`model-escalation-policy`・`subagent-waiting`・`subagent-stop-guard`・`handoff-declaration`・`retirement`・`role-agent-types`・`develop-skill`、リポジトリ直下の `tests/develop-worker-ci-checks.bats` ほか `git grep -l 'worker\.md\|WORKER' -- plugins/dev-workflow/tests tests` の全件）の各アサーションを、その文言が移ったファイルに 1 つずつ付け替える。全ファイルを連結して検査する方式は採らない（#553 と同じ理由: 文言が別の段に紛れ込んでも通ってしまい、その段だけを読む W が規則を見落とす事故を検出できない）。否定の検査（その文言がどこにも無いこと）は、索引と `worker/` の 4 本と `pre-classification.md` の全部で見る形に広げる。
- `subagent-stop-guard.bats` の対の検査は、複製の `worker/implement.md`（待ちの大原則が移る先）に違反を差し込む。`subagent-waiting.bats` が W の指示書として見るファイルも同じく `worker/implement.md` にし、長時間処理の待ちの規約が W の指示書の 1 か所にあることを見る。

## Risks / Trade-offs

- [正本が複数ファイルに分かれ、片方だけ直されて食い違う] → 索引は中身を持たず、節の見出しが 1 ファイルにだけあることを bats で検査する。段をまたぐ参照はファイル名と節名で書く。
- [事前分類表と昇格トリップワイヤーの置き場所が issue の概要と違う] → 上の判断の理由のとおり、issue の受け入れ条件 1（7,000 字以下）を満たすための変更で、中身は変えない。R1 のレビューで確かめる。
- [本体が `段:` を書き忘れる] → エージェント定義で、`段:` が無ければ読まずに本体へ聞き返すと書く。黙って全部を読む動きにはしない。
- [見積もりが外れて、ある段が 7,000 字を超える] → 仕様づくりの段の余裕は約 350 字。超えたら中身を削らず、本体に return する（移す先の選び直しは設計判断なので W が決めない）。
- [受け入れ条件 2（develop を通したときの W の指示書の読み込み量 8K 以下）を満たせない見込みがある] → この change で減るのは worker.md の分だけで、W が return の前に読む `decision-criteria.md`「コンテキスト上限」節（6,619 字。ファイル全体を読めば 11,782 字）と、(3b) の `declarations.md`（3,784 字）は残る。さらに本体は W を SendMessage で再開するので、(1)・(3a)・(3b) を 1 体で通した W は 3 つの段のファイルを合わせて読む。このため 1 体あたり 8K トークンを超える見込みが高い。受け入れ条件 2 は変えず、下の「読み込み量の計測（受け入れ条件 2）」のとおり個体ごとに測り、超えたら未達として主の判断に回す。
- [配布済みのキャッシュに古い agents/worker.md が残った W が新しい索引を読む] → プラグインの更新は agents/worker.md・索引・段のファイルを同じ commit で入れ替えるので、同じ版の中では食い違わない。古い版の W は古い worker.md を通しで読むだけで、手順の中身は変わっていない。

## 読み込み量の計測（受け入れ条件 2）

受け入れ条件 2（W の指示書の読み込み量 8K 以下）は変えない。#553 では主が同種の条件を「記録と follow-up issue」に改めたが、この change では改めず、記録しただけで達成扱いにしない。要件の正本は `dev-workflow-develop` の delta spec「W の指示書の読み込み量は個体ごとに測り、8K を超えたら主の判断に回す」。

- **個体ごとに測る。** `subagent-context-audit.sh --by-role` の `by_role.W.docs_median` は、個体ごとの合計（指示書 Read か Skill を含むホップの usage 差分）を W の担当内で中央値にしたもの（同スクリプト 51 行目付近のコメント）。受け入れ条件は「各作業担当」なので中央値では判定できない。スクリプトは変えずに、1 個体の `agent-<id>.jsonl` と `agent-<id>.meta.json` だけを作業用ディレクトリの `<a>/<b>/subagents/` に置いて `--projects` に渡し（走査経路は `<projects>/*/*/subagents/agent-*.jsonl`）、`--cache` に作業用ファイル、`--refresh` を付けて実行する。`by_role.W.count` が 1 なら `docs_median` がその個体の値になる。
- **計測対象。** 変更後の指示書で動いた develop の 1 本に現れた W の全個体（(1) の spawn、SendMessage で再開された個体、手渡しの後任）。この issue 自身の develop の W は、実行時の正本がキャッシュの変更前の worker.md なので計測対象にならない（比較のための変更前の値として記録してよい）。
- **数えられるパスの制約。** スクリプトが指示書の Read として数えるのは、`file_path` が `INSTR_RE`（`plugins/cache/oratta-claude-harness/.*\.md$`、同スクリプト 254 行目）に一致するものだけ。マージ前に `claude --plugin-dir <worktree>` で動かした W は worktree のパスから読むので、指示書の分が数えられず値が小さく出る。この値を 8K 以下の証拠にしない（未計測として扱う）。マージ前に有効な値を得る方法の候補は、`git archive` などで変更後の `plugins/dev-workflow` を、パスに `plugins/cache/oratta-claude-harness/` を含む作業用ディレクトリ（`~/.claude/plugins/cache/` の外）に展開し、そこを `--plugin-dir` に渡すこと。スクリプトの一致は部分一致（`search`）なので数えられる。この方法で実際に数えられるかは、計測の前に 1 個体で `docs_median` が 0 でないことで確かめる。確かめられなければ未計測として扱う。
- **誰がいつ行うか。** develop の 1 本を通すのは W ではなく本体（W はサブエージェントを起こさない）。この change の (3b) で PR ができたあと、(4) の G を起こす前に本体が行い、PR 本文の受け入れ条件 2 の節に個体ごとの表（agent id・担った工程・`count`・値・8,000 との比較・その個体が Read した指示書のファイル名と字数）を書く。W は (3a) の return に段ごとの字数の実測を書き、(3b) で PR 本文にこの節の枠（計測の手順と、まだ未計測であること）を用意する。
- **超えたとき・測れなかったとき。** 1 個体でも 8,000 を超えるか未計測の個体が残れば未達。PR 本文に個体ごとの値と内訳、超過や未計測を解消する手段を切った follow-up issue の URL を書き、G はリスク宣言に同じ未達を載せる。pr-review-gate の保留の経路で主の判断に回し、達成とは書かない。

## Migration Plan

1 本の PR で、段のファイルと `pre-classification.md` の作成・worker.md の索引化・エージェント定義と SKILL.md の `段:`・参照元とテストの付け替えを入れる。途中の commit で worker.md と移し先の両方に同じ節がある状態を作らないように、移す節ごとに「移し先に足す」と「worker.md から消す」を同じ commit にする。戻すときはこの PR を revert する。

## Open Questions

- 受け入れ条件 2 の扱いは閉じた（変えない。上の「読み込み量の計測（受け入れ条件 2）」）。
- 昇格トリップワイヤーの置き場所（R1 1 周目の B4。未決）。現行の worker.md では W はどの工程でもこの節を読んでおり、規模超過（編集対象 5 ファイル超・作業項目が 2 回増えた）と失敗ループのうち同じ箇所の 2 回の書き直しは、仕様づくりの段（R1 の差し戻しの修正を含む）でも起こりうる。W は hook 注入を受けない（`templates/escalation-tripwires.md` の導入手順のコメント）ので、`implement.md` だけに置くと仕様づくりと仕上げの段で条件が効かなくなる。一方、2850fe32 の worker.md の実測（改行込みの文字数）では、共通に入る節の合計が 2,339 字、仕様づくりの段に入る節の合計が 4,280 字、昇格トリップワイヤーの節が 1,130 字で、節を共通に移すと仕様づくりの段は `段:` の行などの追記前で 7,749 字になり 7,000 字を超える。節のうち本体の動き（失敗ループの原因分類とラダー・残量モードの上限・needs-approval）を書いた 529 字を本体が読む `SKILL.md` に移しても 7,220 字で超える。移すだけで 3 つ（全段で条件が効く・7,000 字以下・中身を変えない）を同時に満たす配置は見つかっていない。候補: (a) 節を `implement.md` に置いたまま、仕様づくりと仕上げの段では条件を効かせないことを設計判断として明記する（適用範囲が狭まる。規模超過の「編集対象 5 ファイル超」を仕様づくりの段に字義どおり当てると、artifact が 6 本以上の change では毎回発火する。この change は 8 本）。(b) 節を共通に移し、本体向けの 529 字を `SKILL.md` に移し、さらに「記録先の用意（Draft PR）」を本体が行う手順にして `spec.md` から外す（W の手順の担い手が変わるので既存要件の MODIFIED が要る）。(c) 仕様づくりの段だけ上限を緩める（受け入れ条件 1 の変更で主の判断）。どれを採るかは本体が決める。
