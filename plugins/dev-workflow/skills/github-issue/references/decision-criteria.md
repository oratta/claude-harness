# 判定基準リファレンス（github-issue スキル）

`SKILL.md` の Step B・Step C・実行戦略判定で使う判定基準の詳細版。

## 共通軸: 4象限モデル

Step B（仕様化要否）と実行戦略は同じ2軸で判定する:

- **縦軸: 実行が吸収するトークン量** — 分業（委譲）するかどうかを決める。小タスクの委譲はハンドオフ毎の固定コーディネーションコストで確実に損（Lance Martin の BrowseComp 実験: 小タスクで 60% 割増）
- **横軸: 判断の分布** — どのモデルが担当するかを決める。設計判断・トレードオフ・探索がどれだけ残っているか

| | **判断が少ない**（やること明確） | **判断が多い**（設計・探索が残る） |
|---|---|---|
| **トークン小** | ① solo・安いモデルで十分<br>例: typo、lint、明白なバグの数行 fix | ② solo・賢いモデルが直接<br>例: 再現困難なバグの根本原因特定 |
| **トークン大** | ③ delegate+verify<br>例: 受け入れ条件が揃った単一 change、機械的な大量移行 | ④ workflow 型<br>例: 複数 change に割れる機能、探索しながらの実装 |

**事前判定は仮決めにすぎない**。誤分類は昇格トリップワイヤー（`plugins/dev-workflow/templates/escalation-tripwires.md`）が実行中に修正するので、入口で精密に当てようとしない。迷ったら①（solo）から始めてよい。

## Step B: 仕様化（opsx / openspec）するかどうか

**一次基準: 設計判断・トレードオフを含むか**。spec の本体価値は「意図と決定の記録」（なぜこう作ったか、何を捨てたか）であり、これはソースコードのどこにも残らない。一方「コンテキスト圧縮」（コードを読まずに把握する要約）としての価値は、モデルの探索能力で代替が利く。前者を含むものだけを spec 化する。

### 仕様化する（opsx に乗せる)

以下のいずれかに該当する:

- 複数案からのトレードオフの選択・採用理由など、後から「なぜこう作ったか」を決定履歴として残す価値のある設計判断を含む
- 外部から観測可能な振る舞いの追加・変更のうち、実装方針に選択肢が残っているもの
- `openspec/specs/` の既存 capability の要件を変える、またはユーザー向け docs の更新を伴う

### 仕様化しない（コード直行）

以下のみに該当する場合:

- typo・lint 指摘・コメント修正・フォーマット変更のみ
- 振る舞いが変わらない内部リファクタリング（関数分割・命名変更・デッドコード削除）
- ワンライナー fix（明白なバグの1行修正で、修正方針に選択肢がない）
- 依存パッケージのバージョン上げのみ（挙動変更を伴わない）
- **受け入れ条件が issue 本文に明記された機械的な振る舞い変更**（設計判断を含まない）。issue とテストが記録として十分なため spec は省略できる

### 判定したら必ず記録する

判定結果は元 issue に `仕様化判断: する` / `仕様化判断: しない`（1 行目・完全一致）＋理由のコメントで残す。書式と照合規則の正本は `references/spec-review.md`「判断記録の契約」。

### どの判定でも変えないもの

**テスト作成は全経路で必須**。テストはドキュメントであると同時に、昇格トリップワイヤー（失敗ループ検知）の信号源であり、これを緩めると実行戦略のハーネス全体が機能しなくなる。

### 判定に迷ったら

- **interactive モード**: 「これは仕様として残しますか、それともコード修正だけで済ませますか？」とその場で聞く。
- **unmanned モード**: 判断がつかない場合は**仕様化する側に倒す**（過剰な spec 化のコストより、無人ループが判断ミスで仕様の裏付けなしに振る舞いを変えるリスクの方が高い）。

## Step C: 単一 change か複数 change か

### 単一 change で足りる

すべてを満たす:

- 単一の capability（機能領域）に閉じる
- 受け入れ条件が概ね1〜5個程度で、1 PR で完結する分量
- 独立した設計判断（トレードオフの選択）が1つ以内

### 複数 change に割れる

いずれかに該当する:

