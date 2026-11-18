# Design

## Context

記録先は #1687、親は #1682。親の最初の OWNER コメントの決定（文言テストの場所の制約を弱め、場面ごとの予算で補う／動きを変えない／削減目標を置かない）を適用する。#1683 は main に入っており、出発点は e10f0a9896d82d0b86c0f7a10becb70c4983bc63。PR #1436 はファイル名の一覧だけを参考にし、commit・内容を取り込まない。

## Goals / Non-Goals

G が宣言した段と条件から読む先を一意に選べ、条件の成り立たない本文を入口から外す。移動前後の契約を保ち、段別に測った量を記録できるようにする。

新しい G の段や Status は足さない。review は計測上の名前で、develop の G を phase review のレビュアーに変えない。#1684 の epic 本文、#1685 の develop/SKILL.md の節構成、#1686 のスクリプト化には入らない。auto-merge やマージ権限を変更しない。

## Decisions

### 共通の入口を残し、条件付き本文を使う場面の正本へ移す

ファイルを機械的な行数で分割する案と、入口ファイルを全部読ませる案は採らない。前者では途中の条件を探す読み直しが増え、後者では使わない規則を読み続ける。段の入口と条件判定の短い分岐を残し、条件が成り立ったときに読む先を明記する。移動する本文の内容は保存する。以下のパスは plugins/dev-workflow/skills/ から。

gate-runner.md は役割・入力・読む表・レビュー経路の判別・Gate Result の共通欄・段と Status の対応・PR コメントを正とする入力契約を持つ。モデルの優先順位の再掲は既存の正本（develop/SKILL.md「モデル」、decision-criteria.md、references/model-tiers.md の各担当部分）への参照にし、G 自身はモデルを選び直さない。return-declaration.md の宣言を再掲しない。

| 元の本文（e10f0a98 の行） | 移動先（pr-review-gate/ から。新規） | 読む条件・残す入口 |
|---|---|---|
| develop/references/roles/gate-runner.md:38-54 三表の機械照合・補足受領、110-111 要約受領の分岐 | stages/gate-triage.md | 照合の G が要約・補足を受けたとき。gate-runner の照合の行から読む |
| stages/prepare.md:45-90 軽い通し方の確認・守備範囲 | stages/prepare-light.md | 手順 1 の 5 の HEAD 固定のあと、最新判断に「通し方: 軽い」があるときだけ読む |
| stages/prepare.md の 2-0 にある 600 行超の区画の本文 | stages/prepare-partitions.md | 一周目で差分が 600 行を超えたとき。重量判定と review-partitions.sh を走らせる既存の判定コマンドは prepare.md に残す。600 行以下でもそのコマンドを省かない |
| stages/prepare.md:138-166 needs-reviewer payload | stages/prepare-reviewer.md | adapter の前提確認の出口、または補足の payload を組むとき。雛形をここに集める |
| stages/triage.md:47-60 順 3 の一覧・2 段の照合 | stages/triage-row3.md | 順 3 の指摘・W の一覧を扱うとき。準備や三表の照合だけでは読まない |
| stages/triage.md:68-125 止めない指摘の段 A/B/D/E・候補探し・記録・切り出す欠陥の置き場所 | stages/triage-nonblocking.md | 止めない指摘が残る、または主が切り出すと答えたとき。切り出す欠陥に段 B/E を当てない規則もここに保存 |
| 同じ範囲の段 C と、候補探しのエピック固有の操作 | stages/triage-epic.md | 親を取得できた、または 404 以外の失敗が再試行でも続いたときの別リポ・失敗時の詳細、候補を child/other に分ける場面。親探索と 404 の判定は triage-nonblocking.md の入口に残し、探索を段 B より先にする順序を保存 |
| stages/triage.md:127-140 収束ルール・W の修正後の再レビュー（207 行の段落）と 32-45 行の周の終わり・混在の条件付き処理 | stages/triage-convergence.md | W 修正後の再レビュー、2 周目以降の周の終わり。prepare から必要な本文だけに接続する |
| stages/triage.md:142-171 手順 2-2 | stages/triage-escalation.md | failed の原因分類と戻し方を決めるとき。段 A のみは昇格なしも保存 |
| stages/triage.md:212-251 コメント上限 | stages/comment-parts.md | 三表または順 3 のコメントを投稿・復元し、本文が上限を超える／部分の参照があるとき |
| declarations.md:81-119 issue で承認済み、pass.md:162-172 確かめ直しと事後報告 | stages/issue-approved.md | 手順 3 の候補 3 分類、手順 5 でその状態の宣言を検査するとき。入口で除外する 4 分類は短い条件として残す |
| hold.md:17-95 手順 3-c、終了コード 4 の判定役 | stages/carryover.md、stages/carryover-judge.md | 前 HEAD に直接の許容があるとき。exit 4 の条件を満たす場合だけ judge を読む |
| hold.md:99-124 手順 6-0、declarations.md:71-79 の重複する結果の説明 | stages/no-point-check.md | 引き継ぎ・issue 承認の両方が当たらず、論点なしの行があるとき。needs-no-point-check の return 雛形は hold.md の既存ブロックに残し、ここからその節を参照 |
| pass.md:78-112 直接リンク／会話の真正性 | stages/authenticity.md、stages/authenticity-conversation.md | 許容済み状態に応じた入口から該当する形だけ読む。真正性不要の「リスクなし」では読まない |
| pass.md:113-137 親経由の真正性 | stages/authenticity-relayed.md | 親経由で受領（委任でない）の記録を検査・再確認するとき |
| pass.md:138-160 委任の真正性 | stages/authenticity-delegated.md | 親経由で受領（委任）の記録を検査・再確認するとき。有効性の判定・再確認を保存 |
| pass.md:203-207 文言合わせ専用の 3 コマンドと、該当する表の詳細 | stages/pass-wording.md | 同じ最新判断に「通し方: 文言合わせ」があるときだけ。判断取得・通常の照合表は pass.md に残す |
| hold.md:132-144 復帰手順の表と、その場面の G 入力 | stages/hold-resume.md | 主の回答を受領し保留を解除するとき |
| hold.md:146-161 承認を求めてよい 4 分類 | stages/hold-categories.md | 主へ依頼する前。hold.md はこの分類の確認を参照する |

