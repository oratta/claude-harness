## ADDED Requirements

### Requirement: 空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない

本体は、W が `(Subagent completed but returned no output.)` だけを返したとき（`continue: false` による打ち切りで、拒否理由が親に届かない場合を含む）、その W に SendMessage で報告を 1 回だけ求めなければならない（MUST）。本体は、報告の有無によらず `git -C <path> status --porcelain` で作業ツリーの未コミット差分を確かめ、残っていれば引き取らなければならない（MUST）。報告に破壊的 git 操作で打ち切られたとあるときは、同じ指示で W を起こし直してはならず（MUST NOT）、打ち切られた操作と指示の見直しを主に上げなければならない（MUST）。`skills/develop/SKILL.md` の「1 ループ」の節に、これらが書かれていなければならない（MUST）。

#### Scenario: 報告を 1 回だけ求める

- **WHEN** `skills/develop/SKILL.md` の `returned no output` を含む段落を読む
- **THEN** SendMessage で 1 回だけ報告を求める、と書かれており、`git -C <path> status --porcelain` で未コミット差分を確かめることも書かれている

#### Scenario: 打ち切られたら起こし直さない

- **WHEN** 同じ段落を読む
- **THEN** 報告に破壊的 git 操作で打ち切られたとあれば、同じ指示では起こし直さず主に上げる、と書かれている
