# 動作確認（手順 4）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。

## 入口

宣言後。許容待ちは hold。手順 5 に進むときだけ `stages/pass.md` を読む（保留か `needs-carryover-judge` を返すなら読まない）。

### 4. 動作確認

条件別に実行・観測を PR 投稿:

```
## 動作確認
対象 HEAD: <$HEAD_SHA 40桁フル>

| 受け入れ条件 | 実行した手順 | 結果 |
|---|---|---|
| <条件> | <再現可能な手順> | ✅ <観測した実際の出力/画面> |
```

「テストが通った」だけは証拠にならない。

テストの全体実行を手元で行わない。対象 HEAD の CI の結果（`gh pr checks $N --repo $R`・run URL）。成功として書かない対象=未決着・失敗。作業者が PR に載せた証拠は URL・コマンド・exit code を写す（自分の実行にしない）。
| 対象 HEAD の CI | 結果の欄 |
|---|---|
| 成功 | ✅ と run の URL |
| 結論がまだ無い（Draft 未実行も含む） | 状態・run URL。CI の見張りで確認、手順5可 |
| 既に失敗 | 失敗した run の URL、CI の見張りで修正。合格可 |

自力検証不能だけ主に依頼、手順6で保留:

```
## 動作確認: 主に依頼
1. 自力検証できなかった理由: <何が足りなかったか。「面倒」「時間」は理由にならない>
2. 主にやってほしい具体的手順: <URL・クリック順・期待される結果まで書く>
3. 次回から自力検証できるようにする改善提案: <テスト整備・認証情報の登録・seed データ等。issue 化するならリンク>
```

依頼は `~/.claude/output-styles/readable.md` 節3。3点目無しは不可。

## G として動くとき（develop）

### この段で起こされたときの入力

- 前の Gate Result が `段: 照合と振り分け`: `declarations.md` 手順3へ。前許容は宣言前に carryover 3-c
- `段: 保留の解除`: 現 HEAD の `対象 HEAD:`・`## リスク宣言` 有り→5の真正性確認、無し→ `declarations.md` の手順 3。HEAD 変更＋前許容は先に carryover 3-c
- **引き継ぎの判定のあと**（`段: 合格処理`・Status `needs-carryover-judge`）: `declarations.md` の手順 3 から入り直し、carryover 3-c の判定の記録（`引き継ぎ判定:`）。一致する記録が無ければ `needs-carryover-judge` を返し直さず手順6。
return: 保留は `stages/hold.md`、needs-carryover-judge は `stages/carryover-judge.md`。