行範囲は案内。見出しと本文を実装前に確かめること。長い 1 行に複数の条件があるものは、短い振り分けの文を元に残し、条件別本文を表の移動先に置く。既存の手順番号・見出しは移動先に一度だけ置く。宣言テンプレート（仕様宣言を含む）は declarations.md に、Gate Result 共通ブロックは gate-runner.md に残す。段の return ブロックは丸ごと逐語移動し、雛形中の旧パスは変更せず、その旧パスの入口から詳細へ辿れるようにする。

三表の区画別の照合は gate-triage.md の中でも区画のあるときだけ読む先を用意する（stages/gate-triage-partitions.md）。区画無しで区画数の比較を足さず、補足回数は PR 全体で 1 のまま。gate-triage.md から条件付きで読む。

通常の段入口に残すものは、prepare の HEAD 固定・重さ判定、triage の全周共通の停止判定と仕分け表・条件付き参照、pass の動作確認・合格条件の表・HEAD と宣言の実測・Ready 化、hold の依頼と条件付き参照。review-run と reviewer-brief は既存の実行経路・レビュアー向け契約の正本として保つ。同じ規則を説明し直す段落を足さない。

### 参照の付け替えと既存仕様との整合

既存仕様の「この旧ファイルのこの節に置く」は、移動表にある本文についてだけ移動先を指すものに更新する。既存の許可・禁止の意味や scenario の入力・出力は変えない。dev-workflow-pr-review-gate の配置を定める要件（手順の本文、同じ手順を再掲しない、G 入力の所在）と、dev-workflow-develop の G の読込表・gate-runner からの移動先を更新する。後者の古い 15K トークン目標の scenario は今回の字数記録に置き換える。

