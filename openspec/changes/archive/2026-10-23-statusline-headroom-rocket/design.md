## Context

statusline はアカウント（スロット）ごとに 5h と 7d のバーを描き、右端に snapshot の `reset_grants`（Claude）または `.statusline-codex` の `resets`（Codex）からリセット権の残数と最短期限を出している（`statusline-multi-account-usage` の要件「Claude のアカウントの行にリセット権の残数と期限を表示する」「Codex リセット権の残数と期限を表示する」）。リセット権を使える量や期限に入れる計算は無い。

oratta/claude-harness#1300 が `plugins/dev-workflow/scripts/headroom.py` を置き、アカウントごとの余りの計算結果を `${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json`（schema 1）に書く。Claude はリセット権を使うと使用率が 0 に戻るが週次リセットの日時は動かないので、次の週次リセットより前に切れるリセット権 1 枚ごとに使える量へ 100% を足す。Codex はリセット権を使うと週次の窓そのものが新しくなるので量を足さず、週次リセットとリセット権の失効の早いほうを期限にする。

見せ方の正本は、2026-10-23 にオーナーが決めた 1 行案（Design 板「ステータスライン 1 行案」。同意の記録は genetta-inc/flatmate#1711）。採らなかった 2 行案は使わない。

制約:

- statusline は他プラグインのスクリプトを実行時に読まない（今の要件「active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く」と同じ方針）。`.headroom.json` はファイルとして読むだけで、headroom.py を呼ばない
- `.headroom.json` が無い・古い・使えないときは今の出力とバイト単位で同じにする（受け入れ条件）
- 描画は 1 回ごとに走るので、外部プロセスを増やさない

## Goals / Non-Goals

**Goals:**

- `.headroom.json` の書いた値で、ロケットモードのアカウントをひと目で分かるようにする（🚀・名前の地のオレンジ・右端の 🚀×N）
- Claude のロケットモードで、使える量（例 200%）に対する使った量と、そのペースの良し悪しをバーの色で示す
- Codex のロケットモードで、経過の線と残り時間をリセット権の失効に対して描く
- 1 アカウント表示で Codex の行が出るときのバーの位置のずれを直す

**Non-Goals:**

- 余り・使える量・期限の計算（#1300 の headroom.py の仕事）。statusline は数え直さない
- `.headroom.json` を書くこと、書く時機を変えること
- 5h の行と Fable のバーの見せ方を変えること（1 行案でも変えていない）
- 2 行案、行全体の地を塗る案、名前の文字だけをオレンジにする案（1 行案の板で推奨されなかった）

## Decisions

### D1. 仮に置いた JSON の形（#1300 の schema 1 の確定版に合わせる）

#1300 の作業ブランチにはこの change を書いた時点でコミットが無く、入れ物の形（アカウントの並びのキー名、`account` の値、時刻の書き方、`tickets` の中身）は確定していない。項目名は #1300 の本文を正とし、それで決まらない部分を次のとおり仮に置く。実装に入る前に #1300 の最初のコミットの書式と突き合わせ、食い違えば #1300 に合わせてこの design・spec・テストを直す（statusline 側から #1300 に形を求めない）。

```json
{
  "schema": 1,
  "computed_at": 1792765811,
  "best": {"provider": "claude", "account": "a"},
  "accounts": [
    {
      "provider": "claude",
      "account": "a",
      "label": "A",
      "status": "ok",
      "used_pct": 20,
      "elapsed_pct": 59,
      "weekly_reset_at": 1793013011,
      "rocket": {"count": 1, "earliest_expiry": 1792906211},
      "tickets": {"count": 3, "earliest_expiry": 1792906211},
      "capacity_pct": 200,
      "deadline_at": 1793013011,
      "deadline_reason": "weekly_reset"
    },
    {
      "provider": "codex",
      "account": "current",
      "status": "ok",
      "weekly_reset_at": 1793306824,
      "rocket": {"count": 3, "earliest_expiry": 1792924024},
      "tickets": {"count": 3, "earliest_expiry": 1792924024},
      "capacity_pct": 100,
      "deadline_at": 1792924024,
      "deadline_reason": "ticket_expiry"
    }
  ]
}
```

