# Design: promote-pr-review-gate-to-dev-workflow

## Context

flatmate の pr-review-gate スキル（212 行）は「主駆動型開発の品質ゲート」として初回バッチ（2026-08-03、10 PR）で検出力を実証済み。auto-merge workflow（368 行）・revert-pr workflow（152 行）・攻撃再現テスト（482 行）とセットで動く。スキルは LLM が読む手順書、workflow は決定論的な機械判定、テストはその不変条件の固定という三層構造。

flatmate 固有の要素が両者に混在している:

- スキル側: `memory/pending-owner.md` + `scripts/pending-mirror.sh`（保留の主向けミラー）、`openspec/specs/channel-reply-policy/spec.md`（投稿規約）、`docs/agent-loop-steps.md`（レビュー姿勢の参照先）、auto-merge を「#226」と issue 番号で参照
- workflow 側: 聖域パス正規表現（`docs/agent-loop*` / `docs/burn-mode` は flatmate の憲法 doc）、`REQUIRED_CHECKS`（flatmate の ci.yml のジョブ名）、docs/auto-merge.md 内の flatmate URL 直書き

flatmate issue #240 に収束ルール（真正性確認・2周キャップ・差分限定再レビュー・blocking 限定・可読性・減量）が積まれており未反映。正本がプラグインへ移るため、反映先は移植版になる。

## Goals / Non-Goals

**Goals:**

- プラグイン導入済みの任意のリポで、PR 作成後に pr-review-gate が発火し flatmate と同一の手順を提供する
- auto-merge 一式を「差し替え箇所が明示されたテンプレート」として配布し、リポ展開を README の手順だけで完結させる
- issue #240 の収束ルールを移植版スキルに織り込み、レビュー周回コストを既定2周に抑える
- flatmate の既存運用を壊さない（スキル名・ラベル名・手順の骨格・fail-closed の原則は同一）

**Non-Goals:**

- flatmate リポ側のポインタ化（別リポの follow-up。本 change のマージ後）
- auto-merge workflow をこのリポ（claude-harness）自身に配備すること（テンプレート配布のみ。配備は各リポの判断）
- レビューゲートの手順自体の再設計（#240 で合意済みの範囲を超える変更はしない）

## Decisions

### D1: スキルの flatmate 固有参照は「あれば従う・無ければ縮退」の条件分岐にする

パラメータ化（プレースホルダ）ではなく、実行時の存在確認による条件分岐にする。スキルは LLM が読む手順書なので、「`scripts/pending-mirror.sh` がリポにあればそれを実行、無ければ needs-approval ラベルと PR コメントのみ」という自然言語の分岐がそのまま機能する。プレースホルダ方式（`{{PENDING_MIRROR}}`）はリポごとの生成ステップが必要になり、スキル配布（プラグイン読み込み）の単純さを失うため不採用。

### D2: workflow はテンプレート（要差し替え）として `templates/auto-merge/` に置く

workflow は GitHub Actions が実行する決定論的な機械判定であり、スキルと違って「実行時に環境を見て縮退」ができない。聖域パス・必須チェック名はリポごとに必ず違うため、`# >>> sacred-paths` / `# >>> required-checks` の既存マーカーをそのまま「差し替え箇所」の印として使い、README に展開手順（差し替え3点: 聖域定義・REQUIRED_CHECKS・AUTOMERGE_PAT 登録）を書く。flatmate 固有の聖域（`docs/agent-loop*` 等)はテンプレート初期値として残す — 例として具体的で、消し方も README に書けるため。

docs/auto-merge.md 相当の運用ガイドは、flatmate URL 直書き部分を `<owner>/<repo>` プレースホルダに置換して templates/ に含める（各リポの docs/ へコピーして使う）。

### D3: 攻撃再現テストもテンプレートに含め、このリポの CI では「テンプレート整合性」だけを bats で検証する