他 capability（dev-workflow-subagent-waiting、dev-workflow-spec-review、owner-question-style、dev-workflow-review-issue-candidates、dev-workflow-execution-strategy、dev-workflow-role-agent-types、dev-workflow-agent-effort、dev-workflow-pr-token-budget、destructive-git-hook）にある旧ファイルへの言及は、ゲート側の移動表による所在の読み替えの対象と明記する。移動表に無い規範には読み替えを掛けない。動作上の仕様の変更やこれらの capability の独立した整理は行わない。

develop/SKILL.md と epic.md 系で付け替える箇所（e10f0a98。本文の変更はパスと参照節に限定）:

- SKILL.md:30 の gate-runner「レビュー経路の判別」はそこに残すため変更不要。
- SKILL.md:70-71 の段 B/D/E と候補探し → triage-nonblocking.md、段 C → triage-epic.md。
- SKILL.md:144 の「段ごとの起動と入力」は gate-runner に残すため変更不要。
- SKILL.md:157 の issue 承認の事後報告 → stages/issue-approved.md。
- SKILL.md:172 の「needs-reviewer の return」→ stages/prepare-reviewer.md。
- SKILL.md:197-198 の手順 3-c・終了コード 4 の判定役 → stages/carryover-judge.md。
- SKILL.md:205 の 6-0 → stages/no-point-check.md。
- references/epic.md:92 の「主の委任」の真正性確認 → stages/authenticity-delegated.md の同名の節。
- references/epic-child-stop.md には今回移すゲートの節への直接参照が無く、変更不要。その他の親・子の本文は編集しない。

prepare / review / triage / pass / hold の入口、declarations と gate-runner の読む表、プラグイン内の引用元（worker/implement、worker/finish、references/subagent-waiting、references/codex-develop 等）も検索し、移動した節を直接名指ししているものだけ付け替える。宣言・return 雛形の文字列は例外として保存する。

### Codex の本文注入も担当する段に揃える

現行の scripts/codex-develop.py:648-688 の prompt() は、phase gate で共通の gate-runner.md と return-declaration.md に加えて、索引・declarations・6 段の本文を常に注入する。ファイルを分けるだけでは Codex の入力は段別にならないため、dev-workflow-develop の既存要件「Codex に渡す正本の一覧を段のファイルに合わせる」も改定する。この注入の変更と test_codex_develop.py の回帰検査は #1687 の範囲（今回の再開指示で明示）。

新しい CLI 引数や段は足さず、既存の起動指示の `レビュー経路: adapter` と `段: <段の名前>` から選ぶ。前の Gate Result や引用されたレビュー要約の `段:` / `次の段:` を担当段として取らない。共通注入は skills/develop/references/roles/gate-runner.md と skills/develop/references/return-declaration.md の 2 ファイルとし、次の入口とそこから無条件で読むファイルだけを加える。

| 起動指示の段 | skills/pr-review-gate/ からの基礎注入 |
|---|---|
| 前提確認と重さ判定 | stages/prepare.md |
| 照合と振り分け | stages/triage.md |
| 合格処理 | declarations.md、stages/pass.md |
| 保留の解除 | stages/hold.md |

他段の入口、索引、条件付き詳細は先回りして注入しない。条件付き詳細は G が入口の条件を確認して Read し、予算の追加 profile に数える。review は計測上の場面であり、adapter の phase gate の段として扱わない。phase review の正本（gate-runner.md・return-declaration.md・reviewer-brief.md）は維持する。`レビュー経路: 従来` と行無しの既定には現行の一括注入を残し、一括 profile で索引も含めて計測する。これらを削る根拠にはしない。

test_codex_develop.py は request を生成して実際の prompt の CANONICAL SOURCE の集合・各本文・sha256 を確認する。4 段それぞれで必要な本文が入り、不要な入口・索引・条件付き詳細が入らないこと、前の Gate Result に異なる段があっても担当段が変わらないこと、従来・行無し・phase review の経路が保たれることを検査する。Codex / Claude の起動自体は要らない。

### 廃止候補は不在を証明できたものだけ除く

