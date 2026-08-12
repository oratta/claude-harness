# capability-registry-fmtoken Specification

## Purpose
プロジェクトスコープのトークン取得ラッパー fmtoken.sh。1Password の agents 保管庫から read-only SA 経由でトークンを引き、未登録・未配布時は人間への依頼文を返す。
## Requirements
### Requirement: fmtoken.sh がプラグイン内から動作する
プラグインは `scripts/fmtoken.sh` を同梱し、以下の振る舞いを提供しなければならない（SHALL）: プロジェクト名を `git remote get-url origin` のリポジトリ名（URL 末尾の `.git` を除いた最終パス要素を小文字化したもの）から機械導出し、1Password の agents 保管庫のアイテム `<project>--<service>`（フィールド `credential`）を read-only Service Account 経由で読む。導出はディレクトリ名に依存しないため、メイン repo・worktree・flatmate 住人の作業リポ（`workspace/<住人>/repo`）のすべてで同じプロジェクト名に解決される。スキルや hook からは `${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh` で参照できること。

#### Scenario: トークンの取得
- **WHEN** origin remote を持つ登録済みプロジェクトで `fmtoken.sh <service>` を実行する
- **THEN** `op://agents/<project>--<service>/credential` の値が標準出力に返り exit 0 となる

#### Scenario: flatmate 住人の作業リポからの導出
- **WHEN** git root のディレクトリ名が `repo`（`workspace/<住人>/repo` 構造）で、origin が `https://github.com/genetta-inc/suimei.git` を指すリポで `fmtoken.sh` を実行する
- **THEN** プロジェクト名は `suimei` に解決され、ディレクトリ名 `repo` は参照されない

#### Scenario: SSH 形式の remote URL
- **WHEN** origin が `git@github.com:oratta/traore.git`（SSH scp 形式）のリポで `fmtoken.sh` を実行する
- **THEN** プロジェクト名は HTTPS 形式と同じ `traore` に解決される

#### Scenario: worktree 配下からの導出
- **WHEN** メイン repo から作成した worktree のディレクトリ内で `fmtoken.sh` を実行する
- **THEN** メイン repo で実行した場合と同じプロジェクト名に解決される

### Requirement: SA トークンは env → 600 ファイル → Keychain の順で解決する（無人経路優先）
fmtoken.sh は `OP_SERVICE_ACCOUNT_TOKEN` 環境変数 → `~/.config/op-sa/claude-agents-ro.token`（600 権限ファイル）→ macOS Keychain `op-sa-claude-agents-ro` の順で SA トークンを解決しなければならない（SHALL）。Keychain は ACL 次第で読み出しごとに生体認証ダイアログを出し、無人文脈（cron・常駐・SSH）ではそこでブロックするため、対話マシン用の最終フォールバックに置く。ファイルが配布済みのマシンでは Keychain に一切触れないこと。どこにも無い場合は exit 43 で「主に SA トークンの配布を依頼する」案内を stderr に返し、ブラウザでのログイン代行に誘導しない。

#### Scenario: 600 ファイルが Keychain より優先される
- **WHEN** Keychain にも 600 ファイルにも SA トークンがあるマシンで `fmtoken.sh <service>` を実行する
- **THEN** ファイルのトークンが使われ、Keychain（`security find-generic-password`）は呼ばれない

#### Scenario: 未セットアップマシン
- **WHEN** SA トークンが env にも Keychain にもファイルにも無いマシンで `fmtoken.sh <service>` を実行する
- **THEN** exit 43 となり、stderr に「主に『SA トークンをこのマシンに配布して』と依頼すること」の案内が出る

### Requirement: 未登録サービスは exit 44 で登録依頼を返す
要求されたサービスが agents 保管庫に未登録の場合、fmtoken.sh は exit 44 で終了し、stderr に「ブラウザに行かず、主に 1Password の agents 保管庫への登録を依頼する」案内を返さなければならない（SHALL）。

#### Scenario: 未登録サービスの要求
- **WHEN** agents 保管庫に `<project>--<service>` が存在しない状態で `fmtoken.sh <service>` を実行する
- **THEN** exit 44 となり、stderr に登録依頼の案内（アイテム名とフィールド名を含む）が出る

#### Scenario: 存在確認モード
- **WHEN** `fmtoken.sh --check <service>` を実行する
- **THEN** トークン値を出力せず、登録済みなら exit 0、未登録なら exit 44 で返る

### Requirement: remote 導出不能時は専用エラーで停止する
`git remote get-url origin` が失敗する場合（git リポジトリでない・origin remote が未設定）、fmtoken.sh は誤ったアイテム参照を組み立てず exit 45 で終了しなければならない（SHALL）。stderr には origin remote が無いためプロジェクトを特定できない旨を出力し、未登録時（exit 44）の登録依頼メッセージには誘導しないこと（導出不能と未登録の混同が、存在するトークンへの登録依頼という誤誘導を生むため）。

#### Scenario: origin remote が無いリポでの実行
- **WHEN** remote 未設定の git リポジトリで `fmtoken.sh <service>` を実行する
- **THEN** exit 45 となり、stderr に origin remote が無くプロジェクトを特定できない旨が出て、登録依頼の案内は出ない

#### Scenario: git リポジトリ外での実行
- **WHEN** git リポジトリでないディレクトリで `fmtoken.sh <service>` を実行する
- **THEN** exit 45 となる（旧実装の cwd フォールバックで誤った参照を組み立てない）

（dir 名正規化の廃止は上記 MODIFIED に含まれる — 旧要件「fmtoken.sh がプラグイン内から動作する」の導出記述とその正規化シナリオを、remote 導出の記述・シナリオで置き換えた。理由と移行は proposal / design を参照）

