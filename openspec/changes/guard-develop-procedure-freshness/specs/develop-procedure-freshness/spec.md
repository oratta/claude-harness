## Purpose

Claude と Codex が実際に読む develop 手順書の内容を、Git 管理外コピーでも取得した main と比較し、配布済みの古い版と証明できるときだけ開発を止める。マージ前の検証対象と判定不能時の続行理由も明示する。

## ADDED Requirements

### Requirement: 版の同一性は手順書集合の生バイトで決める
検査は plugin root 相対の `skills/develop/SKILL.md`、`skills/develop/references/` 以下の全 `.md`、plugin 直下 `references/` 以下の全 `.md` を対象にしなければならない（MUST）。相対 POSIX パスの UTF-8 バイト順で並べ、`b"develop-procedure-v1\0"` に各ファイルの「パス UTF-8 + NUL + 生バイトの SHA-256 小文字 hex + LF」を連結したバイト列の SHA-256 を指紋とする（MUST）。各読込元・各 Git tree は独立してファイル集合を列挙し、改行・空白・frontmatter を正規化してはならない（MUST NOT）。

#### Scenario: キャッシュの場所やメタデータが違う同一内容
- **WHEN** Git 外コピーの絶対パス・mtime・ファイルモード・キャッシュ名が元と異なり、対象のパスと内容は同じである
- **THEN** 指紋は同じになり、docs・scripts・plugin.json・changes・Codex 生成の移行用ディレクトリの差も指紋に影響しない

#### Scenario: 対象集合の変更と過去の列挙
- **WHEN** SKILL または両 references 群で内容（空白・改行・frontmatter を含む）を変更するか、ファイルを追加・削除・改名する
- **THEN** 指紋が変わり、過去の tree の指紋はその tree 自身の集合で求める（現在の一覧を過去へ流用しない）

### Requirement: 比較する main は明示した clone から新たに取得する
`check` は `--loaded-plugin-root` を必須にし、比較用 harness clone は `--comparison-repo`、省略時だけ `CLAUDE_HARNESS_DEV_DIR` から得なければならない（MUST）。作業 repo の cwd・キャッシュ名・ホーム内探索で補ってはならない（MUST NOT）。比較元で `git fetch --no-tags origin +refs/heads/main:refs/remotes/origin/main` を行い、成功後の tip OID を固定して比較しなければならない（MUST）。取得失敗時は既存の origin/main で代用してはならない（MUST NOT）。

#### Scenario: キャッシュに Git が無い
- **WHEN** 読込元に `.git` が無く、比較用 clone が指定されている
- **THEN** キャッシュ内容を指紋化し、比較元で取得した固定 tip と照合する

#### Scenario: fetch が失敗して古い ref だけ残る
- **WHEN** 比較元の origin/main は存在するが今回の fetch が失敗する
- **THEN** その ref の内容から古いと判定せず、取得不能として記録して続行する

### Requirement: main の過去の第一親状態と一致するときだけ古い版として止める
検査は「読込元＝取得した main」「有効なマージ前の印」「main と異なり第一親履歴の過去の状態と指紋一致」「一致未発見」の順で判定しなければならない（MUST）。前二者は続行、過去一致は停止、未発見は新旧判定不能として記録して続行する（MUST）。Git 外コピー・由来不明・先行／分岐 worktree も同じ内容比較とし、コミットの先後を指紋から推測してはならない（MUST NOT）。shallow など探索範囲不足で未発見なら `history-incomplete`、十分な履歴で未発見なら `fingerprint-not-in-main-history` とする（MUST）。

#### Scenario: 古い Git 外コピーを読む
- **WHEN** 読込元の指紋が main と異なり、main の過去の第一親状態と一致し、有効な印が無い
- **THEN** 古い版として停止する（先行・分岐 worktree に同じ内容があっても同様）

#### Scenario: main が過去の内容へ revert した
- **WHEN** 読込元の内容が取得した main と同じで、過去の第一親状態にも存在する
- **THEN** 同一として続行し、過去一致を理由に停止しない

#### Scenario: 先行・分岐・由来不明の内容は新旧を証明できない
- **WHEN** 読込元と main が異なり、第一親履歴に指紋一致が無い
- **THEN** 判定不能を投稿して続行し、第二親にだけ一致があっても古い版としない

#### Scenario: shallow 履歴で古い版を発見できない
- **WHEN** 履歴が不完全で指紋一致が未発見である
- **THEN** `history-incomplete` を投稿して続行する

### Requirement: マージ前の印は元 worktree 固有の場所に内容を拘束して発行する
`mark-preview --loaded-plugin-root <root> --preview-worktree <worktree> --record <URL>` は元 worktree の `git rev-parse --absolute-git-dir` 配下の `develop-procedure-preview.json` 1 個だけに印を発行しなければならない（MUST）。tracked ファイル・共有 git-common-dir に置いてはならない（MUST NOT）。読込元・元 worktree の `plugins/dev-workflow`・その HEAD tree の3者の指紋一致を要求し、対象手順書に未コミット変更があれば発行を拒否しなければならない（MUST）。