現 main の develop/SKILL.md:30,51、gate-runner.md:25-36,113、review-run.md は develop 外の従来経路と行無しの既定を明示している。従来経路・一括 Gate Result を廃止する根拠にはならないため、この仕様では保存し、必要時だけ読む配置にする。キャッシュ済み利用者の書式不一致の既定も呼び出し元不在を証明できていない。return-declaration.md や共通の停止条件を変えない。削る経緯は規則の理由・条件・許す誤りを含まない日付・過去の実測等に限定し、何を除いたかを差分で確認する。

### 字数の比較と予算

前後の比較は UTF-8 ロケールの wc -m。予算検査は既存の W 予算と同じ wc -c にし、CI のロケールに依存させない。字数の減少量・率・トークン目標に合否の条件を置かない。新規 tests/gate-reading-budget.bats と tests/gate-reading-budget.txt で、段の基礎読込と条件付き読込の profile を列挙する。値は実装後の実測から決め、実測以上かつ実測の 1.1 倍以下（端数は整数で扱う）に置く。既存の injection-budget.txt は触らない。

基礎 profile は共通 3 ファイル + 当該段の入口と、その入口から必ず読むファイル。追加 profile は軽い通し方、区画、三表の補足・部分コメント、順 3、止めない指摘とエピック、周の終わり・failed、持ち越しと判定役、issue 承認、論点なし、許容の 4 形、文言合わせ、保留の解除・切り出し、一括の従来経路を測る。同一 profile 内で同じファイルを二度数えない。複合条件は該当する先の和集合をその段の最大 profile にも含める。読む表とテストの一覧が一致すること、条件付き詳細の全ファイルが少なくとも 1 つの profile に入ることを検査する。新しいファイルを計測外に置いて通さない。

上の共通 3 ファイルは Claude の G のファイル読込 profile。Codex は agent 定義を注入しないため別の profile 群とする。codex-develop.py の prompt() で生成した固定入力の prompt 全体（共通 2 ファイル、段の本文、CANONICAL SOURCE 行と sha256、adapter の定型指示、固定 REQUEST を含む）を wc -m / wc -c で測る。注入予定の一覧を別に足すだけで済ませず、生成物から正本の一覧と本文を取り出して読む表と照合し、欠落・余分・重複を落とす。条件付き profile はこの prompt に実際に追加で読むファイルを足し、既に注入したファイルは二度数えない。4 段・各条件・複合条件・従来の一括を検査し、不要な段を再び注入する変更も落とす。phase review も既存経路の生成 prompt と reviewer 向けの追加読込を別に測る。

固定 REQUEST は `Dispatch HEAD: e10f0a9896d82d0b86c0f7a10becb70c4983bc63`、`レビュー経路: adapter`、`段: <段の名前>` をそれぞれ 1 行（末尾 LF あり）、state の cwd はテスト専用の `/gate-reading-fixture`、prompt() の `plugin_root` は表示用の固定値 `/gate-reading-plugin-fixture` とする（生成 prompt の `Plugin root:` 行の字数を実行場所に依存させないため。正本の本文は従来どおり実際のプラグインルートから読む）。従来は経路を `従来`、段を `一括（従来経路）` に置き換える。phase review は同じ HEAD と経路の 2 行だけにする。この固定部分を前後で同じにし、実行ごとに変わる PR 本文・レビュー結果・ログなどの長さは予算に含めない。固定入力による計測であって、全実行の総トークン数の保証ではないと報告に明記する。

予算の checker の異常系は使い捨ての fixture で作る。正常、実測が予算 +1 バイト、境界ちょうど、予算が実測の 1.1 倍を超える場合、ファイル不在、未知・欠落・重複 profile、不正な数値、条件付き詳細の増加を検査する。文言テストは gate 配下と develop の関係手順書を連結して意味のある規則を検査する形に直す。移動しただけで落とさず、規則を消せば落ちることを fixture で確かめる。

文言検査の守備範囲: 入力は pr-review-gate 配下の .md と develop の関係手順書を連結した本文（回帰検査では同じ構成の fixture）。既存の文言検査が確認する規則の文字列が、連結対象の全体から欠落した誤りを拾う。例えば「同じ停止条件の文が別段専用の詳細にだけ残り、本来の入口から参照されない」入力や、「必要な文が残る一方で逆の指示も別の段落にある」入力は文言検査を通ることを許す。到達・条件は関係テスト、量は予算、意味はレビューでも確かめる。これらの穴を文言検査で塞ぎ切ることは完了条件にしない。これは量を測る予算検査とは別の守備範囲である。

