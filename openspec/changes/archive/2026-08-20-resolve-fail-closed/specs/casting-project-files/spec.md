## MODIFIED Requirements

### Requirement: resolve による有効な配役表の合成表示

`casting-check.sh resolve [<repo-root>]` は、catalog.md・project.md・local.md を観点（行）単位で合成した有効な配役表を出力しなければならない (MUST)。出力の前に、合成の入力になる project.md・local.md へ check モードと同じ配役表検証（⓪5列未満の壊れた表行 ①catalog.md に無い観点語彙 ④catalog_version の catalog.md との不一致・front matter 欠落）を実行しなければならず (MUST)、検証に失敗した場合は合成表を stdout に一切出力せず（部分表・ヘッダ行も含む）、失敗理由（検出カテゴリ・ファイル・該当行または観点）を stderr に出して exit 1 しなければならない (MUST)。起案シグナル（②「カタログ外」判例 ③同一観点の「論点じゃなかった」2件以上）と precedents.md を resolve の検証対象にしてはならない (MUST NOT)（観点追加の提案がその repo の自走を止めないため。check モードでは従来どおり検査する）。検証バイパスのフラグを設けてはならない (MUST NOT)。HTML コメント（`<!-- -->`）内の表行（テンプレートの記入例など）を実在の上書き行として扱ってはならない (MUST NOT)。各観点の行には、その値がどの層から来たかの由来（`カタログ既定`／`project`／`local`）を付けなければならない (MUST)。カタログの全観点が出力に含まれなければならない (MUST)。

#### Scenario: 上書きと継承が由来つきで合成される

- **WHEN** project.md で1観点、local.md でさらに別の1観点を上書きしたフィクスチャに対して resolve を実行する
- **THEN** 上書きした2観点はそれぞれ project／local の値と由来、残りの観点はカタログの値と由来 `カタログ既定` で出力される

#### Scenario: 検証を通らない配役表では合成表を出さない

- **WHEN** 壊れた表行・未知語彙・catalog_version 不一致・front matter 欠落のいずれかを含む project.md に対して resolve を実行する
- **THEN** stdout には何も出力されず、stderr に検出カテゴリ・ファイル・該当行（または観点名）が出て、exit code が 1 になる

#### Scenario: 起案シグナルだけの repo は合成できる

- **WHEN** precedents.md に「カタログ外」判例（または同一観点の「論点じゃなかった」2件以上）だけがある repo に対して resolve を実行する
- **THEN** 合成表が出力され exit code が 0 になる
