# Design: openspec-degradation

## Context

longrun（v5.2.0）の自律実行は OpenSpec を仕様管理の中核に置いている:

- **orchestrator Setup フェーズ**（`plugins/longrun/skills/longrun-orchestrator/SKILL.md` L90-）: ツール検証で `which openspec` / `npx openspec --version` / `~/.volta/bin/openspec` を多段で試し、全滅したら `npm install -g openspec` を試行。それでも失敗すると「checkpoint.md に記録してユーザーに報告」で行き止まり（エラーハンドリング表 L575）。縮退して進む正規の道がない
- **spec 類の生成**: `openspec new change` → `specs/<capability>/spec.md` → `openspec apply`（カスタムスキーマ longrun-tdd が TDD を強制）→ verification-guide.md は change の spec から抽出生成
- **feedback Tier 3**（`plugins/longrun/skills/longrun-feedback/SKILL.md`）: 記録先が `openspec/backlog.md` 固定
- **exec.md**: 現状 Step 1-3 のみで前提条件チェックは orchestrator の Setup 内に埋まっている

さらに環境ギャップが 2 つある:

1. **カスタムスキーマの出所が未確定**: `openspec/schemas/longrun-tdd/` が `openspec init --tools claude` で入るのか、claude-harness 固有の fork（`openspec schema fork spec-driven longrun-tdd` + テンプレートコピー、SKILL.md L131-134）でしか生まれないのかが文書化されていない
2. **バージョン乖離**: この環境では openspec が volta グローバル **1.2.0** と npx ローカル（リポジトリ `node_modules`）**0.23.0** の 2 系統あり、どちらを正とするか未確定。検出コマンド系列（`which` 優先か `npx` 優先か）の意味が系統によって変わる

制約: 既存の openspec/ あり repo の従来挙動は一切変えない（回帰なし）。実機検証はコマンド出力のエビデンス付きで docs に記録する。change-2 が exec を全面書き換えするため、本 change の成果は「Step 0 の縮退分岐」という spec として固定し change-2 が引き継ぐ。

## Goals / Non-Goals

**Goals:**

- OpenSpec CLI 不可環境（解決不可 / 未 init）とユーザー明示の opt-out に対して、縮退モードを一級の動作モードとして提供する
- exec Step 0 に前提条件チェック（`npx openspec` 解決可能 + init 済み）を昇格し、失敗時 AskUserQuestion で縮退提案する
- 縮退時の spec 類を `_longruns/<run>/` 内に自己完結生成し、Feedback Tier 3 は `_longruns/<run>/backlog.md` にフォールバックする
- 素の repo での `openspec init --tools claude` → `apply` 実機検証と、バージョン乖離（1.2.0 vs 0.23.0）の正系統確定
- `plugins/longrun/tests/` の bats 新設（コマンド不在シミュレートで縮退分岐を検証）

**Non-Goals:**

- `/longrun:status` への縮退分岐（change-2 で status 自体が廃止される）
- 縮退 run の OpenSpec ありへの「昇格」変換（利用実績を見てから。backlog 残置）
- exec の Workflow 化・orchestrator 解体（change-2 のスコープ）
- 既存 agent 定義の変更

## Decisions

### Decision: 縮退判定はマーカーファイル `_longruns/<run>/.degraded-mode` で永続化する

- **選択肢**: A: checkpoint.md に縮退フラグを散文記録 / B: plan.md にマーカーコメント / C: 専用マーカーファイル
- **決定**: C（`_longruns/<run>/.degraded-mode`）
- **理由**: checkpoint.md は change-2 で「人間向け監査ログ」に格下げされ機械可読パースが廃止されるため、散文パース依存（A）は run 途中の本 plan の方針と矛盾する。B は plan.md がユーザー編集物であり生成タイミングも exec より前。ファイル存在チェックは bash 1 行で判定でき bats でテストしやすく、feedback skill（別エントリポイント `/lr:f` から呼ばれる）も run ディレクトリだけ見れば判定できる。MVP モードの `<!-- mvp-mode -->` マーカーと思想は同じだが、exec 時点で確定する動作モードなので run ディレクトリ側に置く

