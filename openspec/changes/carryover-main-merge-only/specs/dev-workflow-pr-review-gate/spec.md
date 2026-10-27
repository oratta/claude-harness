## MODIFIED Requirements

### Requirement: 前の HEAD の許容を新しい HEAD に引き継いでよい条件

pr-review-gate SKILL.md は、手順 3 で「主のリスク許容が必要」と判定したとき、手順 6 で主に聞く前に、前の HEAD で得た許容を引き継げるかを確かめる手順（手順 3-c。3-b の後ろに置く）を持たなければならない（SHALL）。前の HEAD の宣言は、同じ PR の `## リスク宣言` コメントのうち `主の回答: 許容` で始まる行（引き継ぎの形を含む）と `真正性確認: 済` の行の両方を持つ最新 1 件とし、その `対象 HEAD:` の SHA をスクリプトの前 HEAD に渡さなければならない（MUST）。3-c の冒頭には、この手順の目的を「main の取り込みや PR 自身の修正で HEAD が動いても、リスク宣言の中身（リスク内容・発生条件・影響範囲と戻し方）が前と同じなら、一度許容したリスクを主に聞き直さない」と書き、判定の基準がファイルが変わったかではなくリスクの中身が同じかであることを示さなければならない（SHALL）。引き継げるのは次のすべてを満たすときに限る（MUST）: ①`risk-carryover-check.sh` に前の HEAD・新しい HEAD・前の宣言の根拠ファイルを渡して終了コード 0 が返る、または終了コード 3 が返り、新しい HEAD で取り直したレビューが PR 全体を見た周である（最新の `レビュー重量:` コメントの `固定 HEAD:` が新しい HEAD の 40 桁 SHA と一致し、その周がゲートの開始・CI の見張りのあとの取り直し・方式の書き換え後の全体レビューのどれかで、W の修正後の差分限定の再レビューでも、戻した指摘が順 3 だけでレビューをせずに閉じた周でもない。G が周の種類を前の段の Gate Result と PR のコメントから読めないときは満たさないものとする） ②前の HEAD の宣言に根拠ファイルの行がある ③引き継ぎの元の回答が「引き継ぎの元は真正性確認済みの主の直接の回答に限る」Requirement を満たす ④新しい HEAD のリスク宣言の本文が、`対象 HEAD:` 行を除いて前の HEAD の宣言の本文（末尾の `主の回答:` 以降の追記行を除いた部分）と同一である（リスク内容・該当する観点・発生条件・影響範囲と戻し方・根拠ファイルがすべて同じであることをこの一致で確かめる）。1 つでも満たさなければ、従来どおり手順 6 で主に聞かなければならない（MUST）。ただし、スクリプトが終了コード 0 と `PR_COMMITS=0` を返したとき（前の HEAD から新しい HEAD までに積まれた commit が main を取り込む merge commit だけのとき）は、①を満たし、④を求めず、取り直しのレビューの範囲（差分限定でもよい）・`RESOLVED_OUTSIDE_ALLOWLIST=` の行の有無・判定役の判定によらず、②③を満たせば引き継がなければならない（MUST）。3-c にはこのことを書かなければならない（SHALL）。このとき投稿する宣言の本文は前の宣言の本文のままとし、新しい HEAD のレビューから組み立てた本文に置き換えてはならない（MUST NOT）。スクリプトが終了コード 4（根拠ファイルの PR 自身の差分が前後で違うか、前の HEAD のあとに積んだ merge commit でない commit が根拠ファイルに触れた）を返したときは、要件「終了コード 4 は作業の文脈を持たない判定役に比べさせる」の判定が `引き継ぎ判定: 同じ` で、かつ `RESOLVED_OUTSIDE_ALLOWLIST=` の行があるときは終了コード 3 と同じ PR 全体を見たレビューの確認を満たすときに限り、①を満たすものとする（MUST）。それ以外の終了コード 4（判定が「変わった」「判断できない」、`EVIDENCE_DIFF_LINES=` が上限を超えた、判定役を起こせない、など）は①を満たさないものとし、引き継がず手順 6 で主に聞き、`EVIDENCE_PR_CHANGED=` の行（どの根拠ファイルの PR 自身の差分が変わったか、どの根拠ファイルに PR 自身の commit が触れたか）と、判定役に比べさせなかった理由か判定の理由を、引き継げなかった理由として質問に添えなければならない（MUST）。引き継ぎで省けるのは主への質問だけで、レビュー・動作確認証拠・仕様宣言の取り直しと手順 5 の実測は省いてはならない（MUST NOT）。これは手順 1 の「手順 1 から全工程をやり直す（前回の合格部分を流用しない）」と `gate-runner.md` の再レビューの同趣旨の文に対する唯一の例外であることを、3-c に書かなければならない（SHALL）。

この引き継ぎの判定（スクリプトと G の確認と、終了コード 4 のときの判定役の判定を合わせたもの）の守備範囲は次のとおりとする:

