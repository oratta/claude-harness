# Changelog — dev-workflow

## 2.6.2 — 2026-09-09: サブエージェントのコンテキスト量を母集団で測る（観測のみ）

`subagent-context.sh` は 1 体分しか測らないため、起動時固定分が増えたか・上限超で手渡しになる割合が増えたかを追えなかった（2026-08-31 の約 42,000 → 09-08 の約 58,678 トークンという 8 日で約 4 割の増加に、事後の手集計まで誰も気づかなかった）。観測だけを足し、強制は加えない。

- `scripts/subagent-context-audit.sh`（新規）: `<projects>/*/*/subagents/agent-*.jsonl` の 1 経路を mtime で絞って走査し、件数 / 初回・最終コンテキストの中央値と最大 / 上限超割合を 1 行 JSON で出す。隔離の有無は隣の `agent-<id>.meta.json` の `spawnedWithWorktree` で分類し、`sources.isolated` / `sources.non_isolated` として経路別にも出す。全文は読まない（初回は最初の usage で打ち切り、最終は末尾 256 KiB の窓を 4 MiB まで倍加探索）。結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に残し、`SUBAGENT_CONTEXT_AUDIT_TTL`（既定 21600 秒）以内は再走査しない
- `docs/usage-audit.md`（新規）: 監査手順の正本。実行コマンド・出力キーの意味・固定分の増加の読み方・キャッシュの場所
- **既存スクリプトは 1 本も変更していない**。とくに `session-tripwires.sh`（SessionStart hook）には載せない — SessionStart への注入は全セッションの起動時固定分を増やす側の変更で、固定分の削減という目的に反するため
- 引数エラー以外はすべて exit 0（fail-open）。閾値による停止・警告は行わない

## 2.6.1 — 2026-09-09: 手渡し規則を正本 1 箇所に畳む（手渡しは前任の `工程完了:` return が条件）

コンテキスト上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）の記述は「上限を超えたら手渡す」という**発火条件**だけを書いており、**手渡してよいタイミング**を規定していなかった。2026-09-08 に、バックグラウンドで `bash scripts/test.sh` の完了を待って一時的に idle になっていただけの W を「工程を終えた」と誤認して手渡し、同じ worktree に新旧 2 人の W が並んだ（PR への重複コメント・共有ブラウザタブでのキー入力混線）。判定材料を本体側の内容判断から W / G 側の宣言に移した。

