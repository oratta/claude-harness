## ADDED Requirements

### Requirement: workspace-write ジョブは専用の Git 管理外一時領域を使う
worker は implement/spec-write の job ごとに一つの新規専用ディレクトリを所有者一致・0700 で作り、その正規化済み絶対パスを App Server と子ツールの TMPDIR に渡さなければならない（MUST）。領域は cwd と Git 管理領域の外でなければならず（MUST）、同じ run の別 job と共有してはならない（MUST NOT）。

#### Scenario: Git 管理外を前提とするテストを実行する
- **WHEN** implement job が TMPDIR に一時ディレクトリを作る
- **THEN** 作成に成功し、その場所の git rev-parse --show-toplevel は失敗する。cwd 内への TMPDIR 上書きは不要である

#### Scenario: 同じ run の次のジョブを開始する
- **WHEN** fresh job が受け付けられる
- **THEN** 前の job の一時領域を再利用せず、異なる専用領域を使う

### Requirement: 一時領域の追加許可以外の砂場を維持する
workspace-write の writableRoots は cwd と専用領域だけでなければならない（MUST）。excludeSlashTmp と excludeTmpdirEnvVar は true、networkAccess は false、approvalPolicy は never を維持しなければならない（MUST）。read-only role の許可を拡大したり danger-full-access に変更したりしてはならない（MUST NOT）。

#### Scenario: 許可外へ書き込もうとする
- **WHEN** Codex ツールが cwd/専用領域の外の /tmp/<一意名> および呼び出し元 TMPDIR/<一意名> に書き込む
- **THEN** どちらも砂場で拒否され、専用 TMPDIR 内への同じ操作だけが成功する

#### Scenario: read-only role を実行する
- **WHEN** review/spec-review/impl-review/decider job が開始される
- **THEN** readOnly policy と networkAccess=false、approvalPolicy=never を保持し、本変更で追加の書き込み許可を得ない

### Requirement: 一時領域を別ジョブへ公開せず終了時に片付ける
専用領域を別 job から読める状態にしてはならない（MUST NOT）。0700 だけで同一 UID の隔離を満たしたとみなしてはならない（MUST NOT）。確認済み終了後には ack を待たず削除し、削除失敗を隠してはならない（MUST NOT）。停止未確認の unknown は終了とみなさず、領域を再利用してはならない（MUST NOT）。

#### Scenario: 別ジョブの既知パスを読む
- **WHEN** 同一 OS ユーザーの別 job が実行中 job の専用領域にある既知パスのファイルを読む
- **THEN** 読み取りが拒否される。名前を知らないことや書き込み不可だけでは合格にならない

#### Scenario: 確認済み終了の後を観測する
- **WHEN** 成功、失敗、確認済み取消、または開始前失敗の worker が cleanup を終える
- **THEN** 専用領域は存在せず、cwd・認証元・親領域・symlink 参照先は削除されない。削除できなければ失敗が記録される

#### Scenario: 終了を確認できない
- **WHEN** turn 開始後に切断または worker 喪失で unknown になる
- **THEN** 停止済みと推測せず既存の unknown 所有・再投入禁止を保ち、削除完了を主張しない

### Requirement: 実 Codex のテスト完走と拒否の証拠を残す
実装は fake 回帰試験に加え、実 Codex implement role で scripts/test.sh 全件の成功件数・総件数・exit code と対象 HEAD を記録しなければならない（MUST）。拒否プローブ、ジョブ間読み取り隔離、終了時削除も実環境で確認し、CODEX-WORKER.md に実際の範囲と制約を反映しなければならない（MUST）。

#### Scenario: 実環境の受け入れ結果を記録する
- **WHEN** 対象 HEAD の scripts/test.sh と境界プローブが完了する
- **THEN** 全件成功・exit 0、許可先での成功、許可外での拒否とそのコマンド/出力/exit code、0700、別 job 読み取り拒否、終了後の領域不在を記録する。件数は過去の1465件を固定せず対象 HEAD の実測値を使う
