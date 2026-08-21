## MODIFIED Requirements

### Requirement: casting-check.sh の検出項目

`plugins/casting/scripts/casting-check.sh` は対象 repo の `.claude/casting/` に対して次の6項目を検査しなければならない (MUST): ⓪配役表の表行が5列ちょうどに割れるか（`|` が6個ちょうどでない行は malformed-row として報告する。5列未満だけでなく、セル内の `|` で6列以上に割れる行も対象にしなければならない (MUST)。列がずれると `既定の担い手` 列が別のセルに解決されるため。壊れた行は resolve の合成で有効値として扱わない）⓪'各ファイルの HTML コメントの開閉（`<!--` と `-->`）の個数が一致するか（閉じ忘れは以降の行を EOF まで無視させ、上書き行を黙って全滅させるため）①配役表・判例台帳に catalog.md に無い観点語彙（「カタログ外」を除く）が使われていないか ②判例台帳に「カタログ外」判例があるか（観点追加の起案シグナルとして報告）③同一観点で帰結「論点じゃなかった」が2件以上あるか（移譲仕組み化の起案シグナルとして報告）④各ファイルの `catalog_version` が catalog.md の `version` と一致するか。検出なしなら exit 0、検出ありなら対象の一覧を出力して exit 1 としなければならない (MUST)。対象 repo ルートが存在しない場合は検査結果を返してはならず (MUST NOT)、使い方エラーとして exit 2 としなければならない (MUST)（打ち間違えたパスを「問題のない repo」と同じ exit 0 で返さないため）。日本語語彙の照合に awk のマルチバイト文字列比較を使ってはならない (MUST NOT)（macOS awk は多バイト比較が壊れるため。`LC_ALL=C` の grep -F 等で照合する）。

#### Scenario: 問題のないフィクスチャで exit 0

- **WHEN** カタログ語彙のみ・カタログ外なし・version 一致のフィクスチャに対して実行する
- **THEN** exit code が 0 になる

#### Scenario: 4種の検出がそれぞれ報告される

- **WHEN** ①未知語彙②カタログ外判例③同一観点の「論点じゃなかった」2件④version 不一致 をそれぞれ含む4つのフィクスチャに対して実行する
- **THEN** いずれも該当項目が一覧出力され、exit code が 1 になる

#### Scenario: セル内の | で6列以上に割れる行が報告される

- **WHEN** 観点の説明セルに `|` が含まれ、表行が6列以上に割れる project.md に対して実行する
- **THEN** malformed-row として該当行が出力され、exit code が 1 になる

#### Scenario: 閉じ忘れの HTML コメントが報告される

- **WHEN** 閉じ `-->` の無い `<!--` を含む配役表に対して実行する
- **THEN** unclosed-comment として該当ファイルが出力され、exit code が 1 になる

#### Scenario: 存在しない repo ルートは使い方エラーになる

- **WHEN** 存在しないパスを対象に実行する
- **THEN** 検査結果を出力せず、exit code が 2 になる

### Requirement: resolve による有効な配役表の合成表示

`casting-check.sh resolve [<repo-root>]` は、catalog.md・project.md・local.md を観点（行）単位で合成した有効な配役表を出力しなければならない (MUST)。出力の前に、合成の入力になる project.md・local.md へ check モードと同じ配役表検証（⓪5列ちょうどに割れない表行 ⓪'HTML コメントの開閉不一致 ①catalog.md に無い観点語彙 ④catalog_version の catalog.md との不一致・front matter 欠落）を実行しなければならず (MUST)、検証に失敗した場合は合成表を stdout に一切出力せず（部分表・ヘッダ行も含む）、失敗理由（検出カテゴリ・ファイル・該当行または観点）を stderr に出して exit 1 しなければならない (MUST)。配役表（project.md・local.md）が1枚も存在しない対象に対しては、カタログ既定だけの合成表を stdout に出力してはならず (MUST NOT)、配役表が無い旨を stderr に出して exit 3 としなければならない (MUST)（repo ルートの打ち間違え・casting 未導入と「検証を通った解決結果」を呼び出し側が区別できるようにするため）。起案シグナル（②「カタログ外」判例 ③同一観点の「論点じゃなかった」2件以上）と precedents.md を resolve の検証対象にしてはならない (MUST NOT)（観点追加の提案がその repo の自走を止めないため。check モードでは従来どおり検査する）。検証バイパスのフラグを設けてはならない (MUST NOT)。HTML コメント（`<!-- -->`）内の表行（テンプレートの記入例など）を実在の上書き行として扱ってはならない (MUST NOT)。`resolve` サブコマンドは引数の位置に依存してはならず (MUST NOT)、オプションより後ろに置かれても resolve として扱わなければならない (MUST)（黙って check モードに落ちないため）。対象 repo ルートの positional 引数は1個までとし、2個以上・不明なオプション・`--catalog` の値欠落は usage を出して exit 2 としなければならない (MUST)。各観点の行には、その値がどの層から来たかの由来（`カタログ既定`／`project`／`local`）を付けなければならない (MUST)。カタログの全観点が出力に含まれなければならない (MUST)。

#### Scenario: 上書きと継承が由来つきで合成される

- **WHEN** project.md で1観点、local.md でさらに別の1観点を上書きしたフィクスチャに対して resolve を実行する
- **THEN** 上書きした2観点はそれぞれ project／local の値と由来、残りの観点はカタログの値と由来 `カタログ既定` で出力される

#### Scenario: 検証を通らない配役表では合成表を出さない

- **WHEN** 壊れた表行（5列未満・6列以上）・閉じ忘れコメント・未知語彙・catalog_version 不一致・front matter 欠落のいずれかを project.md または local.md に含む repo に対して resolve を実行する
- **THEN** stdout には何も出力されず、stderr に検出カテゴリ・ファイル・該当行（または観点名）が出て、exit code が 1 になる

#### Scenario: 配役表が1枚も無い repo では解決しない

- **WHEN** `.claude/casting/` に precedents.md だけがあり project.md も local.md も無い repo に対して resolve を実行する
- **THEN** stdout には何も出力されず、stderr に配役表が無い旨と対処が出て、exit code が 3 になる

#### Scenario: オプションの後ろの resolve も resolve として扱われる

- **WHEN** `--catalog <path> resolve <repo-root>` の順で実行する
- **THEN** 合成表が出力され（壊れた配役表なら fail-closed で exit 1 になり）、check モードへ黙って落ちない

#### Scenario: 起案シグナルだけの repo は合成できる

- **WHEN** 有効な project.md があり、precedents.md に「カタログ外」判例（または同一観点の「論点じゃなかった」2件以上）がある repo に対して resolve を実行する
- **THEN** 合成表が出力され exit code が 0 になる