- 入力: G 自身が手順 1 で `git fetch` と main の取り込みを済ませたローカルの git リポジトリ（前の HEAD・新しい HEAD・base）、同じ PR の前の宣言コメント（`- 根拠ファイル:`・`主の回答:`・`真正性確認:` の行）、元の直接の回答リンク、終了コード 4 のときは同じ PR の判定の記録のコメント（1 行目 `引き継ぎ判定:`）。G は協力的だが、列挙漏れと読み違いをする前提で扱う
- 拾いたい誤り: rebase・force-push による履歴の書き換え、main 以外のブランチの merge、PR 全体を見たレビューを経ていない、許可リストの条件を満たさない衝突解消（許可リスト外のファイルでの衝突解消、許可リスト内のファイルでの版の行・並べ直し以外の変更、衝突していないファイルへの手入れ）、根拠ファイルの PR 自身の差分の変更のうちリスクの中身を変えるもの（PR 自身の修正や衝突解消が根拠ファイルの PR の変更を変えたものをスクリプトが終了コード 4 で見つけ、判定役が前の宣言の本文と比べる）、PR 自身の修正が根拠ファイルの中で自分の変えた行を別の位置へ動かしただけのもの（PR 自身の差分の行の並びは前後で同じでも、PR 自身の commit が根拠ファイルに触れたのでスクリプトが終了コード 4 にし、main から来た変更だけ（`EVIDENCE_MAIN_ONLY=`）と取り違えない。判定役が前後の HEAD の差分で位置の変化を読む）、判定の記録が前後の HEAD や根拠ファイルの違う組のものであること（HEAD が動いたあとの古い判定の使い回し）、判定役の返答の 1 行目が 3 形（`引き継ぎ判定: 同じ`・`引き継ぎ判定: 変わった`・`引き継ぎ判定: 判断できない`）に一致しないもの（「判断できない」に倒す）、バイナリの根拠ファイルの変更、前後どちらの HEAD にも無い根拠ファイル、根拠ファイルの行が無い宣言からの引き継ぎ、引き継ぎの記録そのものを回答リンクにする自己参照、真正性確認のやり直しの省略。このうち、PR 全体を見たレビューを経ていないこと・許可リストの条件を満たさない衝突解消・衝突解消による根拠ファイルの PR 自身の差分の変更・バイナリの根拠ファイルの変更・merge-base が 1 つに決まらないことは、前の HEAD のあとに PR 自身の commit（merge commit でない commit）が 1 件以上積まれたときだけ拾う。main を取り込む merge commit だけのとき（`PR_COMMITS=0`）は、主の判断（issue #1329）で拾わない
- 通ることを許す入力の例: main を取り込む merge commit だけの取り込み（`PR_COMMITS=0`）で、衝突解消が許可リストの条件を満たさないもの・衝突解消が根拠ファイルの PR の変更を変えたもの・バイナリの根拠ファイルが変わったもの・新しい HEAD のレビューが差分限定の周のもの・新しい HEAD のレビューから組み立てた宣言の本文が前と違うもの（主の判断。主が許容したのはどう変わるかで、衝突しないように main を取り込むことを条件にしない。衝突解消の正しさは取り直しのレビューと CI が見る）、PR 自身の commit も積まれた取り込みで main 側が根拠ファイル以外の PR が触ったファイルを衝突なしで変えたもの（リスクの中身が変わるかは条件④で見る）、main 側が根拠ファイルを変えたが PR 自身の差分（変えた行の並び）は前後で同じ取り込み（main の変更はそれぞれのゲートを通っている）、根拠ファイルに触れない PR 自身の commit（W の修正・CI の直し。リスクの中身が変わるかは新しい HEAD のレビューから組み立てた宣言の本文を条件④で比べて見る）、根拠ファイルの PR 自身の差分を変えたが、判定役が前の宣言のリスクの中身は同じと判定した修正（例: 子プロセスを止める書き方を置き換えただけで、送るシグナルも止める対象も同じもの）、G が根拠ファイルを列挙し損ねた宣言、`"version"` を含む行の中身、CHANGELOG の並べ直しで項目の属する見出しが変わるもの、主のアカウントで代理投稿された元の回答、新しい HEAD で PR 全体を見たレビューを経た許可リストの条件を満たさない衝突解消（衝突解消の結果は PR の base との差分に現れ、そのレビューで読まれる）
- 範囲外: 代理投稿の見分け、根拠ファイルの列挙の妥当性、merge の仕方の違いによる誤検出（引き継げない側に倒れるだけ）、PR 全体を見たレビューが衝突解消の中身を見落とすこと（レビュー一般の精度の問題として扱う）、PR 自身の commit と許可リストの条件を満たさない衝突解消が重なり、新しい HEAD のレビューが差分限定の再レビューの周だったときに引き継げないこと（主に聞く側に倒れるだけ）、main 側の変更が PR のリスクの前提を変えること（主の決定で、main から入った変更だけなら聞き直さない）、main の取り込みだけのときに衝突解消が PR の変更の意味を変えること（issue #1329 で主が受け入れたリスク。取り直しのレビューと CI が見る）、PR 自身の commit も積まれたときに merge commit の衝突解消が根拠ファイルの PR の変えた行を別の位置へ動かしただけのもの（PR 自身の差分の比べ方は行の位置を見ず、merge commit は PR 自身の commit に数えないので終了コード 4 にはならない。許可リストに無い根拠ファイルなら許可リストの条件を満たさない衝突解消として終了コード 3 になり、PR 全体を見た取り直しのレビューと条件④が残る。許可リストの CHANGELOG を根拠ファイルにしたときの並べ直しは終了コード 0 のまま）、PR 自身の commit が根拠ファイルに触れたが PR 自身の差分は前後で同じもの（例: 一度変えて同じ中身に戻した上に、main が同じファイルの別の場所を変えた）が終了コード 4 になること（判定役に回るか主に聞く側に倒れるだけ）、main が PR の変えた行の近くを変えて差分の切れ目が変わり、中身が同じでも終了コード 4 になること（判定役に回るか主に聞く側に倒れるだけ）、判定役が差分を読み違えて変わったリスクを「同じ」と判定すること（issue #1238 で受け入れたリスク。条件④の本文の一致と新しい HEAD のレビューは残る）、1 回ずつは小さい引き継ぎが積もってリスクの中身が変わること（判定役はその回の差分と前の宣言の本文だけを見る）、判定の記録が本当に判定役の返答かどうか（記録の HEAD と根拠ファイルの一致だけを確かめる）、判定役の返答の 2 行目以降（理由）の妥当性。これらを塞ぐことは本要件の完了条件にしない

