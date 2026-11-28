## Context
PHASES は 4 例外を表さず、adapter と develop の手順が直接 Claude を指定する。自動選択の最後の行は両 provider が欠測でも Claude を返す。`codex-worker` は読み取り役に writableRoots を与えず、TMPDIR は親の値のまま引き継ぐ。

## Goals / Non-Goals
Goals: #1859 の 4 例外と Claude 実行不能の分岐を共通 resolver に集める。
Non-Goals: #1856/#1857 の本体別操作や Claude 起動 transport の実装、worker の sandbox 変更、余裕の計算式・通常の選択表の変更。

## Decisions
### 今回埋める決定 1 件: 4 例外に同じ「起動せず主へ」の代替を使う
Claude を使わない構成では、書き込み可能な Codex reviewer を追加する案を採らず、4 例外を起動しない。既存の read-only 契約を保てる一方、該当する仕事は主の確認待ちになる。issue が許す代替の選択であり、新たな権限や品質判定は作らない。
4 例外を識別できる依頼を `request` に渡し、既存の profile 指定・account-home を保持する。resolver が起動不可と理由を返したら本体は実行コマンドや Agent を呼ばない。通常レビューで一時書き込みが不要な場合は既存の Codex レビューを続ける。profile 形式や canonical role の追加は不要で、例外の依頼は既存役の設定を参照する。
レビューは未完了、V は実行不能として既存の保留経路に接続する。引き継ぎ・論点なしは既存の「判断できない」の記録を本体が代理投稿し、その URL を fresh G へ渡して G が主への確認を扱う。CI や W のテスト結果で独立レビューを代用しない。

### issue 指定の適用: claude 不在を余裕の欠測とは分ける
Claude 本体で Agent を使える従来の呼び出しは既存の選択を維持する。Codex 本体など CLI が必要な環境では、PATH の claude の実行可否を既存表より先に評価する。CLI 不在なら Codex が有効かつ代表 margin が 0 以上の場合だけ `codex-standard` を返す。Codex が負・欠測・オフなら既存の blocked JSON と exit 2 で起動前に止める。明示指定は自動選択で上書きせず、Claude が必要で実行不能なら停止する。これは issue の「専用の分岐」「Claude 本体の選択維持」の具体化であり、新たな選択閾値を設けない。

## Risks / Trade-offs
- 自動継続できる範囲が狭まる → 起動しなかった役・理由・不足する確認を記録して既存の主への確認に接続し、確認済みと記録しない。
- PATH 不在だけで Claude 本体も無効にする誤り → Claude 本体の fixture と CLI が必要な本体の fixture を分けて回帰を取る。
- 実 artifact 反映後の計画 S=23,981,760 は上限 24,000,000 に近い → 実装で読取範囲や変更量が増えたら粒度計算を更新する。入力・出力は #1859 の分割判定コメントに保存する。
