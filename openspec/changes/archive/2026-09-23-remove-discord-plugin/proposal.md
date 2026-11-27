## Why

Discord の改造版プラグイン（公式プラグインの fork。リアクションの push 配送を足したもの）は flatmate の住人が実行時に必要とする部品で、genetta-inc/flatmate#851（PR #853 でマージ済み）で flatmate に移り、flatmate 自身が marketplace として配るようになった。オーナーの PC の住人はすべて `plugin:discord@flatmate` に切り替え済みで、`discord@oratta-claude-harness` は uninstall 済み。harness（オーナー個人の開発環境）に同じ部品が残ると正本が 2 つになるので、harness 側から取り除く（issue #314）。

## What Changes

- **BREAKING** `plugins/discord/` を git 追跡の削除として取り除く（15 ファイル）。`discord@oratta-claude-harness` はインストールできなくなる
- `.claude-plugin/marketplace.json` の `plugins[]` から `discord` のエントリを外す（`bundles[]` の `all` には元から入っていない）
- `.github/workflows/ci.yml` から bun 導入の節（`oven-sh/setup-bun`）を外す。bun を使うテストは Discord の動的ハーネスだけだった
- capability `discord-reaction-delivery` の main spec（`openspec/specs/discord-reaction-delivery/spec.md`）を削除する。中身は flatmate 側に移る（genetta-inc/flatmate#861）
- ルート `README.md` のプラグイン一覧から `discord` 行を外し、「解散済みプラグイン」の節に移設の記録と切り替え手順を足す
- 撤去の状態を検査する bats を足す

## Capabilities

### New Capabilities

- `discord-plugin-retirement`: harness から Discord 改造版プラグインを撤去した状態（ディレクトリ・marketplace 登録・CI の bun 導入・capability spec の不在と、移設先の記録）を規定する

### Modified Capabilities

なし。`discord-reaction-delivery` は capability ごと廃止するが、全要件 REMOVED の delta は archive で `Spec must have at least one requirement` により中断するため delta では表現しない。main spec を直接 `git rm` する（design.md 参照）。

## Impact

- 削除: `plugins/discord/`、`openspec/specs/discord-reaction-delivery/`
- 編集: `.claude-plugin/marketplace.json`、`.github/workflows/ci.yml`（聖域パス）、`README.md`
- 追加: `tests/discord-plugin-retirement.bats`
- 常時注入量: discord の skill description 2 件（201 + 233 = 434 バイト）が減る。実測 39,183 → 38,749 バイト、予算 40,260 は実測の 1.1 倍（42,623）以内なので `tests/injection-budget.txt` は動かさない
- plugin.json の version bump: 対象なし（削除したプラグインは `tests/marketplace-sync.bats` の bump 検査の対象外。他のプラグインには触れない）
