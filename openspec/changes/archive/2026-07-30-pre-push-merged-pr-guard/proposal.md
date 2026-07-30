## Why

マージ済み PR のブランチへの push 事故が多発している。push 自体は成功するため気づきにくく、変更はどこにも取り込まれないまま積み上がり、後から「どのコミットが宙に浮いたか」の調査と積み直しにコストがかかる。典型的な発生経路は「マージ後に残った worktree で作業を再開する」であり、これは `core.hooksPath` による pre-push フック（全 worktree に効く）でちょうど塞げる。「ガードはプロンプトでなくインフラ」という loop-dev-agent の設計原則に沿う。

## What Changes

- `loops-dev-agent-install` が設置する `.githooks/pre-push` テンプレートに、**マージ済み PR ブランチへの push 拒否**チェックを追加する（現状は main/master 直 push 拒否のみ）。
- 判定は「push 先ブランチに **merged な PR が 1 件以上あり、かつ open な PR が 0 件**」のときだけ拒否する。初回 push（PR 未作成）や同名ブランチでの意図的な PR 開き直しは通す。
- `gh` の失敗（オフライン・未認証・非 GitHub remote）では **fail-open**（push を通す）。ガードのために日常作業を止めない。
- ブランチ削除 push（local_sha が全ゼロ）は許可する。
- 環境変数 `PREPUSH_ALLOW_MERGED=1` による明示バイパスを用意し、拒否メッセージ内で案内する。
- 導入済み repo に後から反映するための**再適用手順**（Step 6 の再実行）を SKILL.md に明記する。

## Capabilities

### New Capabilities
- `loops-pre-push-guard`: `loops-dev-agent-install` が設置する pre-push フックの拒否条件・fail-open 方針・バイパス手段・再適用手順を規定する capability

### Modified Capabilities
<!-- 既存 spec の要件は変更しない。pre-push フックを扱う spec は現時点で存在しない -->

## Impact

- `plugins/loops/skills/loops-dev-agent-install/SKILL.md` — Step 6 のフックテンプレート拡張、再適用手順の追記
- `plugins/loops/recipes/loop-dev-agent.md` — ガード説明にマージ済み PR チェックへの言及を追加
- `plugins/loops/.claude-plugin/plugin.json` — バージョン bump（キャッシュ反映のため必須）
- 導入済み repo（agent-loop 導入先）は Step 6 の再実行で反映する。フック未更新の repo は従来どおり main 直 push 拒否のみで動作し続ける（後方互換）
- push 毎に `gh pr list` を 2 回呼ぶため 1 秒弱の遅延が増える
