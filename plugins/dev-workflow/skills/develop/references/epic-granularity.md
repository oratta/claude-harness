# 子の粒度計算（作成・再計画時だけ読む）

本体が issue の作業項目と量を洗い出し、CLI が入力検査・容量判定・梱包を行う。会話ログや repo ファイルを CLI が読むことはない。#1799 の確定結論を使用し、再測定しない。既存の上限、モデル別しきい値、実行中の停止判定は変えない。

## 入力を作って実行する

作業を item に展開する。既存 issue 1 本を item 1 個に固定しない。すべての量と出典を埋め、入力を `$TMPDIR` 等のリポジトリ外に保存する。記録には後で再現できる JSON 全文を残す。

```json
{
  "schema_version": 1,
  "limits": {
    "context_cap": 150000,
    "context_cap_source": "subagent-context.sh: cap 解決箇所（DEV_WORKFLOW_CONTEXT_CAP 未設定）",
    "record_cap": 30000000,
    "record_cap_source": "pr-token-budget.sh: cap 解決箇所（権限・環境変数の変更なし）"
  },
  "context": {
    "startup_tokens": 40000,
    "startup_tokens_source": "今回の起動指示の見積もり",
    "reserve_tokens": 10000,
    "reserve_tokens_source": "未列挙の出力・推論・反復の政策上の余裕"
  },
  "worker_slots": {"max_parallel": 2, "occupied": 1, "source": "epic-worker-slots.md に従って集計した計画時点の snapshot"},
  "items": [{
    "id": "A", "repo": "oratta/claude-harness",
    "capabilities": ["example"], "depends_on": [],
    "sanctuary": false, "approval_wait": false,
    "files": [{"path": "example.py", "access": "edit", "read_id": "example-excerpt", "read_scope": "fixed-rev:example.py:1-20", "tokens": 1000, "source": "fixed-rev の1-20行の予定Bash出力1538文字 × 0.65、切上げ1000 tokens"}],
    "estimated_changed_lines": 100, "context_extra_tokens": 0,
    "estimate_source": "追加＋削除100行、保持出力はreserveで計上",
    "source_issues": ["https://github.com/oratta/claude-harness/issues/1802"]
  }]
}
```

```bash
python3 plugins/dev-workflow/scripts/epic-granularity.py --input "$TMPDIR/epic-input.json"
# --config <json> で出典付き設定の差替えも可能
```

`limits` の値は例のコピーで決めない。context_cap は `scripts/subagent-context.sh` の実効 `cap`（`--cap`、`DEV_WORKFLOW_CONTEXT_CAP`、既定値の解決箇所）、record_cap は `scripts/pr-token-budget.sh` の実効 `cap`（`--cap`、`DEV_WORKFLOW_PR_TOKEN_CAP`、既定値の順）から本体が取得する。計測できない起動前は各スクリプトの設定解決箇所と現在の環境を確認する。親の信頼できる `子の PR トークン権限:` がある場合だけその値を使い、コメント URL と投稿者の権限を source に記す。60M を自動付与しない。CLI に上限の既定値はない。

files は repo 相対の正規化済み path、read/edit、必須の read_id・read_scope、予定出力の非負整数 tokens、source を持つ。read_scope は固定 revision の行範囲、diff の revision と hunk、検索条件など出力を特定する文字列。全文を読むときだけ全文量を渡す。Read の結果なら `ceil(文字数 × 0.77)`、Bash なら `ceil(文字数 × 0.65)`。例えば Read 1,299 文字は 1,001 tokens、Bash 1,538 文字は 1,000 tokens。source に revision/URL・範囲・出力文字数・換算方法を記す。

同じ (repo, path, read_id) は一つの共有出力として子内で一度数える。入力全体で同じキーの read_scope または tokens が矛盾すれば exit 1。同じ path の別出力1,000＋2,000 tokensは F=3,000。部分的に重なる別出力も加算し、同じ出力を再取得する予定なら別 read_id を付けて計上する。範囲の意味や実物は CLI が照合しない。編集競合は引き続きファイル単位。変更行数（追加＋削除）は項目間でも加算する。追加保持量 context_extra_tokens と起動・reserve は必須。生成本文などの保持出力を F と追加保持量に二重計上しない。空の files は許すが、不明な量を 0 に置き換えない。読取量・共有は計画上の仮定で、過去の実測や #1799 と同じ検証済み予測精度とは呼ばない。

入力検査は欠落、bool を整数として使う量、負数・非有限値、不正 repo/path、空 capability、重複 id、未知・自己・循環依存、不正な枠数を拒否する。source_issues は任意の GitHub issue URL 配列。出典の内容・権限と申告量の真偽は本体が確認する。形式が正しく申告 tokens が実物と違う入力は通す。列挙漏れや申告差をすべて防ぐことはこの検査の完了条件ではない。

## 結果を読む

