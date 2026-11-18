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

### 廃止候補は不在を証明できたものだけ除く

現 main の develop/SKILL.md:30,51、gate-runner.md:25-36,113、review-run.md は develop 外の従来経路と行無しの既定を明示している。従来経路・一括 Gate Result を廃止する根拠にはならないため、この仕様では保存し、必要時だけ読む配置にする。キャッシュ済み利用者の書式不一致の既定も呼び出し元不在を証明できていない。return-declaration.md や共通の停止条件を変えない。削る経緯は規則の理由・条件・許す誤りを含まない日付・過去の実測等に限定し、何を除いたかを差分で確認する。

### 字数の比較と予算

前後の比較は UTF-8 ロケールの wc -m。予算検査は既存の W 予算と同じ wc -c にし、CI のロケールに依存させない。字数の減少量・率・トークン目標に合否の条件を置かない。新規 tests/gate-reading-budget.bats と tests/gate-reading-budget.txt で、段の基礎読込と条件付き読込の profile を列挙する。値は実装後の実測から決め、実測以上かつ実測の 1.1 倍以下（端数は整数で扱う）に置く。既存の injection-budget.txt は触らない。

基礎 profile は共通 3 ファイル + 当該段の入口と、その入口から必ず読むファイル。追加 profile は軽い通し方、区画、三表の補足・部分コメント、順 3、止めない指摘とエピック、周の終わり・failed、持ち越しと判定役、issue 承認、論点なし、許容の 4 形、文言合わせ、保留の解除・切り出し、一括の従来経路を測る。同一 profile 内で同じファイルを二度数えない。複合条件は該当する先の和集合をその段の最大 profile にも含める。読む表とテストの一覧が一致すること、条件付き詳細の全ファイルが少なくとも 1 つの profile に入ることを検査する。新しいファイルを計測外に置いて通さない。

予算の checker の異常系は使い捨ての fixture で作る。正常、実測が予算 +1 バイト、境界ちょうど、予算が実測の 1.1 倍を超える場合、ファイル不在、未知・欠落・重複 profile、不正な数値、条件付き詳細の増加を検査する。文言テストは gate 配下と develop の関係手順書を連結して意味のある規則を検査する形に直す。移動しただけで落とさず、規則を消せば落ちることを fixture で確かめる。

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

後の表は同じ共通定義・全ファイル単位・同一ファイルの重複除外で実装 HEAD から測り、基礎 5 行と追加した条件 profile の内訳を PR に書く。before が同じ大きいファイルに合流していた条件 profile は、上の before の和集合を対応する値とする。PR には移動表の各行の「元の段落／新しい先／読む条件」も記録し、最後に #1682 に前後の表をコメントする。

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
