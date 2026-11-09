## ADDED Requirements

### Requirement: rm の hook も `<base>` を確かめてから使う

`rm-permission-guard.sh` は、答える対象の子の呼び出しで、`<base>` とその中のファイルを、spec destructive-git-hook の要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」と「`<base>` の中のファイルを symlink を辿らずに開き、所有者だけのモードで作る」と同じ規則・同じ処理で扱わなければならない（MUST）。確かめを満たさないときは、許可を探さず、記録も `permit-log.jsonl` の行も書かずに `behavior` を `deny` にし、`message` を拒否の記録を作れなかったときの文に揃えて `<base>` のパスと満たさなかった条件を足す（MUST）。主の呼び出しと答える対象でない呼び出しでは `<base>` を作りも確かめもしない（MUST NOT）。

守備範囲: spec destructive-git-hook の同じ要件と同じ（同じ uid は守らない。別のユーザーが先に `<base>` を作った機械では子の rm を親の許可で通せない）。

#### Scenario: `<base>` が symlink なら deny を返し、symlink の先に何も作らない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にして、`agent_id` が `a1` で許可の無い payload に `rm -rf <scratchpad>/tbl/*` を渡す
- **THEN** `decision.behavior` が `deny` で、`message` に「拒否の記録を作れなかった」と `<base>` のパスが含まれ、拒否の記録のパスを示さず、symlink の先に `denied/` も `permit-log.jsonl` も作られない

#### Scenario: symlink の先に置いた許可は使わない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にし、その先の `permits/<key>.json` に 4 つの値が一致し期限内で、rm の一時領域の判定を満たす許可を置いてから、scratchpad の形に合う `session_id`・`agent_id` が `a1`・`cwd` が scratchpad の中のディレクトリの payload に `cd ./tbl; rm -rf x/*` を渡す
- **THEN** `decision.behavior` が `deny` で、`message` に「拒否の記録を作れなかった」が含まれ、置いた許可のファイルが残っている