仮に置いた点:

| 項目 | 仮の形 | 理由 |
|---|---|---|
| アカウントの並び | トップレベルの `accounts`（配列） | #1300 の本文は「アカウントごとの項目」とだけ書く。usage snapshot の `accounts` に名前をそろえた |
| `provider` の値 | `"claude"` / `"codex"`（小文字） | #1300 の本文に値の一覧が無い |
| Claude の `account` | 登録簿のスロットの `id`（登録簿が無いときは `default`） | headroom は snapshot の `accounts.<id>` を入力にするので、同じ id になると見込んだ |
| Codex の `account` | `codex-develop.py` の `default_automatic_account_home()` が付ける名前 `current` | statusline の Codex の行は今の `CODEX_HOME` の 1 アカウントだけを描く。#1300 は Codex の使用量の読み出し（`read_codex_usages`）の名前をそのまま使うと見込んだ |
| 時刻（`computed_at`・`weekly_reset_at`・`earliest_expiry`） | epoch 秒の整数。ISO 8601（`Z` か `±HH:MM`）の文字列も読む | snapshot の時刻は epoch 秒。どちらで確定しても直さずに済むよう、`reset_grants` の `ends_at` と同じ読み方の文字列も受ける |
| `tickets` | `{count, earliest_expiry}`（`rocket` と同じ形）。リセット権が 0 枚なら null か `count: 0` | #1300 の本文は「リセット権の総数と最短の失効」とだけ書く |

statusline が読むのは `schema`・`computed_at`・`accounts[].provider`・`account`・`status`・`weekly_reset_at`・`rocket`・`tickets`・`capacity_pct` だけ。`used_pct`・`elapsed_pct`・`deadline_at`・`deadline_reason`・`forecast`・`surplus_pct`・`margin`・`best` は読まない（D3・D5）。読む項目を少なくして、#1300 の書式が変わったときに直す範囲を狭くする。

### D2. 使えるかどうかはアカウントごとに決め、使えなければそのアカウントだけ今の描き方に戻す

アカウントの行で `.headroom.json` の値を使うのは、次のすべてを満たすときだけ:

1. ファイルがあり、トップレベルがオブジェクトで、`schema` が数値の 1
2. `computed_at` が読め、`now - computed_at` が 21600 秒（6 時間）未満
3. そのアカウントに当たる要素（D1 の照合）がちょうど 1 つあり、`status` が `"ok"`
4. `weekly_reset_at` が読め、statusline がその行に描く週次のリセット時刻との差が 3600 秒以内（Claude は 7d のリセット時刻、Codex は週次の窓のリセット時刻。描く側にリセット時刻が無ければ満たさない）
5. `rocket` が null か、`count` が 1 以上の整数で `earliest_expiry` が読めて未来のオブジェクト
6. `tickets` が null か、`count` が 0 以上の整数のオブジェクトで、`earliest_expiry` は null・欠落か読めて未来の時刻
7. Claude で `rocket` が null でないときは `capacity_pct` が 100 より大きい数値

1 つでも外れたアカウントは、今の描き方（今の右端の区画を含む）で描く。数え直したり一部の項目だけ使ったりしない。

- 6 時間は今の Fable の鮮度の線（active スロットの `fetched_at` から 21600 秒）と同じ値。headroom は usage-probe が snapshot を書くたびに書き直されるので、6 時間書かれていなければ probe が止まっている
- 4 の照合は、`.headroom.json` を書いたあとに窓が変わった場合（Codex でリセット権を使って窓が新しくなった、週次リセットを過ぎた）に古い期限を描かないため。1 時間は usage-session-records の「同じ窓」の幅と同じ
- 5 と 6 で失効を過ぎた値を外すのは、期限を過ぎたのに 🚀 を出し続けないため。今の描き方に戻れば、今の区画が `期限経過（更新待ち）` を出す