- 複数の独立した capability に跨る（例: 「認証を追加し、かつ管理画面にログイン状態を表示する」は認証capabilityと表示capabilityの2つ）
- 受け入れ条件が多く、明確な順序依存を持つサブタスクに割れる（例: 「スキーマ変更 → API 実装 → UI 実装」のように前工程が終わらないと後工程が着手できない）
- 1 実装サイクルで完結しない規模（loop-dev-agent の `size:large` 相当の分量）

**境界の一言定義**: 「opsx change が2つ以上必要になりそうなら複数 change」。

### 複数 change に割れた場合の分割方法

1. issue 本文の受け入れ条件・記述されている機能単位を根拠に、独立した capability ごとに change 候補を機械的に列挙する（想像で機能を足さない。issue に書かれている範囲でのみ分割する）。
2. 各 change 候補間の依存関係を見る（後工程が前工程のファイル・API に依存するか）。依存があれば順序を付ける。依存がなければ並列実行候補としてよい。
3. 各 change 候補は、それ単体で「単一 change で足りる」の基準を満たすように切る（1つの change がさらに複数に割れそうなら、その change 自体をもう一段分割する）。

### 割り方が判断できないほど曖昧な場合

- **interactive モード**: AskUserQuestion でその場で聞く（例: 「issue に書かれている内容は、A と B の2つの独立した変更に見えます。分けて進めてよいですか、それとも1つの change として扱いますか？」）。
- **unmanned モード**: Discord でユーザーに同様の質問を送る。返信を待つ間は `needs-approval` ラベルを付けて経緯を issue にコメントし、そのサイクルは終了する。

## 実行戦略の判定（Step B/C と同時に行う。独立 Step にしない）

Step B/C で issue を読んだ同じ流れの中で、4象限に当てはめて実行戦略を仮決めする。

### 決定論的シグナルの収集（判定の前処理）

判定の入力になるシグナルは script で機械的に集める。判定そのものは表に従ってその場のセッションが下す:

```bash
N=<issue番号>
# 本文の長さ（文字数）
gh issue view $N --json body --jq '.body | length'
# 受け入れ条件チェックリストの有無（行数）
gh issue view $N --json body --jq '.body' | grep -cE '^\s*- \[ \]' || true
# size 系ラベル
gh issue view $N --json labels --jq '[.labels[].name | select(startswith("size:"))]'
# 本文で言及されているファイル数（拡張子付きパスの概数）
gh issue view $N --json body --jq '.body' | grep -oE '[A-Za-z0-9_./-]+\.[a-z]{2,4}' | sort -u | wc -l
```

### 縦軸・横軸の目安

閾値（5超・6個など）はすべて初期値であり、運用しながら調整してよい。

- **トークン大**の目安（いずれか）: 言及ファイル数が5超 / `size:large` ラベル / 受け入れ条件が6個以上 / 複数 change 判定（Step C）
- **判断が多い**の目安: Step B で「設計判断を含む」と判定した（= 同じ軸を共有している）/ 実装方針に未確定の選択が残っている / 探索・調査が必要

### 判定表（シグナル × 判断分布 × 残量モード → 実行戦略）

| 象限 | conserve（既定） | abundant | reserve の自動実行* |
|---|---|---|---|
| ① トークン小 × 判断少 | solo（メインセッションのまま） | solo（同左） | solo（同左） |
| ② トークン小 × 判断多 | solo・Opus が直接 | solo・Fable が直接 | solo・Opus 上限 |
| ③ トークン大 × 判断少 | delegate+verify: 実行=Sonnet subagent / codex、verify=Fable | 同左（実行を Fable にしない。無駄撃ち） | 実行=Sonnet / codex、verify=Opus |
| ④ トークン大 × 判断多 | workflow 型（/lr:e 系）: builder=安いモデル、checkpoint/verify=Fable | 同左 | workflow 型: checkpoint/verify=Opus 上限 |

*reserve の interactive セッションは conserve と同一に扱う。`exhausted` は reserve 列と同じ割り当てを **interactive / unmanned の両方** に適用する（Fable をどの役割でも使わず、昇格上限 Opus）。

### 残量モード `FABLE_BUDGET_MODE`

サブスクの Fable 枠の残り具合を表す環境変数。**明示設定が最優先**で、未設定時は usage snapshot からの自動導出結果を用いる（後述）。導出もできなければ `conserve` 扱い（安全側）。settings.json の `env` ブロックで明示的に固定することもできる。

