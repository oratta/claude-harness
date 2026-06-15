# Design: mvp-plan-split

## Context

longrun プラグイン v5.2.0 で MVP モードが `longrun-plan` SKILL.md 内のモード分岐（`--mode=mvp`）として実装された。構成要素は以下の通り:

- `plugins/longrun/skills/longrun-plan/SKILL.md`: 冒頭にモード分岐 GATE、末尾に「MVP モード（--mode=mvp）」セクション（MVP Step 1〜8 + Step 4.5）
- `plugins/longrun/agents/longrun-mvp-{research,plan-reviewer,bestpractice-reviewer}.md`: MVP 専用 agent 3 種（description / 本文が `/longrun:plan --mode=mvp` を呼び出し元として記述）
- `plugins/longrun/templates/plan-template-mvp.md`: 軽量テンプレ（先頭 `<!-- mvp-mode -->` マーカー + divergence 防止コメント）
- `plugins/longrun/commands/archive.md`: `<!-- mvp-mode -->` マーカー検知で OpenSpec change 生成をスキップする分岐

本 change は change-2（workflow-exec、longrun/lr v6.0.0）のマージ後に着手する。前提となるベースは longrun 6.0.0 / lr 6.0.0（status/decisions コマンド削除済み、orchestrator スキル解体済み）。論理的依存はなく、直列化は plugin.json / README の同時編集コンフリクト回避のため。

ユーザー（唯一の開発・運用者）の動機は「同じものをオプションで呼ぶのに共通のロジックを通っていない」気持ち悪さの解消であり、共通点が少ない 2 フローを独立スキルに分離してそれぞれ別々に最適化可能にすること。

## Goals / Non-Goals

**Goals:**

- MVP プラン作成フローを独立スキル `longrun-mvp-plan` + `/longrun:mvp` + `/lr:m` として提供する
- `--mode=mvp` フラグを廃止し、旧フラグ指定時に明示的な移行案内を出す（サイレント無視しない）
- MVP 用 agent 3 種と軽量テンプレの帰属を新スキルに整理する（記述上の帰属更新のみ、ファイル移動なし）
- Gap Analysis / Interview の方法論を両スキルが自己完結に参照できるようにする
- バージョン同期: longrun 6.0.0 → 6.1.0、lr 6.0.0 → 6.1.0（各 3 箇所）

**Non-Goals:**

- MVP フロー自体のロジック変更（ステップ構成・agent 契約・成果物形式はすべて不変。移動と分離のみ）
- MVP フローの Workflow ツール化（exec の Workflow 化パターンが安定してから次 run で判断）
- `<!-- mvp-mode -->` マーカーおよび `/longrun:archive` 側の分岐の変更（現状維持）
- フルモード（Step 1〜8）の挙動変更（モード分岐ブロックの書き換え以外、本文は触らない）
- MVP 用 agent 3 種の出力契約の変更（呼び出し元の帰属記述のみ更新）

## Decisions

### D1: 独立スキル名は `longrun-mvp-plan`（名詞形）

- 採用: `longrun-mvp-plan`。Skill は名詞形、Agent は `-er`/`-or` 終わりという longrun の命名規則（`longrun-plan-skill` spec「Skill 命名規則の統一」）に従う
- 代替案 1: モード分岐の継続 — 却下。共通ロジックがほぼなく（テンプレ・レビュー体制・OpenSpec 連携・ハンドオフが全て異なる）、分岐構造が双方の regression リスクと最適化の足かせになっている
- 代替案 2: `longrun-mvp-planner` — 却下。`-er` 終わりは Agent 命名であり、過去に `longrun-planner` 命名で Agent 誤起動事故が起きた経緯がある

### D2: 旧フラグは移行案内 + 終了（暗黙リダイレクトしない）

- 採用: `--mode=mvp` 検出時は「`/longrun:mvp` に移動した」案内を出力して終了。plan.md は生成しない
- 代替案 1: サイレント無視してフルモード続行 — 却下。ユーザーが軽量フローを期待しているのに重いフルフロー（OpenSpec 照合・Build Contract 前提の plan）が走るのは最悪の体験
- 代替案 2: 新スキルへ暗黙リダイレクト — 却下。Skill から別 Skill への自動委譲は起動プロトコルを複雑化し、廃止の周知も進まない。案内を出して明示的に再実行してもらう方が単純で確実

### D3: agent 3 種とテンプレはファイル移動しない（帰属の記述更新のみ）

- 採用: `plugins/longrun/agents/` と `plugins/longrun/templates/` の現在のパスを維持し、plugin.json の agents[] 参照も不変。各ファイル内の「`/longrun:plan --mode=mvp` から呼ばれる」という帰属記述を「`longrun-mvp-plan` スキル / `/longrun:mvp`」に更新する
- 理由: agents / templates はプラグインレベルの共有リソースであり、skill ディレクトリ配下への移動は plugin.json のパス変更・キャッシュ churn・archive 側のテンプレ参照に波及する。分離の目的（独立最適化）は帰属の明確化で達成でき、物理移動は不要
- 制約: agent の出力契約（レポートセクション・Search Audit・APPROVE/REQUEST_CHANGES 形式・検索回数上限）は一切変更しない

### D4: オーケストレーションは Agent 並列のまま（Workflow 化しない）

- 採用: 単一メッセージ内複数 tool_use の並列 Agent 起動パターンを新 SKILL.md にそのまま移設する
- 理由: plan.md のスコープ定義どおり、MVP フローの Workflow 化は exec の Workflow 化（change-2）パターンの安定を見てから次 run で判断する。分離によって独立判断が可能になったため、今回は強制しない