#### Scenario: commit 済み候補に印を発行する
- **WHEN** 3者の指紋が一致する直接 worktree または Git 外コピーに印を発行する
- **THEN** 印のフィールドは次の6個だけとなる
  ```json
  {"schema_version": 1, "loaded_plugin_root": "<読込元の実体絶対パス>", "worktree_root": "<元worktreeの実体絶対パス>", "worktree_head": "<完全なcommit OID>", "procedure_fingerprint": "sha256:<hex>", "record_url": "<正規化したissueまたはPRのURL>"}
  ```

#### Scenario: 対象手順書の編集をまだ commit していない
- **WHEN** 読込元または元 worktree の対象内容が HEAD tree と一致しない
- **THEN** 印を発行せず終了コード `2` を返し、先に commit が必要であると分かる

### Requirement: 印は毎回 tuple を再照合し無効なら通常判定に戻る
`check` は `--preview-worktree` が渡されたとき元 worktree の印を読み、実体パス2個・現在の元 HEAD・3者の指紋・今回の記録先を再照合しなければならない（MUST）。記録先入力は完全な issue／PR URL とし、末尾 slash・query・fragment を除去して比較する（MUST）。無効な印は警告して無視し、通常の新旧判定に戻る（MUST）。同じ tuple の再利用は許すが、別 worktree・別キャッシュ・別記録先・HEAD 変更・対象改変・移動後には再発行が必要である（MUST）。印をテスト成功の証明としてはならない（MUST NOT）。

#### Scenario: 意図して古い内容の候補を試す
- **WHEN** 過去の main と同じ内容の直接 worktree または Git 外コピーに有効な印があり、今回の tuple が一致する
- **THEN** マージ前の検証対象として続行し、同じ tuple での再検査も続行する

#### Scenario: 印を使い回すか照合項目を改変する
- **WHEN** schema・いずれかの実体パス・HEAD・指紋・record URL の照合が不成立、または印を読めない
- **THEN** 警告して印を無視し、古い版の fixture なら停止する（印の存在だけでは続行しない）

### Requirement: 取得不能と判定不能は固定文言を記録先へ1回投稿して続行する
比較元が未設定・利用不能なら `comparison-repo-unavailable`、fetch 失敗なら `origin-main-fetch-failed` として、スクリプトが `--record` の issue／PR へ固定文言を1回投稿しなければならない（MUST）。取得後の判定不能も同じ記録先へ理由を1回投稿して続行する（MUST）。本文は stdin または `--body-file` で渡し、shell 展開してはならない（MUST NOT）。

#### Scenario: origin/main を取得できない
- **WHEN** 比較元が未設定・利用不能、または fetch が失敗する
- **THEN** 正しい issue／PR に次の本文を投稿して続行する
  ```text
  手順書の版を確かめられなかった。origin/main を取得できなかったため、develop を続けます。
  読込元: <実体絶対パス>
  比較元: <実体絶対パス、または未設定>
  理由: <comparison-repo-unavailable または origin-main-fetch-failed>
  ```

#### Scenario: 取得後に新旧を証明できない
- **WHEN** 履歴から新旧を証明できず続行する
- **THEN** 本文の先頭行を `手順書の版を確かめられなかった。読込元と origin/main の新旧を証明できないため、develop を続けます。` とし、残りは同じ読込元・比較元の行と、理由 `fingerprint-not-in-main-history` または `history-incomplete` の行にする

### Requirement: 投稿失敗も続行し結果に本文を残す
投稿失敗でも develop を停止してはならない（MUST NOT）。スクリプトは stdout の結果 JSON に投稿本文と `recording: "failed"` を残し、stderr に投稿失敗を出さなければならない（MUST）。本体は次の記録機会に代理投稿し、成功するまでは記録済みと報告してはならない（MUST NOT）。永続 spool・再試行ループを追加してはならない（MUST NOT）。

#### Scenario: gh が投稿できない
- **WHEN** 取得不能または判定不能の投稿が失敗する
- **THEN** 終了コード `0` で本文と `recording: "failed"` が JSON に残り、stderr に失敗が出て、本体が次の記録機会に代理投稿する

### Requirement: CLI 終了コードは停止と入力不備を区別する
`check --loaded-plugin-root <root> --record <URL> [--comparison-repo <clone>] [--preview-worktree <worktree>]` は同一・有効な印・判定不能・取得不能（投稿失敗を含む）で `0`、古い版の確認で `1`、CLI 不正や読込元 SKILL 欠落・読取不能など検査入力不備で `2` を返さなければならない（MUST）。`mark-preview` は発行成功で `0`、照合不成立・入力不備で `2` を返す（MUST）。

#### Scenario: 読込元が壊れている
- **WHEN** 必須引数が無い、または読込元 SKILL が欠落・読取不能である
- **THEN** `check` は `2` を返し、取得不能の続行として扱わない
