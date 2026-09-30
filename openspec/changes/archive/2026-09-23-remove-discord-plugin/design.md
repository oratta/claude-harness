## Context

Discord 改造版プラグインは genetta-inc/flatmate#851（PR #853、`b3ba7f3`）で flatmate に移り、flatmate 自身が marketplace として配っている。オーナーの PC では住人 7 体の `CHANNEL_PLUGINS` を `plugin:discord@flatmate` に切り替え、`discord@oratta-claude-harness` を uninstall 済み（issue #314 の 2026-09-23 のコメント）。この change は harness 側の後始末だけを扱う。どこへ移すか・別リポジトリを作るかといった設計判断は issue #314 で確定済みで、ここでは撤去の手順に残る小さな判断だけを記録する。

撤去の前例は loops / longrun / lr の解散（capability `loops-longrun-retirement`、`plugins/dev-workflow/tests/retirement.bats`）で、構成はそれに倣う。

## Goals / Non-Goals

**Goals:**
- `plugins/discord/`・marketplace のエントリ・CI の bun 導入・capability spec を harness から無くす
- 撤去した状態を bats で検査し、`scripts/test.sh` の全件実行に載せる
- install 済みの環境の切り替え手順を README に残す

**Non-Goals:**
- flatmate 側の変更（spec の移設は genetta-inc/flatmate#861、配布は #851 で済み）
- ユーザーへの連絡手段としての一般名詞「Discord」を含む文（dev-workflow・casting・telegram）の書き換え
- `telegram` プラグイン（同じ系統の fork だが対象外）

## Decisions

### main spec は delta で表現せず `git rm` で直接消す

`discord-reaction-delivery` の要件 6 件をすべて REMOVED にした delta は、archive が main spec に適用した結果の検証で `Spec must have at least one requirement` を出して中断する（issue #341 の R1 指摘。`remove-codex-legacy-state` の change でも同じ理由で直接削除した）。そこで、この change の delta は新しい capability `discord-plugin-retirement` の ADDED だけにし、`openspec/specs/discord-reaction-delivery/` は archive の直前に `git rm -r` で消す。削除の commit メッセージには移設先 genetta-inc/flatmate#861 を書く。

代案として `openspec archive --skip-specs` で delta 無しの change を閉じる方法もあるが、撤去の状態（何が無いべきか）を規範として残せないので採らない。

### 撤去の状態を新しい capability として残す

前例の `loops-longrun-retirement` と同じく、「何が存在してはならないか」を要件にした capability を立てる。後で誰かが Discord 改造版を harness に戻したり、CI に bun を戻したりしたときに、テストと spec の両方で気づけるようにするため。

### テストはルート `tests/discord-plugin-retirement.bats` に置く

前例はプラグイン配下（`plugins/dev-workflow/tests/retirement.bats`）に置いたが、今回は消すプラグイン以外に受け皿となるプラグインが無い。`tests/marketplace-sync.bats` と同じくリポジトリ直下に置く。`scripts/test.sh` は `git ls-files '*.bats'` で自動発見するので登録作業は不要。テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

### CI の bun 導入は節ごと消し、SHA 固定の方針コメントは一般化して残す

`oven-sh/setup-bun` を使うのは Discord の動的ハーネスだけなので、ステップと直前の説明コメントを消す。ファイル冒頭の「サードパーティ製 action はコミット SHA で固定する」方針（issue #138）は、今後サードパーティ製 action を足すときの規則なので残す。例示の `oven-sh/setup-bun` は撤去済みの action 名になるので、例示を外して方針の文だけにする（`grep -i -e discord -e setup-bun` が 0 件になる）。

### 切り替え手順はルート README の「解散済みプラグイン」節に書く

issue #314 の概要は「`enabledPlugins` の切り替え手順を docs に書く」とする。Discord 改造版には CHANGELOG が無く、プラグイン自体を消すので、前例（dev-workflow の CHANGELOG）と同じ置き場は取れない。ルート README にはすでに「解散済みプラグイン」節があるので、そこに移設の記録・uninstall コマンド・`enabledPlugins` と `CHANNEL_PLUGINS` の置き換えを書き、flatmate の marketplace 登録手順は flatmate の正本（genetta-inc/flatmate#851）へリンクで誘導する。

### version bump と注入予算

削除したプラグインは `tests/marketplace-sync.bats` の bump 検査の対象外で、他のプラグインのファイルには触れないので、`plugin.json` の bump と CHANGELOG の追記は発生しない。常時注入量は discord の skill description 2 件ぶん（434 バイト）減り、実測 39,183 → 38,749 バイトになる。予算 40,260 は上限側（実測以上）も下振れ側（実測の 1.1 倍 = 42,623 以下）も満たすので、聖域の `tests/injection-budget.txt` は動かさない。

## Risks / Trade-offs

- [オーナー以外で `discord@oratta-claude-harness` を入れている環境が marketplace 更新でプラグインを失う] → 利用者はオーナーの PC だけで、切り替え済み。README に切り替え手順を残す
- [`.github/workflows/ci.yml` は聖域パスで auto-merge の対象外] → PR は人間の承認でマージする前提で進める
- [同時期の別 PR が注入量を動かし、予算の下振れ判定に掛かる] → 余裕は約 3,900 バイトあり、ここだけで下振れには届かない。マージ直前に `bats tests/injection-budget.bats` を取り直す
