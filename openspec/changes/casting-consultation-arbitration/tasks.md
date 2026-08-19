# tasks — 観点相談・仲裁プロトコル（#127）

## 1. テスト先行（Red）

- [ ] 1.1 `plugins/casting/tests/casting-consultation.bats` を新設し、4受け入れ条件（policy テンプレの人格ブロック形式／specialist・arbiter 定義と入力契約／SKILL.md の事後報告フォーマット・終端条件と実例判例／主の観点が絡む論点は主へ行く分岐の明記）を検査するテストを書き、Red を確認する

## 2. 実装（Green）

- [ ] 2.1 `plugins/casting/templates/policy.md` を新設する（front matter: perspective・catalog_version、## 人格（名前・スタンス・口調）、## 判断基準、入れ物であって代替ではない旨、命名権の記入ガイド）
- [ ] 2.2 `plugins/casting/agents/casting-specialist.md` を新設する（model: sonnet、tools 読み取り専用、policy Read・人格着用・過去判例参照・人格名帰属）
- [ ] 2.3 `plugins/casting/agents/casting-arbiter.md` を新設する（model: fable、入力はフェーズ宣言文＋双方の主張のみ、非共有・入力以外を読まない明記、人格名帰属の裁定）
- [ ] 2.4 `plugins/casting/.claude-plugin/plugin.json` に agents を登録し、version を 0.3.0 に上げ、description に agents を反映する
- [ ] 2.5 `rules/perspective-casting.md` の手順④⑤を差し替える（30行以内を維持。相談・仲裁分岐、主の観点があれば主へ、人格名帰属、SKILL.md へのポインタ）
- [ ] 2.6 casting SKILL.md に「論点相談・仲裁」節を追記する（発火点・分岐・事後報告フォーマット5要素・再相談しない終端条件・非共有の呼び出し規約。version を 0.3.0 に）
- [ ] 2.7 `plugins/casting/templates/precedents.md` の経路語彙に「相談の上自走した」を追加する
- [ ] 2.8 `.claude/casting/precedents.md` に事後報告フォーマット準拠の実例判例を1件追記する

## 3. 検証・整合

- [ ] 3.1 `scripts/test.sh casting` を実行し全件 Green を確認する（exit code を記録）
- [ ] 3.2 `scripts/test.sh` 全件を実行し既存スイートを壊していないことを確認する（exit code を記録）
- [ ] 3.3 意味のある単位で git commit を積む（push はしない）
