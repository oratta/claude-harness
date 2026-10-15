## 1. 実装

- [ ] 1.1 `cmd_reap` の `cat "$rmerr" >&2; rm -f "$rmerr"` と `if tip=...` のあいだ（ブランチが残り先端が HEAD と一致するときだけ）に、`git worktree list --porcelain` から `worktree <path>` の行が消えるのを上限つきで待つ処理を入れる。上限・間隔は `EPIC_DISPATCH_REAP_DETACH_TIMEOUT`（既定 30）・`EPIC_DISPATCH_REAP_DETACH_INTERVAL`（既定 1）、数値でなければ既定、`sleep` は PATH のものを使う。上限超えは既存の `reaped <N> branch-kept` に落とす。スクリプト冒頭の reap の説明コメント（76-79 行）にも 1 句足す。 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:76-79、plugins/dev-workflow/scripts/epic-dispatch.sh:521-546（cmd_reap の rm のあと）

## 2. テスト

- [ ] 2.1 bats のスタブ git に `worktree list --porcelain` を足す（設定 `wtlist_out`／回数で切り替え。無設定は従来どおり空で exit 0 にして既存テストを変えない）。偽の orca の rm が exit 0 のあと一定回数だけワークツリーが残るケースで `reaped 11` とブランチ削除、常に残るケース（上限を短くする）で `reaped 11 branch-kept` と `branch -D` 非呼び出し、先端が違うケース（待たずに消さない）と、一覧に前方一致の別パスだけがあるケース（待たずに消す）を確かめる。 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:156-177（git スタブ）、plugins/dev-workflow/tests/epic-dispatch.bats:269-283（reap_ready）、reap のテスト群（「残ったブランチ」を含むテストの近く）

## 3. 仕様

- [ ] 3.1 `openspec/specs/dev-workflow-develop/spec.md` の reap の要件（1544 行）の該当 1 文を差し替え、Scenario 3 件を足す（specs/ の差分の形で archive 時に反映される）。 触る範囲: openspec/specs/dev-workflow-develop/spec.md:1544、同 1626-1628 付近
