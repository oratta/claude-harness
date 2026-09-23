## MODIFIED Requirements

### Requirement: 前景実行はアカウントを依頼された CODEX_HOME で固定する
前景実行は、依頼に載せられた CODEX_HOME を実行アカウントとして固定しなければならない（MUST）。account 名を CODEX_HOME へ解決するために永続 registry を読んではならない（MUST NOT）。依頼の account 名は結果の記録に使うラベルであり、照合の材料にしてはならない（MUST NOT）。照合は、app-server が返した実行中アカウントが、渡された CODEX_HOME の認証情報と一致することで行わなければならない（MUST）。前景実行は 1 件ごとに runtime CODEX_HOME を作り、認証情報への link が実行中に差し替えられていないことを確認し、終了時にその link を外して片付けなければならない（MUST）。runtime CODEX_HOME は、親に `TMPDIR` があればその配下、無ければ実行環境の既定の一時領域にある、所有者だけが読み書きできるディレクトリに置かなければならず（MUST）、app-server とその子に渡す `TMPDIR` / `TMPPREFIX` を変えてはならない（MUST NOT）。結果の `effective.account` には app-server が返した実行中アカウントを入れなければならず（MUST）、依頼の account 名をそのまま写してはならない（MUST NOT）。依頼の account 名は `requested.account` にだけ残さなければならない（MUST）。どの CODEX_HOME を使うかは呼び出し側の責任であることを仕様は明示しなければならない（MUST）。実行中の認証情報の照合は、渡された CODEX_HOME の認証情報から得る ID token の email と account_id が開始時と同じであることで行わなければならず（MUST）、認証情報ファイルの中身全体が同じであることを要求してはならない（MUST NOT）。email または account_id が開始時と違えば、ターンの中断を要求し、理由を `auth_profile_changed` として結果に残さなければならない（MUST）。email と account_id が同じまま認証情報ファイルの中身が変わったときは、その変化ごとに app-server の実行中アカウントを取得し直し、その email が開始時と同じなら中断してはならず（MUST NOT）、違うか取得できなければ `auth_profile_changed` で中断を要求しなければならない（MUST）。ターンの待機中に認証情報ファイルが読めないときは、その時点で中断せず読み直さなければならず（MUST）、読めない状態が 5 秒を超えて続いたら `auth_profile_changed` で中断を要求しなければならない（MUST）。ターン開始前の照合で認証情報ファイルが読めないときは、ターンを開始せずに終了しなければならない（MUST）。

#### Scenario: 渡された認証情報と実行中アカウントが食い違う
- **WHEN** app-server が返した実行中アカウントが、依頼の CODEX_HOME の認証情報と一致しない
- **THEN** ターンを開始せず、理由を示して終了し、別のアカウントへ切り替えない

#### Scenario: 実行中に認証情報の link が差し替えられる
- **WHEN** ターンの待機中に runtime の認証情報への link が別の場所を指すようになる
- **THEN** ターンの中断を要求し、その理由を結果に残す

#### Scenario: 対応表が指す CODEX_HOME が要求名と食い違う
- **WHEN** 依頼の account 名が意図したものとは別の CODEX_HOME が依頼に載り、そのまま完走する
- **THEN** 結果の実効アカウントには app-server が返した実行中アカウントが入り、依頼の account 名は要求側にだけ残る

#### Scenario: 実行中に同じアカウントの token だけが更新される
- **WHEN** ターンの待機中に元の認証情報ファイルの token が書き換わり、ID token の email と account_id は開始時と同じで、取得し直した実行中アカウントの email も開始時と同じである
- **THEN** ターンを中断せずに続け、結果の `error_kind` を `auth_profile_changed` にしない

#### Scenario: 実行中に別のアカウントへ切り替わる
- **WHEN** ターンの待機中に元の認証情報ファイルが、email または account_id の違う認証情報に置き換わる
- **THEN** ターンの中断を要求し、結果の `error_kind` を `auth_profile_changed` にする

#### Scenario: 識別子は同じだが実行中アカウントが別の email を返す
- **WHEN** ターンの待機中に認証情報ファイルの中身が変わり、ID token の email と account_id は同じだが、取得し直した実行中アカウントの email が開始時と違う
- **THEN** ターンの中断を要求し、結果の `error_kind` を `auth_profile_changed` にする

#### Scenario: 書き換え途中の認証情報ファイルを読む
- **WHEN** ターンの待機中に認証情報ファイルが一時的に読めなくなり、5 秒以内に同じアカウントの内容で読めるようになる
- **THEN** ターンを中断せずに続ける

#### Scenario: 認証情報ファイルが読めない状態が続く
- **WHEN** ターンの待機中に認証情報ファイルが読めない状態が 5 秒を超えて続く
- **THEN** ターンの中断を要求し、結果の `error_kind` を `auth_profile_changed` にする
