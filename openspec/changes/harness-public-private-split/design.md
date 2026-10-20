## Context

- エピック #1127 の方針（2026-10-20 オーナーの決定）: 公開版は今の `oratta/claude-harness`（public）を使い続け、オーナー固有の部品を新しい private リポジトリの個人版へ移す。オーナーの環境は両方を読み、住人（オーナーの住人・客の住人）は公開版だけを読む。営業で見せる動きは公開版に置く
- 判断の基準（#1128 本文）: 公開版は誰の環境でも意味がある道具・住人のふるまいに効くもの・営業で見せる動き。個人版はオーナーに固有の業務・アカウント・資格情報の置き場・固有名に依存するもの
- 下書きの材料は flatmate #1618 本文「仕分けの下書き（2026-10-19 の調査）」。そこでの「配る」「開発用」は公開版、「出さない」は個人版の候補で、capability-registry は「要判断」だった
- 部品の現状（対象 HEAD f336d2ef）: `rules/` に 11 ファイル（`README.md` を含む）、`output-styles/readable.md`、`.claude-plugin/marketplace.json` に 10 プラグイン（worktree・weekly-report・daily-report・infra・dev-workflow・capability-registry・casting・cost-ledger・statusline・product-handover）、直下の `scripts/` に `lint.sh`・`sync.sh`・`test.sh`・`test-auto-merge-workflow.sh`・`poc/`。hooks は 5 プラグイン（capability-registry・cost-ledger・dev-workflow・statusline・worktree）の `hooks/hooks.json` にある
- エピック実行まわり（`plugins/dev-workflow/scripts/epic-dispatch.sh` の Orca の起動部品など）は #1123（Orca 依存を外す）の後に決めてよい

## Goals / Non-Goals

**Goals:**
- どの部品も漏らさず、行き先（公開版／個人版／保留（#1123 の後））と理由が 1 か所の文書で読める
- #1129 が表だけを見て移す物を決められ、#1098・#1105 と新しい子 issue（capability-registry の公開版から fmtoken の参照を外す。下の Decisions）が一覧だけを見て直す箇所を決められる
- capability-registry の置き場を決め、選ばなかった案を残す
- flatmate #1615 の保留の子の扱いを、表に基づいて決めて伝える

**Non-Goals:**
- 部品の移動・書き換え・private リポジトリの作成（#1129）、固有記述の除去（#1098）、索引の二重案内の整理（#1105）、両方を読む仕組み（#1130）
- `docs/`・`tests/`・`openspec/` の仕分け（それぞれが説明・検査している部品に従って #1129 で動かす。表には載せない）
- flatmate 側の子 issue の close・本文の書き換え（#1615 へのコメントで判断を伝えるところまで）

## Decisions

### 表の置き場は `docs/public-private-split.md`

- 採用: 新しい文書 `docs/public-private-split.md` に表と一覧を置き、spec（`harness-public-private-split`）は文書が満たすべき条件（網羅・分類の値・理由・一覧の書式）だけを持つ
- 選ばなかった案: 表を spec の要件の本文に直接書く。表は #1129 の作業で行き先が変わるたびに直す生きた資料で、spec の要件として凍結すると直すたびに change が要る。逆に「漏れなく載っている」「値が 3 つのどれか」は凍結してテストで守る価値がある
- 選ばなかった案: flatmate 側（`docs/client-package.md`）に置く。部品の持ち主は Harness で、#1129・#1098 はこのリポジトリで動く

### 行の単位はプラグイン。行き先が割れるプラグインだけ部品の行を足す

