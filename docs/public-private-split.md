# 公開版と個人版の仕分け

エピック #1127 の方針（2026-10-20 オーナーの決定）で、公開版は今の `oratta/claude-harness`（public）を使い続け、オーナーに固有の部品を新しい private リポジトリの個人版へ移す。この文書は、どの部品をどちらに置くかの表と、公開版に残る部品の中の固有記述の一覧を持つ。表は #1129（部品を移す）が移す物を決める入力で、一覧は #1098・#1164 などが直す箇所を決める入力になる。

決めた issue: https://github.com/oratta/claude-harness/issues/1128
形と網羅の検査: `tests/public-private-split.bats`（部品を足したのに表を直し忘れると落ちる。分類の判断そのものの正しさは検査しない）

## 判断の基準

- **公開版**: 誰の環境でも意味がある道具・住人のふるまいに効くもの・営業で見せる動き
- **個人版**: オーナーに固有の業務・アカウント・資格情報の置き場・固有名に依存するもの

起点にしたのは flatmate #1618 本文「仕分けの下書き（2026-10-19 の調査）」の表で、そこでの「配る」「開発用」は公開版、「出さない」は個人版の候補として、上の基準で確かめ直した。下書きから変えた行は理由の欄に書いた。

## 分類の値

表の分類の欄は次の 3 つのどれかだけを使う。

- **公開版**: 公開版のリポジトリに残す
- **個人版**: private の個人版のリポジトリへ移す
- **分割**: プラグインの行にだけ使う。1 つのプラグインの中で行き先が割れるので、表のそのプラグインの部品の行（`plugins/<名前>/...` で始まる行）で全体を分ける。部品の行の分類は「公開版」か「個人版」

## 分割したプラグインの部品の行の境界の規則

- 部品の欄は、プラグインのディレクトリ配下のファイルのパス、ディレクトリのパス（末尾 `/`）、Markdown の節（`<パス>#<## の見出しの文字列>`）、Markdown の冒頭（`<パス>#冒頭`）のどれか
- 1 つのファイルの行き先は、そのファイルに当てはまる行（パスが一致するファイルの行、またはそのファイルを含むディレクトリの行）のうち、いちばん深い（長い）パスの行で決める。同じパスの行は 2 行置かない
- 節で分けた Markdown は、`## ` の見出しをすべて節の行で 1 回ずつ覆い、同じファイルにファイルの行を置かない。最初の `## ` より前（frontmatter と冒頭の文）は節に含めず、`<パス>#冒頭` の行で独立に行き先を決める。`#冒頭` は冒頭を表す予約の書き方で、`## 冒頭` という見出しを表さない
- どのファイルにも当てはまらない部品の行は置かない

### 付属のファイルの扱い

プラグインのディレクトリの直下からのパスが `.claude-plugin/plugin.json`・`README.md`・`CHANGELOG.md`・`hooks/hooks.json` のファイルと、`changes/`・`tests/` の配下は付属のファイルとして部品の行で覆わない。付属のファイルは、それが記録・検査・配線している部品と同じ行き先に従う。

- 分割したプラグインの付属のファイルは、そのプラグインに公開版の部品の行が 1 つでもあれば公開版にも残る（個人版の部品についての記述は #1129 で個人版の側へ書き分ける）。固有記述の一覧はこの扱いで付属のファイルの行を載せている
- ファイルの中で行き先が割れる付属のファイル（例: `hooks/hooks.json` の中で配線先のスクリプトの行き先が割れる、`tests/` のテストが公開版と個人版の両方の部品を検査する）の書き分けは #1129 で行う。dev-workflow の `hooks/hooks.json` の配線先 11 本はどれも公開版の部品で、エピック実行まわりの配線は無い。capability-registry の `hooks/hooks.json` の配線先は公開版の `scripts/browser-guard.sh` だけで、`tests/fmtoken.bats` は個人版の `scripts/fmtoken.sh` に従う

## 保留の行の確定

#1128 では、エピック実行の Orca 経路にかかわる 5 行（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）を分類の値「保留（#1123 の後）」にし、#1123（エピック実行の Orca 依存を外す）の結果を見て決めることにした。#1129 で #1123 の結果を見て、5 行とも公開版に確定し、分類の値「保留（#1123 の後）」は使わなくなったので消した。

