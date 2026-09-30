# W（作業者）の指示書 — 索引

W の手順は `worker/` の下のファイルにある。この索引は本体・参照元・人間が段の割り当てと旧節の移し先を引くためのもので、手順の本文は持たない。W は、どの段でも `worker/common.md` と、起動指示の `段:` の行が指す段のファイルを読む（エージェント定義 `agents/worker.md`）。本体は W の起動指示・SendMessage による再開指示・手渡しの起動指示に `段:` の行を 1 行書く（場面ごとの値は develop の `SKILL.md`）。

## 段の表

| 段 | 日本語名 | 担う工程 | 読むファイル（`worker/common.md` に加えて） |
|---|---|---|---|
| `spec` | 仕様づくり | (1) 仕様化まで・R1 の `REQUEST_CHANGES` を受けた修正 | `worker/spec.md` |
| `implement` | 実装と検証 | (3a) 実装＋verify・G の `agent-review:failed` や CI の見張りの `fix` を受けた修正 | `worker/implement.md` |
| `finish` | 仕上げ | (3b) archive＋PR＋仕様宣言 | `worker/finish.md` |

## 旧節の移し先

| 旧 worker.md の節 | 移し先 |
|---|---|
| 冒頭（本体が渡すもの） | `worker/common.md` |
| W がしないこと | `worker/common.md` |
| 記録先の用意（Draft PR を記録先にする場合） | `worker/spec.md` |
| 仕様化判断（opsx / openspec の要否）と記録 | `worker/spec.md` |
| 分割判定 | `worker/spec.md` |
| 仕様化する場合（(1) の終わり）（R1 の APPROVE を確認してから実装に入る規則と仕様レビュー結果の書式を除く） | `worker/spec.md` |
| 仕様化判断の「記録する前に実装へ進まない」と、R1 の APPROVE を確認してから実装に入る規則・仕様レビュー結果の書式 | `worker/common.md`「実装に入る前の確認」 |
| (3a) 実装＋verify | `worker/implement.md` |
| (3b) archive＋PR＋仕様宣言 | `worker/finish.md` |
| 重要実装の事前分類 | `../pre-classification.md`（`skills/develop/references/pre-classification.md`） |
| 昇格トリップワイヤー | `worker/common.md` |
| コンテキスト上限と手渡し（「(3) をこれより細かく切らない」を除く） | `worker/common.md` |
| 「(3) をこれより細かく切らない」の箇条 | develop の `SKILL.md` の (3) |
