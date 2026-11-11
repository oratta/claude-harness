# rm-cd-and-success-base — `cd <一時領域> && rm <相対>` は cd が成功した場合の基準だけで判定する

## Why

子の rm の確認画面に親の許可で答える hook（要件「rm の一時領域の判定」）は、`cd` を含むコマンドの削除先を、`cd` が成功した場合の基準と、`cd` が失敗して `rm` が元の作業ディレクトリで走る場合の基準の両方で一時領域の中に収まることを求めている。区切りが `&&` のときも同じに見るため、作業ディレクトリが一時領域の外（普通はワークツリー）の子が `cd <一時領域> && rm -f x/*` で後始末すると、失敗側の基準で削除先がワークツリーの中になり、親は許可を書けず毎回オーナーに上がる（#1134 の実機確認で判明。issue #1159）。`&&` でつないだ形は `cd` が失敗すると `rm` が走らないので、失敗側の基準で見る必要はない。

## What Changes

- rm 用の判定で、`cd` を含み、単純コマンドの区切りが `&&` だけ（`;` も改行も無い）のときは、`cd` の移り先を基準にした解決だけで削除先を判定する
- 区切りに `;` か改行が 1 つでも混じるとき（`cd d && rm a; rm b` を含む）は、今までどおり `cd` の移り先と `cwd` の両方の基準で判定する
- `||`・パイプ・`&` 単独は今までどおり判定を満たさない（使える文字と区切りの規則は変えない）
- hook（`rm-permission-guard.sh`）と許可を書くスクリプトは同じ判定を使うので、両方の振る舞いが同時に変わる。判定の外の答え方・許可の形・拒否の記録は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `rm-permission-hook`: 要件「rm の一時領域の判定」の `cd` がある場合の基準の規則と守備範囲を直し、`&&` だけの形のシナリオを足す

## Impact

- コード: `plugins/dev-workflow/scripts/git-guard-scratchpad.py` の `check_rm`（hook と許可を書くスクリプトが共に読む判定）
- テスト: `plugins/dev-workflow/tests/rm-permission-guard.bats`
- 変更の記録: `plugins/dev-workflow/changes/1159.md`
- hook は聖域なので、マージには主の承認が要る。`git-destructive-guard.sh`・`rm-permission-guard.sh` は触らない（兄弟の子 #1166・#1173 と重ならない）