#### Scenario: main の取り込みだけで HEAD が動いた

- **WHEN** 主が許容した PR で、G が手順 1 で main を取り込んで HEAD が動き、スクリプトが終了コード 0 と `PR_COMMITS=0` を返し、②③を満たす
- **THEN** G は `needs-approval` を付けずに、前の宣言と同じ本文を新しい `対象 HEAD:` で出し直した宣言を投稿して手順 4・5 へ進む

#### Scenario: main の取り込みだけで、許可リストの外の衝突解消を差分限定のレビューだけが見た

- **WHEN** 主が許容した PR で、main を取り込む merge commit が `openspec/specs/x/spec.md` の衝突を解いており、ほかに積まれた commit は無く、スクリプトが `RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md` の行と `PR_COMMITS=0` とともに終了コード 0 を返し、新しい HEAD を固定 HEAD にした周は差分限定の再レビューで、②③を満たす
- **THEN** G は PR 全体を見たレビューを求めずに、`needs-approval` を付けずに引き継いだ宣言を投稿し、引き継ぎの根拠の行に終了コード 0・PR 自身の commit 0 件・許可リスト外のファイル・取り直しのレビュー「不要」を書いて手順 4・5 へ進む

#### Scenario: main の取り込みだけで、衝突解消が根拠ファイルの PR の変更を変えた

- **WHEN** 主が許容した PR で、main を取り込む merge commit が根拠ファイルの PR の変えた行の衝突を解き、PR が足した行の中身が前と変わり、ほかに積まれた commit は無く、スクリプトが `PR_COMMITS=0` とともに終了コード 0 を返し、②③を満たす
- **THEN** G は判定役を起こさず、`needs-carryover-judge` も返さずに、`needs-approval` を付けずに引き継いだ宣言を投稿して手順 4・5 へ進む

#### Scenario: main の取り込みだけで、新しい HEAD の宣言の本文が前と違う

- **WHEN** スクリプトが終了コード 0 と `PR_COMMITS=0` を返し、②③を満たし、新しい HEAD のレビューから組み立てた宣言の本文が前の宣言の本文と一致しない
- **THEN** G は条件④を求めずに引き継ぎ、投稿する宣言の本文は前の宣言の本文のままにする（新しく組み立てた本文に置き換えない）

#### Scenario: main の取り込みで根拠ファイルが動いたが PR 自身の差分は同じ

- **WHEN** 主が許容した PR で、前の HEAD のあとに根拠ファイルに触れない PR 自身の commit が積まれ、兄弟の PR がマージした変更を main から取り込んで根拠ファイルの中身が動き、スクリプトが `EVIDENCE_MAIN_ONLY=<根拠ファイル>` の行とともに終了コード 0 を返し、新しい HEAD のリスク宣言の本文が前と同じである
- **THEN** G は `needs-approval` を付けずに、引き継いだ宣言を投稿して手順 4・5 へ進む

#### Scenario: 根拠ファイルに触れない PR 自身の修正

- **WHEN** 前の HEAD のあとに W の修正の commit が積まれ、その修正は根拠ファイルに触れておらず、スクリプトが終了コード 0 を返し、新しい HEAD のリスク宣言の本文が前と同じである
- **THEN** G は `needs-approval` を付けずに、引き継いだ宣言を投稿して手順 4・5 へ進む

#### Scenario: 根拠ファイルが変わり、判定役が同じと判定した

- **WHEN** PR 自身の修正が根拠ファイルの PR の変更に触れ、スクリプトが `EVIDENCE_PR_CHANGED=<根拠ファイル>` の行とともに終了コード 4 を返し、②〜④を満たし、判定の記録の 1 行目が `引き継ぎ判定: 同じ` である
- **THEN** G は `needs-approval` を付けずに、引き継ぎの根拠の行に終了コード 4 と判定の記録のリンクを書いた宣言を投稿して手順 4・5 へ進む

