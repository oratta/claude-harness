## Context

`codex-worker.py` は Codex の App Server を job ごとに起動し、`thread/start` と `turn/start` に砂場（sandbox）の設定を渡す。現状は role によって `readOnly` / `workspaceWrite` を選ぶが、どちらも `networkAccess: False` 固定で、`workspaceWrite` の `writableRoots` は cwd と job 専用一時領域の 2 つだけ、子プロセスの環境変数は `clean_env()` の 8 個（PATH / HOME / USER / LOGNAME / SHELL / TMPDIR / LANG / LC_ALL / SYSTEMROOT）に絞られている。

このため Codex の worker は次を自分で完了できない。

| できないこと | 直接の原因 |
|---|---|
| 外部・ループバックへの通信 | turn policy の `networkAccess: False` |
| GitHub の取得・コメント・Draft PR 作成・push | 通信の遮断と、認証が環境変数の allowlist で落ちること |
| linked worktree での `git commit` | `.git` がファイルで、参照先の Git 共通ディレクトリ（別の場所）が `writableRoots` に無いこと |

Codex 側の制約ではないことは確認済みで、App Server の `SandboxPolicy`（`codex app-server generate-json-schema` の出力）は `readOnly` と `workspaceWrite` の双方に `networkAccess: boolean` を持ち、`dangerFullAccess`（`thread/start` の `sandbox` では `danger-full-access`）も受ける。Codex CLI 0.153.4 で確認した。

対になる Claude 側の実装は、サブエージェントが親セッションの環境とネットワークをそのまま使い、書き込み範囲の制限も無い。決める役（`dev-workflow:decider`）だけが Read / Grep / Glob に絞られており、シェルを持たないので GitHub も取得しない。

## Goals / Non-Goals

**Goals:**
- Codex の worker の書く役が、worker の中で実装・テスト・commit・push・GitHub 操作を自分で完了できる
- 読む役の取得手段を、Claude 側の対応する役と同じ水準にする（書き込みは増やさない）
- 緩める判断を段階順で行い、各段の採否を実測の証跡とともに残す
- 揃えられなかった項目を、揃ったふりをせず項目ごとに記録する

**Non-Goals:**
- `approvalPolicy: never` と、切り離して投げて後で拾う作りの変更（Claude 側も途中で本体に聞かないので、ここは既に揃っている）
- 一時領域の所有・片付け、account ごとの同時実行と枠判定の変更
- Claude の hooks を Codex に効かせること（製品の違い。必須検査を指示に書く現行運用を維持する）
- 永続 worker・burn 窓・使用量集計（別 issue）

## Decisions

**書く役のネットワークを開ける（`networkAccess: true`）。** 代替案は「ループバックだけ許す」だが、App Server の `SandboxPolicy` に宛先を絞る項目は無く（`networkAccess` は真偽値だけ）、`gh` と `git push` には外部通信が必要なので、部分的に開ける選択肢は実装できない。

**`writableRoots` に Git 共通ディレクトリを足す。** `git rev-parse --path-format=absolute --git-common-dir` を使う。この値は `runtime_home()` が既に取得しているので、算出を 1 か所に寄せて使い回す。代替案は「worktree ではなく通常 clone を使う」だが、`validate_request()` が linked worktree を必須にしており（`linked_worktree_required`。main checkout の誤操作を防ぐ設計）、こちらを崩す方が失うものが大きい。もう一つの代替案「`dangerFullAccess` にする」は、commit だけのために書き込み範囲を全部開けることになるので第 2 段に置く。

**環境変数は「引き継いで、落とすものだけ落とす」に反転させる。** 代替案は allowlist に GH_TOKEN・SSH_AUTH_SOCK 等を足していくことだが、Claude 側は親の環境をそのまま使っており、足りない変数が出るたびに harness を直す運用は「同じにする」という前提に反する。落とすのは worker が自分で決める値（CODEX_HOME・TMPDIR・TMPPREFIX）と、Codex 自身が認証に読み登録済み account 以外の課金経路へ移し得る値に限る。後者を残すと、台帳の account と実際に課金される先が食い違い、枠判定（`quota_available`）が別の窓を見ることになる。

