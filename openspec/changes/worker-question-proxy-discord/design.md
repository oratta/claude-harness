# Design

## Context

動機と対象は proposal.md を参照。現状の直接送信指示は `worker/common.md:31`（仕様の発明 2 回）と `worker/spec.md:82`（割り方が曖昧）にある。`decision-criteria.md:97` にも送信主体を省いた記述がある。`agents/worker.md:4` の tools は `Read, Edit, Write, Bash, Grep, Glob, TaskStop` であり、質問の送信先を扱うのは本体である。

## Goals / Non-Goals

**Goals:**

- W が判断を要する理由と実際に尋ねる質問文を、実行可能な形で本体へ渡す。
- 記録先への needs-approval と経緯の記録は W、Discord への送信は本体、という境界を両者の指示書に揃える。
- 質問待ちでそのサイクルを終える既存の unmanned の運用を保つ。

**Non-Goals:**

- worker の tools 拡張、MCP・CLI での W による Discord 送信、Discord の送信先・認証の新設。
- interactive / channel の問い合わせ方法、質問を要する閾値、承認後の再開方法の変更。
- この spec 段での実装・変更記録の作成・バージョン更新。

## Decisions

### 質問の伝達は既存の return を使う

issue #594 の指定どおり、W は質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントしてから本体へ返す。仕様の発明の場合は既存の義務である埋めた決定の列挙も残す。割り方が曖昧な場合は子 issue を作らず return する。return の先頭宣言は既存の「コンテキスト上限（サブエージェントの手渡し）」の契約に従い、`needs-approval` は本文にも明記する。

代案の W への Discord tools 追加は採らない。質問のために W の権限を増やさず、本体が持つ通信経路を使うという issue の責務分担に従う。Bash から CLI を呼ぶ迂回も直接送信に含めて禁じる。

### 本体の送信手順は SKILL.md の実行モードに置く

unmanned の本体は憲法のメイン自身なので、W の return から質問文・理由を受け取り、本体が Discord へ代理送信し、needs-approval のままそのサイクルを終える手順を `SKILL.md`「実行モード」の unmanned の説明に書く。表の「聞けない」は対面で待つことと混同しないよう、質問は本体が代理送信しサイクルを終える説明と整合させる。

W 側の 2 か所では、直接送信指示を質問文・理由・ラベル・経緯コメント・return の手順に置き換える。Discord の語を残す場合は「W は送らず、本体が送る」という否定文脈だけにする。`decision-criteria.md:97` も同じ分担に直し、送信手順の正本は SKILL.md を指す。

### テストは指示書の責務を固定する

既存の `tests/develop-worker-ci-checks.bats` と同じ配置・命名に合わせて `tests/develop-worker-question-proxy.bats` を新設する。入力は実際の指示書と agent 定義であり、Discord の実サービスは呼ばない。

- `worker/` 配下全体と `agents/worker.md` の Discord の行を列挙し、W への直接送信指示が残っていないことを確認する。否定文脈を許す場合は W の送信禁止と本体の送信主体を確認し、単に Discord の語を許可する検査にはしない。
- common の「仕様の発明」と spec の「割り方が判断できないほど曖昧」の両方で、質問文・理由・needs-approval・経緯コメント・return が揃っていることを確認する。common では埋めた決定の列挙、spec では子 issue を作らないことも確認する。
- SKILL.md の「実行モード」の unmanned の説明に絞り、W の return を受け取った本体（憲法のメイン）による Discord への代理送信とサイクル終了があることを確認する。別の節にある channel の送信文で代用して合格させない。
- `decision-criteria.md` の曖昧な分割時の記述との整合と、worker の tools が従来の列挙のままであることを確認する。

テストの守備範囲は文書の契約の欠落と直接送信指示の再混入である。自然文のあらゆる言い換えや、実際の Discord の配送成功は静的な bats だけでは証明しない。指定の grep 結果の全行確認を併用する。

## Risks / Trade-offs

- [正本と役割の指示書の食い違い] → 2 つの W 側の発火箇所・decision-criteria・SKILL.md を同じ実装で揃え、両者をテストする。
- [Discord の語だけを見ると否定文を誤検出する、または肯定指示を見逃す] → 否定文脈と主体を検査し、grep の全ヒットをレビューする。語の存在だけで成否を決めない。
- [本体の通信ツールや配送先が利用できない] → 既存の憲法側の通信経路を使う。配送の追加実装は本 change に含めず、静的検証を配送成功と報告しない。

## Migration Plan

R1 の APPROVE を記録先で確認した後、実装段で回帰テストを先に追加し、対象の指示書を更新する。新規 bats を git の追跡対象に入れてから、対象 bats と受け入れ条件で指定された `./scripts/test.sh`（全体）を実行し、各 exit code を残す。`openspec validate worker-question-proxy-discord --type change --strict` も実行する。実装段でのみ `plugins/dev-workflow/changes/594.md` を書く。データ移行・新しい依存は無く、取り消しは通常の差分の取り消しで行える。
