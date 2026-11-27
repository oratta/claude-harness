## Why

PR #1435（issue #585）のあと、`stages/hold.md` は保留の解除で許容せず代替案へ作り直すとき `agent-review:failed` に付け替えて failed で返すと書いている。`openspec/specs/dev-workflow-develop/spec.md` と `gate-runner.md` の返り値の表は、代替案への作り直しを Status `次の段へ`・`次の段: 前提確認と重さ判定` で返すと書いたままで食い違っていた。`stages/prepare.md` の入口条件も、failed の保留解除が「W の修正後の再レビュー」（周回 +1）と「保留の解除のあと」（周回を引き継ぐ）のどちらに当たるか読み取れなかった。

## What Changes

- spec の保留の解除の G の要件を、代替案への作り直しは failed で返し、`次の段へ` の `前提確認と重さ判定` は W の修正が要らないときだけ、に合わせる
- spec と `gate-runner.md` の `次の段へ` の次の段の表を同じ内容に直す
- `stages/prepare.md` の入口条件を、前の Gate Result の Status で分ける: failed なら前の `段:` を問わず W の修正後の再レビュー（周回 +1）、`次の段へ` で `段: 保留の解除` なら周回を引き継ぐ

## Impact

文書の食い違いの解消だけ。hold.md の挙動は変えない。
