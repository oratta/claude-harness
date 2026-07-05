# Design: skill-verification

## Context

本 change は run「anthropic-knowledge-reflect」の change-2 であり、公式記事「Getting started with loops」のターンベースループ最適化（スキルへの自己検証ステップ組み込み）をこのリポジトリの主要スキルに適用する。

- 一次ソース: `_longruns/2026-07-04_anthropic-knowledge-reflect/research/loop-engineering.md` 冒頭の公式記事セクション（最上位）、`research/anthropic-agent-knowledge.md` ソース9（「『成功した』と主張させず evidence を提示させる」）
- 依存: **change-1（loops-plugin）**。共通原則リファレンスの置き場所 `plugins/loops/references/` は change-1 が新設する `plugins/loops/` 配下にある
- 現状の対象スキル実態: `plugins/*/skills/*/SKILL.md` は 10 件。受け入れ条件 8 の最低 7 スキルのうち wt-clean は**既に 506 行**あり、500 行ルール（config.yaml rule「追加によって SKILL.md が 500 行を超える場合は references へ分離する」）の適用対象になる
- 用語の解決: 受け入れ条件 8 / plan 本文の「**e2s-distill**」はスラッシュコマンド名（`/e2s:distill`）であり、スキル実体は `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`。本 change の棚卸し・検証節追加・テストはすべてこの実パスで参照する

## Goals / Non-Goals

**Goals:**

- 成果物を出す主要スキルの SKILL.md に、公式例の粒度（具体的なコマンド・確認対象・期待値）で自己検証ステップを明示する
- 検証の書き方の共通原則を `plugins/loops/references/self-verification.md` の 1 箇所に集約し、各スキルは 1 行参照 + スキル固有手順のみとする（重複コピーの構造的禁止）
- 棚卸しリスト（対象/対象外 + 理由）を機械検証可能な形で残す
- 全要件を bats + grep で検証可能にする（テスト先行）

**Non-Goals:**

- 既存スキルの機能・発火条件の変更（frontmatter・既存本文行は一切触らない。追加は検証節のみ）
- 定期実行の機構・配線、独自ループランタイム（plan スコープ外。本 change はターンベースの skill 文書整備のみ）
- plugin.json version bump と marketplace.json 同期（change-5: integration が一括実施。plan の責務分割に従う）
- 検証ステップの実行を強制するランタイム機構（検証は SKILL.md の指示としてエージェントが実行する。公式路線「ランタイムはネイティブ、ハーネスは規約」に従う）
- スキルの検証節を JSON Schema 等で機械強制すること（markdown 見出し規約 + grep 検証で足りる。MVP スコープ厳守）

## Decisions

### D1: 検証節の見出しリテラルを「## 自己検証」に固定する

- **選択肢**: (a) スキルごとに自然な見出し（「検証」「Verification」等）を許容 / (b) 「## 自己検証」の固定リテラル
- **決定**: (b)
- **理由**: 受け入れ条件 8 の検証（「SKILL.md に自己検証ステップ節がある」）を grep 1 発で機械検証可能にする。見出しが揺れると監査のたびに人間判断が要り、後続の recipe-miner（change-4）や将来の監査ループからも検出しにくい。固定見出しは「完了は主張であり証明ではない」を検証コマンドに落とすための最小規約

### D2: 共通原則は self-verification.md の 1 箇所のみ。スキル側は 1 行参照 + 固有手順

- **選択肢**: (a) 各 SKILL.md に原則文を含む完全な検証節をコピー / (b) 原則はリファレンス 1 箇所、スキル側は参照 1 行 + 固有手順のみ
- **決定**: (b)。原則文（「完了は主張であり証明ではない」）が SKILL.md 側に現れたら重複コピーとして検出する（grep で 0 件を検証）
- **理由**: 原則文のコピペは config.yaml rule「汎用文言のコピペ追加を禁止」に直接抵触し、原則を改訂したときに散在ドリフトが起きる（model-allocation の D3 と同根の問題）。参照 1 行 + 固有手順の構造なら、スキル側に残るのは「そのスキルの成果物に即した具体的な検証手段」だけになり、汎用文言の水増しを構造的に防げる

### D3: 棚卸しリストの置き場所は self-verification.md 内の「対象スキル一覧」節

- **選択肢**: (a) change ディレクトリ内のメモ / (b) 独立ファイル `plugins/loops/references/skill-audit.md` / (c) self-verification.md 内の 1 節
- **決定**: (c)
- **理由**: 棚卸しは「どのスキルが自己検証規約の適用対象か」の宣言であり、規約本体と同じファイルにあるのが最も発見しやすい。change ディレクトリ内メモは archive 後に配布物から消える。独立ファイルは 1 節で足りる内容にファイルを増やすだけ。将来スキルが増えたときの監査更新も 1 ファイルで完結する

### D4: e2s-distill はスキル実体の実パスで参照する

