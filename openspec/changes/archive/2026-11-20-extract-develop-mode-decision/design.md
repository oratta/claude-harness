# Design

## Context

動機と範囲は proposal.md を参照。SKILL.md:238–250 と既存 spec:3276–3306 は同じ判定を文章で持ち、`develop-channel-mode.bats:71–81` はその文章を検査する。`develop-skill.bats:846–859` は、判定の直後に channel.md を読む案内が残ることを検査している。後者の動作は削らない。

`git-destructive-guard.sh:943–944` の印の読み方は Python の `.strip()` 後に空文字と `0` を除くもの。単に空白・タブだけを除く別の規則にはしない。hook 本体は読み取りだけで、source・実行・編集しない。

## Goals / Non-Goals

**Goals:** 判定の優先順と環境変数の正規化を 1 か所で実行し、開始コメントにそのまま貼れる結果を返す。手順書は呼び方・分類表と判定後の動作指示を持つ。

**Non-Goals:** モードを自動変更すること、開始コメントを自動投稿すること、channel の読み替えや再開処理をスクリプト化すること、固定注入を増やすこと、epic-dispatch.sh や hook の変更。

## Decisions

### 判定だけを独立スクリプトに移す

セッション開始注入ではなく `scripts/develop-mode.sh` を採る。引数と今回の依頼の届き方は develop の開始時に分かる情報なので、その場で呼ぶ方が責務が小さい。開始注入を足す案は hook の変更や、develop を始めないセッションにも情報を載せることにつながるため採らない。

この選択の入出力契約は以下に閉じる。

- `develop-mode.sh [--unmanned] [--channel-request]`。順不同で、各フラグは有無だけを見る。繰り返し指定も同じ結果にする。
- 本体が develop の引数に `--unmanned` を認めた場合に同名フラグを渡す。今回の依頼の発言本文が `<channel source=` で始まる場合だけ `--channel-request` を渡す。依頼本文中の引用や単なる Discord への言及では渡さない。issue 番号や別の develop 引数はこのスクリプトへ渡さない。
- 環境変数はスクリプト自身が読む。依頼本文全体を shell 引数や一時ファイルに写す API は不要とし、呼び手は届き方の 1 bit だけを渡す。判定の優先順はすべてスクリプトが持つ。
- stdout は末尾改行付きの `実行モード: <mode>（<理由>）` 1 行。正常時は stderr 空・exit 0。4 通りの全文を spec と bats に固定する。
- `--help` / `-h` 単独は呼び方、届き方フラグの条件、印の正規化、優先順と結果を stdout に出して exit 0。引数誤りは stdout 空、stderr に使い方、exit 1。モデル・GitHub・Git・状態ファイルへのアクセスは行わない。
- 印の正規化には既存 script と同じ Python 3 を使える。hook との共通関数化はしない。Python が実行できない場合も結果を既定値で捏造せず、stdout 空・stderr に理由・exit 1 とする。

実行モードを受けたあとの責務は本体に残る。新規開始時に 1 回呼び、成功した 1 行を開始コメントに記録する。判定後・引き継ぎ後に再判定しない。channel なら既存のタイミングで channel.md を Read する。失敗時はモードを推測せず stderr を添えて止まる。

### 消す説明と残す指示の境界

「モードの決め方」の見出しを保ち、判定部分を次の呼び方 1 行と分類表にする。届き方の入力条件も同じ 1 行に含める。

`scripts/develop-mode.sh [--unmanned（develop の引数にあるとき）] [--channel-request（依頼本文が <channel source= で始まるとき）]` を新規開始時に 1 回呼ぶ。

| 出力／終了 | 本体の扱い |
|---|---|
| `実行モード: interactive（既定）`、exit 0 | 出力を開始コメントへ記録して interactive で進む |
| `実行モード: channel（印）` / `実行モード: channel（チャンネルの依頼）`、exit 0 | 出力を記録し、直後の案内に従い channel.md を読む |
| `実行モード: unmanned（引数）`、exit 0 | 出力を記録して unmanned で進む |
| exit 1 | stderr を添えて報告し、推測で進めない |

削る文: 現在の「次の順で決める」と番号付き 3 段、印を printf で読む例、正規化と理由の選択肢の説明、印なし住人などの許容例の説明。これらの意味は script・help・spec・bats に残す。

残す動作指示: 開始コメントに `実行モード: <モード>（<理由>）` の行を記録すること、途中で変えないこと、引き継ぎの値を使い再判定しないこと、最後の channel.md 案内の段落全体（開始直後・引き継ぎ・コンパクト後と読むタイミング）。小節外のモード表・W/R1 の interactive 読み替え・channel の運用には触れない。

### 既存 spec と検査の対応

該当要件を MODIFIED で全文置き換え、既存 4 Scenario の名前を保つ。「SKILL.md の文面」だけはアルゴリズムの重複掲載を要求せず、呼び方・分類表・残す動作指示を検査する形に変える。他 3 Scenario の判定結果を保ち、新 script の実行テストに結び付ける。別の ADDED 要件で既存 MUST を上書きしない。

`develop-channel-mode.bats` の旧説明検査を、script の案内・フラグの入力条件・分類表と残す動作指示の検査に置き換える。優先順と値の分岐は新しい `develop-mode.bats` で実行して確かめ、grep の削除だけで対応を終えない。`develop-skill.bats` の channel.md 即時 Read の検査はそのまま通す。

### 今回出さないもの

(b) は `epic-loop.md:72,84` の本体の動作指示を維持する。`reap` の厳密な HEAD 照合に加えて行う tree 同値確認、`wait` の後の `pending-owner`・`needs-approval`・stderr と終了理由別の判断は、既存出力だけで代替できない。これらを消すと振る舞いを変えるので採らない。

(c) は `collect-parent-merge-inputs` として後続に分ける。既存の停止・マージ・委任・別 repo の入力契約の照合は (a) と独立し、(a) の成果に依存しない。今回は該当文書・script・tests を触らない。finish で (b) の不採用理由と (c) の残作業を PR 本文へ転記し、issue を閉じない。

## Risks / Trade-offs

- [呼び手が届き方のフラグを付け忘れる] → 1 行の呼び方に正確な prefix 条件を残し、その案内を文書テストで検査する。依頼本文がスクリプトに渡らないため、この認識自体を script で検証することは範囲外。
- [空白の正規化が hook とずれる] → `.strip()` と同じ規則を使い、ASCII の空白・タブ・改行と NBSP・全角空白のテストで固定する。
- [説明削除で運用指示も失う] → 上の境界で編集し、既存の開始記録・再開・channel.md 案内の文書テストを通す。
- [削減と無関係な予算も下げて失敗する] → 実測対象と変更量を記録する。startup の SKILL.md 予算は削減後の bytes へ下げる。固定注入は frontmatter 等を変えないため削減効果を主張せず、`tests/injection-budget.txt` を実測と照合する。起点 HEAD 230b839e の固定注入実測は 44,032 bytes、同予算も 44,032 で既に一致しているため、この範囲だけでは下げられず維持する。他の場面集合に SKILL.md は含まれないため、無関係な予算は下げない。各確認結果を PR 本文に示す。

## Migration Plan

状態の移行は無い。新 script と手順書を同じ PR で配布する。戻す場合はその PR を revert する。実装前に R1 の APPROVE を要する。