| 値 | 意味 | 効果 |
|---|---|---|
| `abundant` | Fable が余っている（消費が週の経過ペースより遅い） | solo の推奨モデルを Fable に倒す。委譲は「結果が変わらない機械的な大量仕事」かつ **self-contained なタスク**（後述）に限定 |
| `conserve` | 使い切りそう / 消費が週の経過ペースより速い（既定） | solo=Opus。Fable は verify / checkpoint のみ |
| `reserve` | Fable 枠を人間用に温存 | conserve に加えて、**自動実行（unmanned / cron / loop 経由）では Fable をいかなる役割でも使わない**。昇格ラダーは Opus 上限。Opus でも2連続失敗が続く問題は `needs-approval` で人間に返す。interactive は conserve と同一 |
| `exhausted` | Fable 週次枠を実質使い切った（`fable_weekly_pct > 90`、または明示宣言） | **reserve と異なり interactive を含む全経路で Fable を一切使わない**（枠が実際に無いため）。昇格ラダーは Opus 上限。加えて rate-limit 実エラーで reactive に Opus へ降格する（`escalation-tripwires.md` トリップワイヤー4） |

`reserve` と `exhausted` の差: reserve は「温存」で自動実行のみ Fable を禁じ interactive は自由。exhausted は「枠が実際に無い」ため interactive を含む全経路で禁じる。

モードが動かすのは solo の推奨モデルと委譲閾値・昇格上限だけで、判定の構造は変えない。env のためセッション起動後の明示的な変更は次セッションから反映される（モード切替は週単位想定のため許容）。自動導出は SessionStart 毎に更新される。

### `FABLE_BUDGET_MODE` の自動導出（usage snapshot 契約）

`scripts/usage-probe.sh` が OAuth usage API（`/api/oauth/usage`）から Fable 週次消費率を取得し、`~/.claude/.usage-snapshot`（`fable_weekly_pct` / `fable_active` / `weekly_resets_epoch` を含む JSON）を書く。5 分キャッシュ・fail-open（取得失敗時は snapshot を書かず既存を保持）。`scripts/session-tripwires.sh` が SessionStart 毎にこの probe を best-effort 実行し、snapshot からモードを導出して残量ブロックを文脈に注入する。

導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較で、次の優先順位に従う:

1. **明示 env `FABLE_BUDGET_MODE` があればそれを使う**（自動導出より優先）
2. snapshot が無い / `fable_weekly_pct` が読めない → `conserve`（既定・安全側）
3. `fable_weekly_pct > 90` → `exhausted`
4. `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant`
5. それ以外（消費が週経過を上回る）→ `conserve`

週経過% = `(7日 − (リセット時刻 − 現在)) / 7日 × 100`。probe が失敗しても導出は conserve に倒れ、トリップワイヤー注入自体は従来どおり行われる。

### abundant の委譲は self-contained タスクに限定（クリーンなハンドオフ）

abundant で solo を Fable に倒しても、委譲（delegate+verify）に回してよいのは **self-contained なタスク** に限る。self-contained とは以下をすべて満たすこと:

1. 委譲側（賢いモデル）が**再文脈化なしに検証できる**受け入れ条件が明確
2. 実装中の**追加ヒアリング（往復）を要しない**
3. **入力・出力が着手前に確定**している

これを満たさない（実装中に仕様の往復や再文脈化が必要な）タスクは、abundant でも solo に留める。ハンドオフの固定コーディネーションコストが便益を上回るため（小タスクの委譲が損なのと同じ理屈を、判断が絡むタスクにも適用する）。

### モード不変ルール（どのモードでも変えない2本）

1. **結果が変わらない大量トークン仕事は常に安いモデル**（fan-out ワーカー、機械的編集）。abundant でも Fable を使うのは無駄撃ち
2. **判断が集中する場所は常に賢いモデル**（checkpoint の再ランク、verify）。reserve の自動実行だけが例外で Opus 上限

## 判定に使わない材料（注意）

- `docs/agent-loop.md` の有無 — これは loop-dev-agent（無人ループ）が導入済みかどうかの判定材料であり、wt-setup 済みかどうかや仕様化要否の判定には使わない。
- issue に付いているラベルの種類 — `agent-ready` 等のラベルは loop-dev-agent 側の運用状態を表すものであり、Step B・Step C の判定基準そのものではない（unmanned モードで呼ばれた時点で、着手可否の判定は既に呼び出し側=loop-dev-agent の Step 0.9 が済ませている）。`size:` ラベルのみ実行戦略のシグナルとして使う。
