# #705限定の接続PoC

本番workerではない。実行は同時1件、read-only、固定の無害な入力だけ。現在profileを変更しない。既存server/brokerへ接続せず、所有するstdio App Serverだけを起動・終了する。

```sh
python3 scripts/poc/codex-appserver/poc.py --cwd /tmp --mode preflight
python3 scripts/poc/codex-appserver/poc.py --cwd /tmp --mode complete --model <明示モデル> --expected-account <確認済fingerprint>
python3 scripts/poc/codex-appserver/poc.py --cwd /tmp --mode interrupt --model <明示モデル> --expected-account <確認済fingerprint>
python3 -m unittest discover -s scripts/poc/codex-appserver -v
```

fingerprintは `SHA256("chatgpt:" + lower(trim(email)))`。preflightの出力をそのまま期待値にコピーするだけでは独立の帰属照合にならない。今回の実測では現在profileのauth.jsonに保存されたID tokenのemail claimをローカルで読み、account/readの観測と比較した。token/email自体は表示・保存せず、署名検証や複数workspaceの一意識別を保証する仕組みとは扱わない。本番account_key設計は#699/#706の担当。

上限は各RPC15秒＋turn観測最大60秒。待ち期限・切断は不明のまま終了し、再送しない。終了時は所有serverを閉じるため、このclientには親終了後の子継続保証はない。接続方式を実証するPoCであり、#706の寿命分離が別途必要。

中断は受付後の実際のturn activityを待って送る。非競合interruptedだけを合格に数える。完了との競合・unknownは不合格。未対応server requestは拒否し所有turnの中断を試みる。モデルエラー内容は秘密混入防止のため出力せず種別とRPC codeだけ残す。