#### Scenario: PR 自身の修正が根拠ファイルの行を動かしただけ

- **WHEN** 前の HEAD のあとに積んだ W の修正の commit が、根拠ファイルの中で PR が足した行を同じ本文のまま別の位置へ動かし、PR 自身の差分の行の並びは前後で同じである
- **THEN** スクリプトは `EVIDENCE_MAIN_ONLY=` を出さずに `EVIDENCE_PR_CHANGED=<根拠ファイル>` の行とともに終了コード 4 を返し、G は終了コード 0 として引き継がず、判定役の判定の記録で条件①を決める

#### Scenario: 根拠ファイルが変わった

- **WHEN** スクリプトが終了コード 4 を返し、判定の記録の 1 行目が `引き継ぎ判定: 変わった` か `引き継ぎ判定: 判断できない` である
- **THEN** 引き継げず、G は手順 6 で主に聞き直す。質問には `EVIDENCE_PR_CHANGED=` の行と判定の理由を、引き継げなかった理由として添える

#### Scenario: スクリプトが NG を出した

- **WHEN** スクリプトが `NG:` 行とともに終了コード 1 を返す（履歴の書き換え・main 以外の merge・バイナリの根拠ファイルの変更など）
- **THEN** 引き継げず、G は手順 6 で主に聞き直す。質問にはスクリプトの `NG:` 行を添える

#### Scenario: レビューで新しいリスクが見つかった

- **WHEN** 前の HEAD のあとに PR 自身の commit が 1 件以上積まれ（`PR_COMMITS=` が 1 以上）、スクリプトは終了コード 0 を返したが、新しい HEAD のレビューで観点や根拠ファイルが増え、宣言の本文が `対象 HEAD:` 行を除いて前の宣言と一致しない
- **THEN** 引き継げず、G は手順 6 で主に聞き直す

#### Scenario: 根拠ファイルの行が無い古い宣言

- **WHEN** 前の HEAD の宣言に `- 根拠ファイル:` の行が無い
- **THEN** 引き継げず、G は手順 6 で主に聞き直す

#### Scenario: 引き継いでもレビューは省かない

- **WHEN** SKILL.md の引き継ぎの手順を読む
- **THEN** 省けるのは主への質問だけで、手順 2 のレビュー・手順 4 の証拠・手順 3 の仕様宣言を新しい HEAD で出し直すこと、これが手順 1 の「前回の合格部分を流用しない」の唯一の例外であることが書かれている

#### Scenario: 前の HEAD の宣言の選び方

- **WHEN** 同じ PR に `## リスク宣言` コメントが複数あり、最新のものには `主の回答:` の行が無い
- **THEN** G は `主の回答: 許容` 系の行と `真正性確認: 済` の行の両方を持つ最新 1 件を前の宣言とし、その `対象 HEAD:` の SHA を前 HEAD としてスクリプトに渡す

#### Scenario: 許可リスト外の衝突解消を全体レビューが見た

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit が積まれ、合格処理の取り直しで main を取り込んだ merge commit が `openspec/specs/x/spec.md` の衝突を解いており、スクリプトが終了コード 3 を返し、最新の `レビュー重量:` コメントの `固定 HEAD:` が新しい HEAD で、その周が CI の見張りのあとの取り直し（PR 全体を見たレビュー）で、根拠ファイルの diff が空で、宣言の本文が同一である
- **THEN** G は `needs-approval` を付けずに引き継いだ宣言を投稿し、引き継ぎの根拠行に終了コード 3・許可リスト外のファイル・取り直しのレビューの固定 HEAD と周の種類とその `レビュー重量:` コメントのリンクを書いて手順 4・5 へ進む

#### Scenario: 許可リスト外の衝突解消を差分限定の再レビューしか見ていない

- **WHEN** 前の HEAD のあとに PR 自身の commit が積まれ、スクリプトが終了コード 3 を返したが、新しい HEAD を固定 HEAD にした周が W の修正後の差分限定の再レビュー、または戻した指摘が順 3 だけでレビューをせずに閉じた周である
- **THEN** 引き継げず、G は手順 6 で主に聞き直す。質問には `RESOLVED_OUTSIDE_ALLOWLIST=` の行と、PR 全体を見たレビューを経ていないことを理由として添える

#### Scenario: 周の種類が読めない

- **WHEN** スクリプトが終了コード 3 を返したが、G が新しい HEAD の周の種類を前の段の Gate Result と PR のコメントから読めない
- **THEN** 引き継げず、G は手順 6 で主に聞き直す

### Requirement: risk-carryover-check.sh が差分の範囲と根拠ファイルの PR 自身の差分を判定する

