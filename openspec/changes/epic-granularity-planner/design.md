# Design

## Context

動機は proposal.md を参照。根拠は #1799 の確定コメントだけを使う: https://github.com/oratta/claude-harness/issues/1799#issuecomment-7120074012 。会話ログの再収集・回帰の再計算はしない。

現行の Step C は capability・受け入れ条件数・設計判断数で割り、規模超過は編集ファイル 5 個超で止まる。一方、`epic-state.sh:4-10,71-75` の状態記録は repo と子 issue 番号ごとに 1 本、`epic-dispatch.sh:2113-2155` の wait は渡された番号の closed と done を見る。`epic.md:54-56` は子のマージに加え親の実機確認を要求する。この単位を保つ。

## Goals / Non-Goals

**Goals:** 同じ入力には同じ説明付き計画を返す。LLM が洗い出しと量の申告を担い、CLI は検査・見積もり・梱包だけを担う。計算器単体と手順の契約を別々に検証する。

**Non-Goals:** GitHub の自動変更・実行時スケジューラ・最適解や所要秒数の保証・モデル別上限の導出。既存の 150k / 220k、30M の停止と親の 60M 権限を変えない。#1800・聖域・予算ファイルは対象外。

## Decisions

### 1. 純粋な JSON 入出力の Python CLI

`python3 plugins/dev-workflow/scripts/epic-granularity.py --input <json> [--config <json>]`。標準ライブラリだけで実装する。stdout は JSON 1 件、stderr は診断。exit 0 は全項目を配置できた計画、1 は不正入力／設定、2 は検査は通るが配置不能。2 でも未配置項目・超過量・部分計画を返し、全体を実行可能とは表示しない。ネットワーク・会話ログ・repo ファイルの自動読み取り・issue 更新は行わない。

入力は schema_version=1。JSON/YAML の併用より依存と曖昧さが少ない JSON を採用する。必須キー:

| 場所 | 内容 |
|---|---|
| limits | context_cap、record_cap、各値の source。正の整数。既存計測スクリプトの cap と既存権限記録から本体が渡す |
| worker_slots | max_parallel、occupied（0 以上、occupied は max 以下）、source。空きは差から計算 |
| context | startup_tokens、reserve_tokens（起動指示・未列挙の出力／推論メモ等の余裕）、それぞれ source |
| items[] | id、repo（owner/repo）、capabilities（空でない文字列配列）、depends_on（id 配列）、sanctuary（bool）、approval_wait（bool）、files、estimated_changed_lines、context_extra_tokens、estimate_source |
| items[].files[] | path（repo 相対）、access（read/edit）、tokens（全文の非負整数）、source |
| items[].source_issues | 任意。既存 issue の URL 配列。入力全体で同じ URL を複数項目に付けてよい |

tokens は LLM が数えた量か、文字数を Read 0.77／Bash 0.65 で換算して切り上げた量を渡し、source に方法を残す。空の files は許すが量を省略して 0 扱いしない。新規ファイルは予測全文量を渡す。変更行数は追加＋削除（複数項目が同じ行を直す場合も加算して安全側）。既存 issue 自体を 1 item に固定しない。

id 重複、未知の依存、自己依存・循環、非有限／負数／bool を整数として使った量、欠落、不正 repo／絶対パス／`..`、空 capability、不正 slots を exit 1 にする。同じ repo/path の files は子内で最大 tokens を 1 回計上し、edit があれば edit とする。入力順を変えても id と repo/path で正規化し同じ出力にする。

上限は係数設定に保存しない。context_cap は既存 `subagent-context.sh` の実効 cap（DEV_WORKFLOW_CONTEXT_CAP を含む）、record_cap は既存 `pr-token-budget.sh` の実効 cap を基本とし、親の信頼できる `子の PR トークン権限:` がある場合だけその権限を使用する。本体は値と出典（計測結果、既存設定箇所、権限コメント URL）を入力に記す。未起動で計測できない場合も既存の設定解決箇所から取得し、CLI は代替の上限値を内蔵しない。60M を自動で付与したり停止値 30M を書き換えたりしない。

### 2. 異なる計測対象を別の式にする

`references/epic-granularity-coefficients.json` に版・source URL・各係数・政策上の余裕を置き、スクリプトに係数を埋め込まない。モデル名や上限の値はここに持たせず、#1800 と独立させる。

子 G に対し F は repo/path で重複排除したファイル全文 tokens の和、L は変更行数の和、X は context_extra_tokens の和とする:

| 出力 | 式と使い道 |
|---|---|
| total_tokens_estimate T | ceil(9,900,000 + 49.9 × F)。本体＋Claude サブエージェントの総消費回帰。まとめる手間と所要量の比較にだけ使う |
| record_tokens_estimate E | ceil(8,200,000 + 18,650 × L)。Claude サブエージェント＋Codex（本体を除く）の累計見積もり |
| record_tokens_guard S | ceil(1.6 × E)。停止例での実測／見積もりの中央値 1.6 を安全側の計画係数として適用 |
| context_tokens_estimate C | startup_tokens + reserve_tokens + F + X。1 人の W が保持する量の包絡見積もり |