- 見たもの: #1123 の後、`epic-dispatch.sh` は起動部品を別のプロセスとして呼ぶ形になり、部品は `epic-launch-orca.sh`（Orca）と `epic-launch-tmux.sh`（tmux）から選ぶ。Orca 管理下でも tmux の中でもなければサブエージェント方式で回すので、Orca が無い環境でもエピックを回せる
- `epic-launch-orca.sh` は `epic-launch-<名前>.sh` の差し替えの部品の 1 つとして残った。Orca は誰でも入れられる製品で、判断の基準の「個人版」に当たらない。`epic-dispatch.sh` は部品の既定を orca にしているので、Orca の部品だけを個人版へ移すと公開版の既定の経路が壊れる
- `stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md` は `epic-dispatch.sh` と同じ側に決めると書いていたので公開版にした。`parent-merge-criteria.md` は別セッション方式（起動部品は Orca か tmux）の親が使う

決めた issue: https://github.com/oratta/claude-harness/issues/1129

## 表に載せないもの

リポジトリ直下の `docs/`・`tests/`・`openspec/` は表に載せない。それぞれが説明・検査している部品の行き先に従い、#1129 で一緒に動かす。

## 仕分けの表

| 部品 | 分類 | 理由 |
|---|---|---|
| `rules/README.md` | 公開版 | rules の索引と配線の説明。公開版に残る規則の入口なので一緒に残す |
| `rules/browser-infra-env-capture.md` | 公開版 | 認証情報を見た次の手で env に保存する規則で、誰の環境でも意味がある（下書きの「配る」） |
| `rules/communication-style.md` | 公開版 | 住人の書き方に効く規則（下書きの「配る」） |
| `rules/destructive-git-guard.md` | 公開版 | 住人の止まり方に効く規則（下書きの「配る」） |
| `rules/dev-server.md` | 公開版 | 他のプロジェクトのプロセスを止めない規則で、誰の環境でも意味がある（下書きの「配る」） |
| `rules/git-commit-policy.md` | 公開版 | commit と PR の運用の規則で、誰の環境でも意味がある（下書きの「開発用」） |
| `rules/link-when-requesting-review.md` | 公開版 | 人に操作を頼むときに URL を添える規則で、住人のふるまいに効く（下書きの「配る」） |
| `rules/one-off-no-script.md` | 公開版 | 一回限りの操作をスクリプトにしない規則で、誰の環境でも意味がある（下書きの「開発用」） |
| `rules/perspective-casting.md` | 公開版 | 主に上げるかどうかの判断の規則で、住人のふるまいに効く。下書きの「出さない」から変えた（casting プラグインを公開版にしたのと同じ理由） |
| `rules/plugin-editing.md` | 個人版 | Harness 自体を開発するときの手順で、`CLAUDE_HARNESS_DEV_DIR` と開発用 clone というオーナーの開発環境を前提にしている |
| `rules/subagent-model-selection.md` | 公開版 | サブエージェントのモデルの選び方で、誰の環境でも意味がある（下書きの「開発用」） |
| `output-styles/readable.md` | 公開版 | 住人の書き方に効く Output Style（下書きの「配る」） |
| `scripts/lint.sh` | 公開版 | このリポジトリの lint で、公開版の CI が使う |
| `scripts/sync.sh` | 公開版 | marketplace の clone を最新にして rules の symlink を張る道具で、誰の環境でも意味がある |
| `scripts/test.sh` | 公開版 | このリポジトリのテストの入口で、公開版の CI が使う |
| `scripts/test-auto-merge-workflow.sh` | 公開版 | auto-merge の workflow の攻撃再現テストで、公開版の CI が使う |
| `scripts/poc/` | 公開版 | Codex の app-server の試作で、オーナーの環境に依存しない |
| `worktree` | 公開版 | worktree の作成と片付けの道具で、誰の環境でも意味がある |
| `weekly-report` | 個人版 | Obsidian の vault・Notion などオーナーの記録の置き場を前提にした、オーナーの業務の週報 |
| `daily-report` | 個人版 | Obsidian の vault と Fieldy の記録を前提にした、オーナーの業務の日報 |
| `infra` | 公開版 | 新しいプロジェクトの CI・デプロイの雛形とセットアップの手順で、誰の環境でも意味がある。下書きの「出さない」から変えた（オーナーのアカウントには依存せず、営業で見せる動きにも使える） |
| `dev-workflow` | 分割 | 開発の進め方（develop・pr-review-gate・hook）は公開版。エピック実行（起動部品は Orca か tmux、無ければサブエージェント方式）も #1129 で公開版に確定した。オーナーのリポジトリへの展開の記録は個人版。下の部品の行で分ける |
| `plugins/dev-workflow/` | 公開版 | 下の行に当たらない dev-workflow の全ファイル。開発の進め方・レビューのゲート・hook・アカウントの切り替え（`accounts.json` の中身は利用者ごとに書く仕組み）は誰の環境でも意味があり、住人のふるまいに効く |
| `plugins/dev-workflow/docs/auto-merge-deployments.md` | 個人版 | オーナーのリポジトリごとの auto-merge の展開の一覧と PAT の失効日で、オーナーに固有の業務とアカウントの記録 |
| `plugins/dev-workflow/scripts/epic-dispatch.sh` | 公開版 | エピックの子を起動して見張る部品。#1123 の後は起動部品を Orca と tmux から選び、どちらも無ければサブエージェント方式で回すので、Orca が無い環境でもエピックを回せる。#1129 で公開版に確定 |
| `plugins/dev-workflow/scripts/epic-launch-orca.sh` | 公開版 | `epic-dispatch.sh` から切り出した、Orca で子のワークツリーとセッションを扱う起動部品。#1123 の後は `epic-launch-<名前>.sh` の差し替えの部品の 1 つとして残り、Orca は誰でも入れられる製品なので個人版に当たらない。`epic-dispatch.sh` の部品の既定でもある。#1129 で公開版に確定 |
| `plugins/dev-workflow/scripts/stop-judge.sh` | 公開版 | `epic-dispatch.sh` の `wait --resolve` から呼ばれる、止まった子の判断の部品。`epic-dispatch.sh` の行と同じ側と決めていたので、#1129 で公開版に確定 |
| `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` | 公開版 | `stop-judge.sh` が読む、親が子の止まりを通す基準。`stop-judge.sh` の行と同じ側と決めていたので、#1129 で公開版に確定 |
| `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md` | 公開版 | 別セッション方式（起動部品は Orca か tmux）の親が子の PR をマージしてよいかの基準。#1123 の後は Orca 経路だけのものではなく、`epic-dispatch.sh` の行と同じ側になるので、#1129 で公開版に確定 |
| `capability-registry` | 分割 | 外部サービスの前に CLI を探す仕組みは公開版、オーナーの 1Password の保管庫とトークンの取り出しは個人版。下の部品の行と「capability-registry の扱い」で分ける |
| `plugins/capability-registry/scripts/browser-guard.sh` | 公開版 | ブラウザを開く前に CLI の代替を確かめさせる hook で、住人のふるまいに効く（`fmtoken.sh` の案内は #1164 で外す） |
| `plugins/capability-registry/scripts/fmtoken.sh` | 個人版 | オーナーの 1Password の保管庫と SA の構成を前提にしたトークンの取り出しで、資格情報の置き場そのもの |
| `plugins/capability-registry/skills/capability-registry/1password.md` | 個人版 | オーナーの 1Password の保管庫・SA の設定手順で、資格情報の置き場 |
| `plugins/capability-registry/skills/capability-registry/github.md` | 公開版 | GitHub の CLI の使い方で、誰の環境でも意味がある（`fmtoken.sh` の参照は #1164 で外す） |
| `plugins/capability-registry/skills/capability-registry/supabase.md` | 公開版 | Supabase の CLI の使い方で、誰の環境でも意味がある |
| `plugins/capability-registry/skills/capability-registry/stripe.md` | 公開版 | Stripe の CLI の使い方で、誰の環境でも意味がある |
| `plugins/capability-registry/skills/capability-registry/vercel.md` | 公開版 | Vercel の CLI の使い方で、誰の環境でも意味がある（`fmtoken.sh` の参照は #1164 で外す） |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#冒頭` | 公開版 | frontmatter の description はスキルの発火条件で、外部サービスの前にスキルが発火することが公開版に要る |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#表記規約（生成文にも適用すること）` | 個人版 | agents 保管庫・human-only 保管庫というオーナーの保管庫名の書き方の規約。主の決定 https://github.com/oratta/claude-harness/issues/1128#issuecomment-6292306455 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` | 公開版 | ブラウザに行く前に CLI と認証確認を調べる原則で、住人のふるまいに効く |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#資格情報の階層（どこに置くかはプロジェクトごとに決めない）` | 個人版 | オーナーの保管庫・SA 名・アイテムの命名規約の表で、資格情報の置き場そのもの |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#索引（1 サービス 1 行）` | 公開版 | サービスごとの CLI 名と認証確認コマンドの索引で、誰の環境でも意味がある |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#CLI が無いサービス（ネガティブエントリ）` | 公開版 | CLI の無い操作を探し回らないための記録で、誰の環境でも意味がある |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#新サービスの追加` | 公開版 | 索引の育て方で、誰の環境でも意味がある |
| `casting` | 公開版 | 観点の配役で、住人が主に上げるかどうかに効く。下書きの「出さない」から変えた（配役表と判断基準の中身は利用者ごとに作る仕組みで、オーナーに固有の値はプラグインに無い） |
| `cost-ledger` | 公開版 | 会話ログからコストを集計して記録する道具で、誰の環境でも意味がある。下書きの「出さない」から変えた（書き込み先のリポジトリは利用者が設定する） |
| `statusline` | 公開版 | ステータスラインと枠の残量の表示で、誰の環境でも意味がある（共有先の環境変数は中立の名前を主にし、flatmate と共有する旧名は互換として読む） |
| `product-handover` | 公開版 | プロダクトを引き渡すときの法務ドラフト・窓口・教訓ログの雛形で、営業で見せる動きに使う |