`plugins/dev-workflow/scripts/risk-carryover-check.sh [--base <ref>] <前 HEAD> <新 HEAD> <根拠ファイル>...` は、ローカルの git リポジトリだけを読み、pathspec をリポジトリのルート相対で解釈し（実行時の cwd によらない）、次の 4 つの条件を判定しなければならない（SHALL）: ①前の HEAD が新しい HEAD の祖先である ②`git rev-list <新> ^<前> ^<base>` のうち merge commit であるものがすべて 2 親で、第 2 親が base の祖先、第 1 親が前の HEAD かこの集合の別の commit である（merge commit でない commit は PR 自身の commit として数え、②を外れたとはしない） ③各 merge commit の衝突解消したファイル（`git merge-tree --write-tree <第1親> <第2親>` の tree と merge commit の tree で差のあるファイル。rename 検出をせず `git diff --no-renames --name-only` で列挙し、消したファイルと作ったファイルを別々に数える）が許可リストに入り中身の条件を満たす ④根拠ファイルそれぞれについて、`git diff <前> <新> -- <ファイル>` が空であるか、空でなくても**根拠ファイルの PR 自身の差分**が前後で同じで、かつ②の集合の merge commit でない commit のどれもその根拠ファイルに触れていない（その commit と親の間で、そのファイルの中身か mode に差のある commit が無い）。許可リストは、`.claude-plugin/marketplace.json` と `plugins/*/.claude-plugin/plugin.json`（`"version"` を含む行を除いた本文が第 1 親か第 2 親の版と一致する）、および `CHANGELOG.md` とサブディレクトリの `CHANGELOG.md`（merge commit の版のすべての行が第 1 親か第 2 親の版に存在する）に限る（MUST）。`--base` の既定は `origin/main` とする。

根拠ファイルの PR 自身の差分は、その HEAD と base の merge-base からその HEAD までの、そのファイルの差分とする（前は `<merge-base(前, base)>..<前>`、新は `<merge-base(新, base)>..<新>`）。前後の比較は、文脈を付けない差分（`-U0`）の、`old mode`・`new mode`・`new file mode`・`deleted file mode` の行と、最初のハンクの見出しより後ろにある削除の行・追加の行・改行なしの印の行だけを、出てくる順のまま比べ、ハンクの見出し（行番号）と差分の頭の行は比べない（MUST）。前後の diff が空でなくバイナリでもない根拠ファイルについて、前の HEAD か新しい HEAD のどちらかで base との merge-base が 1 つに決まらないときは `NG:` 行を出さなければならない（SHALL）。前後の diff が空でない根拠ファイルのうち、前後の HEAD の diff、または各 HEAD の PR 自身の差分（merge-base からその HEAD まで）のどちらかでバイナリとして扱われるもの（`git diff --numstat` の行数が `-` になるもの）は、PR 自身の差分を比べずに `NG:` 行を出さなければならない（SHALL）。前後の diff が空でなく、PR 自身の差分が同じで、②の集合の merge commit でない commit のどれも触れていない根拠ファイルは `EVIDENCE_MAIN_ONLY=<ファイル>` の行で、PR 自身の差分が違うか、②の集合の merge commit でない commit のどれかが触れた根拠ファイルは `EVIDENCE_PR_CHANGED=<ファイル>` の行で、それぞれファイルごとに 1 行出さなければならない（SHALL）。PR 自身の差分の比べ方は行の位置を見ないので、PR 自身の commit が根拠ファイルに触れたときは、PR 自身の差分が同じでも `EVIDENCE_MAIN_ONLY=` に出してはならない（MUST NOT）。前後の diff が空の根拠ファイルは、PR 自身の commit が触れていても従来どおりどちらの行にも出さない（SHALL）。