- **W / G の return に 1 行目完全一致の宣言契約**: `工程完了: <工程名>`（成果一覧を伴う工程の終わり）／`工程中断: <理由>`（バックグラウンドコマンド待ち等）。書式は `仕様化判断: する|しない` と同型。自分が起動したバックグラウンドコマンドが未完了なら、成果一覧を併記していても 1 行目は `工程中断:`
- **「再開の禁止」と「手渡しの許可」を分離**: exit 2 のときは前任の状態にかかわらず作業の継続を指示する SendMessage を送らない（無条件）。手渡し（新しい W / G の spawn）を行ってよいのは、①前任の直近 return の 1 行目が `工程完了:` のとき、②前任へ停止を指示して停止確認を受け取ったとき、のいずれかだけ。停止を指示する SendMessage はこの禁止の対象外
- **前任が動作中の交代手順**: 停止指示 → 停止確認（何を編集・投稿したか。自分で元に戻さない＝破壊的 git 操作をしない）→ 手渡し先を spawn。停止確認待ちはノンブロッキングで、unmanned は待ち続けずサイクルを終える
- **同一 worktree の同一役割は常に 1 人**（並列に起こしてよいのは別々の worktree を持つ役割だけ）
- **規則の本文を正本 1 箇所に畳んだ**: 上の 4 点（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）の本文は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」にだけ置く。SKILL.md の 1 ループ (3)(4) と昇格ラダー、`worker.md`・`gate-runner.md` の該当節、`README.md`、`templates/escalation-tripwires.md` のトリップワイヤー 4、`scripts/session-tripwires.sh` の毎セッション注入文、`scripts/subagent-context.sh` のヘッダコメント、2 つの live spec は、正本への参照だけを書く。同じ規則を 10 前後の面に言い換えて配ったことが、3 周続けての書き換え漏れ（1 周目 6 箇所・2 周目 1 箇所・3 周目 5 箇所の取り残し）の原因だった
- **ファイルを開かずに届く面にはガードを義務づけた**: `session-tripwires.sh` の注入文は、エージェントが正本を開かずに受け取る唯一の面なので、参照に加えて「正本を読むまで手渡さない」の 1 行を必ず持つ。純粋なポインタにすると、失敗の形が「古い規則を適用する」から「規則を知らないまま即興する」に変わり、二重 spawn 事故の直接原因（即興）に戻る
- **本文が 1 箇所にあることの機械検査は入れない**: 「トリガー語に掛かった面が正本への参照を持つか」を見るホワイトリストと、規則の言い換えを文単位で拾う走査（`tests/lib/handoff-scan.py`）を一度は作ったが、この PR から外した。検査の緑が「違反が無い」のか「何も見ていない」のか区別できない形に 7 周続けて落ち、原因は調整不足ではなく「規則の言い換えを機械で検出する」という目的そのものにある（語彙を増やせば別の言い回しで抜け、除外を書けばそこが穴になる）。本文の一本化は規約として spec の MUST NOT に残し、破りを捕まえるのは仕様レビューとする。機械検査が成立するかごと https://github.com/oratta/claude-harness/issues/265 に切り出した（`tests/handoff-declaration.bats` に残るのは、正本が①〜④を現に規定していることを固定する `criteria:` 系）
- **正本の節の切り出しを次の見出し（`## ` / `### `）で止めた**（後続の小節まで含んでいたため、正本の本文が小節へ移動しても `criteria:` 系が緑のままだった。2026-09-09 のレビュー指摘）
- **正本に 1 点足した**: 固定された 2 つの書式のどちらにも当てはまらない return は `工程中断:` と同じに扱う（展開直後に必ず現れる形で、明記が無いと本体が内容判断へ戻る）。あわせて④の「前任が先に `工程完了:` を返したら、そのまま続行し手渡しはしない」が①②と矛盾していたのを、通常の手渡しに戻る形に直した。「idle と return の違い」も 2 択の列挙をやめ、1 行目の完全一致だけで見分ける形にした（2 択のままだと、どちらにも一致しない 1 行目を「宣言ではないから内容で見る」と読む余地が残る）
- **停止確認が返らないときの終端は入れない**（2026-09-09 のレビュー B1〜B3。行き先: https://github.com/oratta/claude-harness/issues/266）。一度は「本体のターンを 3 回はさんだら人間に手渡しの可否を仰ぐ」と書いたが、①終端の帰結が検査で固定できておらず、事故そのもの（前任を放置して後任を spawn する）を許す文に書き換えても全テストが緑だった、②「人間に可否を仰ぐ」が手渡しの許可条件（工程完了 return か停止確認のいずれかだけ）と矛盾する第 3 の経路になる、③本体のターン数は終端の単位として働かない（他に進める作業が無ければカウンタが進まず、あれば数秒で 3 ターン空回りする）。この論点は別 issue に切り出す
- `gate-runner.md` から正本に無い書式規則（「1 行空けてから」）を落とし、`marketplace.json` の description を手渡しの記述に追随させた（spec がズレを許容したのは `plugin.json` だけ）
- openspec change `handoff-requires-completed-return` を archive

## 2.5.0 — 2026-09-08: Fable は決める役の種別（dev-workflow:decider）でだけ立てる

2.4.1 で配線したガードは `model` 未指定を拒否するが、`model: "fable"` を明示した spawn はどの種別でも素通りしていた（2026-09-08 に develop の本体が「層間契約だから」を根拠に実行役の W を fable で spawn した実例あり）。文書が自分で例外を作れる状態を、ガードに移した。

