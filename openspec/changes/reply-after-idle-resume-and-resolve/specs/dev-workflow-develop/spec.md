## ADDED Requirements

### Requirement: 起動し直した親は主の返事待ちの子を主に出し直す
SKILL.md の Orca 経路の手順 7（`回し方: Orca` を引き継いだ再開）は、`launch` の前に、`launch` に渡したことのある開いた子のうち、最新の `子の停止: 主の返事待ち` コメントに一致する最新の `親の判断:`（手順 8 と同じ照合）が「通した」以外で、その停止のあとの再開の記録が無い子を集め、手順 8 と同じ報告を本文で出し直してから待ちに入ると書かなければならない（MUST）。`親の判断: 通すが送れなかった` の件は手順 8 と同じく送り直す。`references/reply-after-idle.md` の「親への適用」の復元元の表は、主の返事待ちの子の行（復元元は子 issue の `子の停止: 主の返事待ち` と対応する `親の判断:`）を持たなければならない（MUST）。`tests/develop-skill.bats` はこの 2 点を確かめなければならない（MUST）。

#### Scenario: 手順 7 が主の返事待ちの子の出し直しを書いている
- **WHEN** SKILL.md の手順 7 を読む
- **THEN** `epic-stopped-seen` の子を含む主の返事待ちの子を、`launch` の前に手順 8 と同じ報告で出し直すと書いてある

#### Scenario: 復元元の表に主の返事待ちの子の行がある
- **WHEN** `reply-after-idle.md` の「親への適用」の表を読む
- **THEN** 主の返事待ちの子の行があり、復元元に `子の停止: 主の返事待ち` と `親の判断:` が書いてある

### Requirement: wait --resolve は通す返事を送る前に起動し直すかを表で決める
`epic-dispatch.sh wait --resolve` の `resolve_stopped` は、判断が `通す` のとき、`reply-after-idle.md` の表に従って `deliver_reply` の `relaunch` を決めなければならない（MUST）。子の最後のリクエストから 60 分以上で、その間にコンパクトが走っておらず（最後の assistant の行より後に `compact_boundary` の行が無い）、会話量 N（`subagent-context.sh --file` の `context_tokens`）が 150,000 以上なら起動し直し（`relaunched`）、それ以外は今までどおり送る（`sent`）。トランスクリプト（子のワークツリーに対応する `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}` 配下のディレクトリの `*.jsonl`）が 0 本または 2 本以上、時刻や会話量を読めない、のいずれかのときは送る（MUST）。`tests/epic-dispatch.bats` は偽の `orca`・`gh`・トランスクリプトで次の Scenario を確かめなければならない（MUST）。

#### Scenario: 60 分以上・コンパクトなし・150,000 以上なら起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く、会話量が 150,000 以上で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、エピックに通した記録が残る

#### Scenario: 60 分未満ならそのまま送る
- **WHEN** 最後のリクエストが 60 分未満前で同じ実行をする
- **THEN** 返事は `sent` で届く

#### Scenario: 事実を読めなければそのまま送る
- **WHEN** トランスクリプトが無い、または 2 本ある
- **THEN** 返事は `sent` で届く
