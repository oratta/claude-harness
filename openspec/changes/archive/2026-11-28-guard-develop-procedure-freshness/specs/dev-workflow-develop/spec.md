## ADDED Requirements

### Requirement: 記録先確定直後に実際に読んだ手順書の版を検査する
SKILL.md の「入口 0」と「1 ループ」は、記録先確定直後・仕様化判断と編集前に `develop-procedure-freshness.py check` を必須検査として規定しなければならない（MUST）。issue がある経路と軽い通し方は本体、W が Draft PR を作る経路は W が作成直後に実行し、`references/roles/worker/spec.md` にも置く（MUST）。読込元は実際に読んだ SKILL.md の場所から解決した plugin root を明示し、W にもその値を引き継がせる（MUST）。詳細契約は `references/procedure-freshness.md` とし、追加の return 工程や工程ごとの再検査を設けてはならない（MUST NOT）。

#### Scenario: issue が既にある
- **WHEN** 本体が issue を記録先として確定する
- **THEN** その直後、W の仕様化判断や対象の編集より前に、実際の読込元 root と issue URL を渡して検査し、古い版なら develop を止める

#### Scenario: W が記録先の Draft PR を作る
- **WHEN** 記録先が無いため W が Draft PR を作成する
- **THEN** W は本体から引き継いだ読込元 root と作成した PR の URL で直後に検査し、通過後に仕様化判断へ進む

#### Scenario: 軽い通し方を選んだ
- **WHEN** 本体が軽い通し方の記録先を確定する
- **THEN** 本体が仕様化判断の記録や編集より先に同じ検査を行い、取得不能・判定不能なら記録して続行し、投稿失敗なら本文を保持して次の記録機会に代理投稿する

### Requirement: 導入前キャッシュの保証限界を明記する
詳細 reference と変更記録は、guard も呼出規定も持たない導入前キャッシュを本変更だけでは強制検査できないことを明記しなければならない（MUST）。この保証を補う同期機構・hook・provider 別入口を本変更に追加してはならない（MUST NOT）。

#### Scenario: 古いキャッシュに guard が存在しない
- **WHEN** 導入前キャッシュに guard と呼出規定のどちらも無い
- **THEN** 強制実行の保証対象外であると文書から分かり、同期機構の追加を今回の完了条件にしない