- `agents/decider.md`（新規・`plugin.json` の `agents` で宣言）: 決める役の種別 `dev-workflow:decider`。`model: fable`、`tools: Read, Grep, Glob` の読み取り専用で Edit / Write / NotebookEdit / Bash を持たない（編集できないので実装ループを物理的に回せない）。入力（記録先の本文とコメントは呼び出し側が貼る・失敗の出力・対象ファイルのパス・実行役の return）と出力（原因の分類・実行役がそのまま実行できる指示・次の実行役のモデル）を契約として持ち、記録先への投稿は行わない
- `scripts/agent-model-guard.sh`: Fable を指す `model`（`fable` の完全一致・`claude-fable` の前方一致）は `dev-workflow:decider` のときだけ許可し、それ以外は deny。判定は fork の後・`model` 有無の前。残量モードは見ない。`model` 未指定の拒否文からも fable の 4 分類を外した
- 昇格ラダー: 「実行役を sonnet → opus → fable と 1 段ずつ」を廃止し、失敗の原因が判断側か実行側かで**決める役と実行役のどちらか一方だけ**を上げる形にした（`templates/escalation-tripwires.md` が正本。develop SKILL.md・worker.md・gate-runner.md・pr-review-gate 2-2・`rules/subagent-model-selection.md` を追随）。実行役の上限は `opus`
- 重要実装の事前分類表（`references/roles/worker.md` が正本）: マージ権限・層間契約・課金/法務の「1 周目」を `fable` → `opus`。聖域パスの `opus` は据え置き。読んで判断する役（R1・G が要求するレビュアー）が分類に当たるときは `subagent_type: dev-workflow:decider` で spawn する
- R1 を decider 経路で起こしたときは、R1 が `gh` を実行できないため本体が同じ書式で代理投稿する（記録先の本文と関連コメントは本体が入力文に貼って渡す）。`general-purpose` + `model` の従来経路は R1 が自分で投稿する
- フォールバック記録の書式を「修正実装モデル: opus」→「決める役モデル: opus（… `subagent_type` は `dev-workflow:decider` のまま）」に変更
- `tests/decider-agent.bats`（新規）: 定義の検証に加え、`plugins/*/agents/*.md` のうち `model` が Fable の定義が編集系ツールを持たないことを横断で assert
- 旧方針が残っていた 4 か所を追随させた（レビュー指摘）: `gate-runner.md` の needs-reviewer 節とモデル節（`general-purpose` に `model: fable` を付けさせる案内）、`references/decision-criteria.md` の残量モード表 `abundant` / `conserve` 行、`scripts/session-tripwires.sh` の残量モード効果文（毎セッション旧方針を注入していた）、pr-review-gate のレビュアー昇格条件（`fable` への昇格を `subagent_type: dev-workflow:decider` に置換）
- 書き換え漏れの再発防止として、`gate-runner.md` は Fable に触れる全行が決める役の種別を伴うことを行単位で assert し、退役した言い回し（「事前分類の fable 行」「Fable は verify / checkpoint のみ」）がプラグイン内の文書・スクリプトに残っていないことを横断で assert する。`session-tripwires.sh` は注入される実文字列で検証する
- openspec change `fable-decider-only` を archive

## 2.4.1 — 2026-09-06: agent-model-guard を hooks.json に配線

2.4.0 で同梱した `scripts/agent-model-guard.sh` を PreToolUse（matcher: Agent）に配線した。これ以降、`model` 未指定の `Agent` 呼び出し（general-purpose / Explore / Plan / 未指定）は拒否され、理由に規範（rules/subagent-model-selection.md）と選ぶべきティアが出る。fork は共有枠モードが ok のときだけ許可。`DEV_WORKFLOW_MODEL_GUARD=off` で一時的に外せる。

## 2.4.0 — 2026-09-06: Fable は判断だけ（聖域パスの実装は opus・G は sonnet・abundant の押し上げ廃止・修正実装は 1 段昇格）

2.3.0 の後に Fable の行き先を再集計した。先週の Fable 消費のうち W 924・G 497・R1 464（API 定価換算）で、Fable で走った W / G 24 本のうち 20 本は事前分類の「聖域パス」（`.claude/` 配下・CLAUDE.md・スキル）によるものだった。エージェント設定が製品であるリポではほぼ全実装が聖域に当たり、例外のはずの Fable が既定になっていた。今週は abundant の押し上げで R1 / G が 100% Fable。G 自身の仕事は照合・ラベル操作で、判定は Codex か needs-reviewer のレビュアーが担っている。オーナー決定（2026-09-06）で「判断は Fable、実装と照合は Sonnet / Opus」に揃えた。

- 事前分類表に「1 周目」列: 聖域パス = `opus`、マージ権限・層間契約・課金/法務 = `fable`
- G の既定 `opus` → `sonnet`（上げない）。needs-reviewer のレビュアーは既定 `opus`、マージ権限・層間契約・課金/法務で `fable`
- R1 は `opus` 固定。聖域パスだけでは `fable` にしない
- `abundant` はどの役割の既定も上げない（session-tripwires の効果文言・decision-criteria 表・spec）
- pr-review-gate 2-2: 実装品質起因の修正実装は `fable` 直行ではなく前回モデルの 1 段上
- openspec change fable-judgment-only を archive
- `scripts/agent-model-guard.sh`（新規）: PreToolUse（Agent）で `model` 未指定の spawn を拒否する hook スクリプト。fork は共有枠モードが ok のときだけ許可。**hooks.json への配線は聖域パスのため別 PR**（配線されるまで効かない）

