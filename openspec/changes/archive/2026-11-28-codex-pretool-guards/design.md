# Design

## Context

動機と対象は proposal を参照する。dispatch HEAD は `0f5c744334f2b3bf7ad1673368e44c2fdfa69591`。指示書4本は cache と worktree で同一だった。

確認済み（静的なコード・文書）:

| 根拠 | 分かったこと | 証拠の段階 |
|---|---|---|
| `scripts/git-destructive-guard.sh:40-59,687-775,935-1065` | Bash/command を読み、字句解析と対象9種の判定後に Claude 用 ask/deny/allow・permit へ分岐する。NO_ASK は FORCE より先 | repo の静的確認 |
| `capability-registry/scripts/secret-guard.py:113-173,190-215` と `.sh:1-17` | Bash command と Read file_path を別判定。Bash の値表示は既に deny。off と依存欠落は fail-open | repo の静的確認 |
| `scripts/unattended-ask-guard.sh:9-36` | 空白を除いた印の読み方、無人時 deny と連絡先の案内。質問名は Claude の登録側で選別 | repo の静的確認 |
| [OpenAI Hooks](https://learn.chatgpt.com/docs/hooks)（2026-11-28閲覧、Tool coverage / PreToolUse / Tool calls from code mode） | shell/unified exec は hook 上 Bash。apply_patch は同名で command に patch、Edit/Write は matcher alias。nested call にも hook の判定が掛かる。deny は対応、ask/continue:false は PreToolUse で未対応 | 公式文書の確認。対象端末の実測ではない |
| この worker の公開ツール定義 | `functions.request_user_input` と `functions.request_user_input_async` が提示されている | 公開名だけ。Codex hook 名との対応は未確認 |

未確認: 対象 Codex 版の実際の stdin、Bash/apply_patch の実測名・フィールド、質問の同期/非同期と名前空間・nested call の実際の hook 経路、本体/子/worker の継承。今回 Claude・codex exec・codex-companion・子エージェントは起動しておらず、質問ツールも試験目的で呼んでいない。

## Goals / Non-Goals

**Goals:** 入力契約を限定して既存判定を再利用し、Codex へ渡す結果を deny/無出力に揃える。正負 fixture は pending command を実行せずに確かめる。

**Non-Goals:** 別の歯止め、全 shell/言語の解釈、permit store の保護の移植、Claude 判定の守備範囲の拡張、ユーザーホームの編集、配布/信頼方式の選定は行わない。#1861 の一覧設計をやり直さず、3登録の判定結果だけを追記する。

## Decisions

### 親から継承した決定

[元 issue の判断](https://github.com/oratta/claude-harness/issues/1858#issuecomment-7234062095) と [分割記録](https://github.com/oratta/claude-harness/issues/1858#issuecomment-7234092634) の「Codex は deny のみ」「既存判定を再利用」「hooks/codex に新設」「配布/信頼は G003」を採用する。親子識別の発明や Claude transcript の読替えはしない。新しい拒否分類を作るより既存の正負例を保持する。

### 追加した決定: 判定は既存スクリプトを子プロセスとして呼び、Codex 出力を組み直す

`plugins/dev-workflow/hooks/codex/pretool-guard.py` と `hooks.json` を入口にする。Python は隔離モードで起動し、ツール入力を shell に評価しない。巨大な git 字句解析のコピーや、既存 Claude 本体の共通化リファクタリングは避ける。前者は検出差分、後者は既存の許可/回数契約への影響が大きい。

- 定義は PreToolUse を受ける。質問名の取りこぼしを定義側に埋め込まないよう matcher による事前絞込みをせず、adapter 内で Bash と確認済み質問名を選別する。apply_patch/無関係なツールは無出力。
- Bash は必要な command を正規化した入力だけで git と secret の既存スクリプトへ渡す。git への入力から agent_id と permission_mode を除き、子プロセス環境で NO_ASK=1 を固定し FORCE を除く。元のコマンド文字列はそのまま検査し、off は起動環境の既存の逃げ道として維持する。permit が存在しても読む/書く分岐へ入らない。
- `subprocess` の argv と stdin を使い、shell=True/eval は使わない。payload は引数や環境変数へ載せない。Bash の pending command は実行しない。
- secret は既存の wrapper を呼ぶ。git/secret の一方でも拒否なら一つの deny にする。既存出力を丸ごと転送せず、固定の Codex 向け案内（言い換えて再実行しない、必要なら主が実行、子は本体に返す）へ整形し、ask/allow/continue/stopReason を漏らさない。
- 質問は確認した tool_name の集合で選別してから、既存 unattended script の印の判定を利用する。理由文の Claude 専用ツール名だけを Codex 向けの表現へ整形し、運用で定める連絡先や needs-approval の案内を残す。adapter が自動でメッセージを送ることはない。
- 依存 script の所在は module 自身を基準にした repo 配置をテストの既定とし、配布側が絶対パスで明示できる入口も設ける。cwd/PYTHONPATH を検索しない。#1863 は capability-registry を含む依存の配置とパスを解決する。未配布の相対配置をインストール済みとみなさない。

### 受け入れ条件とルールの守備範囲

AC1 の「一覧」は `rules/destructive-git-guard.md:13-24` の hook との分担を含めて読む。既存9種は全て Codex deny の正例にする。push 済み amend・rebase -i は元々 rule のみの対象で、この移植で対応済みにはしない。この読み方は R1 の確認点とし、一覧全項目の新たな機械拒否が必要という判断なら、仕様と量を再計算して本体へ返す（無断で正例から除外して合格とはしない）。

## 実装前の入力確認ゲート

fixture の基礎は公式文書。最初の実装作業では、対象版・根拠・取得方法付きで、実際の hook stdin と公開名/正規名の対応を確かめる。保存するのはダミー操作の必要フィールドだけで、個人の認証・prompt・会話ログ全体を repo に入れない。

1. shell と unified exec が Bash/command に正規化されること、apply_patch の command がパッチ本文であることを照合する。
2. 主に質問する同期・非同期ツール、名前空間付き公開名、code mode 内 nested call の対応をそれぞれ確かめ、確認した名前だけを列挙する。文字列に question を含むだけでは拒否しない。
3. 実測できる経路は実測由来 fixture、できないものは文書由来/合成 fixture と識別する。fixture 成功は実 hook 到達の証拠にしない。
4. 質問が PreToolUse に届くと確認できない/対象版に操作がない/必要な起動が今回のworker権限でできないなら、AC3 は未完了として止め、`needs-decider`（経路なし）または `blocked`（確認手段なし）と証拠を返す。要求は「対象版で主への同期・非同期質問を安全に1回ずつ要求し、実際の hook event/tool_name/tool_input と nested call の到達を取得」。未確認の名前を追加して通したことにしない。

このゲートの観測値は現工程で埋めた決定ではない。拒否が観測できなければ機能の完成条件を満たさないという契約は固定する。質問先の経路を新設する必要が出た場合は、この設計のまま進めない。

## Risks / Trade-offs

- [既存判定の限界と fail-open] → 非文字列/壊れた入力/依存失敗は無出力にし、依存失敗は stderr で未検査を通知する。動的な git、スクリプト内部、ssh/別言語の秘密読み出し等を全て防ぐ境界とは呼ばない。
- [再利用の改変で出力が変わる] → 複数回拒否しても禁止出力がないこと、FORCE=ask・偽 agent_id・permit の影響がないことを独立した反例で検査する。
- [広い matcher の負荷と質問の取りこぼし] → 非対象を早期終了し、実測した質問名の表を固定する。任意の MCP ツールを全部止める案は採らない。
- [実装のみで本体が保護されたと誤認] → 一覧の本体/子/worker は未確認を維持。`changes/1858.md` に判定テストと #1863 の残件を別記する。
- [聖域接触] → hooks/codex は SACRED 対象。既存 hooks.json、CLAUDE.md、権限設定、注入固定分/予算は編集しない。本 worker は merge/auto-merge をしない。

## Migration Plan

R1 の承認後、入力確認→adapter/定義→正負fixture→Claude 既存回帰→一覧3登録と共有変更記録の順で進める。#1863 へ入口と依存・確認済み/未確認を引き継ぐ。ロールバックは配布前なら当該追加物の取り下げで足り、ユーザーホームはこの change では変更しない。

粒度計算の入力・出力は proposal のリンクに保存した。700行は予定値。当初は C=121635 で停止したが、本体の [再計画完了記録](https://github.com/oratta/claude-harness/issues/1862#issuecomment-7235062756) により exit 0 / 1 group / unplaced なし、C=98505<=120000、S=34008000<=48000000 となり、容量による停止は解消済み。次工程は `openspec/specs/destructive-git-hook/spec.md` の要件見出しを grep し、本文が必要な要件の行範囲だけを読む。上限・reserve・保持量は削っていない。現在は R1 指摘を反映した仕様案の再レビュー待ちであり、承認後も上記入力確認ゲートを維持する。計画上の容量内という結果を起動枠や品質の実測成功とは扱わない。