`test-auto-merge-workflow.sh` は展開先リポの CI で回すもの（`$ROOT/.github/workflows/` を見る）なので、このリポの CI で直接実行はできない。代わりに bats テストで次を固定する:

- テンプレート yml にマーカー（sacred-paths / required-checks / labeled-target / pre-merge-recheck / automerge-script / revert-script）が揃っている
- 安全不変条件: 素の `pull_request` トリガーが無い・`actions/checkout` が auto-merge.yml に無い・`gh pr merge` を使っていない・sha ピンがある（テンプレート改変の退行検知）
- テスト sh がテンプレート同梱の yml に対して pass する（ROOT を上書きして実行できる構造なら実行、不可なら構文チェックのみ）
- スキル: frontmatter・6手順の見出し・#240 の収束ルール（2周キャップ・真正性確認）の存在・flatmate 固有文字列（`genetta-inc/flatmate` / `pending-mirror.sh` の無条件参照）の不在

テスト sh は `ROOT` の導出を「引数で上書き可能」に1行だけ改修し、テンプレート dir を仮リポに見立てて self-test できるようにする（ci.yml が無い分のチェックはスキップされる設計を確認した上で）。

### D4: 収束ルールは手順2（レビュー）と手順5（合格処理）に織り込み、独立節を立てない

#240 の 6 項目は既存手順の修正として入れる: 2周キャップ・差分限定・blocking 限定は手順2の末尾（レビュー判定の規定）、真正性確認は手順5の合格条件（許容リンク経由の場合の確認手順）、並行動作確認の明示は手順6、減量は冒頭「前提」節への理由集約。手順番号・ラベル名は flatmate 版と同一に保つ（受け入れ条件「手順が同一」の解釈は「手順の骨格・番号・ラベル・fail-closed 原則が同一」であり、#240 織り込みによる規定の追加は issue #82 自身が指定している）。

### D5: version は 1.6.2 → 1.7.0（minor bump）

スキル追加は後方互換の機能追加。plugin.json の description にも pr-review-gate の一文を足す（プラグイン選択時の発火判定材料になるため）。

## Risks / Trade-offs

- [テンプレート初期値の聖域パスが展開先リポと合わない] → README の展開手順の先頭に「差し替え必須3点」を置き、テスト sh が展開先 CI で REQUIRED_CHECKS と ci.yml ジョブ名の一致を機械検証する（ズレは fail-closed 側に倒れ、マージされない停滞として顕在化する）
- [スキルが発火しても auto-merge 未配備のリポでは「passed を付けて終わり」になる] → スキル冒頭に「auto-merge 未配備リポでは passed 付与後のマージは人間操作」と明記（縮退動作を仕様化）
- [flatmate 版とプラグイン版の二重管理期間が生まれる] → flatmate 側ポインタ化を follow-up として issue #82 に明記済み。プラグイン版マージ後すみやかに実施
- [#240 織り込みで flatmate 初回運用時と挙動が変わる] → 変更は「コストを絞る方向」（周回キャップ・blocking 限定）のみで、fail-closed の安全側判定は一切緩めていない
- [`.sh` テンプレートが CI の shellcheck 対象になる] → flatmate で shellcheck 通過済みの実物を移すため新規指摘は想定しない。出たら修正して取り込む

## Migration Plan

1. このリポ: スキル + テンプレート + テスト + version bump を 1 PR（#83）で入れる
2. 各リポへの展開: `/plugin install dev-workflow@oratta-claude-harness`（スキルは自動で効く）。auto-merge が欲しいリポは templates/auto-merge/README.md の手順で workflow を配置
3. flatmate: `.claude/skills/pr-review-gate/SKILL.md` をプラグイン版へのポインタに置換する PR（follow-up）。flatmate issue #240 はそこで close
4. ロールバック: プラグイン版スキルの削除（revert PR）で従前の状態に戻る。flatmate はポインタ化まで従来スキルが生きているため影響なし

## Open Questions

（なし — 実装判断はすべて上の Decisions で確定）