## 2.3.0 — 2026-09-06: サブエージェントのコンテキスト上限（手渡し）・共有枠モード・W の既定を sonnet に

2026-08-31〜09-05 の使用量監査（521 セッション・API 定価換算 12,159 USD）で、消費の 3 分の 2 が develop の W / G / R1 で、うち W が 44.5%（31 本・平均 174 USD・最大 745 USD）だった。原因はモデルではなくコンテキスト: W は SendMessage 再開のたびに全履歴を読み直し、Opus の W は平均 32.6 万トークンを毎ターン投げていた（W の消費の 63% が 30 万トークン超のリクエスト）。W に Sonnet は 1 本も無く、Fable 残量モードは 4 段すべて下限 Opus で、Fable が尽きた日に総量が最大になった。sonnet の別コンテキストで再集計し、分類境界の差はあるが機構（W の平均 34 万・上限超の割合 68%・Sonnet ゼロ・畳む仕組み無し）は一致した。

### コンテキスト上限（新規）

- `scripts/subagent-context.sh <agent-name> [--cap N]`: 名前付きサブエージェントのトランスクリプト（`~/.claude/projects/*/*/subagents/agent-*<name>*.jsonl`）の最後の usage から input + cache_creation + cache_read を読み、上限超なら exit 2。cwd が一致するトランスクリプトを優先
- 本体は W / G を SendMessage で再開する**前に毎回**測り、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）超なら再開せず、前回 return を渡した新しい W / G に**手渡し**する。W は工程ごとに必ず return し、return に「編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業」を列挙する（手渡しの唯一の入力）
- 昇格トリップワイヤーに 4【コンテキスト上限 → 手渡し】を追加（旧 4 の rate-limit 実エラーは 5 へ）

### 共有枠モード `SHARED_BUDGET_MODE`（新規）

- `session-tripwires.sh` が snapshot の `weekly_all_pct`（全モデル共通の週次枠）から `ok` / `throttled`（週経過ペースより速い）/ `depleted`（90% 超）を導出し、Fable 残量モードと並べて注入する。明示 env が優先
- `throttled`: W / R1 / G の既定を sonnet、昇格上限 opus、abundant の押し上げ無効。`depleted`: 全役割 sonnet 固定。Fable 残量モードと食い違えば共有枠モードの下限が勝つ

### 役割の既定モデル（変更）

- W の既定を `opus` → `sonnet`。`opus` は設計判断を含む記録先と失敗ループ昇格、`fable` は事前分類（従来どおり）。昇格ラダー sonnet → opus → fable の Sonnet 段が初めて到達可能になる
- `abundant` が押し上げるのは R1 / G だけ。W は abundant でも上げない（W の 4 割が Fable で走っていた原因）

## 2.2.0 — 2026-09-04: usage snapshot schema 2（複数アカウント対応）

`usage-probe.sh` を複数の Claude アカウントに対応させ、`~/.claude/.usage-snapshot` を schema 2 に拡張した。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると `CLAUDE_CONFIG_DIR` を共有したまま Keychain の認証情報だけを分けられるが、probe が Keychain のサービス名を `Claude Code-credentials` に固定していたため、常に既定アカウントの値しか取れず `FABLE_BUDGET_MODE` の導出もそこに固定されていた。

### アカウントレジストリ（新規）

`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）にスロットを列挙する。**ファイルが無ければ既定スロット 1 つとして扱われ、挙動も出力も従来と変わらない。** 生成は `scripts/accounts-init.sh` を登録したいアカウントのシェルで実行する（`CLAUDE_SECURESTORAGE_CONFIG_DIR` の実値をそのまま書き出すので、パスの転記ミスが起きない）。

Keychain サービス名の導出は Claude Code 本体と同じ規則: `securestorage` が空なら `Claude Code-credentials`、そうでなければ `Claude Code-credentials-` + NFC 正規化した値の sha256 先頭 8 桁。

### snapshot schema 2

| キー | 内容 |
|---|---|
| `schema` | `2` |
| `active` | 現在アクティブなスロット id |
| `accounts.<id>` | `label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active` |
| トップレベルの上記同名キー | **active スロットのミラー**（独立に計算しない） |

トップレベルのミラーを残しているのは、`session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出と statusline の 6 時間鮮度ゲート（`fetched_at` を読む）を無改修で動かすため。schema 2 は追加のみなので、古い読み手も新しい読み手も同じ snapshot で動く。

