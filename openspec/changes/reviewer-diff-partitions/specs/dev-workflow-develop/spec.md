## ADDED Requirements

### Requirement: adapter 経路の本体は Claude のレビュアーを区画ごとに起こす

develop の SKILL.md の (4) の `needs-reviewer` の手順は、phase `review` で選ばれた executor が claude で、G の payload の `区画:` に区画の一覧があるときは、区画ごとにレビュアーを 1 体ずつ並列に起こすことを書かなければならない（MUST）。各レビュアーの Agent の `description` は `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` の形にしなければならない（MUST。`subagent-context-audit.sh --by-role` が先頭トークン `Reviewer` でレビュアーに数えるため）。executor が codex のときは区画を使わず、差分全体を 1 つの request に渡さなければならない（MUST）。

本体は全区画の要約が揃ってから、照合と振り分けの G を 1 体だけ新しく起こし、全区画の要約をまとめて渡さなければならない（MUST）。区画ごとに G を起こしてはならない（MUST NOT）。一周目照合の補足要求では、残差のある区画だけに補足のレビュアーを起こし、その区画の元の三表と残差を渡さなければならない（MUST）。

#### Scenario: claude の executor で区画がある

- **WHEN** G の `needs-reviewer` の payload に区画が 3 つあり、phase `review` の executor が claude である
- **THEN** 本体はレビュアーを 3 体並列に起こし、`description` は `Reviewer: 区画 1/3 for PR #N (#issue)` の形で、3 体の要約が揃ってから照合と振り分けの G を 1 体起こして全区画の要約を渡す

#### Scenario: codex の executor では区画を使わない

- **WHEN** G の `needs-reviewer` の payload に区画があり、phase `review` の executor が codex である
- **THEN** 本体は区画に分けず、差分全体を 1 つの request で Codex のレビュアーに渡す