### D5: バージョンは longrun 6.1.0 / lr 6.1.0、各 3 箇所同期

- plugin.json / marketplace.json top-level / marketplace.json plugins[] の 3 箇所 × 2 プラグイン。過去に同期漏れ事故があるため受け入れ条件に明示（plan.md 受け入れ条件 19）
- `longrun-plan` と `longrun-mvp-plan` の SKILL.md frontmatter `version` も plugin.json と一致させる（既存 spec のバージョン同期要件を踏襲）

### D6: Gap Analysis / Interview 方法論は共有リファレンスに切り出す（option (a)）— 両スキルから Read、ただし longrun-plan の Step 3/4 本文は温存

- 採用: `plugins/longrun/references/plan-interview-methodology.md` を新設（Gap Analysis フォーマット + 発散リスク判定表 + Interview 質問設計原則 + 閾値を内包）。**新スキル `longrun-mvp-plan`** はこのリファレンスを Read 指示で参照して方法論を適用する。**既存 `longrun-plan` SKILL.md は一切変更しない**（Step 1〜8 本文を温存し、task 3.3 の「git diff で Step 1〜8 に差分なし」を厳格に満たす。MVP セクション削除とモード分岐の移行案内化のみ手を入れる）。
- spec 要件「Methodology source MUST be self-contained without runtime dependency on longrun-plan」の充足: 新スキルは references ファイルを Read するのみで、`skills/longrun-plan/SKILL.md` を実行時に Read しない（S25 を満たす）。
- option (a)/(b) ハイブリッドの根拠: spec は「両スキルが同一 reference を Read する」を理想とするが、`longrun-plan` の Step 3/4 を reference 参照に置換すると task 3.3 のフルモード regression ガード（Step 1〜8 本文 no-diff）と衝突する。よって reference は新設しつつ、`longrun-plan` 側の置換は本 change のスコープ外（フルモード本文不変が最優先）とする。reference 冒頭に「longrun-plan SKILL.md Step 3/4 と同期すること」の divergence 防止コメントを置き、将来 longrun-plan 側を reference 参照に寄せる余地を残す。
- 代替案 1: 新 SKILL.md にインライン複製 + divergence 防止コメント（option (b)） — 採用見送り。reference 切り出しの方が将来の single-source 化に繋がり、新スキル本文も短く保てる。
- 代替案 2: longrun-plan の Step 3/4 も reference 参照に置換（純 option (a)） — 却下。task 3.3 のフルモード本文 no-diff ガードに反する。本 change は「移動と分離のみ・フルモード挙動不変」が config 制約。

## Risks / Trade-offs

- [フルモード regression] モード分岐ブロックの書き換え時に Step 1〜8 本文へ意図しない差分が入る → Mitigation: 書き換え範囲を frontmatter 直後の分岐ブロックと末尾 MVP セクションの削除に限定し、`git diff` で Step 1〜8 本文に差分がないことを確認する
- [方法論の divergence] Gap Analysis / Interview の記述が 2 スキルに分かれ、片方だけ更新される → Mitigation: 共通参照ドキュメント化（または複製時の divergence 防止コメント必須）。plan-template-mvp.md で実績のある相互参照コメント方式を踏襲する
- [プラグインキャッシュ] バージョン bump 漏れで他プロジェクトに旧 SKILL.md（モード分岐あり）が残る → Mitigation: 3 箇所 × 2 プラグインの同期を受け入れ条件・タスクの両方に明記
- [旧フラグ利用の習慣] ユーザーが `--mode=mvp` を打ち続ける → Mitigation: 移行案内に新コマンドをコピペ可能な形で含める。README にも deprecation を明記
- [残存参照] README / commands / agents / テンプレに `--mode=mvp` 表記が残る → Mitigation: 完了時に `grep -rn -- "--mode=mvp" plugins/` で 0 件（移行案内・deprecation 記述内の意図的言及を除く）を確認するタスクを置く

## Migration Plan

1. change-2（longrun/lr v6.0.0）の PR マージ後、新しい worktree（`--with-pr`、Draft PR バックアップ）で着手
2. 新スキル・新コマンドの追加 → 旧モード分岐の移行案内化 → 帰属・ドキュメント更新 → バージョン同期 の順で実装（途中段階でも plugin として壊れない順序）
3. ロールバック: 単一 PR のため PR クローズ（または revert）で v6.0.0 状態に戻る。成果物形式（マーカー付き plan.md）は不変のため、生成済み plan.md への影響はない
4. ユーザー移行: `--mode=mvp` → `/longrun:mvp`（`/lr:m`）。旧フラグは案内を出すのみで動作しない

## Open Questions

- **Gap Analysis / Interview 方法論の切り出し vs 複製**（実装時判断）: 共有プローズが十分小さい（目安: 数十行）なら新 SKILL.md への複製 + divergence 防止コメントで足りる。切り出す場合の置き場所は `plugins/longrun/references/`（または `skills/*/references/`）配下とし、両 SKILL.md から Read 指示で参照する。spec はどちらの実装も許容する形（「Methodology source MUST be self-contained」要件）で固定済み
- 移行案内の文言詳細（コマンド例の提示形式）は実装時に確定する。spec 上の要件は「`/longrun:mvp` と `/lr:m` を名指しする」「Step 1〜8 を実行しない」「plan.md を生成しない」のみ