- 行は `rules/*.md` の各ファイル・`output-styles/*.md` の各ファイル・`marketplace.json` の各プラグイン・直下の `scripts/` の各項目に 1 行ずつ。分割しないプラグインは、hooks を含めてそのプラグインの行 1 行で全体の行き先が決まる
- 1 つのプラグインの中で行き先が割れるとき（capability-registry、エピック実行まわりを含む dev-workflow など）は、プラグインの行の分類を「分割」とし、その下の部品の行で**プラグインの全ファイルを重複なく覆う**。境界の規則（正本は spec「分割したプラグインは部品の行で全体を重複なく覆う」）:
  - 部品の欄はファイルのパス・ディレクトリのパス（末尾 `/`）・Markdown の節（`<パス>#<## の見出し>`）のどれか
  - ファイルの行き先は、当てはまる行のうちいちばん深いパスの行で決める（例: `plugins/dev-workflow/scripts/` を公開版にし、`plugins/dev-workflow/scripts/epic-dispatch.sh` だけを保留にする）。同じパスの行は置かない
  - 節で分けた Markdown は `## ` の見出しをすべて節の行で 1 回ずつ覆い、ファイルの行と併置しない
  - 付属のファイル（`.claude-plugin/plugin.json`・`changes/`・`tests/`・`README.md`・`CHANGELOG.md`・`hooks/hooks.json`）は行で覆わず、記録・検査・配線している部品に従う。ファイルの中で行き先が割れる付属（dev-workflow の `hooks/hooks.json` の中のエピック実行まわりの配線など）の書き分けは #1129 で行う
- この規則なら、テストが `git ls-files` からファイルを列挙して各ファイルの行を 1 つに決められ、行を落とせば行の決まらないファイルとして名前つきで落ちる。#1129 は表から「どのファイルを移すか」を機械的に引ける
- 選ばなかった案: 全ファイルを 1 行ずつ。dev-workflow だけで 40 を超えるスクリプトがあり、表が読めなくなる。ディレクトリの行といちばん深いパスの規則で、例外のファイルだけを個別に書けば足りる
- 選ばなかった案: 「分割」の下に部品の行が 1 行以上あればよいとする。残りの部品を落としても検出できず、#1129 が移す範囲を決められない（R1 1 周目の指摘）
- 選ばなかった案: hooks.json のエントリも行で覆う。エントリは配線先のスクリプトの行き先で決まり、別に書くと 2 か所で食い違いうる

### capability-registry は分割する（発見の仕組みは公開版、オーナーの資格情報の置き場は個人版）

- 採用: 公開版に残すのは browser-guard の hook（`scripts/browser-guard.sh`）と、スキルのうち「外部サービスを操作する前に CLI と認証確認を調べる・ブラウザに行く前に CLI 代替を確かめる」という原則と、CLI の索引（github・supabase・vercel・stripe の CLI 名と認証確認コマンド）。個人版に移すのは `scripts/fmtoken.sh`・`skills/capability-registry/1password.md`・スキルの「資格情報の階層」の表（agents 保管庫・human-only 保管庫・SA 名 `claude-agents-ro` / `claude-agents-rw`・命名規約 `<project>--<service>`）と、オーナーのプロジェクト名の例（uranai・suimei・moko など）
- 理由: browser-guard と CLI を先に調べる原則は誰の環境でも意味があり、住人のふるまい（ログインを頼む前に CLI を探す）に効き、公開版に残る `rules/browser-infra-env-capture.md` からも参照されている。fmtoken はオーナーの 1Password の保管庫と SA の構成を前提にした道具で、flatmate では `fmtoken` が出荷物に入れてはいけない語になっている
- 選ばなかった案: 丸ごと個人版。公開版の `rules/browser-infra-env-capture.md` の参照先が消え、住人からブラウザ操作の前の注意喚起も消える
- 選ばなかった案: 丸ごと公開版にして fmtoken を一般化する。保管庫の設計（read-only SA・human-only 保管庫）を一般化するのは設計変更で、#1127 の範囲（仕分けて移す）を越える
- 部品の行（境界の規則に従う）: `scripts/browser-guard.sh` 公開版、`scripts/fmtoken.sh` 個人版、`skills/capability-registry/1password.md` 個人版、`skills/capability-registry/{github,supabase,stripe,vercel}.md` 公開版、`SKILL.md` は節で分け、「表記規約」「原則」「索引（1 サービス 1 行）」「CLI が無いサービス（ネガティブエントリ）」「新サービスの追加」を公開版、「資格情報の階層」を個人版にする（実装時に見出しを読み直し、この割り当てと食い違えば文書に理由を書いて直す）

#### 公開版に残る部品から個人版への参照を外す作業（この change では直さない）

公開版に残す部品は、いまの仕様と実ファイルが `fmtoken.sh`（個人版へ移す）の案内を必須にしている。参照を外さないまま `fmtoken.sh` を移すと、公開版の hook と索引が存在しない道具を案内する。対象（対象 HEAD f336d2ef の時点。実装時に `grep -rn fmtoken` で確かめ直して文書に載せる）:

