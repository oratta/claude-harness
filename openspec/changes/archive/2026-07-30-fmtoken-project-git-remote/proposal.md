# Proposal: fmtoken-project-git-remote

## Why

fmtoken.sh は project 名を git root のディレクトリ名から導出しているが、flatmate 住人の作業リポは全員 `workspace/<住人>/repo` 構造のため導出結果が `repo` になり、登録済みトークンが存在するのに全サービスで exit 44（未登録）となる。さらに exit 44 のメッセージが「主に登録を依頼しろ」と誘導するため、存在するトークンに対して主へ登録依頼が飛ぶ誤誘導が実際に発生した（genetta-inc/suimei#209、2026-07-29）。設計判断は oratta/claude-harness#56 で確定済み: `git remote get-url origin` のリポ名一本に切り替え、dir 名 normalize は廃止する。

## What Changes

- **BREAKING**: `fmtoken.sh` の project 導出を dir 名 normalize（小文字化・`_ver.X.Y` 除去・親 dir フォールバック）から `git remote get-url origin` のリポ名ベースへ変更する
- remote が取得できない場合（git リポでない / origin 未設定）は、誤った参照を組み立てず専用の終了コード・メッセージで停止する（登録依頼への誘導はしない）
- vault `agents` のアイテムを remote 名に合わせてリネームする（運用作業・同一 PR 内で実施）: `uranai--*` 13件 → `suimei--*`、`traoremvp--*` 4件 → `traore--*`
- `tests/fmtoken.bats` に回帰テストを追加する: `workspace/<住人>/repo` ケース / worktree ケース / remote 無しケース

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `capability-registry-fmtoken`: project 名の導出要件を「git root のディレクトリ名の正規化」から「`git remote get-url origin` のリポ名」へ差し替える。dir 名正規化のシナリオは削除し、remote 不在時の専用エラー（新 exit code）要件を追加する

## Impact

- `plugins/capability-registry/scripts/fmtoken.sh`（導出ロジック 29-33 行目）
- `plugins/capability-registry/tests/fmtoken.bats`（既存テストの make_repo が remote 前提になる）
- 1Password vault `agents` のアイテム 17件（リネーム。fmtoken 修正とセットでないと suimei / traore の住人がトークンを引けない期間が生まれるため分割不可）
- 利用側への影響: メイン repo・worktree・flatmate 住人のすべてで project 名が GitHub リポ名に一貫する。remote を持たないローカル専用リポは対象外（該当 vault エントリは 2026-07-29 にアーカイブ済みでフォールバック不要）
