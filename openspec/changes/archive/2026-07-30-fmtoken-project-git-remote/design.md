# Design: fmtoken-project-git-remote

## Context

fmtoken.sh の project 導出は「git root の dir 名を normalize（小文字化・`_ver.X.Y` 除去）し、空なら親 dir にフォールバック」という多段の吸収装置だった。これはワークスペース dir 名が5つの名前空間（Obsidian / ワークスペース / GitHub / 1Password / flatmate 住人）の中で最も信頼できない（世代ディレクトリでネストする・`00_IndieDev` の外に出る）ことへの対処だったが、flatmate 住人の `workspace/<住人>/repo` 構造（basename が一律 `repo`）で破綻した。#56 のシソーラス調査の結論として、リポ粒度で一貫しているのは GitHub リポ名だけであり、主が「remote 一本化・フォールバック廃止」を決定済み。remote を持たないローカル専用リポの vault エントリは 2026-07-29 にアーカイブ済みで、dir 名フォールバックを残す理由は消滅している。

## Goals / Non-Goals

**Goals:**

- project 名が実行場所（メイン repo / worktree / flatmate 住人 dir）によらず GitHub リポ名に一意に決まる
- 導出不能時（remote 無し）に誤った参照を組み立てない・誤誘導メッセージを出さない
- vault 命名を remote 名に統一する（`uranai--*`→`suimei--*` / `traoremvp--*`→`traore--*`）

**Non-Goals:**

- dir 名フォールバックの温存（廃止が決定事項）
- org 名の考慮（`genetta-inc/suimei` の `suimei` だけを使う。org 込み命名への変更は vault 全件リネームになり過剰）
- Obsidian / flatmate 住人名の名前空間統一（#58 でスコープ外と明記）

## Decisions

1. **導出コマンドは `git remote get-url origin`**。upstream 等の複数 remote 解決はしない（この環境の全リポが origin 運用）。取得した URL から末尾の `.git` を落とし、最後の `/`（SSH scp 形式では `:`）以降をリポ名として採る。HTTPS 形式（`https://github.com/org/repo.git`）と SSH 形式（`git@github.com:org/repo.git`）の両方を同じ結果にする。
2. **リポ名は小文字化だけ行う**。vault 命名が全て小文字であり、GitHub のリポ名は大文字を含みうるため。`_ver` 接尾辞除去・先頭 `_` 除去・親 dir フォールバックは削除する。
3. **remote 取得不能は専用 exit 45**。既存の 43（SA 未配布）・44（未登録）と区別する。メッセージは「git remote origin が無いため project を特定できない」ことを伝え、**登録依頼には誘導しない**（44 の誤誘導が本件の起点であるため、導出不能を未登録と混同させない）。旧実装の `git rev-parse` 失敗時 `pwd` フォールバックも廃止し、同じ exit 45 に落とす。
4. **vault リネームは `op item edit <id> title=<new>` を rw SA（`op-sa-claude-agents-rw`）で実行**。fmtoken 修正と同一 PR・同一タイミングで行う（片方先行は suimei / traore 住人のトークン取得を壊す）。リネームは冪等確認（`--list` 相当の title 一覧）を前後で取る。

## Risks / Trade-offs

- [リネームと main マージの間に時間差があると、旧 dir 名（`Uranai` 等）で動いていたメイン repo セッションが一時的に exit 44 になる] → リネームは実装・テスト完了後、マージ直前に実施し、時間差を最小化する。exit 44 は再実行で回復する一過性の事象で、破壊的ではない
- [remote URL の形式が想定外（`ssh://` 明示形式・trailing slash）だと導出がズレる] → basename 抽出は `.git` 除去 → 最後の `/` と `:` の後ろを採る素朴な実装で両形式をカバーし、bats に HTTPS / SSH 両ケースを置く
- [fork 等で origin が別名リポを指すと project 名が変わる] → この環境の運用（origin = 正本）では発生しない。発生時は exit 44 の未登録メッセージで気づける

## Migration Plan

1. fmtoken.bats に新導出のテストを追加（Red）→ fmtoken.sh 修正（Green）
2. spec 更新済みの状態で PR を Ready 化
3. vault リネーム 17件を実行し、前後の title 一覧を PR に記録
4. 住人 dir（`workspace/uranai-market/repo`）で `--list` 実機確認
5. マージ。ロールバックは fmtoken.sh の revert + vault title の逆リネーム（`op item edit` で可逆）

## Open Questions

（なし — 設計判断は #56 で主が確定済み）