①②のどれかが外れたとき、または④でバイナリか merge-base で `NG:` が出たときは、外れた理由ごとに `NG: <理由>` 行を出し、`CARRYOVER=no` で終了コード 1 を返さなければならない（SHALL）。`NG:` 行が無く `EVIDENCE_PR_CHANGED=` の行が 1 つでもあるときは、`CARRYOVER=if-judged` で終了コード 4 を返さなければならない（SHALL）。終了コード 4 は「根拠ファイルの PR 自身の差分が前後で違うか、PR 自身の commit が根拠ファイルに触れたので、リスクの中身が同じかを git の履歴だけでは決められない」を意味し、スクリプトは引き継げるかを決めない。`NG:` 行も `EVIDENCE_PR_CHANGED=` の行も無く③だけが外れたとき（許可リストの条件を満たさない衝突解消があるとき）は、`NG:` 行にせず、許可リストの条件を満たさないファイルごとに `RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行（重複は除く）を出し、`CARRYOVER=if-rereviewed` で終了コード 3 を返さなければならない（SHALL）。ここで「許可リストの条件を満たさない」は、許可リストに無いファイル・許可リストのファイルで中身の条件を満たさないもの・衝突していないファイルへの手入れのすべてを指す。終了コード 1 と 4 のときも、③を満たさないファイルは `RESOLVED_OUTSIDE_ALLOWLIST=` の行に出す。4 つすべてを満たすときは `CARRYOVER=yes` で終了コード 0 を返さなければならない（SHALL）。終了コードの優先順は 1・4・3・0 とする（MUST）。終了コード 3 は「新しい HEAD で PR 全体を見たレビューを経ていれば引き継げる」を意味し、その確認は G が手順 3-c で行う（スクリプトはレビューの有無を見ない）。

ただし、②の集合に merge commit でない commit が 1 つも無いとき（`PR_COMMITS=0`。前の HEAD から新しい HEAD までが main を取り込む merge commit だけのとき）は、④の根拠ファイルの PR 自身の差分の比較を行わず（`EVIDENCE_MAIN_ONLY=` と `EVIDENCE_PR_CHANGED=` の行を出さず、`EVIDENCE_DIFF_LINES=0` とし、④のバイナリと merge-base の `NG:` も出さない）、①②に `NG:` が無ければ③の結果によらず `CARRYOVER=yes` で終了コード 0 を返さなければならない（SHALL）。このときも③を満たさないファイルは `RESOLVED_OUTSIDE_ALLOWLIST=` の行に出し（記録のため。終了コードには効かせない）、根拠ファイルが前の HEAD にも新しい HEAD にも無いときは終了コード 2 を返さなければならない（SHALL）。`PR_COMMITS` が 1 以上のときの判定と終了コードは上の段落のとおりとする（MUST）。

判定の守備範囲は「前の HEAD の許容を新しい HEAD に引き継いでよい条件」Requirement の守備範囲の段落に従う（スクリプトが担うのは、そこに挙げた誤りのうち commit・衝突解消・根拠ファイルの PR 自身の差分と存在に関わるもの）。出力は `CARRYOVER=yes|if-rereviewed|if-judged|no`・`MAIN_MERGES=<件数>`・`PR_COMMITS=<merge commit でない commit の件数>`・`RESOLVED_FILES=<衝突解消したファイル全件のカンマ区切り。無ければ none>`・`RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>`（該当ファイルごとに 1 行。無ければ出さない）・`EVIDENCE_MAIN_ONLY=<ファイル>`（該当ファイルごとに 1 行。無ければ出さない）・`EVIDENCE_PR_CHANGED=<ファイル>`（該当ファイルごとに 1 行。無ければ出さない）・`EVIDENCE_DIFF_LINES=<行数>`（`EVIDENCE_PR_CHANGED=` に出たファイルについての `git diff --numstat <前> <新>` の追加と削除の行数の合計。無ければ 0）と、不可の理由ごとの `NG: <理由>` 行とする。引数不足・SHA が解決できない・根拠ファイルが 1 つも無い・根拠ファイルが前の HEAD にも新しい HEAD にも無い・git が `merge-tree --write-tree` に対応しないときは終了コード 2 を返さなければならない（SHALL）。

#### Scenario: main の取り込みだけで衝突なし

- **WHEN** 前の HEAD に main を衝突なしでマージした commit だけが積まれ、根拠ファイルは変わっていない
- **THEN** 終了コード 0、`CARRYOVER=yes`、`MAIN_MERGES=1`、`RESOLVED_FILES=none` を出す

#### Scenario: 版番号と CHANGELOG の衝突解消だけ

- **WHEN** main のマージで plugin.json の `"version"` 行と CHANGELOG.md が衝突し、版の行の選び直しと CHANGELOG の項目の並べ直しだけで解消した
- **THEN** 終了コード 0 を返し、`RESOLVED_FILES` にその 2 ファイルを出す

#### Scenario: main 側の変更で根拠ファイルが変わった

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、PR が根拠ファイルの一部の行を変えており、main のマージで同じ根拠ファイルの別の場所（PR の変えた行と離れた行）が変わった
- **THEN** 終了コード 0、`CARRYOVER=yes`、そのファイルを示す `EVIDENCE_MAIN_ONLY=<ファイル>` の行を出し、`NG:` 行も `EVIDENCE_PR_CHANGED=` の行も出さない

#### Scenario: PR が触れていない根拠ファイルを main が変えた

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、PR 自身の差分に根拠ファイルが含まれず（前後とも PR はそのファイルを変えていない）、main のマージでそのファイルが変わった
- **THEN** 終了コード 0 と、そのファイルを示す `EVIDENCE_MAIN_ONLY=<ファイル>` の行を出す

#### Scenario: PR の変えた行の近くを main が変えた

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、main のマージで、PR が変えた行から 2 行離れた行（既定の差分なら文脈の 3 行に入る行）だけが衝突なしで変わり、PR が足した行・消した行そのものは前後で同じである
- **THEN** 終了コード 0 と `EVIDENCE_MAIN_ONLY=<ファイル>` の行を出す（文脈の行は比べない）

#### Scenario: main 以外の commit が積まれた

- **WHEN** 前の HEAD と新しい HEAD の間に、根拠ファイルに触れない merge commit でない commit（W の修正など）がある
- **THEN** 終了コード 0、`CARRYOVER=yes`、`PR_COMMITS=1` を出し、`NG:` 行を出さない

#### Scenario: PR 自身の commit が根拠ファイルの PR の変更を変えた

- **WHEN** 前の HEAD のあとに積んだ merge commit でない commit が、根拠ファイルの PR が変えた行を書き換えた
- **THEN** 終了コード 4、`CARRYOVER=if-judged`、そのファイルを示す `EVIDENCE_PR_CHANGED=<ファイル>` の行と、前後の diff の追加と削除の合計を示す `EVIDENCE_DIFF_LINES=<行数>` を出し、`NG:` 行を出さない

#### Scenario: PR 自身の commit が根拠ファイルの自分の行を別の位置へ動かしただけ

- **WHEN** 前の HEAD のあとに積んだ merge commit でない commit が、根拠ファイルの中で PR が足した行を同じ本文のまま別の位置へ動かし、PR 自身の差分の削除・追加の行の並びは前後で同じである
- **THEN** 終了コード 4、`CARRYOVER=if-judged`、そのファイルを示す `EVIDENCE_PR_CHANGED=<ファイル>` の行を出し、`EVIDENCE_MAIN_ONLY=` の行も `NG:` 行も出さない

#### Scenario: PR 自身の commit が根拠ファイルを変えて戻し、main も同じファイルを変えた

- **WHEN** 前の HEAD のあとに、根拠ファイルを一度変えてから同じ中身に戻す 2 つの merge commit でない commit を積み、さらに main のマージで同じ根拠ファイルの別の場所が変わった（PR 自身の差分は前後で同じ）
- **THEN** 終了コード 4 と、そのファイルを示す `EVIDENCE_PR_CHANGED=<ファイル>` の行を出す（PR 自身の commit が触れた根拠ファイルは main から来た変更だけと扱わない）

#### Scenario: 根拠ファイルに触れない PR 自身の commit と main の根拠ファイルの変更が重なった

- **WHEN** 前の HEAD のあとに根拠ファイル以外のファイルだけを変える merge commit でない commit を積み、main のマージで根拠ファイルの PR が変えた行と離れた場所が変わった
- **THEN** 終了コード 0、`CARRYOVER=yes`、`PR_COMMITS=1`、そのファイルを示す `EVIDENCE_MAIN_ONLY=<ファイル>` の行を出す

#### Scenario: PR 自身の commit が根拠ファイルの変更を元に戻した

- **WHEN** 前の HEAD のあとに、根拠ファイルを一度変えてから同じ中身に戻す 2 つの commit を積んだ
- **THEN** 前後の diff が空なので終了コード 0 を返す

#### Scenario: 衝突解消が根拠ファイルの PR の変更を変えた

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、main のマージで根拠ファイルの PR が変えた行が衝突し、解消した結果、PR が足した行の中身が前と変わった
- **THEN** 終了コード 4 と、そのファイルを示す `EVIDENCE_PR_CHANGED=<ファイル>` の行を出す

#### Scenario: main の取り込みだけで、衝突解消が根拠ファイルの PR の変更を変え、許可リストの外でもある

- **WHEN** 前の HEAD のあとに積まれた commit が main を取り込む merge commit 1 つだけで、その merge commit が根拠ファイル（許可リストに無いファイル）の PR が変えた行の衝突を解き、PR が足した行の中身が前と変わった
- **THEN** 終了コード 0、`CARRYOVER=yes`、`PR_COMMITS=0`、そのファイルを示す `RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行を出し、`EVIDENCE_PR_CHANGED=` の行も `EVIDENCE_MAIN_ONLY=` の行も `NG:` 行も出さず、`EVIDENCE_DIFF_LINES=0` を出す