## capability-registry の扱い

capability-registry は分割した。外部サービスを操作する前に CLI と認証確認を調べる仕組み（browser-guard の hook・スキルの冒頭・原則・索引・CLI が無いサービス・新サービスの追加・サービス別ファイルの github・supabase・stripe・vercel）は公開版、オーナーの 1Password の保管庫とトークンの取り出し（`scripts/fmtoken.sh`・`1password.md`・スキルの「表記規約」と「資格情報の階層」の節）は個人版にする。部品ごとの行き先は上の表のとおり。

browser-guard と「CLI を先に調べる」原則は誰の環境でも意味があり、住人のふるまい（ログインを頼む前に CLI を探す）に効き、公開版に残る `rules/browser-infra-env-capture.md` からも参照されている。`fmtoken.sh` はオーナーの 1Password の保管庫と SA の構成を前提にした道具で、flatmate では出荷物に入れてはいけない語になっている。

選ばなかった案:

- **丸ごと個人版**: 公開版の `rules/browser-infra-env-capture.md` の参照先が消え、住人からブラウザ操作の前の注意喚起も消える
- **丸ごと公開版にして fmtoken を一般化する**: 保管庫の設計（read-only の SA・human-only 保管庫）を一般化するのは設計の変更で、#1127 の範囲（仕分けて移す）を越える

