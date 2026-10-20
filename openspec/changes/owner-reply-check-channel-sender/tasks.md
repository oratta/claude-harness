## 1. 判定（owner-reply-check.sh）

- [ ] 1.1 `OWNER_REPLY_CHANNEL_SENDERS` を読み、空白（改行を含む）かカンマで区切って `(server, ID)` の組の集合にする。形に合わない項目があれば stderr に `OWNER_REPLY_CHANNEL_SENDERS` の名前を含む理由を出して exit 2。確かめは使い方の振り分け（`relayed(...)` を呼ぶ前）より先に置き、会話ログの中身によらず効かせる。値は python の `os.environ` から読む（`-I` でも読める） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:252-256（`mode, raw_excerpt, … = sys.argv[1:6]` の直後）
- [ ] 1.2 チャンネルの行の中身を取り出す関数を足す（spec の条件 1〜7。開きタグは `^<channel((?: [A-Za-z_][A-Za-z0-9_]*="[^"\n]*")*)>\n` で先頭に固定して読み、属性名の重複・`source` と `origin.server` の一致・`user_id` が空でないこと・末尾の `\n</channel>` を確かめる。満たさなければ None） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:112-121（定数と `norm` の近く）
- [ ] 1.3 `owner_text` の origin の判定を、`kind == "human"` のときは今のまま、`kind == "channel"` のときは本文を組み立てた後に 1.2 で中身を取り出して以降の判定（⑥・⑦・⑨）と戻り値を中身にする形に直す。それ以外の kind・null は今のまま None 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:123-157（`owner_text`）
- [ ] 1.4 冒頭の説明の「主の発言として数える行」の 4 と、終了コード 2 の一覧に、チャンネルの行の条件と `OWNER_REPLY_CHANNEL_SENDERS` の形の誤りを足す 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:10-43

## 2. テスト（owner-reply-check.bats）

- [ ] 2.1 `setup` で `OWNER_REPLY_CHANNEL_SENDERS` を unset する（呼び出したシェルの値が既存のテストに漏れないように）。チャンネルの行を足す helper（`add_channel <server> <開きタグの属性> <中身> [uuid] [timestamp]`）を、2026-10-20 時点の実物の形（`type:"user"`・`isMeta:false`・`isSidechain:false`・`origin:{"kind":"channel","server":…}`・`promptSource:"system"`・文字列の本文）で足す 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:7-22
- [ ] 2.2 既存の「origin.kind other than human does not match」の channel を、設定が無いときの入力として残し（exit 1）、peer と task-notification は設定があっても exit 1 になることを足す 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:140-147
- [ ] 2.3 spec の ADDED 要件の Scenario を 1 件ずつ bats にする（許可された送信者で通す・MATCH の全文が中身だけ・複数の項目・許可されていない送信者・別のチャンネルの同じ ID・未設定と空・送信者を読めない 8 つの形・中身の偽の開きタグ・中身の ⑨・設定の形の誤り 3 つを 3 つの使い方で exit 2・対話の行と `<bash-input>` の行は設定があっても今までどおり）。`--locate` と `--relayed` は既存の `add_report`・`STOP_AT`・`STOP_URL` を使う 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:526 の後ろ（末尾に新しい節として足す）
- [ ] 2.4 `bats plugins/dev-workflow/tests/owner-reply-check.bats plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` が全件通ることを確かめる 触る範囲: plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats（読むだけ）

## 3. 記録

- [ ] 3.1 変更の記録を `plugins/dev-workflow/changes/1125.md` に書く（何を変えたか・住人の環境では `OWNER_REPLY_CHANNEL_SENDERS` の設定が要り、その決まりは #1126 で決めること） 触る範囲: plugins/dev-workflow/changes/1125.md（新規）