採らなかった案: ファイル全体で 1 つでも外れたら全アカウントを今の描き方に戻す。Codex の取得だけが止まったときに Claude のロケットモードまで消えるので採らない。

### D3. 使った量は statusline の値、使える量とリセット権は `.headroom.json` の値

バーの使った量は今と同じ値（active は stdin のライブ値、非 active は snapshot とセッション記録から選んだ値、Codex は `.statusline-codex`）を使い、`.headroom.json` の `used_pct` は使わない。`.headroom.json` から取るのは使える量（`capacity_pct`）とリセット権（`rocket`・`tickets`）だけ。

理由: 使った量は数分で動くが、`.headroom.json` は probe の周期でしか書かれない。今の値を古い値に置き換えると、ロケットモードに入った瞬間に数字が戻って見える。使える量とリセット権は数分では動かない。

採らなかった案: `used_pct` も `.headroom.json` から取って 1 か所の数字だけで描く。数字が今の表示より古くなるので採らない。

### D4. Codex の経過と残り時間は statusline が失効に対して数える

Codex のロケットモードの経過の線は、週次の窓の始まり（`.statusline-codex` の週次のリセット時刻 − 窓の長さ）からリセット権の最短の失効（`rocket.earliest_expiry`）までに対する今の位置にする。残り時間は失効までの時間にする。どちらも statusline が描くたびに数える。

理由: 今の経過の線も statusline が描くたびにリセット時刻から数えている。`.headroom.json` の `elapsed_pct` を使うと線が probe の周期でしか動かない。これは表示のための割り算で、余りの計算（headroom の仕事）ではない。期限は `deadline_at` ではなく `rocket.earliest_expiry` を使う。ロケットモードの期限は定義上リセット権の最短の失効なので同じ値になり、読む項目を 1 つ減らせる。

採らなかった案: `elapsed_pct` と `deadline_at` を読む。線が止まって見えるのと、読む項目が増えるので採らない。

### D5. ロケットモードのための列は、使えるアカウントが 1 つでも描かれるときだけ空ける

バーの前の 🚀 の列（表示幅 4）と、7d のバーのうしろの「使った / 使える」の列（表示幅 9）は、ロケットモードの行にだけ出すと他の行とバーや数字の位置がずれる。そこで D2 で使えると決まったアカウントの行が 1 つでも描かれるときは、描かれるすべての行（Claude の 5h・7d、Codex の行）でこの 2 列を空ける。ロケットモードでない行では空白で埋める。使えるアカウントが 1 つも無ければ列を空けず、今の出力と同じにする。

1 行案の板は「割合と経過の組はロケットモードでなくても同じ位置に出す」と決めている。リセット権を持たないアカウントでも、ファイルが使えれば列は空く。

採らなかった案: 列を常に空ける。`.headroom.json` が無い人の出力まで変わり、受け入れ条件（無いときは今と同じ）に反するので採らない。

### D6. 右端の区画は、使えるアカウントでは 🚀×N に置き換える

D2 で使えるアカウントでは、今の `リセットN回・最短あと…` の区画を出さず、`tickets` から `🚀×N ~1d 20h` を出す（N は `tickets.count`、時間は `tickets.earliest_expiry` まで。`fmt_left` の書式）。`tickets` が null か `count` が 0 なら区画を出さない。Codex のロケットモードでは、失効までの時間が左の残り時間と同じになるので `🚀×N` だけにする。

使えないアカウントは今の区画のまま。値の出どころが 2 つ（snapshot の `reset_grants` と `.headroom.json` の `tickets`）になるが、1 つの行にはどちらか一方しか出ない。

### D7. 色

