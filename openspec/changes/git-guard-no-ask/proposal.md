# Proposal

## Why

画面を見ている人もチャンネルも無い別セッションの `/develop` の子では、破壊的 git 操作への `ask` が誰にも応答されず、親の `wait --watch-stopped` にも検知されない。実行モードを channel に変える `DEV_WORKFLOW_UNATTENDED` や検証専用の FORCE を流用せず、git ガードだけに効く拒否の印が必要である（#1582）。

## What Changes

- 起動側が設定する `DEV_WORKFLOW_GIT_GUARD_NO_ASK` を追加する。前後の空白を除いて未設定・空・`0` は印なし、それ以外は印ありとする。
- 印のある主の呼び出しは permission mode・FORCE によらず `deny` とし、オーナーへの承認依頼に必要な内容を報告してターンを終えるよう案内する。確認画面・入力欄の `!`・チャンネルへの案内は出さない。
- 子の判定・親の一度限りの許可・既存の無人セッションの扱い・develop の実行モードは維持する。両方の印のある主には NO_ASK 用の理由を優先する。
- `epic.md` 手順 5 の注意に、印のある子は確認画面で止まらず、承認を求めてターンを終えた止まりが会話ログから検知される旨を追記する。
- 版を上げず、実装段で `plugins/dev-workflow/changes/1582.md` に変更を記録する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `destructive-git-hook`: 主の ask / deny の判定と拒否理由にガード専用の NO_ASK 印を追加する。

## Impact

実装対象は `plugins/dev-workflow/scripts/git-destructive-guard.sh`、同プラグインの `tests/git-destructive-guard.bats`、`skills/develop/references/epic.md`、`changes/1582.md` の 4 ファイル。新しい依存は不要。

印を付ける責務は flatmate 側（PR #2022・#2007）に置き、harness の `epic-dispatch.sh launch` 等は変更しない。`rules/destructive-git-guard.md` と `rules/README.md` は既存の承認規範・UNATTENDED の案内のまま維持し、新しい起動設定と具体的な拒否後の案内は hook・spec・epic.md に置く。常時注入予算は変更しない。マージは主の承認とする。