| 対象 | いま書かれていること |
|---|---|
| `plugins/capability-registry/scripts/browser-guard.sh:31` | 注意喚起の (2) が「トークンは fmtoken.sh で取れないか」 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md` の「原則」と「索引」 | トークンの取得を `fmtoken.sh <service>` で案内（13 か所） |
| `skills/capability-registry/{github,supabase,stripe,vercel}.md` | `fmtoken.sh` での取得手順 |
| `plugins/capability-registry/tests/browser-guard.bats:59`・`tests/skill-registry.bats:43-44` | 出力と SKILL.md に `fmtoken` があることを検査 |
| `plugins/capability-registry/.claude-plugin/plugin.json` | description と keywords に fmtoken |
| `plugins/dev-workflow/references/self-verification.md:53` | `fmtoken.sh --register` を名指し |
| `openspec/specs/capability-registry-browser-guard/spec.md`「hook は deny ではなく注意喚起から始める」 | メッセージに `fmtoken.sh` の存在を含めることが SHALL |
| `openspec/specs/capability-registry-skill/spec.md`「索引は 1 サービス 1 行で 1 画面以内を維持する」 | 各行のトークン取得方法を `fmtoken.sh <service>` と書くことが SHALL |

担い手: 既存の issue の範囲に収まらない。#1098 の範囲は `rules/` の 5 本と `output-styles/readable.md` で、capability-registry の hook とサービス別索引を含まない。#1105 の範囲は flatmate の住人で索引と案内を二重にしないことで、`fmtoken.sh` の参照を外すことを含まない。#1129 は「個人版の部品と固有名が公開版から無くなる」ことを受け入れ条件に持つが、本文は「移す」作業で、公開版の hook の文言と既存仕様の要件を書き換えることは書いていない。そこで **新しい子 issue が要る**（エピック #1127 の子。この change では作らず、後続の issue の本文も書き換えない。本体に知らせる）。その子は次を受け持つ:

- 上の表の参照を、公開版では「トークンの在処はオーナーの環境の索引（個人版）があればそちらを見る」のような個人版の有無に依らない書き方に直し、`fmtoken.sh` の案内は個人版の側（#1130 で重ねて読む）に移す
- 既存仕様の要件の更新（`capability-registry-browser-guard`・`capability-registry-skill` の上の 2 要件の MODIFIED と、`capability-registry-fmtoken` を個人版へ移すか REMOVED にするか）は、その子の openspec change で行う
- 時期: #1129 が `fmtoken.sh` を公開版から消すより前か同じ PR で着地させる（後になると、公開版が存在しない道具を案内する期間ができる）。依存は「#1128 の後・#1129 の前」

一覧（固有記述の一覧）には、上の行を「直す issue: 新しい子 issue（未作成）」として載せる

### 保留は「#1123 の後に何を決めるか」を書く

- 保留の行には、#1123 の結果のどこを見て決めるか（例: Orca の起動部品が差し替え可能な部品として切り出されたら公開版、Orca 固有の部品として残ったら個人版）を理由の欄に書く
- 確定する人と時期: #1129 は #1123 に依存するので、#1129 の着手時には #1123 が終わっている。#1129 の担い手が着手時に #1123 の結果を見て保留の行を 3 つのどれかに確定し、#1129 の PR でこの表を直してから移す。文書の冒頭にこれを書く（保留のまま #1129 が止まらない）

### 固有記述の一覧の書式

- 一覧は公開版（分割の行で公開版になった部品を含む）に残る部品だけを対象にし、1 行 1 件で `<リポジトリ相対パス>:<行>` ・種別（固有名／環境依存）・何が書かれているか・直す issue（#1098・#1105・新しい子 issue（未作成）のどれか。#1098 は `rules/` と `output-styles/` の 6 本、#1105 は flatmate の住人での索引と案内の二重、それ以外の capability-registry の fmtoken の参照は新しい子 issue）を書く。どの範囲にも当たらない行は「担い手なし」と書き、本体に知らせる
- 種別の境界: 固有名はオーナーのプロジェクト名・アカウント名・保管庫名・人名・オーナーのリポジトリ名。環境依存はオーナーの PC のパス・オーナーだけが持つ環境変数やサービス（Obsidian vault・Fieldy・Orca など）を前提にした記述。誰でも置き換えられる例として書かれたもの（`<project>` のような書式の説明）は載せない
- 探し方: 固有名の候補語（オーナーのリポジトリ名・プロジェクト名・`oratta`・`/Users/`・保管庫名など）で `grep` をかけ、当たった行を目で仕分ける。候補語は文書に残し、#1098 が同じ語で取りこぼしを確かめられるようにする

### flatmate #1615 への判断は子ごとに 1 行

- 対象は flatmate #1615 の 2026-10-20 のコメント（https://github.com/genetta-inc/flatmate/issues/1615#issuecomment-6279954960 ）の表の保留の子と claude-harness #1098・#1105。子ごとに「閉じる／作り直す／そのまま進める」と、表のどの行を根拠にしたかを書く
- 子の close や本文の書き換えはしない（flatmate 側の親セッションが判断に沿って行う）

### テストで網羅を守る

- `tests/public-private-split.bats` が、`rules/*.md`・`output-styles/*.md`・`marketplace.json` のプラグイン名・直下の `scripts/` の項目がすべて表にちょうど 1 行あること、分割のプラグインの全ファイル（付属を除く）がいちばん深いパスの規則で 1 行に決まること、節の行が見出しを 1 回ずつ覆うこと、どのファイルにも当たらない行が無いこと、分類の値が決めた値だけであること、理由の欄が空でないこと、一覧のパスが実在し行番号が行数以内で公開版に決まる部品に属することを確かめる
- 部品を足した PR がこの表を直し忘れるとテストが落ちるので、#1129 の後も表が古くならない
- 表は Markdown の表として読み、列は「部品」「分類」「理由」に固定する（テストが列の位置で読むため。列名も文書の冒頭とテストで揃える）

#### 守備範囲（正本は spec「表と一覧の検査の守備範囲」）

- 入力の出どころ: 表と一覧は実装の担い手が部品を読んで手で書く。テストはそれを、実行時点の `git ls-files`・`rules/*.md`・`output-styles/*.md`・`marketplace.json` の `plugins[].name`・直下の `scripts/`・Markdown の `## ` 見出しと突き合わせる。突き合わせる相手はテストが自分で列挙し、文書から取らない
- 拾う誤り: 表に無い部品・同じ部品の 2 行・どのファイルにも当たらない行・分割のプラグインで行の決まらないファイル・節の行の覆い漏れと重複・決めた値以外の分類・空の理由・実在しないパスや行数を超える行番号の一覧の行・公開版に決まらない部品を指す一覧の行
- 通してよい具体例: 分類の判断の誤り、中身の薄い理由、候補語に当たらない固有記述の取りこぼし、あとの編集でずれたが行数以内に収まる行番号。これらは仕様レビュー・pr-review-gate と #1098 の再検索が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない。検査の目的は、表を直し忘れた PR と、#1129 が移す範囲を引けない表を落とすことで、仕分けの正しさの保証ではない

## Risks / Trade-offs

- [capability-registry の分割は #1129 の作業を増やす（1 つのプラグインを 2 つのリポジトリに割る）] → 割れる境界をファイル単位（hook・スクリプト・索引ファイル）とスキル本文の節単位で表に書き、#1129 が迷わないようにする
- [保留の行が残る間、#1129 が全部を移しきれない] → 保留は #1123 に依存する部品に限り、それ以外は全部 3 つのどれかに決める
- [表を固定のテストで守ると、部品を足すたびに表を直す手間が増える] → 足すのは 1 行で、漏れて個人版の部品が住人に届くよりは安い
- [固有記述の一覧は grep の候補語に依存し、取りこぼしうる] → 候補語を文書に残して #1098 が再検索できるようにし、一覧は #1098 の作業範囲の初版と位置づける
- [capability-registry の公開版から fmtoken の参照を外す担い手が既存の issue に無い] → design に新しい子 issue が要ることと受け持つ範囲・時期（#1129 より前か同じ PR）を書き、本体に知らせる。子 issue を作るかどうかと作る時期は本体とエピックの親が決める