予算の守備範囲: 入力は profile のファイル一覧と本文・予算値。大きさ超過・不在・一覧の欠落を拾う。同じ字数で本文が入れ替わること、短い案内に誤った条件を書くこと、自然文の参照を機械が解釈しきれないことは通り得る。親が受け入れた残りとして仕様レビューと PR レビューで見る。規則の正しさを予算だけで保証しない。

## 変更前の測定（固定 main）

共通 C = agents/gate-runner.md（557 字） + skills/develop/references/roles/gate-runner.md（13,256 字） + skills/develop/references/return-declaration.md（2,129 字） = 15,942 字。以下のパスは plugins/dev-workflow/ から。hook の注入文・PR 本文・ログ・リンク先のソースコードは前例と同じく数えない。節だけ読む指示でも、その節が置かれたファイルを丸ごと数える。

| profile | C に加えるファイル（skills/pr-review-gate/ から） | 字数（wc -m） | バイト数（wc -c） |
|---|---|---:|---:|
| prepare | stages/prepare.md | 29,718 | 59,590 |
| review | stages/review-run.md、stages/reviewer-brief.md | 34,148 | 71,822 |
| triage | stages/triage.md | 49,211 | 110,079 |
| pass | declarations.md、stages/pass.md | 49,509 | 103,693 |
| hold | stages/hold.md | 36,797 | 80,443 |
| prepare-rereview | stages/prepare.md、stages/triage.md | 62,987 | 136,055 |
| triage-row3 | stages/triage.md、stages/prepare.md | 62,987 | 136,055 |
| pass-risk | declarations.md、stages/pass.md、stages/hold.md | 70,364 | 150,522 |
| hold-split | stages/hold.md、stages/triage.md | 70,066 | 156,908 |
| legacy-all | declarations.md と既存 stages/ の 6 ファイル全部 | 135,615 | 291,171 |

review 行は従来経路でレビューを自分で起こす場面に追加して読むファイルを切り出した比較値。adapter の G はこの行の本文を読まず needs-reviewer を返す。一括 G が実際に読む合計は legacy-all 行。測定の都合で新しい G の段を導入しない。

再現コマンド（prepare の例。他の行も表どおりにファイルを置き換える）:

```bash
{
  git show e10f0a9896d82d0b86c0f7a10becb70c4983bc63:plugins/dev-workflow/agents/gate-runner.md
  git show e10f0a9896d82d0b86c0f7a10becb70c4983bc63:plugins/dev-workflow/skills/develop/references/roles/gate-runner.md
  git show e10f0a9896d82d0b86c0f7a10becb70c4983bc63:plugins/dev-workflow/skills/develop/references/return-declaration.md
  git show e10f0a9896d82d0b86c0f7a10becb70c4983bc63:plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md
} | LC_ALL=en_US.UTF-8 wc -m
```

後の表は同じ共通定義・全ファイル単位・同一ファイルの重複除外で実装 HEAD から測り、基礎 5 行と追加した条件 profile の内訳を PR に書く。内訳はファイル別に書く: 共通 3 本（`agents/gate-runner.md`・develop の `roles/gate-runner.md`・`return-declaration.md`）と基礎 5 場面の before／after のファイル名・各字数・合計、条件別 profile は基礎との差分のファイル一覧、Codex は固定 REQUEST・cwd・固定 Plugin root で生成した prompt と注入した正本を別表にする。before のファイルは移動先ではなく固定 main の元のファイルで数え、hook の注入は数えない。`python3 -B tests/gate_reading_report.py .` がこの表を再生成し、各ファイルの字数は `LC_ALL=en_US.UTF-8 wc -m` と一致する。before が同じ大きいファイルに合流していた条件 profile は、上の before の和集合を対応する値とする。PR には移動表の各行の「元の段落／新しい先／読む条件」も記録し、最後に #1682 に前後の表をコメントする。

