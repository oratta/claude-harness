# tasks — 観点相談・仲裁プロトコル（#127）

## 1. テスト先行（Red）

- [x] 1.1 `plugins/casting/tests/casting-consultation.bats` を新設し、4受け入れ条件（policy テンプレの人格ブロック形式／specialist・arbiter 定義と入力契約／SKILL.md の事後報告フォーマット・終端条件と実例判例／主の観点が絡む論点は主へ行く分岐の明記）を検査するテストを書き、Red を確認する

## 2. 実装（Green）

- [x] 2.1 `plugins/casting/templates/policy.md` を新設する（front matter: perspective・catalog_version、## 人格（名前・スタンス・口調）、## 判断基準、入れ物であって代替ではない旨、命名権の記入ガイド）
- [x] 2.2 `plugins/casting/agents/casting-specialist.md` を新設する（model: sonnet、tools 読み取り専用、policy Read・人格着用・過去判例参照・人格名帰属）
- [x] 2.3 `plugins/casting/agents/casting-arbiter.md` を新設する（model: fable、入力はフェーズ宣言文＋双方の主張のみ、非共有・入力以外を読まない明記、人格名帰属の裁定）
- [x] 2.4 `plugins/casting/.claude-plugin/plugin.json` に agents を登録し、version を 0.3.0 に上げ、description に agents を反映する
- [x] 2.5 `rules/perspective-casting.md` の手順④⑤を差し替える（30行以内を維持。相談・仲裁分岐、主の観点があれば主へ、人格名帰属、SKILL.md へのポインタ）
- [x] 2.6 casting SKILL.md に「論点相談・仲裁」節を追記する（発火点・分岐・事後報告フォーマット5要素・再相談しない終端条件・非共有の呼び出し規約。version を 0.3.0 に）
- [x] 2.7 `plugins/casting/templates/precedents.md` の経路語彙に「相談の上自走した」を追加する
- [x] 2.8 `.claude/casting/precedents.md` に事後報告フォーマット準拠の実例判例を1件追記する

## 3. 検証・整合

- [x] 3.1 `scripts/test.sh casting` を実行し全件 Green を確認する（exit code を記録）
- [x] 3.2 `scripts/test.sh` 全件を実行し既存スイートを壊していないことを確認する（exit code を記録）
- [x] 3.3 意味のある単位で git commit を積む（push はしない）

## 4. Codex アドバーサリアルレビュー対応（2026-08-19、PR #129 High 3件）

- [x] 4.1 相談を「担い手がエージェントの観点すべて」への並行起動に拡張し、仲裁の入力契約を主張リスト（メインセッション1件＋各人格1件ずつ、人格名付き）に拡張する（SKILL.md・casting-arbiter.md・injection.md・specs・bats）
- [x] 4.2 「判断基準の範囲外」・policy 不在・読み取り不能を主へ上げる fail-closed の第3分岐を rules 手順④・SKILL.md・casting-specialist.md に明記する（specs・bats 追随）
- [x] 4.3 仲裁のツール境界を防御層で補強する — bats で `tools: Read` のみを検査、定義文面に「参照を開くことは入力契約違反＝裁定拒否」の自己監視、呼び出し規約で入力からパス・URL を排除、design.md に限界を明記
