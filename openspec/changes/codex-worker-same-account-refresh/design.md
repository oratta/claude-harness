## Context

`auth_info()` は元 CODEX_HOME の `auth.json` から `auth_hash`（ファイル全体の sha256）・`identity`（ID token の email を小文字化したものの sha256）・`account_id_hash`（`tokens.account_id` の sha256）を作る。`runtime_identity_matches()` は runtime の symlink が元の `auth.json` を指していることを確かめたうえで、この 3 つがすべて開始時と一致することを要求し、外れると `auth_profile_changed` を投げる。`run_turn()` はこれをターン開始前に 1 回、ターン待機ループの各周（約 0.25 秒ごと）に呼び、例外はすべて「変わった」とみなしてターンを中断する。

runtime の `auth.json` は元 profile への symlink なので、app-server 自身が token を更新すると元の `auth.json` が書き換わる。更新後も email と account_id は同じだが、`auth_hash` が変わるので止まる。これが #426 の停止の原因と考えられる（再現はまだ確かめていない）。

## Goals / Non-Goals

**Goals:**
- 同じアカウントのまま token だけが更新されたときにターンを止めない
- 別アカウントへの切り替え（email か account_id が変わる）では、今までどおりターンを中断して `auth_profile_changed` を返す
- runtime symlink の差し替え検出（`runtime_auth_link_changed`）はそのまま残す

**Non-Goals:**
- ID token の署名検証、複数 workspace の完全識別（従来どおり主張しない）
- 更新の検出や停止の合図の仕組み（`ForegroundRecorder`）の変更

## Decisions

### 同一性は email と account_id の 2 つで判定し、ファイル全体のハッシュは比べない

`auth_hash` を比較対象から外し、`identity` と `account_id_hash` だけを比べる。email だけにしない理由は、同じ email で別 workspace（別 account_id）に切り替わるケースを今までどおり止めるため。account_id だけにしない理由は、ターン開始前の照合が email で app-server の値と突き合わせているので、同じ軸を実行中も見続けるため。

代わりの案として「`auth.json` の token 以外のフィールドを比べる」も考えたが、Codex CLI が `last_refresh` などのフィールドを増減させるたびに誤停止が戻るので採らない。

### 中身が変わったときは account/read で app-server 側の実行中アカウントも確かめる

ローカルの識別子が同じでも、`auth_hash` が直前に確認した値と違うときは、`account/read`（`refreshToken: false`）を 1 回呼んで、返った email のハッシュが開始時の `identity` と同じかを確かめる。同じなら確認済みの `auth_hash` を更新し、同じ中身に対して再び呼ばない。email が違う、`chatgpt` 型でない、エラー応答が返るときは `auth_profile_changed` で中断する。issue #426 の「識別子（ID token の email と `account/read` の結果）で判定する」をそのまま実装する形で、ターン開始前の照合（`server_identity_mismatch`）と同じ比べ方を実行中にも使う。

`Rpc.request` はターン中の通知を `rpc.buffer` に退避してから応答を返すので、待機ループの中で呼んでも通知を落とさない。呼ぶのは中身が変わった回だけなので、通常の待機中に RPC は増えない。

代わりの案として「ローカルの識別子だけで判定し account/read は呼ばない」も考えた。実装は小さいが、app-server が別アカウントの token で動き続けている状態を実行中に確かめる手段がなくなるので採らない。

### 書き換え途中で読めない auth.json は、5 秒までは止めずに読み直す

token 更新の書き込みがアトミックでない場合、待機ループが書き換え途中の `auth.json`（壊れた JSON や id_token 欠落）を読むことがある。今の実装はこれも「変わった」とみなして止めるので、識別子で比べるようにしても同じ停止が残る。そこで、待機ループ中の読み取り失敗（JSON の解析失敗・id_token の形の不正・email や account_id の欠落・ファイルが無い）は「判定できない」として扱い、その周は止めずに次の周で読み直す。判定できない状態が最初に起きてから 5 秒を超えて続いたら `auth_profile_changed` で中断する。5 秒は、1 回の書き込みが終わるには十分長く、別アカウントへの切り替え後に壊れたファイルを放置した場合でも工程の損失が小さい長さとして選んだ。

ターン開始前の照合は今までどおり厳格にする（読めなければその場で止める）。この時点ではまだ何も始めていないので、止めても失うものがない。

runtime symlink の検査（`runtime_auth_link_changed`）は読み取りの前に行い、猶予の対象にしない。symlink の差し替えは token 更新では起きないため。

### 既存テスト 2 件は書き換え内容を「別アカウントへの切り替え」に直す

`test_changed_auth_never_starts_server` と `test_source_auth_change_interrupts_the_running_turn` は、`auth.json` の末尾に空白を 1 つ足して「変わった」ことを作っている。これは識別子の変わらない書き換えなので、新しい振る舞いでは止まらないのが正しい。この 2 件の意図は「別アカウントへの切り替えで止まる」ことなので、書き換え内容を別の email・account_id を持つ認証情報への置き換えに直し、期待値（`auth_profile_changed`、開始前なら model/list 以降を呼ばない、待機中なら `interrupted`）は変えない。末尾に空白を足すケースは、新しく足す「同じアカウントの token 更新では止まらない」テストの側で扱う。

## Risks / Trade-offs

- [同じ email・同じ account_id のまま、中身が別人の token に差し替わる] → app-server の account/read の email で確かめるが、email が同じなら区別できない。署名検証や完全識別を主張しないという従来の制約の範囲内として受け入れる
- [別アカウントへの切り替え直後にファイルが壊れたまま放置される] → 最大 5 秒、ターンが続く。5 秒を超えれば従来どおり中断するので、切り替えを見逃すのではなく検出が最大 5 秒遅れるだけになる
- [account/read の呼び出しが待機ループを遅らせる] → 呼ぶのは中身が変わった回だけで、応答待ちは既存の `Rpc.request` の期限に従う

## Migration Plan

利用者側の移行作業は無い。worker の停止条件が緩むだけで、結果 JSON の形と `error_kind` の値は変わらない。
