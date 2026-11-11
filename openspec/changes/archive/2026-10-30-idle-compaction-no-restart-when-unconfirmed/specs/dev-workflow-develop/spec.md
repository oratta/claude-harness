## MODIFIED Requirements

### Requirement: idle compaction の設定を確かめられなければ成功にしない
設定部品は、読めない・壊れた・object でない・重複キーのある JSON、不正な worktree、対象への symlink を検出したら書かず exit 1 にしなければならない（MUST）。check は disk 上で false なら exit 0、false への変更が必要なら exit 2 とする（MUST）。本体は disk 上の成功だけで live 反映を断定してはならず（MUST NOT）、機械確認で live の off を確かめられず on の証拠も無いときは、再起動を求めず止まらずに進んで「未確認」と記録する（MUST）。on 判明、check exit 1、apply 失敗での扱いは各シナリオに従う。

#### Scenario: 機械確認の根拠と確認失敗時の扱い
- **WHEN** check / apply 後に開始可否を判断する
- **THEN** 起動引数の `--settings '{"idleCompaction":false}'` と矛盾する上書きが無いこと、起動前から disk が false の新セッションで矛盾する起動引数が無いこと、または実効値 off を機械確認できれば、interactive / unmanned とも主に聞かず進む。確認した根拠を記録する。主の `/config` 確認は初回の実機検証に限る。新規 worktree の子は check exit 2 と承認済み apply の後も起動引数の経路を使え、既存 local false は書き込まない
- **AND** これらで live の off を確かめられず on の証拠も無いとき（起動後の apply だけ、起動時の値が不明など）は、interactive / unmanned とも再起動を求めず、主に聞かず、停止せずに進み、「未確認」と記録する
- **AND** 機械で確認した範囲を超えて live で off と報告せず、disk false だけや起動後の apply だけで live 反映を断定しない

#### Scenario: 既に off の起動は主の毎回確認を求めない
- **WHEN** 新規 worktree の子が CLI false で起動した、既存 local false を起動前から読み矛盾する指定が無い、または実効値 off を機械確認できた
- **THEN** 必要な承認済み apply の後、interactive / unmanned とも追加の主の確認を求めず進み、確認した根拠だけを記録して live 反映は断定しない

#### Scenario: 起動後の apply だけでは再起動せず未確認で進む
- **WHEN** check が exit 2 で、apply で disk を false にしたが、起動引数に `--settings '{"idleCompaction":false}'` は無く、起動時の値も false だったと確認できない
- **THEN** interactive / unmanned とも、新しいセッションでの再起動を求めず、主にも聞かず、開始を止めずに進む
- **AND** 「live の off は未確認」と develop 開始コメントに記録し、「live で off」とは報告しない。compact 後の再読で既に同じ記録があれば書き足さない
- **AND** apply 前の disk の値は on の証拠にしない。on 判明の記録があるセッションはこの扱いにせず、on 判明の規則に従う

#### Scenario: 不正な入力を上書きしない
- **WHEN** 壊れた JSON、配列、重複キー、読めないファイル、worktree でないパス、.claude または settings.local.json の symlink を渡す
- **THEN** exit 1 で対象パスと原因を出し、設定全体を出さず、ファイルとリンク先を変更しない
- **AND** 本体は対象パスと原因を記録して開始を止める

#### Scenario: ファイルが false でも反映していない
- **WHEN** disk 上は false だが、実機の /config などで実効値 Idle compaction が on のままであると判明した、または矛盾する上書き指定（例えば起動引数の `{"idleCompaction":true}`）がある
- **THEN** live 反映済みとは報告せず、未反映として状態と on 判明を issue に記録し、同じ worktree の新セッションで再起動して入口から機械確認する。interactive は主に新しいセッションでの再開を案内して終える。channel / unmanned は本体が新しいセッションを開けないので、記録して開始を止める
- **AND** on 判明の記録がある再起動後のセッションでなお off を確認できなければ開始を止めて報告する

この検査の入力元は利用者の worktree の通常の設定ファイルとパスである。拾う誤りは設定破損・他キー消失・別パスへの書き込み・未反映を成功と呼ぶこと。未知の正常な設定キーや同じ worktree の別セッションへの設定の持続、live の off が未確認のまま進むセッションは通してよい。同時書き換えの完全な排他、悪意あるファイル差し替え、将来の Claude 設定形式のすべてを防ぐ検査ではない。穴を塞ぎ切ることを完了条件にしない。