**Codex 側の環境変数ポリシーも開ける。** App Server に渡した環境がそのままモデルの実行するシェルに届くとは限らない（Codex には `shell_environment_policy` があり、既定では核となる変数だけを継承し、名前に KEY / SECRET / TOKEN を含む変数を除く挙動が文書化されている）。job ごとの runtime `config.toml` は worker が生成しているので、そこに引き継ぎ設定を書く。実際に絞られるかは実測で確かめ、絞られていなければ設定を足さない（効かない設定を書かない）。

**読む役は役ごとに分ける。** review / spec-review / impl-review は Claude 側で汎用サブエージェントとして起き、`gh` で PR や issue を読めるので `networkAccess: true` にする。decider は Claude 側が Read / Grep / Glob だけの読み取り専用エージェントで、シェルを持たず取得もしないので `networkAccess: false` のままにする。「read-only は一律で維持」「read-only も一律で開ける」の両方より、Claude 側の実際の手段に合わせる方が「同じにする」という前提に忠実である。

**砂場を外すのは第 2 段に置き、role ごとに決める。** 第 1 段（workspace-write + network + Git 共通ディレクトリ）で足りるかは実測でしか分からない。とくに macOS では `gh` と `git` の認証がキーチェーンに入っている場合があり、Seatbelt の砂場からキーチェーンへ届かない可能性がある。第 1 段で失敗したコマンド・出力・exit code を記録してから、足りない role だけ `dangerFullAccess` に落とす。

## Risks / Trade-offs

- 認証情報を持ち外と通信できる子を、途中で誰も止められない → 受け入れる。`approvalPolicy: never` で動く Claude のサブエージェントと同じ水準で、Codex 側だけが増やすリスクではない（issue の「受け入れるリスク」に明記済み）
- 読む役に通信を開けると、read-only の役が GitHub へ書き込むことを砂場が止められなくなる → 「read-only reviewer は投稿しない」は指示で守る。Claude 側も同じで、指示による保証しかない。ラベルや承認記録の投稿が本体の担当であることは既存の正本（roles / pr-review-gate）が持つ
- 親の環境を引き継ぐと、無関係なサービスの認証情報も子に届く → 落とすものを限定した引き換えに受け入れる。Claude 側と同じ水準になるだけで、それ以上の露出ではない
- `dangerFullAccess` に落ちた role は、cwd の外への書き込みも止められない → role ごとに決め、証跡を残し、CODEX-WORKER.md に「どの role がどの段か」を書く。第 1 段で足りるなら落とさない
- キーチェーンや SSH エージェントに届かず、第 2 段でも `git push` が通らない可能性 → 揃えられなかった項目として記録し、その操作だけ本体の代理実行を残す（全部を戻さない）

## Migration Plan

1. fake App Server の回帰テストを新しい policy と環境変数の形に合わせて先に落とす（Red）
2. 第 1 段を実装し、fake テストを通す
3. 実 Codex の implement role で受け入れ対象の操作を実測する。足りない role があれば失敗の証跡を記録してから第 2 段へ
4. 代理実行の記述を削り、CODEX-WORKER.md に実際の範囲（role ごとの段・落とす環境変数）を反映する
5. 戻し方: この change の diff を revert すれば元の砂場に戻る。台帳・一時領域・runtime の形は変えないので、走っている job の互換性を壊さない

## Open Questions

- 第 1 段で `gh` の認証が届くか（キーチェーン格納の場合）は実測待ち。届かなければ第 2 段の判断材料として記録する
- Codex の `shell_environment_policy` が実際にどこまで絞るかは実測で確認する（設定を足すかどうかがこれで決まる）