- exit 0: 全項目を配置。exit 1: 不正入力／設定（stderr と JSON の診断）。exit 2: 単独でも容量外の項目を unplaced に保持。部分計画で成功としない。診断の path/read_id/読取量を確認し、必要情報を保存した作業・読取範囲・依存の再設計後だけ再入力する。同じ担当の読取範囲の名目上の分割や tokens の切詰めは禁止。分離できなければ未完了で返す。
- F は子内の (repo, path, read_id) ごとの予定読取出力 tokens の和、L は変更行数の和。T=`ceil(9,900,000+49.9F)` は本体＋Claude サブエージェントの総消費。E=`ceil(8,200,000+18,650L)` は本体を除く Claude サブエージェント＋Codex の累計、S=`ceil(1.6E)` は計画用累計。T を記録先上限と比較しない。
- C=`startup+reserve+F+追加保持量の和`。C と S がそれぞれ実効上限の `floor(0.8×cap)` 以下なら入る。margin は計画用上限との差。係数は `references/epic-granularity-coefficients.json` の版・出典を出力する。1.6 は停止例の中央値由来、0.8 は政策値。外挿には不確かさがあり、実消費・時間・精度の保証ではない。
- repo の違い、聖域に触る／触らないの違い、承認待ちは分離する。承認待ちは一項目ずつの子。6 ファイルや多 capability だけでは分けない。
- 容量内の対を、直接依存の辺数→共通 capability 数→共有前提数の降順、併合後 T→項目 id 順でまとめる。その後に無関係な部分を量で詰める。merge_reasons は選択理由、groups.depends_on は子間 DAG（子内辺は除去）。unplaced_dependencies があればその前提の分解を待つ。
- 空き 0/1 では並列化のために分けない。空き 2 以上だけ、関係を優先してまとめた部分を保ち、無関係・依存なし・共有 edit なしの部分を分離して代理 makespan を比較する。子ごとに T の切片を払い直す。同値なら少ない子を維持。parallel_comparison に比較値を残す。これは局所探索で最短時間の保証ではない。
- worker_slots は計画時 snapshot であり起動許可ではない。空き 0 なら起動しない。実行直前に `epic-worker-slots.md` の空き枠と再開優先順を再確認する。

上の例は F=1,000、L=100、T=9,949,900、E=10,065,000、S=16,104,000、C=51,000。出力は正規化し入力順で変わらない。係数設定の出典欠落・不正値も拒否するが、申告上限や source の権限を CLI が取得・照合することはない。見積もりを実消費と照合してすり抜けをすべて塞ぐことは容量判定の完了条件ではない。

## 計画の記録と増分

CLI 実行→記録先へ入力・出力を保存→代表子の作成の順。異なる所属にするなら逸脱した所属と理由を記録し、三境界・DAG・両容量を再検査する。個数だけの分割はしない。

規模が増えたら、追加の予定読取範囲・出力量・変更行数・作業項目・保持出力を反映して再計算する。ファイルが 6 個、項目増加が 2 回というだけでは止めない。今の担当分を一つの子として C/S で確認し、容量超過／配置不能、または量が不明で再計算できなければ止まる。新しい計画が複数 group になった場合も W は独断で分割せず、更新入力・出力・成果を本体へ return する。上限を広げない。形式は正しいが量の過少申告で通る場合は続行可能とし、既存の実測停止判定を維持する。増分の申告漏れをすべて拾うことは停止判定の完了条件ではない。

## 既存 issue を代表子へ集約する

1. 着手済み（W・worktree・未マージ PR・状態記録がある）issue は自動集約しない。完了を待つか、除外理由を親へ記録する。既存セッションを移し替えない。
2. `group id → item ids → 元 issue URL → 代表子` の多対多の対応表と受け入れ条件の和集合を親へ先に保存する。再利用は元 issue 1 本だけに対応し、元 issue の全項目が単一 group に収まり、他 group が参照しない場合だけ。それ以外は group ごとに代表子を新設する。元 A だけを容量で割った場合も C/D を別々に新設する。
3. 代表本文にも表と受け入れ条件を書く。元 issue へ代表への参照コメントを残す。元を代表の sub-issue にしない（nested にしない）。親の直接の子を代表だけへ付替える。元 issue にある未充足の外部依存を関係する全代表へ移設し、内部依存を取り除く。外部の後続から元への依存は元を閉じるまで維持する。
4. 付替え・対応表・依存移設を確認するまで起動しない。失敗時は停止して更新済み箇所と不足を親に記録。route/launch/wait/adopt に渡すのは代表だけ。既存の repo/issue 単位の状態 schema と closed/done の読み方は維持する。
5. PR の Closes は各代表だけ。マージ後、本体は元 issue の全 group が完了し全受け入れ条件の証拠が揃ったことを照合し、PR URL と条件ごとの証拠をコメントして元を completed で閉じる。not_planned の重複扱いにしない。C/D 分割なら C 完了時は A を開いたままにし、D 完了後に証拠を確認して A を閉じる。
6. 精算失敗は親の表に「未精算」として残し、再開時に idempotent に再試行する。代表ごとに closed/done を一度だけ進捗へ計上し、元の閉鎖を進捗に加算しない。未精算・未マージ PR・親の実機確認が一つでも残れば親は完了しない。

以下は手順の検証 fixture。起動・Closes・進捗の期待値であり GitHub 自動更新機能ではない。events の eligible_to_settle は全 group 完了時の精算資格を示す（実際の閉鎖には証拠確認も必要）。同じ done を再受信し、元の閉鎖を再試行しても増分は変わらない。

<!-- procedure-fixtures -->
```json
[
  {
    "mapping": {"C": ["A", "B"]}, "direct_children": ["C"], "nested_originals": [],
    "launch": ["C"], "launch_if_active": [], "launch_if_reattach_failed": [], "closes": {"C": ["C"]},
    "events": [
      {"done": ["C"], "eligible_to_settle": ["A", "B"], "progress": 1},
      {"done": ["C"], "eligible_to_settle": ["A", "B"], "progress": 1}
    ]
  },
  {
    "mapping": {"C": ["A"], "D": ["A"]}, "direct_children": ["C", "D"], "nested_originals": [],
    "launch": ["C", "D"], "launch_if_active": [], "launch_if_reattach_failed": [], "closes": {"C": ["C"], "D": ["D"]},
    "events": [
      {"done": ["C"], "eligible_to_settle": [], "progress": 1},
      {"done": ["D"], "eligible_to_settle": ["A"], "progress": 2},
      {"done": ["D"], "eligible_to_settle": ["A"], "progress": 2}
    ]
  }
]
```
