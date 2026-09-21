## ADDED Requirements

### Requirement: 本体は role profile から executor を選ぶ
名前付き role profile を使う develop 本体は、各委譲の直前に canonical role の executor/account/model/effort を共通 resolver から取得し、executor=claude なら Agent、executor=codex なら foreground request/run 経路を選ばなければならない（MUST）。executor の選択は transport と execution setting だけを変え、仕様化判断、工程順、独立レビュー、差戻し上限、verify、archive、PR gate の条件を変えてはならない（MUST NOT）。

#### Scenario: 1 つの profile で executor が工程間に変わる
- **WHEN** spec-write=codex、spec-review=claude の profile で仕様化工程を進める
- **THEN** W は Codex foreground 経路、R1 は Claude Agent 経路で別 thread として動き、R1 の APPROVE が記録されるまで実装へ進まない

#### Scenario: executor 切替でも canonical role を維持する
- **WHEN** 同じ role の executor を profile で Claude から Codex または Codex から Claude へ変える
- **THEN** role の指示書、read-only/write 権限、return 契約、記録先、次工程の判定は変わらず、provider 固有の起動操作だけが変わる