### Decision: 前提条件チェックと縮退判定ロジックを bash スクリプトに切り出す

- **選択肢**: A: exec.md / SKILL.md の散文手順のまま / B: `plugins/longrun/scripts/openspec-preflight.sh` に切り出し
- **決定**: B
- **理由**: markdown skill 内の分岐は bats でテストできない。スクリプトに切り出せば「コマンド不在シミュレート（PATH 操作 / stub）で縮退分岐を検証」という受け入れ条件 5 を bats で機械的に担保できる。スクリプトは判定（exit code + 標準出力で `OK` / `NO_CLI` / `NO_INIT` を返す）のみを担い、AskUserQuestion による対話は exec.md 側に残す（スクリプトから対話はできないため）

### Decision: 検出基準は「`npx openspec` 解決可能」を正とする（暫定。タスク 1.1 で確定）

- **選択肢**: A: `which openspec`（グローバル優先） / B: `npx openspec`（ローカル優先） / C: 多段フォールバック現状維持
- **決定**: B を暫定の正とし、タスク 1.1 の実機検証（init / apply / schema fork / validate が期待どおり動く系統はどちらか）で最終確定する
- **理由**: plan.md の受け入れ条件 5 が「`npx openspec` が解決できない環境で」と明示しており、リポジトリローカルの node_modules でバージョンを固定できる方が repo 間の再現性が高い。volta グローバル 1.2.0 と npx ローカル 0.23.0 は major が異なり CLI 仕様差のリスクがあるため、現状の多段フォールバック（C）は「どのバージョンで動いているか不定」という不確実性の温床であり廃止する。検出系列はスクリプト 1 箇所に集約し、実機検証で結論が変わっても差し替えが 1 箇所で済む構造にする。**最終確定値（正系統・検出コマンド系列・導入案内）は本ドキュメントには書かず、`plugins/longrun/docs/openspec-cli-verification.md` を参照すること**（タスク 1.1 / 1.2 で記録）

### Decision: 縮退 artifacts は `_longruns/<run>/specs/<change-name>/` に openspec/changes 配下とほぼ同じレイアウトで置く

- **選択肢**: A: `_longruns/<run>/degraded/` 等の専用名 / B: `_longruns/<run>/specs/<change-name>/{proposal.md,tasks.md}` のミラーレイアウト / C: 単一ファイル `_longruns/<run>/spec.md` に統合
- **決定**: B
- **理由**: orchestrator / builder / feedback の既存ロジックは「change 名でディレクトリを引き、proposal.md で capability スコープを、tasks.md のチェックボックスで進捗を読む」ことを前提にしている。レイアウトをミラーすれば縮退分岐は「ベースパスの差し替え」に局所化でき、将来の「昇格」変換（Non-Goal だが backlog 残置）もディレクトリ移動で済む。C は複数 change の run で破綻する

### Decision: 縮退 run の Archive はランディレクトリのみアーカイブ（MVP モードの既存分岐を踏襲）

- **選択肢**: A: openspec change 相当の擬似 archive を `_longruns/` 内に再現 / B: ランディレクトリのみアーカイブ
- **決定**: B
- **理由**: archive skill には既に MVP モード（`<!-- mvp-mode -->`）で「OpenSpec change 生成をスキップしてディレクトリのみアーカイブ」する分岐が存在する。縮退 run の spec 類は `_longruns/<run>/specs/` に内包されているため、ランディレクトリごとアーカイブすれば spec も一緒に保全される。判定は `.degraded-mode` マーカーで行う
- **注意（判定ソースの不一致）**: 既存 MVP 分岐（`plugins/longrun/commands/archive.md` L15-19）の判定ソースは **plan.md 先頭の `<!-- mvp-mode -->` マーカー**であり、縮退分岐の判定ソース（run ディレクトリの `.degraded-mode` ファイル）とは**別物**。archive.md には両分岐を併記し、判定順は `.degraded-mode` → `<!-- mvp-mode -->` とする（動作はいずれも「ディレクトリのみアーカイブ」で同一だが、判定根拠の表示を分ける）。`plugins/longrun/commands/archive.md` は本 change の編集対象ファイルである（タスク 3.3）