### Codex の変更前の生成入力

上のファイル合計とは別に、前節の固定入力で現行 prompt() を直接呼んだ結果。対象コードと注入元の本文は固定 main e10f0a98 と dispatch HEAD ee0f55ff で同一。4 段とも共通 2 ファイル + 索引・宣言・6 段の計 10 ファイルが入り、正本本文だけでは 138,041 字 / 296,023 バイト、固定 prompt 全体は次のとおり。after も同じ方法で測り、条件付き読込の追加分と分けて PR・親への表に載せる。

| 段 | 固定 prompt 全体の字数 | バイト数 |
|---|---:|---:|
| 前提確認と重さ判定 | 141,303 | 299,317 |
| 照合と振り分け | 141,301 | 299,311 |
| 合格処理 | 141,298 | 299,302 |
| 保留の解除 | 141,299 | 299,305 |

## Risks / Trade-offs

- 参照だけ残して到達できなくなる → 入口から条件別の経路を辿る関係テスト、移動表、PR レビューで確認する。
- 宣言や return の再整形で契約を壊す → 元の fenced block を逐語保存し、e10f0a98 の宣言・return の全ブロックとの文字列一致を新しい回帰テストで確かめる。重複を寄せる場合も正本の同じブロックが残ることを確認する。コマンド、停止条件、守備範囲も対応表を作り、移動だけであることを照合する。
- 場所固定のテストを弱めた結果、場面外への増加を見逃す → 上記の予算・条件付きファイル被覆を使う。同じ大きさの入れ替えは親の受容した残り。
- 切り出しでファイルが増える → 1 capability の読込配置という同じ判断で一体として検証する。実装の編集対象は 5 ファイルを超えるため、規模超過の見込みを本体へ報告し、段 implement の開始判断は本体に残す。

## Migration Plan

1. R1 が artifact を審査し、記録先に APPROVE が出てから実装する。spec 段の検証結果を R1 の APPROVE と読み替えない。
2. 実装の前に次節の open PR を再照合する。先行マージされたものがあれば本体が定める順で main を取り込んでから移動する。変更前表は指定された固定 main のまま保ち、取り込み分の差は注記する。
3. 逐語移動、条件付き参照、関係テスト、予算、変更記録を 1 PR に積む。full test と lint は実装段で行う。lint.sh は claude plugin validate を呼ぶので、この Codex worker の「Claude を呼ばない」制約下では実行せず、実装段で使用可能な担当が必要。未実行を成功にしない。
4. finish で Closes #1687 を含む Draft PR を作り、前後の表を記録する。レビュー・確認後も主がマージし、自動マージを有効にしない。戻す場合はこの PR の変更を単位に戻す。
5. #580 と #1436 を閉じるかは、finish の報告で主に確認する。勝手に閉じず、本 spec の成立をその回答待ちにしない。

### 競合する open PR（2026-11-18、gh pr list --state open --limit 1000 --json number,title,headRefName,files）

| PR | ブランチ | 重なる段 |
|---|---|---|
| #1456 | burn/589 | triage.md |
| #1448 | burn/622 | prepare.md |
| #1436 | burn/580 | 旧試案。prepare / reviewer-brief / triage / pass / hold と多数の新規先 |
| #1410 | burn/549 | triage.md |
| #1306 | burn/500 | pass.md |
| #1285 | burn/1119 | reviewer-brief.md |
| #1284 | burn/1004-wording-gate-fixes | pass.md |
| #1195 | burn/479 | hold.md |
| #637 | fix/242-approval-provenance | hold.md、pass.md |
| #229 | fix/220-pr-review-gate-empty-body-fail-closed | prepare.md |

既存 PR と急ぎの修正は先にマージするという issue の順序に従う。ただし #1436 は置き換える旧試案なので取り込まない。どれを先に通すかの調整とマージはこの spec worker では行わず、実装前の前提として本体へ返す。未着手の後続 issue に仕様や受け入れ条件を足さない。

## 取り込み後の固定 main（実装基準）