- **決定**: 受け入れ条件 8 / plan 本文の「e2s-distill」は、棚卸しリスト・SKILL.md 編集・bats テストのすべてで `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` として参照する（Build Contract レビューの NOTE を反映）
- **理由**: `plugins/experience-to-skill/` に `e2s-distill` という名前のスキルディレクトリは存在しない（コマンド名だけが `e2s-distill`）。コマンド名でパスを組み立てると存在しないファイルへの検証となり、テストが恒久的に FAIL するか、誤って新規ファイルを作ってしまう

### D5: 500 行超過時は references 分離 + SKILL.md 内の節は 15 行以内

- **選択肢**: (a) 500 行超過を一律禁止（既存 506 行の wt-clean は本文削減が必要になる） / (b) 超過する場合は検証詳細を同プラグイン references/ に分離し、SKILL.md 内の節は 15 行以内の要約 + 参照に留める
- **決定**: (b)
- **理由**: wt-clean は追加前から 506 行あり、(a) を採ると「既存本文の削除・変更をしない」という本 change の不変条件と矛盾する。(b) なら既存行に触れずに規約を満たせる。15 行という上限は「参照 1 行 + 固有検証の要点」が収まり、かつ SKILL.md の肥大化を防ぐ値として固定（grep/wc で機械検証可能）

### D6: bats テストは plugins/loops/tests/ に置く

- **選択肢**: (a) 各プラグインの tests/ に分散 / (b) `plugins/loops/tests/` に集約
- **決定**: (b)。`self-verification-reference.bats`（リファレンス内容の検証）と `skill-verification-sections.bats`（各スキルの節の検証）の 2 ファイル
- **理由**: 検証対象は「loops プラグインが定める自己検証規約への準拠」であり、規約のオーナーは loops。各プラグインに分散させると、規約変更のたびに 7+ プラグインのテストを揃って更新する必要が生じる。テスト実行コマンド（`find plugins -name '*.bats' -print0 | xargs -0 bats`）はリポジトリ全体を走査するため、置き場所によらず実行される

### D7: 検証手順の具体性は「検証コマンドまたは成果物パスを最低 1 つ」で機械検証し、意味的な妥当性は reviewer 判断とする

- **決定**: bats で機械検証するのは (1) 固定見出しの存在、(2) 参照 1 行の存在、(3) 節内に検証コマンド（バッククォート付きコマンド）または成果物パスが最低 1 つあること、(4) 節本文（参照行を除く）の完全一致ペアが 0 であること。検証手段がそのスキルの成果物に本当に即しているかは reviewer（inherit ティア）の妥当性判断に委ねる
- **理由**: 「具体的か」の完全な機械判定は不可能。完全一致検査で最悪のコピペだけを機械的に弾き、粒度の妥当性（公式例の粒度に達しているか）は plan のモデル割り当てどおり reviewer が担う

## Risks / Trade-offs

- [change-1 未完了の状態で本 change を開始すると `plugins/loops/` が存在しない] → plan の依存関係定義（change-2 は change-1 に依存）により実行順序で解決する。worktree は change-1 のマージ後に切る
- [「## 自己検証」節の追加が既存スキルの動作を変えてしまう] → 追加は末尾または論理的な完了ステップ直後への節挿入のみとし、frontmatter・既存本文行の削除・変更を git diff で 0 件と確認する。検証節はスキルの完了条件を厳しくする方向（evidence 提示）にしか働かない
- [完全一致検査では「わずかに語尾を変えたコピペ」を検出できない] → D7 のとおり意味的な汎用文言判定は reviewer の責務。加えて棚卸し（tasks 1.2）で各スキルの成果物 × 検証手段の対応表を先に作ることで、コピペの起きにくい執筆順序にする
- [500 行境界近くのスキル（daily-report 477 行等）が追加で 500 行を超える] → D5 の分離ルールがそのまま適用される。境界の判定は「追加後の wc -l」で機械的に行う
- [既存スキルに検証的な記述が既に部分的にある場合、節の追加と二重になる] → 棚卸しで「既存記述あり」と判定し、自己検証節からその既存記述に言及する（既存行は変更しない）。重複が節の完全一致検査に引っかかることはない（既存記述はスキル固有のため）

## Migration Plan

1. 棚卸し → bats テスト作成（RED）→ self-verification.md 作成 → 各スキルへの節追加 → 統合検証、の順で実装する（TDD 順。tasks.md 参照）
2. **後方互換**: 追加は検証節のみで、既存スキルの発火条件・手順・出力形式は不変。利用者側の移行作業は不要
3. **ロールバック**: 各 SKILL.md から「## 自己検証」節を削除し、`plugins/loops/references/self-verification.md` と分離 references・bats テストを削除すれば完全に旧状態へ戻る（既存行を変更していないため巻き戻し衝突がない）

## Open Questions

- 棚卸しの結果、最低 7 スキル以外に対象（成果物を出すのに検証明示が無いスキル）が見つかった場合の追加対象数は棚卸し（tasks 1.1）で確定する。仕様は「棚卸しリストに記録された対象スキルすべて」に適用される書き方とし、7 スキルは下限として固定する
