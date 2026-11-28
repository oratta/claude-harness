# Tasks

根拠は design.md と2つの delta spec。全テストは一時 HOME・一時ディレクトリ内だけで実行し、ローカル bare origin と偽 gh を使う。実ホームは書き換えない。各実装は対応する Bats を先に失敗させてから通す。以下の行番号は固定 HEAD `93543270038cdf040edb6cd9d3a8b4b41a540ae4` の案内であり、編集前に該当箇所を読む。

## 1. 共通指紋・main 照合・続行理由の記録

- [ ] 1.1 新規 Bats に一時 HOME／ローカル bare origin／偽 gh の fixture と、同一コピー・パス／mtime／mode／キャッシュ名の相違・SKILL／両 references 群の内容変更と追加／削除／改名・除外対象の差を加え、スクリプトの指紋処理と詳細 reference を作る。独立した既知の入力から仕様のバイト形式を確かめ、対象外の変更が指紋に影響しないことを Bats で検証する。触る範囲: `plugins/dev-workflow/scripts/develop-procedure-freshness.py`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）
- [ ] 1.2 `check` に明示読込元・比較元引数／環境変数・指定 fetch／tip 固定・各 tree の独立列挙・第一親履歴照合を実装して reference を更新する。Bats で古い Git 外コピーは `1`、同一と revert 済み main は `0`、先行／分岐／由来不明・第二親だけの一致・shallow 未発見は理由付き投稿と `0`、CLI 不正／SKILL 欠落・読取不能は `2` を確かめる。触る範囲: `plugins/dev-workflow/scripts/develop-procedure-freshness.py`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）
- [ ] 1.3 比較元未設定／利用不能・fetch 失敗と取得後判定不能の固定本文を issue／PR へ1回投稿する処理、投稿失敗の JSON／stderr、代理投稿の文書を実装する。Bats で正しい URL・全文・理由コード・終了 `0`、古い ref の不使用、shell 展開されない本文、投稿失敗の本文保持と `recording=failed`、再試行／永続 spool が無いことを確かめる。触る範囲: `plugins/dev-workflow/scripts/develop-procedure-freshness.py`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）

## 2. マージ前の印

- [ ] 2.1 `mark-preview` の6フィールド・worktree 固有 absolute git dir の単一印・3者の指紋照合・URL 正規化と、`check --preview-worktree` の再照合を実装して reference を更新する。Bats で有効な印の直接 worktree／Git 外コピーは `0`、同じ tuple の再利用と URL の末尾 slash／query／fragment の正規化、未コミット対象の発行拒否 `2`、印の置場が tracked／共有 git-common-dir／キャッシュでないことを確かめる。触る範囲: `plugins/dev-workflow/scripts/develop-procedure-freshness.py`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）
- [ ] 2.2 古い版 fixture で schema・両実体パス・元 HEAD・3者の指紋・記録先の各不一致、別 worktree／別キャッシュ／別記録先への流用、改変／移動／読取不能を個別に検査する。Bats で警告後に通常判定へ戻り `1` になることを確かめ、印はテスト成功の証拠でなく変更後は再発行する契約を reference に残す。触る範囲: `plugins/dev-workflow/scripts/develop-procedure-freshness.py`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）

## 3. 入口接続と変更記録

- [ ] 3.1 SKILL の入口 0／1ループと worker/spec の PR 作成直後に必須検査を接続し、実際に読んだ SKILL からの plugin root と記録先を渡し、W にもその値を引き継ぐ。issue／Draft PR／軽い通し方の担い手と、仕様化判断・編集より前の順序を Bats で検証する。追加 return・各工程再検査を増やさず、取得不能・投稿失敗の扱いは詳細 reference に接続する。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md`:85-96（入口 0）、`plugins/dev-workflow/skills/develop/SKILL.md`:102-116（1ループ）、`plugins/dev-workflow/skills/develop/references/roles/worker/spec.md`:5-29（記録先の用意）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）
- [ ] 3.2 `plugins/dev-workflow/changes/1864.md` に古い版の停止・有効な印・取得不能時の記録を記し、reference とともに導入前キャッシュを強制検査できない保証限界を明記する。Bats で変更記録と保証限界を確かめ、固定 HEAD からの diff で plugin.json version・sync.sh・worktree 読込手順・provider-compat-update・1860.md に変更が無いことを確認する。触る範囲: `plugins/dev-workflow/changes/1864.md`（新規）、`plugins/dev-workflow/skills/develop/references/procedure-freshness.md`（新規）、`plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）

## 4. 統合検証

- [ ] 4.1 一時環境で `bats plugins/dev-workflow/tests/develop-procedure-freshness.bats` と `bats plugins/dev-workflow/tests/develop-skill.bats tests/develop-startup-budget.bats` を実行し exit `0` を確認する。`openspec validate guard-develop-procedure-freshness --type change --strict` も exit `0` とし、予算値や範囲外ファイルを変更して通さない。触る範囲: `plugins/dev-workflow/tests/develop-procedure-freshness.bats`（新規）、`plugins/dev-workflow/tests/develop-skill.bats`:1-85（既存 suite、原則読取）、`tests/develop-startup-budget.bats`:1-212（既存 suite、読取）、`openspec/changes/guard-develop-procedure-freshness/`（本 change）