| 用途 | 値 | 1 行案の色 |
|---|---|---|
| ロケットモードの名前の地 | `\033[1;38;5;16;48;5;214m`（太字・黒字・地は 256 色の 214） | 地 `#FFAF00`・字 `#0A0C10`・太字 |
| 使える量の足した分の空き | 256 色の 24 | `#1E4A7A` |
| ロケットモードの右端・Codex の失効までの時間 | 256 色の 214（`usage_color_num` の黄と同じ） | `#FFAF00` |
| ロケットモードの Claude の右端・Codex の失効までの時間で、失効まで 24 時間以内 | 256 色の 203（`usage_color_num` の赤と同じ） | `#FF5F5F` |
| ロケットモードでない右端・かっこの週次リセット | `DIM` | `#7A8290` |

214 と 203 は今のバーの色の番号と同じなので、端末の色の設定で見え方がずれない。

### D8. 1 アカウント表示の名前の列は Codex の行が出るときだけ出す

ずれは、Codex の行だけが名前の列を持つことから起きる。Codex の行が出ないときは揃える相手が無く、今の 1 アカウント表示（名前も目印も無い、バイト単位で同じ）を変える理由が無い。そこで、表示する Claude のスロットが 1 つで Codex の行が出るときだけ、Claude の各行の左端を「半角スペース 2 つ（目印の列）＋名前の列」にする。目印 `▸` は出さない（今の要件どおり、1 つのときに示す対象が無い）。名前は active の行と同じく `DIM` を掛けない。登録簿が無いときの既定スロットの名前は `Claude`（アカウント名が無い）にする。

採らなかった案: 1 アカウントなら常に名前を出す。Codex を使わない人の出力まで変わるので採らない。

### D9. `.headroom.json` は jq 1 回で読み、無ければ起動しない

snapshot と同じく、全アカウント分を jq 1 回で TSV にして読む。途中で headroom が書き換わっても 1 回の描画の中で新旧が混ざらない。ファイルが無いときは jq を起動しない（今の出力と起動数を変えない）。D2 の 1〜3・5〜7 は jq の中で判定し、4（描く値との照合）は bash で判定する。

## Risks / Trade-offs

- [#1300 の確定版が D1 の仮の形と違う] → 実装の最初の作業で #1300 の最初のコミットと突き合わせる（tasks.md 1.1）。違えばこの change の design・spec・テストを #1300 に合わせて直してから実装する。形が違ったまま動いても、D2 の判定で今の描き方に戻るだけで、誤った 🚀 は出ない
- [列を空けると 7d の行の表示幅が 12 桁伸びる] → ラベルの欄を 9 桁から 7 桁に縮めて 🚀 の列 4 桁を足し（+2）、「使った / 使える」の列 9 桁を足し、割合の数字の欄を 1 桁広げる（+10）。5h の行は +2。Claude の 7d の行は Fable と右端の区画を含めて 100 桁を超えうる。1 行案の板の幅で決めたもので、狭い端末で折り返すのは今の 7d の行と同じ性質。オーナーの決定なのでこの change では変えない
- [🚀 の表示幅を 2 と見なす] → U+1F680 は East Asian Width が W で、名前の列の数え方（W / F を 2 桁）と同じ前提。🚀 は揃えたい列（バーの左端）より上流にあるが、🚀 の列は全行が同じ表示幅 4 を占める（🚀 の無い行は空白 4 つ）ので、端末が絵文字を 1 桁で描いても、ずれるのは 🚀 のある行の 1 桁だけで、目印の Ambiguous の問題（要件「active スロットの行を視覚的に示す」）のように行頭から全列に伝わるのではない
- [使える量が 100% を超えると、使った量が 100% に届いてもバーは半分しか塗られない] → これが 1 行案の意図（使える量に対する割合で見る）。数字の「使った / 使える」で使った量そのものも読める

## Migration Plan

statusline だけの変更で、`.headroom.json` が無い環境では出力が変わらない。#1300 がマージされて `.headroom.json` が書かれ始めると表示が切り替わる。戻すときはこの change の commit を戻すだけでよい（`.headroom.json` は消さなくてよい）。

## Open Questions

- #1300 の schema 1 の確定版（D1 の表の 6 項目）。実装に入る前に突き合わせる
