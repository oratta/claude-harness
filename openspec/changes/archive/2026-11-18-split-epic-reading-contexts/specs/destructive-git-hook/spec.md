# Spec Delta

## MODIFIED Requirements

### Requirement: 別セッションの子の停止検知の条件を案内する

`skills/develop/references/epic-loop.md` の手順 5 は、NO_ASK の印を起動側が付けた子は git ガードの確認画面で止まらず、拒否後に承認を求めてターンを終えた止まりを、会話ログが読めるとき `wait --watch-stopped` が検知することを案内しなければならない（MUST）。印の無い子の確認画面や会話ログを読めない子は検知できないという注意を維持しなければならない（MUST）。

#### Scenario: 手順 5 が検知できる止まりと検知できない止まりを区別する

- **WHEN** `epic-loop.md` の手順 5 を読む
- **THEN** NO_ASK の印の名前、拒否後に承認を求めてターンを終えた子は会話ログから検知されること、確認画面で止まった子とログを読めない子は検知できないことが書かれている
