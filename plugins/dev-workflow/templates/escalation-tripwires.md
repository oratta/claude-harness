# 昇格トリップワイヤー（作業役が手を止める条件）

<!--
導入手順:
- interactive で使う場合: **手動導入は不要**。dev-workflow プラグインの SessionStart hook
  （hooks/hooks.json → scripts/session-tripwires.sh）が、セッション開始時に本ファイルの
  「## 昇格トリップワイヤー」節を自動で文脈に注入する。
  手動コピー（グローバルルール ~/.claude/rules/ またはプロジェクト CLAUDE.md への転記）は、
  プラグイン未導入の環境や閾値を独自に改変したい場合向けのオプション。hook 注入と併存しても
  同文が2回載るだけで無害。
  セッションを跨がずにプラグインを更新した場合（/plugin marketplace update <name>・/reload-plugins）は
  SessionStart が再発火しないため、UserPromptSubmit hook（scripts/prompt-tripwires-refresh.sh）が
  「プラグインが前回注入時から更新されたとき（CLAUDE_PLUGIN_ROOT が変わったとき）」だけ同じ本文を再注入する。
  CLAUDE_PLUGIN_ROOT が同じ間は毎プロンプト無出力で、文脈を食わない。
- unmanned（loop-dev-agent）で使う場合: 各リポに配備済みの憲法ファイル（docs/agent-loop.md。
  それを配るリポジトリが保守する正本で、harness 側にテンプレートや再生成手順は無い）が同じ条件を
  組み込んでいる。手動コピーは不要。
- develop スキルの W（サブエージェント）は hook 注入を受けないため、W の指示書
  （skills/develop/references/roles/worker/common.md「昇格トリップワイヤー」）が同じ条件を return の契機として持つ。
- このテンプレートは「いつ手を止めるか」だけを定義する。「どう実行するか」は発火先
  （develop の本体、Workflow 実行の型 references/workflow-execution.md、/opsx:explore 等）が持つ。
  ここに実行手順を書き足さないこと。
- 閾値（ファイル5個・2回など）は初期値であり、運用しながら調整してよい。
-->

## 昇格トリップワイヤー

作業中に以下のいずれかを踏んだら、その場で手を止めて乗り換える。
「あと少しで終わるから」は乗り換えない理由にならない。
乗り換え・昇格の際、ここまでの成果（編集済みファイル・通ったテスト・判明した事実）は
破棄せず引き継ぐ。作業をやり直さない。

1. 【規模超過 → 分割へ】
   編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた
   → develop スキルの W として起動されている場合は本体に return し、本体が change / 子 issue
      （develop のエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop の
      エピック化、またはネイティブ Workflow 実行（型は plugins/dev-workflow/references/workflow-execution.md。
      スクリプトは workflow-authoring スキルを読んで書く）に切り替える（成果は引き継ぐ）

