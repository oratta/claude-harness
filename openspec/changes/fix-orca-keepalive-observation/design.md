# Design

## Context

背景は proposal.md を参照。現行コードの分類器は `result.tail` / `source` / `draft` を読む。送信後は busy の分類結果と、古い `result.draft` が空であることを組み合わせているため、実際の入力欄を独立には確認できない。`turn_started` は JSON 内の stages 配列を再帰探索しており、既に入れ子の配列を扱う。

仕様段でローカル CLI の `orca --version`（1.4.263）、`terminal read --help`、`terminal send --help` と、この worktree の端末の read を確認した。read のキーは `result.terminal`、その中に `tail: string[]`、`source: screen` があり、`draft` は無かった。ヘルプでは draft は任意の UI composer text で、tail に含まれないとされる。status の running は前景の実行状態を表さない。

実際の末尾は、上罫線・`❯`・下罫線・複数のカスタム statusline・`⏵⏵ bypass permissions on · 1 shell · ← 3 agents · ↓ to manage` で、既存 fixture の `? for shortcuts` は無かった。画面の本文や個人のパスをこの設計には複写しない。send は仕様段では実行しておらず、応答の実測は実装段の声かけ確認で行う。

## Goals / Non-Goals

**Goals:** 現行 Orca の読み取り構造と実測の画面枠を扱い、入力済みの欄を壊さず、未確認の送信を成功としない。構造の不一致を transport の失敗と見分けられるようにする。

**Non-Goals:** tmux の観測コードや運用手順、状態の記録形式、返事の分類、起動し直し、TTL / トークン閾値の変更。旧 `result.tail` 形式へのフォールバックや、未知の Claude Code 画面を推測して送る互換層も作らない。

## Decisions

### 画面を空欄の主な証拠にし、任意の draft を併せて確認する

`result.terminal` が object、tail が文字列の配列であることを確かめ、source が screen のときだけ画面として解釈する。source が欠落・stream・screen-unavailable の場合は `skipped unknown-state` とする。draft は欠落を許し、存在すれば文字列だけを受け付ける。非空なら、画面が空でも `skipped input-not-empty` とする。

draft が欠落していても空欄とは決めず、既存の罫線・プロンプト・フッターによる入力領域全体の判定を使う。Orca では薄字の提案も入力扱いを保つ。複数行の入力、空行のあとの入力、本文中のプロンプトやフッターに似た文字を捨てない。複数の開始枠は曖昧として扱う。

Orca の画面枠に限り、既知の shortcuts / cycle / manual-mode フッターに加え、実測の bypass-permissions フッターを入力枠末尾の証拠として認める。bypass フッターは `⏵⏵ bypass permissions on` に `(shift+tab to cycle)`、`·` で始まる操作案内がこの順に続く形を扱い、どちらも省略を許す。下罫線とフッターの間にカスタム statusline が複数あってよい。statusline の内容を設定値として固定しない。

bypass フッターの下にエージェント一覧が続く実測形も扱う。ANSI 装飾と空行を除いた観測で bypass フッターが一つだけあり、その後の全行が、先頭の `⏺ main` と、それに続く一行以上の `◯ <空白を含まない名前><2 文字以上の空白><空でない状態表示>` なら、その一覧だけを末尾判定から除外する。各行の前後の空白は許す。一覧が無ければ従来どおりフッター自体を最終可視行とする。既知の一覧を除外しても、一意な入力枠全体と任意の draft の空欄検査は省かない。main 行の欠落、未知の行、既知の行形式に合わない折り返し、末尾のシェル表示などは除外せず、他の busy / dialog / 非空 draft の判定が無ければ `skipped unknown-state` とする。任意の一覧を読み飛ばす案は、古い Claude 画面を入力待ちと誤認し得るため採らない。