固定 main: `0e7bf3f80d0241bd9582f7b89e5ec3f529f2139f`。#1448・#1456・#1306 を含む。旧 e10f0a98 の表は履歴として残す。

| Claude profile | 字数 | バイト数 |
|---|---:|---:|
| prepare | 30053 | 60177 |
| review | 34148 | 71822 |
| triage | 49262 | 110140 |
| pass | 50143 | 105383 |
| hold | 36797 | 80443 |
| prepare-rereview | 63373 | 136703 |
| triage-row3 | 63373 | 136703 |
| pass-risk | 70998 | 152212 |
| hold-split | 70117 | 156969 |
| legacy-all | 136635 | 293509 |

| Codex 固定 prompt | 字数 | バイト数 |
|---|---:|---:|
| 前提確認と重さ判定 | 142323 | 301655 |
| 照合と振り分け | 142321 | 301649 |
| 合格処理 | 142318 | 301640 |
| 保留の解除 | 142319 | 301643 |
| 一括（従来経路） | 142317 | 301651 |
| review | 24938 | 51034 |

取り込み後の移動表補正: prepare.md の区画入力は 2 段の取得・検査を入口に残す。triage.md の「上の同じ証拠」は triage-convergence.md 内の周の終わりの証拠を指す。pass.md:44-50 の本体を流せない受け入れ条件の代替確認は共通の動作確認に残す。prepare の payload は 148-176、triage のコメント分割は 212-251、pass の真正性は 86-180（旧表より +8 行）を実際の見出しで切り出す。

## 実装後の計測（#1687）

再現: `python3 -B tests/gate_reading_report.py .`。固定 main の既存比較値とも一致を照合する。Claude 一括の比較は従来の宣言＋6段で、Codex 一括は索引も注入する。

字数は UTF-8 の文字数（Python len、wc -m 相当）。同じファイルは一度だけ。before は固定 main `0e7bf3f80d0241bd9582f7b89e5ec3f529f2139f` から実測。Codex は定型指示・固定 REQUEST・ヘッダー・sha256・正本本文を含む実際の prompt() 生成物。可変の PR 本文・結果・ログは予算外で、全実行の総トークン数の保証ではない。予算は UTF-8 バイト数、全 156 profile を実測の1.0倍に設定。

Claude 基礎5場面・条件別（max は同じ段の全条件の和集合）:

| profile | before | after |
|---|---:|---:|
| prepare | 30,053 | 20,538 |
| prepare-light | 30,053 | 24,179 |
| prepare-partitions | 30,053 | 21,098 |
| prepare-reviewer | 30,053 | 23,054 |
| prepare-rereview | 63,373 | 26,764 |
| prepare-approval-wait | 50,908 | 26,635 |
| prepare-max | 84,228 | 39,578 |
| review | 34,148 | 30,614 |
| review-fallback | 48,259 | 33,130 |
| review-partitions | 48,259 | 31,174 |
| review-summary | 34,148 | 33,577 |
| review-comments | 67,468 | 36,499 |
| review-max | 81,579 | 39,575 |
| triage | 49,262 | 22,379 |
| triage-summary | 49,262 | 25,342 |
| triage-partitions | 49,262 | 25,963 |
| triage-supplement | 63,373 | 27,858 |
| triage-comments | 49,262 | 28,264 |
| triage-row3 | 63,373 | 33,435 |
| triage-nonblocking | 49,262 | 29,285 |
| triage-epic | 49,262 | 31,569 |
| triage-convergence | 49,262 | 28,605 |
| triage-failed | 49,262 | 25,416 |
| triage-max | 63,373 | 60,910 |
| pass | 50,143 | 31,434 |
| pass-issue-approved | 50,143 | 37,300 |
| pass-carryover | 70,998 | 44,646 |
| pass-judge | 70,998 | 48,094 |
| pass-no-point | 70,998 | 39,428 |
| pass-risk-link | 70,998 | 37,242 |
| pass-risk-conversation | 70,998 | 39,011 |
| pass-risk-relayed | 70,998 | 39,741 |
| pass-risk-delegated | 70,998 | 43,406 |
| pass-wording | 50,143 | 32,642 |
| pass-max | 70,998 | 65,869 |
| hold | 36,797 | 17,583 |
| hold-carryover | 60,514 | 25,569 |
| hold-judge | 60,514 | 29,017 |
| hold-no-point | 36,797 | 20,351 |
| hold-resume | 36,797 | 19,986 |
| hold-categories | 36,797 | 18,454 |
| hold-split | 70,117 | 29,176 |
| hold-max | 93,834 | 44,249 |
| legacy-all | 136,635 | 73,120 |
| legacy-all-max | 136,635 | 140,154 |