`fetched_at` は **そのスロットの値を実際に取得できた時刻**であって probe の実行時刻ではない。fail-open で前回値を引き継いだスロットは前回の `fetched_at` を保つ。

### fail-open がスロット単位になった

あるスロットのフェッチが失敗しても、そのスロットは既存 snapshot の前回値（`fetched_at` 込み）を引き継ぎ、他スロットの新しい値は書く。使っていないアカウントは OAuth アクセストークンが期限切れでフェッチが落ちるのが常態なので、1 スロットの失敗で snapshot 全体の更新が止まると使い物にならない。

全スロットが失敗したとき、および組み立て・書き込みが失敗したときに snapshot を書かない従来の契約はそのまま。

**API のエラーレスポンスも失敗として扱う。** HTTP 401 / 429 / 5xx でも API は正しい JSON のオブジェクト（`{"type":"error", ...}`）を返すので、「JSON として読めた」を成功の判定に使うと、期限切れトークンのスロットの前回値を全 `null` で上書きしてしまう。HTTP ステータスを見たうえで、使用量の数字が 1 つも取れなかったレスポンスも失敗と判定する。

### そのほか

- `Authorization` ヘッダを `curl --config -` で stdin から渡すようにした。コマンドライン引数に載せると、同一ユーザーの任意プロセスと root から `ps auxww` でアクセストークンが読める
- `label` / `securestorage` に制御文字を含むスロットは捨てる。スロット一覧は区切り付きで受け渡すため、区切りを壊すと列がずれて実在しない「幽霊スロット」が生まれ、`securestorage` が空になって既定サービス名に一致し active を乗っ取りうる
- `accounts-init.sh` が `--id` / `--label` を値なしで渡されたときに無限ループしていたのを修正（`shift 2` が失敗しても `set -e` が無いため回り続けていた）。書き込みの一時ファイル名も固定名から `mkstemp` に変更（アカウントごとに別シェルで実行する運用なので、同時実行で奪い合う）
- `label` は文字数ではなく**表示幅**（全角を 2 桁と数える）で扱い、8 桁を超えたら切り詰める。日本語のラベルで statusline の列がずれるのと、長い label で全行が押し出されるのを防ぐ
- probe のテスト経路の判定を `env | grep` から既知のキー名の直接参照に変更（改行を含む無関係な変数への誤マッチと、空文字設定時に本番経路へ落ちる従来挙動との食い違いを解消）

### refresh_token は使わない

Keychain の `refreshToken` でアクセストークンを更新すれば非 active アカウントの値も新鮮に保てるが、リフレッシュはトークンをローテートするため、Claude Code 本体が同じ refresh_token でリフレッシュしたときに無効化され、そのアカウントがログアウトしうる。使用量表示のために認証を壊すのは割に合わないので意図的に非対応とし、鮮度は statusline 側の経過時間表示で扱う。

## 2.1.0 — 2026-08-31: loops / longrun / lr の解散と契約の移設（#205）

`loops`・`longrun`・`lr` の 3 プラグインを解散し、中に埋まっていた契約だけを dev-workflow に移した（oratta/claude-harness#205、epic #208）。手順書としての層はモデルが自力でできるようになったので持たない。契約は他プラグインからも参照されるため、スキル配下ではなくプラグイン直下の `references/` に置く。

### install 済み環境でやること

marketplace から 3 エントリが消えるため、install 済みの環境ではキャッシュに残った旧プラグインを外す:

```
/plugin uninstall loops@oratta-claude-harness
/plugin uninstall longrun@oratta-claude-harness
/plugin uninstall lr@oratta-claude-harness
/reload-plugins
```

各プロジェクトの `.claude/settings.local.json` の `enabledPlugins` に `loops@oratta-claude-harness` / `longrun@oratta-claude-harness` / `lr@oratta-claude-harness` のキーが残っていれば外す（skill-pack の `enabledPlugins` 編集の規約に従う）。

### 契約の新旧パス

