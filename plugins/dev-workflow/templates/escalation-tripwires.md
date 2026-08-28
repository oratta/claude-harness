# 昇格トリップワイヤー（作業役が手を止める条件）

<!--
導入手順:
- interactive で使う場合: **手動導入は不要**。dev-workflow プラグインの SessionStart hook
  （hooks/hooks.json → scripts/session-tripwires.sh）が、セッション開始時に本ファイルの
  「## 昇格トリップワイヤー」節を自動で文脈に注入する。
  手動コピー（グローバルルール ~/.claude/rules/ またはプロジェクト CLAUDE.md への転記）は、
  プラグイン未導入の環境や閾値を独自に改変したい場合向けのオプション。hook 注入と併存しても
  同文が2回載るだけで無害。
  セッションを跨がずにプラグインを更新した場合（/plugin update・/reload-plugins）は
  SessionStart が再発火しないため、UserPromptSubmit hook（scripts/prompt-tripwires-refresh.sh）が
  「plugin.json のバージョンが前回注入時から変わったとき」だけ同じ本文を再注入する。
  バージョンが同じ間は毎プロンプト無出力で、文脈を食わない。
- unmanned（loop-dev-agent）で使う場合: 憲法ファイル（docs/agent-loop.md）への組み込みを
  loops プラグイン側が行う（loop-dev-agent-tripwires）。手動コピーは不要。
- develop スキルの W（サブエージェント）は hook 注入を受けないため、W の指示書
  （skills/develop/references/roles/worker.md）が同じ条件を return の契機として持つ。
- このテンプレートは「いつ手を止めるか」だけを定義する。「どう実行するか」は発火先の
  スキル（develop の本体、/lr:e、/lr:p 等）が持つ。ここに実行手順を書き足さないこと。
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
      エピック化、または /lr:e 系の workflow 実行スキルに切り替える（成果は引き継ぐ）

2. 【失敗ループ → モデル昇格】
   同じテストが2連続で落ちた、または同じ箇所を2回書き直した
   → 実行役を1段昇格する（Sonnet → Opus → Fable）。
   `FABLE_BUDGET_MODE=reserve` の自動実行（unmanned / cron / loop）では Opus を上限とし、
   Opus でも2連続失敗が続く場合は issue に needs-approval を付けて経緯をコメントし、
   そのサイクルを終了する。
   `FABLE_BUDGET_MODE=exhausted`（Fable 週次枠を実質使い切った。明示宣言または
   usage snapshot からの自動導出）では、interactive / unmanned を問わず昇格上限を Opus とする
   （Fable へは昇格しない）

3. 【仕様の発明検知 → plan/質問へ】
   実装を進めるために、ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が
   2回に達した（「埋めた」= 例:「DB は SQLite でいいだろう」と自分で決めて書いた瞬間。
   その瞬間に1カウント）
   → 手を止める。埋めた決定を列挙し、
      - 決定が2〜3個で局所的 → AskUserQuestion で確認する
      - 決定が構造に及ぶ（データモデル・フロー・スコープ） → /lr:p を起動して壁打ちに戻す
      - unmanned なら Discord でユーザーに質問し、issue に needs-approval を付けて
        経緯をコメントし、そのサイクルを終了する

4. 【rate-limit 実エラー → reactive 降格】
   Fable 実行が rate-limit / weekly-limit の実エラー（429、weekly limit reached 等）を返した
   → 予測的な閾値判定（トリップワイヤー2）とは別系統の事後対応。その場で Fable を諦め、
   実行役を Opus に降格して同じ作業を続行する（成果は引き継ぐ）。併せて usage-probe を
   再実行して snapshot を更新し、以降のセッションの残量モード導出に反映させる
