# 現行仕様の参照移設一覧

基準: main e10f0a98。要件名を識別子として保ち、本文と scenario の参照を変更する。delta は既存ブロック全文を含む。entry に残すものは不要な変更をしない。

| capability / 現行行 | 要件名 | 新しい参照先・扱い |
|---|---|---|
| destructive-git-hook:620 | 別セッションの子の停止検知の条件を案内する | `epic-loop.md` |
| dev-workflow-develop:201 | エピックの条件・作り方・回し方・完了条件を規定する | `epic-delegation.md`、`epic-loop.md`、`epic-merge-wait.md`、`epic-multirepo.md`、`epic-stop.md`、`epic-subagent.md`、`epic.md` |
| dev-workflow-develop:608 | epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う | `epic-loop.md` |
| dev-workflow-develop:739 | エピックの並列起動は 1 段で止める | 子の nested は `epic.md`、親の子エピック除外・待ち受け・完了報告は `epic-loop.md`。delta で本文・scenario・存在検査の参照先を更新 |
| dev-workflow-develop:1726 | epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける | `epic-loop.md` |
| dev-workflow-develop:1930 | Orca 経路の本体は印が付いた子のワークスペースを片付ける | `epic-loop.md` |
| dev-workflow-develop:1984 | develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする | `epic-loop.md` |
| dev-workflow-develop:2007 | エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ | `epic-loop.md`、`epic.md` |
| dev-workflow-develop:2096 | 端末を作れなかった子と指示が届かなかった子の案内は、二重起動を避ける確認を先に出す | `epic-loop.md` |
| dev-workflow-develop:2450 | 親が通してよい範囲の基準を 1 つのファイルに置く | `epic-stop.md`、`parent-pass-criteria.md` |
| dev-workflow-develop:2488 | Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる | `epic-stop.md`、`parent-pass-criteria.md`、`reply-after-idle.md` |
| dev-workflow-develop:2598 | 親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る | `epic-child-stop.md`、`epic-stop.md` |
| dev-workflow-develop:2738 | Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける | `epic-merge-wait.md`、`parent-merge-criteria.md` |
| dev-workflow-develop:2773 | Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る | `epic-loop.md`、`reply-after-idle.md` |
| dev-workflow-develop:2829 | 起動し直した親は主の返事待ちの子を主に出し直す | `epic-loop.md`、`reply-after-idle.md` |
| dev-workflow-develop:2965 | epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める | `epic-loop.md` |
| dev-workflow-develop:3051 | 親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる | `epic-loop.md`、`epic-subagent.md` |
| dev-workflow-develop:3198 | epic.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ | `epic-loop.md`、`epic.md`、`reply-after-idle.md` |
| dev-workflow-develop:3326 | 別のリポジトリの子を含むエピックの回し方を epic.md に書く | `epic-child-stop.md`、`epic-multirepo.md`、`epic.md` |
| dev-workflow-develop:3402 | エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う | `epic-loop.md`、`epic-stop.md` |
| dev-workflow-develop:3450 | 着手できる子が 1 件でも別セッション方式で回す | `epic-loop.md` |
| dev-workflow-develop:3585 | 回し方の手順は推定した done も子の付けた done と同じに片付ける | `epic-loop.md` |
| dev-workflow-develop:3609 | エピックの親は子 1 件あたりの PR トークンの権限をエピックのコメントに置く | `epic-loop.md` |
| dev-workflow-develop:3627 | 親は PR トークン上限の止まりを権限に照らして続けさせる | `epic-stop.md`、`parent-pass-criteria.md` |
| dev-workflow-develop:3868 | 親は主の委任を、定型の委任の記録への主の直接の確認で受ける | `epic-delegation.md`、`epic-stop.md` |
| dev-workflow-develop:3919 | 親は委任の確認の場所をエピックに残す | `epic-delegation.md`、`epic-stop.md` |
| dev-workflow-develop:3928 | 主の委任は取り消しと新しい記録とエピックの終わりで切れる | `epic-delegation.md`、`epic-stop.md` |
| dev-workflow-develop:3937 | 委任が有効かを決まった条件で確かめる | `epic-delegation.md` |
| dev-workflow-develop:3956 | 委任が効く止まりを決まった条件で確かめる | `epic-delegation.md`、`parent-merge-criteria.md` |
| dev-workflow-develop:4000 | 親は有効な委任が効く止まりにだけ、委任で許容を送る | `epic-delegation.md`、`epic-stop.md` |
| dev-workflow-develop:4071 | エピックの親は報告に付ける状態表を区切りより下に置く | `epic-loop.md` |
| dev-workflow-develop:4095 | 状態表は全部の子と親自身を決まった列で並べる | `epic-loop.md` |
| dev-workflow-develop:4103 | 状態表の下に答えが要る子の URL と片付いたものを書く | `epic-loop.md` |
| dev-workflow-develop:4111 | channel モードの状態表は答え方の列をチャンネルで返す内容にする | `epic-loop.md` |
| dev-workflow-develop:4119 | 状態表の規定の守備範囲を限る | `epic-loop.md` |
| dev-workflow-develop:4127 | 別セッション方式の親は表を書く前に子の会話ログの末尾を読む | `epic-loop.md` |
| dev-workflow-develop:4146 | 読めない子のステータスは確かめられなかったと書く | `epic-loop.md` |
| dev-workflow-develop:4257 | 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める | `epic-loop.md`、`reply-after-idle.md` |
| dev-workflow-develop:4276 | 親が長く待ったあとは親の表で続けるか起動し直すかを決める | `epic-loop.md`、`reply-after-idle.md` |
| dev-workflow-develop:4298 | epic.md の回し方は子の起動コマンドの指定と返事の規則のファイルを指す | `epic-loop.md`、`epic.md`、`reply-after-idle.md` |
| dev-workflow-develop:4375 | 親は wait の上限で起きたら子を調べ直さずに同じ wait を掛け直す | `epic-loop.md` |
| dev-workflow-develop:4421 | 手順 5 で気づけない子のことは最初に待ちに入る通知で一度だけ主に伝える | `epic-loop.md` |
| dev-workflow-develop:4435 | timeout から外した確認は closed のときと待ちをやめる前に残し、片付け待ちだけの待ちは長い上限を明示する | `epic-loop.md` |
| dev-workflow-develop:4556 | 子への声かけ文と返事の形は一か所の定義を共有する | `epic-child-stop.md`、`epic-keepalive.md`、`epic.md`、`reply-after-idle.md` |
| dev-workflow-develop:4944 | 記録の無い止まりを主に上げるときは最後の発言から組み立てる | `epic-stop.md` |
| dev-workflow-develop:4992 | エピックの子の止まりの手順と、親が stopped を受けて報告する手順を規定する | `epic-child-stop.md`、`epic-stop.md` |
| dev-workflow-develop:5036 | 親は検知できない止まりを手順 5 と手順 2 に書く | `epic-loop.md` |
| dev-workflow-develop:5086 | 親は今回の止まった理由を記録か最後の発言から読む | `epic-merge-wait.md`、`epic-stop.md`、`parent-merge-criteria.md`、`parent-pass-criteria.md` |
| dev-workflow-develop:5100 | `止まった理由:` の行がある止まりを問いでないとして落とさない | `epic-stop.md` |
| dev-workflow-develop:5254 | 親は主に上げた止まりで told を呼び、expired で見張りを終える | `epic-loop.md`、`epic-stop.md` |
| dev-workflow-develop:5378 | 親は論点なしの止まりの委任で、マージ待ちの子の PR に判断の印を付ける | `epic-merge-wait.md`、`parent-merge-criteria.md` |
| dev-workflow-develop:5401 | 主に上げた件と主の聞き返しを判例台帳に記録する | `epic-stop.md` |
| dev-workflow-develop:5410 | 親の報告に親の判断で通した PR と止まりの一覧を載せる | `epic-loop.md` |
| dev-workflow-epic-state:116 | 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く | `epic-multirepo.md` |
| dev-workflow-epic-state:256 | 記録は片付けた子ごとに消し、エピックの完了時にディレクトリごと消す | `epic-loop.md` |
| dev-workflow-epic-state:661 | サブエージェント方式は状態の記録を書かない | `epic-subagent.md` |
| dev-workflow-pr-token-budget:144 | 本体は spawn と再開の前に測り、上限超なら止まる | `epic-stop.md` |
| harness-public-private-split:287 | 載せない行の基準に起動部品の 1 つとして並べた行を含める | `epic-loop.md`、`parent-pass-criteria.md` |
| owner-question-style:73 | 主に問いを返す各所は正本を参照し、固有の事柄だけを残す | `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`、`plugins/dev-workflow/skills/develop/references/epic-loop.md`、`plugins/dev-workflow/skills/develop/references/epic-merge-wait.md`、`plugins/dev-workflow/skills/develop/references/epic-stop.md`、`plugins/dev-workflow/skills/develop/references/epic-subagent.md` |
| dev-workflow-develop:5367 | 主の側にしか答えが無いとする前に 3 つを確かめる | 子の確認を保持し、例の本文は parent-pass-criteria.md、子から参照 |