| 旧（loops / longrun / lr） | 新（dev-workflow 2.1.0） | 備考 |
|---|---|---|
| `plugins/loops/references/self-verification.md` | `plugins/dev-workflow/references/self-verification.md` | 自己検証の共通原則。6 スキルの `## 自己検証` 節が参照（旧 `longrun-plan` は対象から外れた） |
| `plugins/loops/references/pr-body-format.md` | `plugins/dev-workflow/references/pr-body-format.md` | PR / issue 本文の型。内容は同じ。`.github/PULL_REQUEST_TEMPLATE.md` と `roles/worker.md` の参照先も差し替え |
| `plugins/longrun/references/model-tiers.md` | `plugins/dev-workflow/references/model-tiers.md` | Workflow 実行のロール別ティア → `opts.model` エイリアス。longrun 固有の resolver・plan.md の割り当て節・`LONGRUN_AUTOMATED` は廃止。`rules/subagent-model-selection.md` の参照先も差し替え |
| `/loops:issueify`（`plugins/loops/skills/loops-issueify/SKILL.md`） | `plugins/dev-workflow/skills/issueify/SKILL.md`（スキル名 `issueify`） | `/develop` の issueify フォールバックは同プラグイン内を Read する。goalify・レシピへの参照は本文に取り込んで解消 |
| `/lr:e` / `/longrun:exec`（plan.md → Workflow スクリプト生成） | ネイティブ Workflow ツール。型は `plugins/dev-workflow/references/workflow-execution.md`、書き方は `workflow-authoring` スキル | 昇格トリップワイヤー 1 と develop SKILL.md の乗り換え先を差し替え。Build Contract レビュー・verifier のしきい値（品質 100% / 完成度 80%）・schema 付きレポートの知見はこの 1 ファイルに集約 |
| `/lr:p` / `/longrun:plan`（brain dump → plan.md） | `/opsx:explore`（openspec ネイティブ） | develop は上流の壁打ちを呼ばない方針のまま。トリップワイヤー 3 の構造的決定の逃がし先も `/opsx:explore` |
| `/loops:review-queue` | **廃止** | このリポに呼び出し元が無く、読み取り専用ビューのデータ源（GitHub Project「Review Queue」）は直接使える。人が捌く PR は `gh pr list --label human-merge --state open` |
| `plugins/loops/references/feature-list-format.md` | **廃止** | 唯一の利用者 `recipes/routine-long-build.md` が同時に消えた。外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ |
| `plugins/loops/templates/agent-loop-template.md`（憲法テンプレ） | **廃止**。各リポの `docs/agent-loop.md`（flatmate が保守）が正本 | harness からの再生成・逆同期はしない |
| `plugins/loops/tests/integration.bats` の S130 / S130b / S131 / S132 / S133 / S139 | `tests/marketplace-sync.bats`（リポ直下） | marketplace と `plugins/` の整合ガード。特定プラグインに属さないので loops と一緒に消さない |
| レシピ 10 本・`loops-design`・`goalify`・`dev-agent-start`・longrun の agents / schemas / scripts | **廃止**（git 履歴のみ） | 参照ゼロ。必要なら `git log --diff-filter=D -- plugins/loops plugins/longrun plugins/lr` から復元できる |

`openspec/specs/` の `loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（38 件）も削除した。生き残る契約の要件は `dev-workflow-shared-references`・`dev-workflow-issueify`・`marketplace-plugin-sync`・`loops-longrun-retirement` に引き継いだ。

### flatmate 側で追従が必要なもの

genetta-inc/flatmate#458 で追従する（https://github.com/genetta-inc/flatmate/issues/458）:

- `docs/agent-loop.md`（loop-dev-agent 憲法）: 正本宣言後は flatmate 側で自立。本文の `/loops:issueify`・`plugins/loops/references/pr-body-format.md`・`loops-dev-agent-install` の参照を新パスに
- `docs/burn-mode.md`: 「残り PR を人が捌く経路」の `/loops:review-queue` を `gh pr list --label human-merge` / Project 直接参照に
- issue テンプレート（`agent-task.md` 等）の書式の正本パスを `plugins/dev-workflow/references/pr-body-format.md` に
- リポジトリローカル pre-push フック（main 拒否込み）の雛形と挙動テスト（旧 `pre-push-merged-pr-guard.bats`）が harness から消えた。以後の正本は `new-resident` 側

### その他の変更

- `templates/escalation-tripwires.md`: unmanned の組み込み先を憲法（flatmate 保守）に、乗り換え先を `references/workflow-execution.md` と `/opsx:explore` に
- `skills/develop/SKILL.md`: 「longrun:plan を呼ばない理由」→「上流の壁打ち（`/opsx:explore`）を呼ばない理由」、参照節に憲法の正本宣言と Workflow 実行の型
- `skills/push-guard-setup/SKILL.md`: ローカル層の設置者を「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に
- 参照を直した他プラグインの patch bump: casting 0.4.1・experience-to-skill 0.3.2・skill-pack 0.2.1・infra 0.5.7・weekly-report 1.1.3・daily-report 0.3.5・worktree 2.12.3