#### Scenario: main の取り込みだけで、許可リストの外のファイルで衝突解消した

- **WHEN** 前の HEAD のあとに積まれた commit が main を取り込む merge commit だけで、その merge commit が許可リストに無いファイル（例 `openspec/specs/x/spec.md`）の衝突を解いた
- **THEN** 終了コード 0、`CARRYOVER=yes`、`PR_COMMITS=0` と、そのファイルを示す `RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行を出す

#### Scenario: main の取り込みだけで、バイナリの根拠ファイルが変わった

- **WHEN** 前の HEAD のあとに積まれた commit が main を取り込む merge commit だけで、main 側の変更でバイナリの根拠ファイルの中身が前後で変わった
- **THEN** 根拠ファイルの PR 自身の差分を比べずに、終了コード 0、`CARRYOVER=yes`、`PR_COMMITS=0` を出し、`NG:` 行を出さない

#### Scenario: merge commit だけでも、main 以外のブランチの merge は通さない

- **WHEN** 前の HEAD のあとに積まれた commit が merge commit だけで、そのうち 1 つの第 2 親が base の祖先でない
- **THEN** 終了コード 1、`CARRYOVER=no` と、その merge commit を示す `NG:` 行を出す

#### Scenario: バイナリの根拠ファイルが変わった

- **WHEN** 前の HEAD のあとに PR 自身の commit が積まれ、根拠ファイルがバイナリで、前後の HEAD で中身が違う
- **THEN** 終了コード 1、`CARRYOVER=no` と、そのファイルを示す `NG:` 行を出す

#### Scenario: merge-base の版ではバイナリの根拠ファイル

- **WHEN** 根拠ファイルが merge-base の版ではバイナリで、PR がそのパスをテキストに置き換えており、前の HEAD のあとに PR 自身の commit でそのテキストを書き換えた
- **THEN** PR 自身の差分を比べずに、終了コード 1、`CARRYOVER=no` と、そのファイルを示す `NG:` 行を出す

#### Scenario: PR 自身の commit が根拠ファイルの mode だけを変えた

- **WHEN** 前の HEAD のあとに積んだ merge commit でない commit が、根拠ファイルの中身を変えずに mode だけを変えた（例: 実行権を付けた）
- **THEN** 終了コード 4 と、そのファイルを示す `EVIDENCE_PR_CHANGED=<ファイル>` の行を出す

#### Scenario: merge-base が 1 つに決まらない

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、PR に main をマージし、main にも PR の commit をマージして（criss-cross merge）、新しい HEAD と base の merge-base が 2 つになり、main 側の変更で根拠ファイルが前後で変わった
- **THEN** 終了コード 1、`CARRYOVER=no` と、merge-base が 1 つに決まらないことを示す `NG:` 行を出す

#### Scenario: 根拠ファイルの PR 自身の差分の変更と許可リスト外の衝突解消が重なった

- **WHEN** 前の HEAD のあとに PR 自身の commit が積まれ、`EVIDENCE_PR_CHANGED=` に当たる根拠ファイルがあり、同じ取り込みで許可リストに無いファイルでも衝突を解いた
- **THEN** 終了コード 4 を返し、`EVIDENCE_PR_CHANGED=` の行と `RESOLVED_OUTSIDE_ALLOWLIST=` の行の両方を出す

#### Scenario: main 以外のブランチの merge が積まれた

- **WHEN** 前の HEAD のあとに、第 2 親が base の祖先でない merge commit がある
- **THEN** 終了コード 1、`CARRYOVER=no` と、その merge commit を示す `NG:` 行を出す

#### Scenario: 許可リスト外のファイルで衝突解消した

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、merge commit が許可リストに無いファイル（例 `openspec/specs/x/spec.md`）で自動マージの結果と違う中身になっており、根拠ファイルの diff は空で、ほかに `NG:` に当たるものが無い
- **THEN** 終了コード 3、`CARRYOVER=if-rereviewed`、そのファイルを示す `RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行を出し、`NG:` 行を出さない