採用理由: F による総消費回帰は決定係数 0.83 で、係数が両方明記されている。累計は計測対象が一致する行数回帰を使う。対数ターン数回帰は係数が無く、1.37 補正は総消費向けなので累計には転用しない。T を記録先上限と比較する案は棄却する。C はターン数回帰ではなく申告した保持量の和で、起動分やツール出力を落とさないため X と reserve を必須にする。

採用する余裕は C <= floor(0.8 × context_cap)、S <= floor(0.8 × record_cap)。0.8 は本 change で採る政策値で測定結果ではない。1.6 は信頼区間ではなく、#1799 の外側当てはめの弱さを補う計画係数に過ぎない。設定には両者の性質を明記する。設定値の妥当性（余裕は 0 より大きく 1 未満、係数は正の有限値、出典必須）も検査する。出力は T/E/S/C を別キーにし、実効上限・計画用上限・それぞれとの差・係数版・出典・不確かさを含める。「±8% で累計を予測できる」とは書かない。

### 3. 関係を優先してまとめ、量と空き枠で調整する

最初に repo の違い・sanctuary の真偽を分ける。approval_wait=true は承認待ちで他を止めないよう 1 item ずつ単独の子にする。承認後の項目は依存する別の子にする。これが意味上必ず分ける 3 条件であり、capability 数・設計判断数・受け入れ条件数・ファイル数では強制分割しない。消費で収まらない分の容量分割は別に行う。

決定的な貪欲法を使う。単独 item から始め、容量内かつ境界を越えない子対を、(直接依存の辺数、共通 capability 数、共有する前提 id 数) の降順、併合後 T の昇順、所属 id 配列の辞書順で選び併合する。いずれかの関係値が正の対を先に処理し、その後に無関係な対を同じ容量検査で詰める。毎回、縮約した子の依存 DAG が循環しないことも検査する（A→B→C の A と C だけを併合しない）。収まる対が無くなるまで行う。共有ファイルは量の重複排除に反映する。

空き W 枠が 0/1 ならこの案を使う。2 以上のときだけ、量詰めで一緒になった無関係な構成部分の分離案を評価する。直接／推移依存がある組、共有 edit ファイルがある組は並列候補にしない。関係を優先した段で一緒になった部分は維持し、無関係な部分を id 順に切り離す候補を 1 回ずつ試し、改善する最良の分離を繰り返す。

比較は子の T を所要量の代理にした依存付き list scheduling（ready 子を T 降順・id 順、空いた枠へ、枠数は現在の空き W 枠）の makespan で行う。小さい方を採用し、同値なら子数が少ない方、次に所属 id 配列順。分けるたびに T の切片を再計上するので、並列案にも子ごとの手間がかかる。これは時間の代理指標による局所探索で、実時間／大域最短の保証ではない。出力に merged 案との比較と採用理由を残す。空き枠 0 の出力は起動許可ではない。実行直前の枠検査・再開優先順は既存 epic-worker-slots.md のまま。

出力 schema_version=1 は status、groups（安定した group id、item ids、repo、source_issues、外部依存 group ids、T/E/S/C と余裕）、unplaced、worker_slots、parallel_comparison、warnings、coefficient_version を持つ。各 item は group または unplaced にちょうど 1 回だけ現れ、子内依存は出力の外部依存から除く。単独でも収まらない項目は unplaced にして超過量を示す。LLM が項目を分解し再入力するまで、上限の緩和・架空の細分化・黙った切捨ては行わない。

### 4. 計算の詳細を必要時だけ読む reference に置く

新規 `references/epic-granularity.md` を入力形式・呼出し・結果の読み方・既存 issue 集約の正本にする。Step C と epic.md の作り方はこれを指す。規模超過は「ファイル数や作業増分を更新して再計算し、容量超過／配置不能なら return」へ変え、W 共通指示も揃える。作業項目の増加 2 回も再計算の材料とし、自動分割の根拠にはしない。

template は短い条件と参照だけに置き換え、長い JSON・計算式・手順を常駐注入しない。rules は増やさない。既存の常時注入予算と場面別読込予算を実装時に実測して通す。必要なら対象段落を短くし、`tests/injection-budget.txt` を緩めない。

### 5. 集約先の子 issue を 1 本作り、親はそれだけを数える

採用するのは「まとめ先の子を 1 本立てる」方式。PR に複数の既存 issue の Closes を並べるだけでは、起動・状態・レビュー記録先が元 issue ごとに残り、同じ PR に複数 W が起動しうる。代表子なら既存の repo/issue ごとの記録を変えずに済む。

