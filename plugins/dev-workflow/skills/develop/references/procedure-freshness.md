# 実際に読んだ develop 手順書の版

入口 0 の記録先確定直後、仕様化判断の記録と対象の編集より前に一度だけ実行する。issue がある経路と軽い通し方は本体、W が Draft PR を作る経路は W が作成直後に行う。本体は実際に読んだ `skills/develop/SKILL.md` から2階層上の plugin root を解決し、W にその値を引き継ぐ。作業 repo や比較元から読込元を推測しない。追加の return 工程や各工程の再検査は設けない。

```bash
python3 <plugin-root>/scripts/develop-procedure-freshness.py check \
  --loaded-plugin-root <実際の読込元plugin-root> --record <issueまたはPRの完全URL> \
  --comparison-repo <比較用harness-clone>
```

比較元は `--comparison-repo`、省略時だけ `CLAUDE_HARNESS_DEV_DIR`。cwd・キャッシュ名・ホーム探索では補わない。Python 標準ライブラリ・git・gh が必要。記録先 URL は末尾 slash・query・fragment を除去する。

## 指紋と判定順

対象は plugin root 相対の `skills/develop/SKILL.md`、`skills/develop/references/` と plugin 直下 `references/` 以下の全 `.md`。docs・scripts・plugin.json・changes・Codex の移行用ディレクトリは対象外。絶対パス・mtime・mode は含めない。

相対 POSIX パスの UTF-8 バイト順で、`b"develop-procedure-v1\0"` に各ファイルの「パス UTF-8 + NUL + 生バイトの SHA-256 小文字 hex + LF」を連結し、全体の SHA-256 を指紋とする。空白・改行・frontmatter を正規化しない。読込元と各 Git tree で独立して集合を列挙するため、追加・削除・改名も識別する。

比較元で `git fetch --no-tags origin +refs/heads/main:refs/remotes/origin/main` が成功した後、tip OID を固定する。取得に失敗したとき既存 ref は使わない。

1. 読込元と取得 main の指紋が同じなら続行（revert した main も同様）。
2. 有効なマージ前の印があれば続行。
3. main と異なり、過去の第一親履歴に同じ指紋があれば古い版として停止。第二親だけの一致は含めない。
4. 未発見なら新旧を推測せず記録して続行。十分な履歴は `fingerprint-not-in-main-history`、shallow 等の不足は `history-incomplete`。

stdout は結果 JSON。`check` は同一・有効な印・判定不能・取得不能（投稿失敗含む）で exit 0、古い版で 1、CLI 不正・読込元 SKILL 欠落／読取不能等の入力不備で 2。1 は develop を停止し、2 は入力を直してから進む。

## マージ前の印

対象手順書を commit した後、意図して検証する候補を指定する。

```bash
python3 <plugin-root>/scripts/develop-procedure-freshness.py mark-preview \
  --loaded-plugin-root <読込元> --preview-worktree <元worktree-root> --record <完全URL>
# 検査にも --preview-worktree <元worktree-root> を明示する
```

発行は読込元・元 worktree の `plugins/dev-workflow`・元 HEAD tree の3者の指紋一致が必要。発行成功は exit 0、不一致・入力不備は 2（未コミット対象は先に commit）。印は元 worktree の `git rev-parse --absolute-git-dir` 配下の `develop-procedure-preview.json` 1個だけ。tracked ファイル・共有 git-common-dir・キャッシュへの保存や自動探索はしない。

6フィールドは `schema_version: 1`、`loaded_plugin_root`（実体絶対パス）、`worktree_root`（実体絶対パス）、`worktree_head`（完全 OID）、`procedure_fingerprint`（`sha256:<hex>`）、`record_url`（正規化 URL）。検査時は全フィールドと現在の3者の指紋を再照合する。無効・読取不能な印は警告し通常判定へ戻る。同じ tuple は再利用可。別 worktree・別キャッシュ・別記録先、HEAD 変更・対象改変・移動後には再発行する。印は候補を意図して読む宣言であり、テスト成功の証明ではない。署名・期限・使用回数制限は設けない。

## 取得不能・判定不能と投稿失敗

比較元未設定／利用不能は `comparison-repo-unavailable`、fetch 失敗は `origin-main-fetch-failed`。次の全文を `--record` の issue／PR に gh の stdin で1回投稿する。

```text
手順書の版を確かめられなかった。origin/main を取得できなかったため、develop を続けます。
読込元: <実体絶対パス>
比較元: <実体絶対パス、または未設定>
理由: <理由コード>
```

取得後の判定不能は先頭行を `手順書の版を確かめられなかった。読込元と origin/main の新旧を証明できないため、develop を続けます。` にし、残りは同じ形式で上記の履歴の理由コードを使う。shell 展開しない。

投稿失敗でも exit 0。stdout JSON の `body` に本文、`recording: "failed"` を保持し、stderr に投稿失敗を出す。本体はこの本文を次の記録機会に代理投稿し、成功するまでは記録済みと報告しない。W が実行して `recording: "failed"` なら `body` 全文を既存 return に載せ、記録未完了と報告する（本体が代理投稿する）。永続 spool・自動再試行ループは作らない。

## 保証限界

guard も呼出規定も無い導入前キャッシュを、本変更だけで強制検査することはできない。同期機構・hook・provider 別入口の追加はこの変更の範囲外。