Codex 固定生成 prompt（追加読込なし）:

| profile | before | after |
|---|---:|---:|
| prepare | 142,323 | 22,334 |
| review | 24,938 | 21,377 |
| triage | 142,321 | 24,172 |
| pass | 142,318 | 33,351 |
| hold | 142,319 | 19,372 |
| legacy-all | 142,317 | 78,818 |

Codex 条件付き追加読込（注入済みを除外。total は生成 prompt＋追加読込）:

| profile | before追加 | after追加 | before total | after total |
|---|---:|---:|---:|---:|
| prepare-light | 0 | 3,641 | 142,323 | 25,975 |
| prepare-partitions | 0 | 560 | 142,323 | 22,894 |
| prepare-reviewer | 0 | 2,516 | 142,323 | 24,850 |
| prepare-rereview | 0 | 6,226 | 142,323 | 28,560 |
| prepare-approval-wait | 0 | 6,097 | 142,323 | 28,431 |
| prepare-max | 0 | 19,040 | 142,323 | 41,374 |
| review-fallback | 14,111 | 2,516 | 39,049 | 23,893 |
| review-partitions | 14,111 | 560 | 39,049 | 21,937 |
| review-summary | 0 | 2,963 | 24,938 | 24,340 |
| review-comments | 33,320 | 5,885 | 58,258 | 27,262 |
| review-max | 47,431 | 8,961 | 72,369 | 30,338 |
| triage-summary | 0 | 2,963 | 142,321 | 27,135 |
| triage-partitions | 0 | 3,584 | 142,321 | 27,756 |
| triage-supplement | 0 | 5,479 | 142,321 | 29,651 |
| triage-comments | 0 | 5,885 | 142,321 | 30,057 |
| triage-row3 | 0 | 11,056 | 142,321 | 35,228 |
| triage-nonblocking | 0 | 6,906 | 142,321 | 31,078 |
| triage-epic | 0 | 9,190 | 142,321 | 33,362 |
| triage-convergence | 0 | 6,226 | 142,321 | 30,398 |
| triage-failed | 0 | 3,037 | 142,321 | 27,209 |
| triage-max | 0 | 38,531 | 142,321 | 62,703 |
| pass-issue-approved | 0 | 5,866 | 142,318 | 39,217 |
| pass-carryover | 0 | 13,212 | 142,318 | 46,563 |
| pass-judge | 0 | 16,660 | 142,318 | 50,011 |
| pass-no-point | 0 | 7,994 | 142,318 | 41,345 |
| pass-risk-link | 0 | 5,808 | 142,318 | 39,159 |
| pass-risk-conversation | 0 | 7,577 | 142,318 | 40,928 |
| pass-risk-relayed | 0 | 8,307 | 142,318 | 41,658 |
| pass-risk-delegated | 0 | 11,972 | 142,318 | 45,323 |
| pass-wording | 0 | 1,208 | 142,318 | 34,559 |
| pass-max | 0 | 34,435 | 142,318 | 67,786 |
| hold-carryover | 0 | 7,986 | 142,319 | 27,358 |
| hold-judge | 0 | 11,434 | 142,319 | 30,806 |
| hold-no-point | 0 | 2,768 | 142,319 | 22,140 |
| hold-resume | 0 | 2,403 | 142,319 | 21,775 |
| hold-categories | 0 | 871 | 142,319 | 20,243 |
| hold-split | 0 | 11,593 | 142,319 | 30,965 |
| hold-max | 0 | 26,666 | 142,319 | 46,038 |
| legacy-all-max | 0 | 67,034 | 142,317 | 145,852 |
