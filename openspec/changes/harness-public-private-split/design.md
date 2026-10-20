## Context

- エピック #1127 の方針（2026-10-20 オーナーの決定）: 公開版は今の `oratta/claude-harness`（public）を使い続け、オーナー固有の部品を新しい private リポジトリの個人版へ移す。オーナーの環境は両方を読み、住人（オーナーの住人・客の住人）は公開版だけを読む。営業で見せる動きは公開版に置く
- 判断の基準（#1128 本文）: 公開版は誰の環境でも意味がある道具・住人のふるまいに効くもの・営業で見せる動き。個人版はオーナーに固有の業務・アカウント・資格情報の置き場・固有名に依存するもの
- 下書きの材料は flatmate #1618 本文「仕分けの下書き（2026-10-19 の調査）」。そこでの「配る」「開発用」は公開版、「出さない」は個人版の候補で、capability-registry は「要判断」だった
- 部品の現状（対象 HEAD f336d2ef）: `rules/` に 11 ファイル（`README.md` を含む）、`output-styles/readable.md`、`.claude-plugin/marketplace.json` に 10 プラグイン（worktree・weekly-report・daily-report・infra・dev-workflow・capability-registry・casting・cost-ledger・statusline・product-handover）、直下の `scripts/` に `lint.sh`・`sync.sh`・`test.sh`・`test-auto-merge-workflow.sh`・`poc/`。hooks は 5 プラグイン（capability-registry・cost-ledger・dev-workflow・statusline・worktree）の `hooks/hooks.json` にある
- エピック実行まわり（`plugins/dev-workflow/scripts/epic-dispatch.sh` の Orca の起動部品など）は #1123（Orca 依存を外す）の後に決めてよい

## Goals / Non-Goals

**Goals:**
- どの部品も漏らさず、行き先（公開版／個人版／保留（#1123 の後））と理由が 1 か所の文書で読める
- #1129 が表だけを見て移す物を決められ、#1098・#1105 が一覧だけを見て直す箇所を決められる
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

- 行は `rules/*.md` の各ファイル・`output-styles/*.md` の各ファイル・`marketplace.json` の各プラグイン・直下の `scripts/` の各項目に 1 行ずつ。hooks はそのプラグインの行に含め、行き先が割れるときは部品の行で書く
- 1 つのプラグインの中で行き先が割れるとき（capability-registry、エピック実行まわりを含む dev-workflow など）は、プラグインの行の分類を「分割」とし、その下に部品（スキル・スクリプト・hook）ごとの行を足して 3 つのどれかを書く
- 選ばなかった案: 全ファイルを 1 行ずつ。dev-workflow だけで 40 を超えるスクリプトがあり、表が読めなくなる。#1129 が要るのは行き先が割れる箇所の境界で、そこだけ細かくすれば足りる

### capability-registry は分割する（発見の仕組みは公開版、オーナーの資格情報の置き場は個人版）

- 採用: 公開版に残すのは browser-guard の hook（`scripts/browser-guard.sh`）と、スキルのうち「外部サービスを操作する前に CLI と認証確認を調べる・ブラウザに行く前に CLI 代替を確かめる」という原則と、CLI の索引（github・supabase・vercel・stripe の CLI 名と認証確認コマンド）。個人版に移すのは `scripts/fmtoken.sh`・`skills/capability-registry/1password.md`・スキルの「資格情報の階層」の表（agents 保管庫・human-only 保管庫・SA 名 `claude-agents-ro` / `claude-agents-rw`・命名規約 `<project>--<service>`）と、オーナーのプロジェクト名の例（uranai・suimei・moko など）
- 理由: browser-guard と CLI を先に調べる原則は誰の環境でも意味があり、住人のふるまい（ログインを頼む前に CLI を探す）に効き、公開版に残る `rules/browser-infra-env-capture.md` からも参照されている。fmtoken はオーナーの 1Password の保管庫と SA の構成を前提にした道具で、flatmate では `fmtoken` が出荷物に入れてはいけない語になっている
- 選ばなかった案: 丸ごと個人版。公開版の `rules/browser-infra-env-capture.md` の参照先が消え、住人からブラウザ操作の前の注意喚起も消える
- 選ばなかった案: 丸ごと公開版にして fmtoken を一般化する。保管庫の設計（read-only SA・human-only 保管庫）を一般化するのは設計変更で、#1127 の範囲（仕分けて移す）を越える
- 公開版側のスキルから fmtoken・保管庫名への参照を外す作業は、一覧に載せて #1098・#1105 に渡す（#1105 はこの分割を前提に索引の二重案内を整理する）

### 保留は「#1123 の後に何を決めるか」を書く

- 保留の行には、#1123 の結果のどこを見て決めるか（例: Orca の起動部品が差し替え可能な部品として切り出されたら公開版、Orca 固有の部品として残ったら個人版）を理由の欄に書く。保留のまま #1129 が止まらないよう、保留の行は #1129 が移す対象から外れることを文書の冒頭に書く

### 固有記述の一覧の書式

- 一覧は公開版（分割の行で公開版になった部品を含む）に残る部品だけを対象にし、1 行 1 件で `<リポジトリ相対パス>:<行>` ・種別（固有名／環境依存）・何が書かれているか・直す issue（#1098 か #1105）を書く
- 種別の境界: 固有名はオーナーのプロジェクト名・アカウント名・保管庫名・人名・オーナーのリポジトリ名。環境依存はオーナーの PC のパス・オーナーだけが持つ環境変数やサービス（Obsidian vault・Fieldy・Orca など）を前提にした記述。誰でも置き換えられる例として書かれたもの（`<project>` のような書式の説明）は載せない
- 探し方: 固有名の候補語（オーナーのリポジトリ名・プロジェクト名・`oratta`・`/Users/`・保管庫名など）で `grep` をかけ、当たった行を目で仕分ける。候補語は文書に残し、#1098 が同じ語で取りこぼしを確かめられるようにする

### flatmate #1615 への判断は子ごとに 1 行

- 対象は flatmate #1615 の 2026-10-20 のコメント（https://github.com/genetta-inc/flatmate/issues/1615#issuecomment-6279954960 ）の表の保留の子と claude-harness #1098・#1105。子ごとに「閉じる／作り直す／そのまま進める」と、表のどの行を根拠にしたかを書く
- 子の close や本文の書き換えはしない（flatmate 側の親セッションが判断に沿って行う）

### テストで網羅を守る

- `tests/public-private-split.bats` が、`rules/*.md`・`output-styles/*.md`・`marketplace.json` のプラグイン名・直下の `scripts/` の項目がすべて表に載っていること、分類の値が決めた値だけであること、理由の欄が空でないこと、一覧のパスが実在し公開版の部品に属することを確かめる
- 部品を足した PR がこの表を直し忘れるとテストが落ちるので、#1129 の後も表が古くならない

## Risks / Trade-offs

- [capability-registry の分割は #1129 の作業を増やす（1 つのプラグインを 2 つのリポジトリに割る）] → 割れる境界をファイル単位（hook・スクリプト・索引ファイル）とスキル本文の節単位で表に書き、#1129 が迷わないようにする
- [保留の行が残る間、#1129 が全部を移しきれない] → 保留は #1123 に依存する部品に限り、それ以外は全部 3 つのどれかに決める
- [表を固定のテストで守ると、部品を足すたびに表を直す手間が増える] → 足すのは 1 行で、漏れて個人版の部品が住人に届くよりは安い
- [固有記述の一覧は grep の候補語に依存し、取りこぼしうる] → 候補語を文書に残して #1098 が再検索できるようにし、一覧は #1098 の作業範囲の初版と位置づける