「表記規約」の節を個人版にしたのは、節の中に個人版へ移す保管庫名（agents・human-only）と `op item list --vault agents` が残るからで、主の決定（https://github.com/oratta/claude-harness/issues/1128#issuecomment-6292306455 ）による。節の中で Obsidian の vault との区別の書き方だけを公開版に残す案は、節を割ると境界の規則（節の行は `## ` の見出しの単位）を越えるので取らない。

### 公開版に残る部品から `fmtoken.sh` への参照を外す作業

公開版に残す部品は、いまの仕様と実ファイルが個人版へ移す `fmtoken.sh` の案内を必須にしている。参照を外さないまま `fmtoken.sh` を移すと、公開版の hook と索引が存在しない道具を案内する。`grep -rn fmtoken plugins rules output-styles openspec/specs` で確かめた対象（個人版へ移す `fmtoken.sh`・`1password.md`・`tests/fmtoken.bats`・`openspec/specs/capability-registry-fmtoken/`・SKILL.md の「資格情報の階層」の節の 31・34・46 行目と、`changes/` を除く）:

| 対象 | いま書かれていること |
|---|---|
| `plugins/capability-registry/scripts/browser-guard.sh:31` | 注意喚起の (2) が「トークンは fmtoken.sh で取れないか」 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md:3` | 冒頭の description に「トークンの在処（fmtoken.sh）」 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md:16,17,19,20` | 原則の節でトークンの取得・登録・確認を `fmtoken.sh` で案内 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md:56,57,58,59,60` | 索引の各行のトークンの取得を `fmtoken.sh <service>` で案内 |
| `plugins/capability-registry/skills/capability-registry/github.md:4`・`stripe.md:3,4`・`supabase.md:3,4`・`vercel.md:3,4` | `fmtoken.sh` での取得手順 |
| `plugins/capability-registry/tests/browser-guard.bats:59`・`plugins/capability-registry/tests/skill-registry.bats:43,44` | 出力と SKILL.md に `fmtoken` があることを検査 |
| `plugins/capability-registry/.claude-plugin/plugin.json:3,14` | description と keywords に fmtoken |
| `plugins/dev-workflow/references/self-verification.md:53` | `fmtoken.sh --register` を名指し |
| `openspec/specs/capability-registry-browser-guard/spec.md:19,23`（要件「hook は deny ではなく注意喚起から始める」） | メッセージに `fmtoken.sh` の存在を含めることが SHALL |
| `openspec/specs/capability-registry-skill/spec.md:19`（要件「索引は 1 サービス 1 行で 1 画面以内を維持する」） | 各行のトークン取得方法を `fmtoken.sh <service>` と書くことが SHALL |

担い手は #1164（既存の issue の範囲に収まらないため本体が起票した。エピック #1127 の子）。
https://github.com/oratta/claude-harness/issues/1164

#1164 が受け持つ範囲:

- 上の表の参照を、公開版では個人版の有無に依らない書き方（例: トークンの在処はオーナーの環境の索引（個人版）があればそちらを見る）に直し、`fmtoken.sh` の案内は個人版の側（#1130 で重ねて読む）に移す
- 既存の仕様の要件の更新（`openspec/specs/capability-registry-browser-guard/spec.md`・`openspec/specs/capability-registry-skill/spec.md` の上の 2 要件の MODIFIED と、`capability-registry-fmtoken` を個人版へ移すか REMOVED にするか）を #1164 の openspec の change で行う
- 時期: #1129 が `fmtoken.sh` を公開版から消すより前か、同じ PR で着地させる（後になると、公開版が存在しない道具を案内する期間ができる）

#1164 の受け入れ条件は fmtoken の参照の除去だけなので、`fmtoken.sh` を伴わず保管庫名などだけが残る行（`supabase.md:5`・`stripe.md:5`・`supabase.md:10`・`SKILL.md:63`・`SKILL.md:70`）は #1164 に割り当てず、一覧で「担い手なし」にした。

## 固有記述の一覧

公開版に残る部品（分割で公開版になった部品の行と、付属のファイルを含む）の中の固有名とオーナーの環境に依存する記述。行番号はこの文書を書いた時点（#1128 の PR）の値。直す issue は、`rules/` と `output-styles/` の 6 本（#1098 の範囲）の行を #1098、capability-registry の公開版の `fmtoken.sh` の参照を #1164 にし、どの issue の範囲にも当たらない行を「担い手なし」にした。その後 #1168 で、担い手なしだった行を直すか、載せない行の基準に当たるとして外し、Orca 経路の行の担い手は #1177 にした。その後 #1177 で、Orca 経路の行を「Orca を使う場合」の書き方に直すか、載せない行の基準（差し替え可能な起動部品の 1 つとして Orca を並べた行）に当たるとして外し、候補語に当たらない 1 行（`SKILL.md:517`）も外し、担い手が #1177 の行はなくなった。一覧に「担い手なし」の行は残さない。#1164 の行は、PR #1175 のマージで実ファイルから `fmtoken` が消えていたので一覧から外した。その後 #1123 の PR（tmux の部品の追加）で develop の SKILL.md「エピックの扱い」を書き直したので、SKILL.md の行番号を今の本文に合わせ、Orca の語もエピックの経路への依存も無くなった 4 行（親の側の手順の送り先、同時に動く子の上限の説明、サブエージェント方式の別のリポジトリの子の扱い、完了時の状態ディレクトリの確認）を外した。flatmate の住人での索引と案内の二重（#1105 の範囲）は、まだ書かれていない参照を足す作業なので、当たる行は無い。

| 場所 | 種別 | 内容 | 直す issue |
|---|---|---|---|

### 候補語

公開版に残る部品（上の表で公開版に決まるファイルと付属のファイル。`changes/`・`CHANGELOG.md`・`tests/`・`evals/` を除く）を、次の語で大文字と小文字を区別して `grep -n` した（`Oratta` は大文字始まりで別に引いた）。

`genetta`・`flatmate`・`FLATMATE`・`oratta`・`Oratta`・`/Users/`・`Dropbox`・`uranai`・`suimei`・`shukan`・`moko`・`traore`・`human-only`・`保管庫`・`claude-agents-r`・`Obsidian`・`Fieldy`・`Orca`・`marketing-harness`・`Notion`・`1Password`・`CLAUDE_HARNESS_DEV_DIR`・`LLM_LOG_DIR`・`fmtoken`・`rules-archive`・`~/repos`・`sns-autopilot`

### 載せない行の基準

候補語に当たっても、次に当たる行は一覧に載せない。

- **公開版自身の名前**: `oratta/claude-harness`・`oratta-claude-harness`、その install 先のパス（`~/.claude/plugins/marketplaces/oratta-claude-harness/...`・`plugins/cache/oratta-claude-harness/...`）、`plugin.json` の author と README の著者の `Oratta`。公開版はこの名前のまま使い続けるので固有記述ではない。利用者がそのまま実行する設定値（書き込み許可先など）に書かれた名前は除外しない。また #1098 の 6 本（`rules/communication-style.md`・`rules/link-when-requesting-review.md`・`rules/dev-server.md`・`rules/browser-infra-env-capture.md`・`rules/destructive-git-guard.md`・`output-styles/readable.md`）は #1098 の受け入れ条件が `oratta`・`marketplaces/` を 0 件にすると定めているので載せる
- **GitHub のラベル名 `human-only`**: 保管庫の名前ではなく、auto-merge と issueify が使うラベルの名前
- **置き換える前提の例**: `/Users/example`・`/Users/x`・`<project>` のような書式の説明
- **記録と検査**: `changes/`・`CHANGELOG.md`・`tests/`・`evals/`（変更の記録と検査は、それが記録・検査している部品と一緒に #1129・#1164 で動かす）
- **出典や経緯としてだけ名前を挙げる行**: `flatmate#320`・`flatmate #701`・「suimei で実発生」・「genetta-inc の flatmate リポで実運用検証済み」・「出典: oratta/marketing-harness#36」・「2026-08-10 に flatmate で実走したとき」のように、決まりの由来を示すだけで、読み手の環境にその名前の物が無くても指示として実行できる行
- **互換のために残す旧名の読み取り**: 新しい名前が主であること、旧名を互換として読むことが同じ箇所に書かれた行（例: statusline の `FLATMATE_RATE_SHARE_DIR`・`FLATMATE_RATE_SHARE_CONF`。主は `CLAUDE_RATE_SHARE_DIR`・`CLAUDE_RATE_SHARE_CONF`）。旧名は固有名として読み手に見えるが、指示としては新名で足りる。`tests/public-names/allow/nondev.txt` に 1 行ずつ載せる（書式 `<path>:<語>:=<行に含まれる固定の文字列>`、基準は直前の `#` のコメントに書く）
- **差し替え可能な起動部品の 1 つとして Orca を並べた行**: 「Orca・tmux」「起動部品は Orca か tmux」「Orca の部品の列」のように、`epic-launch-<名前>.sh` の差し替えの部品の 1 つとして Orca を他の部品や方式と並べた行（develop の SKILL.md の「部品ごとの欄」の見出しと表を含む）。Orca だけを前提にした行（Orca 経路と名乗る・Orca に登録済みのリポジトリを探す・Orca の親が子のターミナルに打ち込む）は当たらず、「Orca を使う場合」の書き方に直す。下の「一般の製品を例の 1 つとして並べる行」は一般の製品を並べた例で、この項目は `epic-launch-<名前>.sh` の差し替えの部品として並べた行である。この項目は `epic-launch-orca.sh` が公開版に決まる前提で当てるもので、#1129 で `epic-launch-orca.sh` は公開版に確定し、前提は満たされた。下の節「起動部品の 1 つとして一覧から外した行」の行は一覧に戻さない
- **Orca の起動部品の中の行と、起動部品を呼ぶ側で Orca の部品を選んだときの振る舞いを書いた行**: `plugins/dev-workflow/scripts/epic-launch-orca.sh` の行と、`plugins/dev-workflow/scripts/epic-dispatch.sh` の中で Orca の部品を選んだときの動き（orca のコマンド・Orca の画面の印・Orca 管理のワークツリーの判定・Orca に登録されたリポジトリ）を書いた行。Orca を入れていない環境では Orca の部品は選ばれない（経路の判定が tmux かサブエージェント方式になる）ので、読み手の環境に Orca が無くても誤った指示にならない。起動部品の外で Orca だけを前提にした手順を書く行（develop の SKILL.md や `references/` の文書の「Orca 経路の…」）は当たらず、「Orca を使う場合」の書き方か別セッション方式の書き方に直すか、一覧に載せて担い手を付ける
- **一般の製品を例の 1 つとして並べる行**: 「1Password / Bitwarden / Keychain 等」「Orca や端末から起動した Claude Code」のように、ほかの製品と並べた例
- **個人版の部品の中の行**: 表で個人版に決まる部品（`plugins/dev-workflow/docs/auto-merge-deployments.md`・`plugins/capability-registry/scripts/fmtoken.sh` など）は一覧の対象外