#### Scenario: 許可リスト外の衝突解消と根拠ファイルの変更が重なった

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、merge commit が許可リストに無いファイルで衝突を解き、同じ取り込みで main 側の変更により根拠ファイルの中身も変わったが、根拠ファイルの PR 自身の差分は前後で同じである
- **THEN** 終了コード 3、`CARRYOVER=if-rereviewed` を出し、`RESOLVED_OUTSIDE_ALLOWLIST=` の行と `EVIDENCE_MAIN_ONLY=` の行の両方を出す

#### Scenario: 衝突していないファイルに merge commit の中で手を入れた

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、merge commit が、衝突していないファイルを自動マージの結果と違う中身にしている
- **THEN** 終了コード 3 と、そのファイルを示す `RESOLVED_OUTSIDE_ALLOWLIST=` の行を出す

#### Scenario: 許可リストの JSON で版以外の行を変えた

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、merge commit の plugin.json が、`"version"` 行を除いても第 1 親・第 2 親のどちらの版とも一致しない
- **THEN** 終了コード 3 と、その plugin.json を示す `RESOLVED_OUTSIDE_ALLOWLIST=` の行を出す

#### Scenario: CHANGELOG に新しい文を足した

- **WHEN** 前の HEAD のあとに根拠ファイルに触れない PR 自身の commit も積まれ、merge commit の CHANGELOG.md に、第 1 親にも第 2 親にも無い行がある
- **THEN** 終了コード 3 と、その CHANGELOG.md を示す `RESOLVED_OUTSIDE_ALLOWLIST=` の行を出す

#### Scenario: 許可リスト外のファイルを消して似たファイルを作った

- **WHEN** merge commit の中で許可リストに無いファイルを消し、それとよく似た中身のファイルを別の名前で作った（git の rename 検出なら 1 件の rename に見える）
- **THEN** 消したファイルも `RESOLVED_FILES` と `RESOLVED_OUTSIDE_ALLOWLIST=` の行に出る

#### Scenario: 根拠ファイルがどちらの HEAD にも無い

- **WHEN** 前の HEAD にも新しい HEAD にも存在しないパスを根拠ファイルとして渡す（誤字など）
- **THEN** 終了コード 2 を返し、標準エラーにそのパスを出す

#### Scenario: サブディレクトリから実行する

- **WHEN** リポジトリのサブディレクトリを cwd にして、ルート相対の根拠ファイルのパスを渡して呼ぶ
- **THEN** ルートから呼んだときと同じ判定になる（PR 自身の commit が根拠ファイルの PR の変更を変えていれば終了コード 4）

#### Scenario: 前の HEAD が祖先でない

- **WHEN** 新しい HEAD が前の HEAD を含まない（rebase や force-push で履歴が書き換わった）
- **THEN** 終了コード 1 を返す

#### Scenario: 根拠ファイルが渡されない

- **WHEN** 根拠ファイルを 1 つも渡さずに呼ぶ
- **THEN** 終了コード 2 を返す
