## ADDED Requirements

### Requirement: rm の hook も `<base>` を確かめてから使う

`plugins/dev-workflow/scripts/rm-permission-guard.sh` は、子の呼び出しに答えるとき（要件「子の rm の確認画面に、親の許可に従って答える」で答える対象のとき）、`<base>`（`${TMPDIR:-/tmp}/dev-workflow-git-guard`）とその下の `denied/`・`permits/` を、要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」（spec destructive-git-hook）と同じ規則で、同じ `plugins/dev-workflow/scripts/git-guard-scratchpad.py` の処理を使って確かめてから使わなければならない（MUST。確かめ方を rm の hook に書き分けない）。`<base>` の中のファイル（許可・拒否の記録・`permit-log.jsonl`・一時ファイル）の開き方と作り方も同じ規則に従わなければならない（MUST）。

確かめを満たさないとき、hook は許可を探さず・使わず、拒否の記録も `permit-log.jsonl` の行も書かずに、`hookSpecificOutput.decision.behavior` を `deny` にしなければならない（MUST）。このときの `message` は、要件「子の rm の確認画面に、親の許可に従って答える」の、拒否の記録を作れなかったときの文（パスの代わりに「拒否の記録を作れなかった」ことと、親に報告するときはコマンドの全文を書くこと）に揃え、そのうえで、拒否の記録を置く場所を安全に使えなかったこと・その場所（`<base>` のパス）・満たさなかった条件を含めなければならない（MUST）。拒否の記録のパスは載せない。主の呼び出しと答える対象でない呼び出しでは、今までどおり何も出力せず、`<base>` を作りも確かめもしてはならない（MUST NOT）。

守備範囲: 受け取る入力は、要件「子の rm の確認画面に、親の許可に従って答える」の入力に、`<base>` とその下のフォルダ・ファイルのファイルシステム上の種類・持ち主・モードを足したものである。拾いたい誤りと、通す・止めることを許す入力は、spec destructive-git-hook の要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の守備範囲と同じである（同じ uid のプロセスが `<base>` の中に書くものは守らない。別のユーザーが先に `<base>` を作った機械では、子の rm は親の許可で通せなくなる）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: `<base>` が symlink なら deny を返し、symlink の先に何も作らない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にして、`agent_id` が `a1` で許可の無い payload に `rm -rf <scratchpad>/tbl/*` を渡す
- **THEN** `decision.behavior` が `deny` で、`message` に「拒否の記録を作れなかった」と `<base>` のパスが含まれ、拒否の記録のパスを示さず、symlink の先に `denied/` も `permit-log.jsonl` も作られない

#### Scenario: symlink の先に置いた許可は使わない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にし、その先の `permits/<key>.json` に 4 つの値が一致し期限内で、rm の一時領域の判定を満たす許可を置いてから、scratchpad の形に合う `session_id`・`agent_id` が `a1`・`cwd` が scratchpad の中のディレクトリの payload に `cd ./tbl; rm -rf x/*` を渡す
- **THEN** `decision.behavior` が `deny` で、`message` に「拒否の記録を作れなかった」が含まれ、置いた許可のファイルが残っている