## 起動部品の 1 つとして一覧から外した行

上の基準「差し替え可能な起動部品の 1 つとして Orca を並べた行」に当たるとして、#1177 で一覧から外した行。#1129 で `epic-launch-orca.sh` が公開版に確定したので、この行は一覧に戻さない。表は外した行の場所の記録として残す。行番号は #1177 の時点の値で、行の先頭の語で探し直せる。

| 場所 | 行の先頭の語 |
|---|---|
| `plugins/dev-workflow/skills/develop/SKILL.md:46` | \| **`orca`** または **`tmux`** |
| `plugins/dev-workflow/skills/develop/SKILL.md:207` | - **worktree の片付けを提案も質問もしない** |
| `plugins/dev-workflow/skills/develop/SKILL.md:350` | 別セッション方式（Orca・tmux）で起動された |
| `plugins/dev-workflow/skills/develop/SKILL.md:353` | - **印**: 記録を投稿してから付ける |
| `plugins/dev-workflow/skills/develop/SKILL.md:483` | **経路の決め方** |
| `plugins/dev-workflow/skills/develop/SKILL.md:489` | **別セッション方式**（起動部品は Orca か tmux |
| `plugins/dev-workflow/skills/develop/SKILL.md:491` | **子の状態の正本** |
| `plugins/dev-workflow/skills/develop/SKILL.md:493` | **部品ごとの欄** |
| `plugins/dev-workflow/skills/develop/SKILL.md:495` | \| 点 \| Orca の部品（`epic-launch-orca.sh`） |
| `plugins/dev-workflow/skills/develop/SKILL.md:497` | \| 子の起こし方 \| Orca の子ワークツリーを作り |
| `plugins/dev-workflow/skills/develop/SKILL.md:498` | \| 使える条件 \| `orca` が PATH |
| `plugins/dev-workflow/skills/develop/SKILL.md:499` | \| `kept <N> <理由>` を確かめたあとで消す操作 |
| `plugins/dev-workflow/skills/develop/SKILL.md:500` | \| 止まった子への `reply`・完了を促す返事 |
| `plugins/dev-workflow/skills/develop/SKILL.md:501` | \| 画面への写し |
| `plugins/dev-workflow/skills/develop/SKILL.md:502` | \| 設定の誤りの報告 |
| `plugins/dev-workflow/skills/develop/SKILL.md:508` | 3. `done <N>...` で起こされたら |
| `plugins/dev-workflow/skills/develop/SKILL.md:511` | 6. `wait` の `error gh ...` |
| `plugins/dev-workflow/scripts/epic-launch-tmux.sh:19` | `# orca は呼ばない。` |
| `plugins/dev-workflow/scripts/epic-state.sh:86` | `and ((.launcher \| type) == "string")` |