busy / dialog の検出は一覧を除外する前の観測全体に適用する。送信前は、行頭の既知の記号（`✻✽✶✢✳✺` のいずれか）と `Waiting for N background agent` または `agents`、任意の ` to finish` からなる待機行も `skipped busy` とする（行頭・行末の空白を許す）。スピナーや `esc to interrupt` が無く、空の入力欄と既知の一覧が同居しても送らない。一覧内の `Waiting for parent reply` などの状態表示だけでは、この待機行とはみなさない。

代案の「draft 欠落を空欄扱い」は実際の入力を見逃す。「Orca の別フィールドだけで判定」は、現行ヘルプと実測に入力テキストを必ず返すフィールドが無いため採らない。tmux の部品を呼び出すのではなく、Orca スクリプト内の既存の画面判定を再利用・調整する。

### 送信前と送信後で同じ観測を使い、到達確認を保守的にする

初回と送信直前の read が両方 ready のときだけ 1 回 send する。send の成功 exit と、現行 receipt の stages 配列にある `turn_started` を到達の第一の証拠にする。現在の再帰探索で実測 receipt が通る場合は、共用関数をむやみに変更しない（start / deliver にも使われる）。input_accepted、queued、provider unsupported だけでは成功にしない。

ターン開始を確認できない場合の既存の補助経路は保ち、1 回だけ再観測する。ただし busy の分類と空欄の証明を分ける。送信前は busy でなく、送信後には前景の実行中を観測し、同じ画面枠によって入力領域全体が空で、任意の draft も空であると確認できた場合だけ sent にする。バックグラウンドエージェントの待機行だけでは新しい前景ターンの開始の証拠にしない。既知の一覧がある画面でも、前景の実行中表示と空欄の両方を必要とする。busy 判定が先に return して空欄検査を飛ばす構造を成功確認に使わない。

代案の「turn_started だけを認める」は既存の unsupported-provider で到達した場合を失敗扱いにする。「送信 exit 0 / draft 欠落だけで成功」は未送信を成功にするため採らない。返事と cache hit は送信の確認とは別に実機で確認する。

### stdout を保ち、構造の不一致は stderr に出す

JSON 不正、result / terminal / tail の欠落や型違い、任意の draft の型違いは、送信前なら stdout `failed observe` / exit 1 に加えて stderr に `failed observe shape` と期待するフィールドを出す。送信後の見直しで起きた場合も同じ診断を出し、stdout は既存の `failed send` / exit 1 とする。画面全体は出さない。

結果語に shape を付ける代案では dispatch の記録・help などにも変更が及ぶため、issue が許す stderr の経路を選ぶ。呼び出し元の結果記録や通常の skipped の出力は保つ。

## Risks / Trade-offs

- 画面テーマ・フッター変更で送れなくなる → 実測 fixture と既存の分類 matrix を併用し、未知は unknown-state に倒す。任意の表示を全て認識することは目標にしない。
- 観測後に主が入力する競合、または別の入力が偶然ターンを始める可能性 → 送信直前の再観測と空欄検査を保つ。CLI だけで原子的な排他は保証できない。
- send 後すぐに返事が終わり busy を観測できない → turn_started が無ければ failed send に倒す。同じ呼び出しでは再送しない。
- 合成 fixture だけでは実際の構造変更を見逃す → バージョンと取得コマンドを添えた実測 read fixture をテスト内に 1 件保存し、send receipt も実装段で実測と照合する。識別子や個人のパスを匿名化しても JSON の構造・型・画面枠は保つ。

## Migration Plan

仕様レビュー後、Orca の部品と tests の 2 ファイルを変更する。bats と実機確認を行い、#1728 に子の識別子・送信結果・予約文と返事・次の request の usage の根拠を記録する。声かけを行うには実際の停止中の子、共通定義の固定文、その会話ログが必要で、仕様段の read 成功だけでは受け入れ完了としない。条件が無い場合は未検証として引き継ぐ。

切り戻しはこの実装の revert で行う。状態の記録形式と閾値を変えないためデータ移行は不要。
