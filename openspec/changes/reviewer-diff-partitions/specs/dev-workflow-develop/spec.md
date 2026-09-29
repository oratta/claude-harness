## ADDED Requirements

### Requirement: adapter 経路の本体は Claude のレビュアーを区画ごとに起こす

develop の SKILL.md の (4) の `needs-reviewer` の手順は、phase `review` で選ばれた executor が claude で、G の payload の `区画:` に区画の一覧があるときは、区画ごとにレビュアーを 1 体ずつ並列に起こすことを書かなければならない（MUST）。各レビュアーの Agent の `description` は `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` の形にしなければならない（MUST。`subagent-context-audit.sh --by-role` が先頭トークン `Reviewer` でレビュアーに数えるため）。executor が codex のときは区画を使わず、差分全体を 1 つの request に渡さなければならない（MUST）。

本体は全区画の要約が揃ってから、照合と振り分けの G を 1 体だけ新しく起こし、全区画の要約を `区画 <k>/<n>` の見出しを付けてまとめて渡さなければならない（MUST）。区画ごとに G を起こしてはならない（MUST NOT）。

#### Scenario: claude の executor で区画がある

- **WHEN** G の `needs-reviewer` の payload に区画が 3 つあり、phase `review` の executor が claude である
- **THEN** 本体はレビュアーを 3 体並列に起こし、`description` は `Reviewer: 区画 1/3 for PR #N (#issue)` の形で、3 体の要約が揃ってから照合と振り分けの G を 1 体起こして全区画の要約を渡す

#### Scenario: codex の executor では区画を使わない

- **WHEN** G の `needs-reviewer` の payload に区画があり、phase `review` の executor が codex である
- **THEN** 本体は区画に分けず、差分全体を 1 つの request で Codex のレビュアーに渡す

### Requirement: 補足は一周目の区画の構成のまま、選び直した executor で残差だけを補う

一周目照合の補足要求（`needs-reviewer` の補足 payload）でも、本体は既存要件「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」のとおり phase `review` の投げ先を選び直す。SKILL.md の (4) は、選び直しで executor が一周目と変わっても変わらなくても、補足を一周目の区画の構成（G が `レビュー三表:` のコメントと補足 payload に書いた `一周目の区画:`）のまま行うことを書かなければならない（MUST）。補足のときに区画を計算し直してはならず、差分全体のレビューを始めてはならない（MUST NOT）。一周目の三表の変更点 ID と finding ID はそのまま残し、補った項目にも一周目と同じ ID の付け方（区画があれば補足先の区画の `P<k>-`、区画が無ければ接頭辞なし）を使わなければならない（MUST）。既存の「元の三表を置き換えず、残差に挙げた不足した項目だけを補う」と「補足は PR 全体で 1 回まで（補足済み回数は PR で 1 つ）」は変えない（MUST）。

executor ごとの起こし方は次のとおりとしなければならない（MUST）:

- 一周目に区画があり、補足の executor が claude: 残差のある区画だけに補足のレビュアーを 1 体ずつ起こし、その区画の元の三表と残差を渡す。`description` は `Reviewer: 補足 区画 <k>/<n> for PR #<N> (#<issue>)` とする
- 一周目に区画があり、補足の executor が codex: 1 つの request に、残差のある区画ごとに区画の番号・その区画のファイル一覧・元の三表・残差を分けて載せ、区画ごとに `P<k>-` の ID で補わせる。差分全体のレビューは頼まない
- 一周目に区画が無く（一周目が Codex、または `区画: なし`）、補足の executor が claude: 補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で補わせる。payload の `区画:` に区画の一覧があっても区画ごとに起こさない
- 一周目に区画が無く、補足の executor が codex: 今までどおり 1 つの request で補わせる

#### Scenario: 区画に分けた Claude の一周目のあと、補足で Codex が選ばれる

- **WHEN** 一周目は claude で 3 区画に分けてレビューし、G が区画 2 と区画 3 に残差を出して `一周目の区画: 3` の補足 payload を返し、補足の選び直しで executor が codex になる
- **THEN** 本体は 1 つの request に区画 2 と区画 3 の番号・ファイル一覧・元の三表・残差を分けて載せ、`P2-`・`P3-` の ID で不足分だけを補わせ、差分全体のレビューも区画 1 の補足も頼まない。補足済み回数は PR で 1 のまま

#### Scenario: 区画に分けなかった Codex の一周目のあと、補足で Claude が選ばれる

- **WHEN** 一周目は codex で差分全体を 1 体で見て（payload の `区画:` には 3 区画があった）、G が `一周目の区画: なし` の補足 payload を返し、補足の選び直しで executor が claude になる
- **THEN** 本体は補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で不足分だけを補わせ、区画ごとに起こさず差分全体のレビューも始めない