2. 【失敗ループ → 決める役 / 実行役の分離ラダー】
   同じテストが2連続で落ちた、または同じ箇所を2回書き直した
   → 実行役を1段ずつ上げるのではなく、失敗の原因が「決めた内容が間違っていた（判断側）」か
      「決めたとおりに実行できなかった（実行側）」かで、上げる相手を**一方だけ**決める
      （両方同時に上げない）。決める役は数ターンで終わるので先に上げ、実行役を上げるのは
      実行側が原因と分かったときだけ。

   表の格（最安・中位・上位・最上位）は `codex-develop.py request` の、上限を適用する前の要求の格で、
   Claude と Codex のどちらの profile でも同じ。モデル名は `references/model-tier-map.json` で引いた値で、
   括弧内は Claude での値の例。実際に起こすモデルは、その段の `--failure` の値を渡して
   `request` が返した `model`（残量モードと構成の上限を適用済み）を使い、表から計算し直さない
   （例: `SHARED_BUDGET_MODE=depleted` では決める役も中位の model が返る）。

   | 段階 | `--failure` | 決める役の要求の格（phase `decider`） | 実行役の要求の格（W の phase） |
   |---|---|---|---|
   | 初回 | なし | 仕様化判断と R1 レビューが担う（既存の流れ） | 既定の格（中位。Claude では `sonnet`） |
   | 1 回目の失敗 | `first` | 上位（Claude では `opus`）。失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする | 格を変えずに再試行 |
   | 2 回目の失敗・指示どおりやって結果が違う（実行側） | `executor` | 上位 | 上位（上限。Claude では `opus`） |
   | 2 回目の失敗・指示を解釈できなかった / 指示自体が外れていた（判断側） | `judgment` | 最上位（Claude では `fable`） | 格を変えない |
   | 最上位が決めて上位が実行しても落ちる | — | 人間へ（interactive は AskUserQuestion、unmanned は `needs-approval`） | — |

   決める役はどの段階でも `subagent_type` を `dev-workflow:decider` に固定し、`model` だけを
   切り替える（`general-purpose` に読み替えない）。**実行役の格の上限は上位で、実行役を最上位で
   起こさない**（Claude の強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`。`model: fable` の
   実行役 spawn は PreToolUse で拒否される）。本体は昇格の手段として profile を作り直したり、
   `request` が返した model と違う model を独自に指定したりしない（Codex の手順は
   `references/codex-develop.md`「本体が行う操作」）。
   `SHARED_BUDGET_MODE=throttled`（全モデル共通の週次枠が週の経過ペースより速く減っている）では
   昇格上限を上位、`depleted`（同枠 90% 超）では昇格しない。
   `FABLE_BUDGET_MODE=reserve` の自動実行（unmanned / cron / loop）と `exhausted`（Fable 週次枠を
   実質使い切った。明示宣言またはセッション記録と usage snapshot の実効値からの自動導出）では、決める役も
   `dev-workflow:decider` のまま上位止まりとする（種別は変えない。どちらも `request` が適用する）。
   上位が決めて上位が実行しても2連続失敗が続く場合は issue に needs-approval を付けて
   経緯をコメントし、そのサイクルを終了する

3. 【仕様の発明検知 → plan/質問へ】
   実装を進めるために、ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が
   2回に達した（「埋めた」= 例:「DB は SQLite でいいだろう」と自分で決めて書いた瞬間。
   その瞬間に1カウント）
   → 手を止める。埋めた決定を列挙し、
      - 決定が2〜3個で局所的 → AskUserQuestion で確認する
      - 決定が構造に及ぶ（データモデル・フロー・スコープ） → /opsx:explore で壁打ちに戻す
      - unmanned なら Discord でユーザーに質問し、issue に needs-approval を付けて
        経緯をコメントし、そのサイクルを終了する

4. 【コンテキスト上限 → 手渡し】
   名前付きサブエージェント（develop の W。G は再開せず段ごとに新しく起こす）を SendMessage で再開する前に
   `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-context.sh <名前>` で測り、
   上限を超えていた（exit 2）。あわせて、サブエージェントの**起動の途中**でも hook
   （`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）が本人を測り、上限超で締めを通知し、
   さらに越えると編集系ツールを拒否する（本人が途中で工程を締めて return する経路）
   → **閾値・環境変数・2 経路・通知や強制停止に当たったときの扱いは `${CLAUDE_PLUGIN_ROOT}/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本。
      条件・書式・手順はこのテンプレートには書かない。正本を読むまで手渡さない**
      （モデルは変えない。再開のたびに全履歴を読み直すため、畳まずに続けると 1 本で
      30 万トークン超のリクエストを毎ターン投げることになる。2026-09 監査の実測）

5. 【rate-limit 実エラー → reactive 降格】
   Fable 実行が rate-limit / weekly-limit の実エラー（429、weekly limit reached 等）を返した
   → 予測的な閾値判定（トリップワイヤー2）とは別系統の事後対応。その場で Fable を諦め、
   実行役を Opus に降格して同じ作業を続行する（成果は引き継ぐ）。併せて usage-probe を
   再実行する（前回の試行から間隔内・429 の待ち中なら叩かないので、snapshot が更新されないこともある）。
   以降のセッションの残量モード導出は、セッション記録と snapshot の実効値で行われる