本体は計画の group ごとに代表子を新設する。既存 issue を再利用できるのは、group がその元 issue 1 本だけに対応し、元 issue の全項目が単一 group に収まり、他 group がその元 issue を参照しない場合に限る。それ以外は group ごとに別々の代表子を新設し、元 issue を代表として再利用しない。同じ元 A だけを容量で二分した場合も、両 group に別々の代表 C/D を新設する。代表子本文と親に「group id → item ids → 元 issue URL」の表と受け入れ条件の和集合を記し、元 issue に代表へのコメントを残す。元 issue を代表子の sub-issue にしない（nested の展開拒否に当たる）。親の直接の子は代表だけに付け替え、元 issue を route/launch/wait/adopt に渡さない。状態の schema と dispatch の完了計測は変更しない。

元 issue の項目が複数 group に分かれれば表は多対多とし、その元 issue の全 group が完了するまで元を閉じない。依存は item の DAG から代表子間へ写し、内部の辺を除く。元 issue に付いた外部依存も、既に満たされたものを除き関係する全代表へ写す。外部の後続から元 issue への依存は元が閉じるまで残す。既に W／worktree／未マージ PR／状態記録がある元 issue は自動集約せず、完了を待つか集約対象から外した理由を親に記録する。既存セッションを移し替えない。

PR の Closes は代表子 1 件だけに向ける。マージ後に本体が対応表を照合し、元 issue の全受け入れ条件を満たした証拠と PR URL をコメントして元を completed で閉じる。単なる重複として not_planned で閉じない。失敗時は未精算として親の表に残し、再開時に idempotent に再試行する。代表の closed/done は wait のイベントとして扱い、親の進捗は代表ごとに 1 回数える。元の閉鎖を追加の子完了には数えない。元の精算漏れ、未マージ PR、親の実機確認が 1 つでも残れば親は完了しない。

### 6. 過去の入力と出力を実装の検証成果にする

候補は #1701（元の子 3 本）と #1732（本文に列挙された細分化済みの子）。本文・子／マージ PR のファイル一覧と差分から作業を洗い出し、tokens・行数・起動／出力余裕の根拠を fixture の source に固定する。#1799 の会話ログを再測定しない。#1732 の hooks／権限関連は sanctuary=true として非聖域の作業と分け、承認待ちや別 repo の境界を保存する。

入力 JSON は `tests/fixtures/epic-granularity/`、比較は `docs/epic-granularity-validation.md` に置く。元の子数、計算後の子数、所属と依存、W 枠条件、各子の C/E/S/T、実効／計画用上限と差、減らなければ理由、正確な再実行コマンドと exit code を記録する。実装前の本 artifact は実行済み結果を主張しない。再現テストはネットワーク不要にし、計画後の全項目保存・境界・非循環・両方の消費検査を確認する。

## Risks / Trade-offs

- 行数回帰は停止しなかった件の外側当てはめで、実測は 0.9〜4.2 倍 → 1.6 と 20% の余裕でも保証ではないと出力し、既存の実測トリップワイヤーを維持する。
- C は申告外の出力／反復読込を予測しきれない → 起動・追加保持量・余裕を入力必須にし、増えたら再計算。実行中の 150k／220k の仕組みは維持する。
- 空き W 枠は変化する → 計画時の snapshot と起動許可を分け、既存の再開優先順で再確認する。
- 集約途中の GitHub 更新失敗 → 対応表を先に保存し、付替え・依存移設を確認するまで起動しない。精算漏れは親の完了を止める。
- 貪欲法は大域最適でない → 同一入力の安定性と根拠を優先し、本体による逸脱は理由付きで記録可能にする。

## Migration Plan

計算器とオフラインテストを実装し、既存手順と対応する仕様を同じ PR で切り替える。進行中の子の構成は勝手に変更しない。新規作成／未着手項目の再計画から適用する。問題時は手順の切替を戻せるが、作成済み代表子の対応表は消さず、閉鎖済み元 issue の受け入れ条件と証拠を保持する。

## Acceptance Coverage

| #1802 の条件 | 仕様の置き場 | 実装時の検証タスク |
|---|---|---|
| 1 入力形式 | epic-granularity: JSON 入力・不正入力 | 1.1、1.3 |
| 2 関係優先の計算器 | epic-granularity: 関係の近い項目を先にまとめる | 2.1 |
| 3 消費で子の上限を決める | epic-granularity: 総消費／累計の区別・文脈・出典付き容量判定 | 1.2 |
| 4 必ず分ける三条件 | epic-granularity: 三つの意味上の分離境界 | 2.1 |
| 5 W の空き枠 | epic-granularity: 並列分離、dev-workflow-develop: snapshot と起動 | 2.2、3.1 |
| 6 分割規則の書換え | dev-workflow-develop: Step C とエピック作成、dev-workflow-escalation-tripwires: 規模超過 | 3.1、3.2 |
| 7 既存 issue と親の完了 | dev-workflow-develop: 代表子へ集約・代表一件を一回数える | 3.3、3.4 |
| 8 過去エピック二件以上 | epic-granularity: 過去エピックへの適用 | 4.1、4.2 |