### Decision: status コマンドには触らない

- **選択肢**: A: status にも縮退分岐を追加 / B: 触らない
- **決定**: B
- **理由**: plan.md で明示（change-2 で `/longrun:status` `/lr:s` 自体が廃止される）。捨てるコードへの投資はしない。縮退 run 中に status を叩いた場合の表示劣化は許容（5.3.0 の既知の制限として README に記載）

## Risks / Trade-offs

- [Risk] openspec のバージョン乖離（1.2.0 / 0.23.0）により init / apply / schema fork の挙動が SKILL.md の記述と異なる → タスク 1.1 を最初に実行し、実コマンド出力のエビデンス付きで正系統と挙動を docs に固定。以降の実装はその記録を一次ソースとする（推測で書かない）
- [Risk] 縮退分岐の追加が既存 openspec あり repo の挙動を変えてしまう（回帰） → 通常モードのパスでは preflight が `OK` を返した後の処理を従来コードパスと完全に同一に保つ。回帰観点の bats（preflight OK 時に縮退マーカーが作られない・openspec フローが選ばれる）を追加
- [Risk] change-2 の exec 全面書き換えで Step 0 分岐が移植漏れする → 本 change の spec（longrun-openspec-preflight）が要求として残るため、change-2 の検証で grep / bats が落ちる構造にする。preflight ロジックをスクリプト外出しにしたことで移植対象が「スクリプト呼び出し 1 箇所」に縮む
- [Risk] markdown skill の対話分岐（AskUserQuestion）は bats で検証できない → 機械検証はスクリプトの判定値まで、対話部分は plan.md の「動作確認方法」手順 4（PATH から外して `/lr:e` → 縮退提案）の手動確認に委ねる、と責務を明示
- [明確化] 「縮退 run は Archive まで完走できる」Requirement の全フェーズ E2E は bats では検証しない: 全フェーズ完走の確認は plan.md「動作確認方法」手順 4 のユーザー手動確認に委ね、bats は archive 縮退分岐の単体検証（`.degraded-mode` マーカー判定 → ランディレクトリのみ移動・`openspec/changes/archive/` への移動が発生しないこと）に限定する
- [Trade-off] 縮退 run では `openspec validate` による構造検証が効かない → tasks 相当のチェックボックス形式と spec 相当の WHEN/THEN 形式はテンプレートで担保し、形式逸脱は Verify フェーズのレビューで補完する（縮退モードの本質的な劣化として受容）

## Migration Plan

追加的変更のためマイグレーション不要。

1. longrun 5.2.0 → 5.3.0 へ bump（plugin.json / marketplace.json top-level / marketplace.json plugins[] の 3 箇所同期）
2. 既存の openspec/ あり repo: 何もしなくて良い（従来挙動を維持）
3. 既存の進行中 run: `.degraded-mode` マーカーが無いため全て通常モードとして扱われる（安全側）
4. ロールバック: 5.2.0 に戻すだけ。縮退 run の成果物は `_longruns/<run>/` 内に自己完結しており repo を汚さない

## Open Questions

- カスタムスキーマ longrun-tdd は `openspec init --tools claude` で入るのか、fork + テンプレートコピーが常に必要か → **タスク 1.1 の実機検証で確定**（本 change 内で解消する前提の question）
- 正系統を npx ローカル（0.23.0）とした場合、openspec 未インストール repo への導入案内は `npm i -D openspec` とすべきか → タスク 1.1 の結果と合わせて docs に記載
- 縮退 run の「昇格」変換（`_longruns/<run>/specs/` → `openspec/changes/`）の需要 → スコープ外。利用実績を見て backlog から判断
