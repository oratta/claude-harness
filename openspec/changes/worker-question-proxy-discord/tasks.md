# Tasks

行番号は仕様作成時点（b1705170）の案内。編集前に各範囲を読み直す。実装開始には記録先 #594 の R1 APPROVE が必要。

## 1. 質問の return と代理送信の契約

- [x] 1.1 `tests/develop-worker-question-proxy.bats` を新設する。worker/ 全体と agent 定義の直接送信禁止（Discord の残存行は否定文脈のみ）、tools 不変、common/spec 両方の質問文・理由・needs-approval・経緯コメント・return、decision-criteria の整合、SKILL.md の実行モード内での本体の代理送信とサイクル終了を検査する。common の決定列挙と spec の子 issue 非作成も検査し、変更前に `bats tests/develop-worker-question-proxy.bats` で現状の欠落を検出できることを確認する。触る範囲: tests/develop-worker-question-proxy.bats（新規）
- [x] 1.2 common の「仕様の発明 2 回」の unmanned 分岐を、埋めた決定・質問文・理由を return に含め、記録先に needs-approval と経緯コメントを残して本体へ返す手順にする。W の Discord 直接送信は MCP・CLI とも禁止し、既存の interactive 分岐と return の先頭宣言規約を保つ。1.1 の該当 bats が通ることを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/common.md:25-32（昇格トリップワイヤー）
- [x] 1.3 spec の「割り方が判断できないほど曖昧」の unmanned 分岐を、子 issue を作らず質問文・理由と needs-approval を return に含め、記録先にラベルと経緯コメントを残して本体へ返す手順にする。W の Discord 直接送信を要求せず、interactive 分岐を保つ。1.1 の該当 bats が通ることを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:74-82（曖昧な分割判定）
- [x] 1.4 decision-criteria の曖昧な分割時の unmanned の記述を、W が質問文・理由を return しラベル・経緯を記録、本体が代理送信する分担に揃え、送信手順は SKILL.md の実行モードを参照する。1.1 の該当 bats が通り、W に直接送信を求める記述が無いことを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:94-97（割り方が判断できないほど曖昧な場合）
- [x] 1.5 SKILL.md「実行モード」の unmanned の説明に、W の return の質問文・理由を本体（憲法のメイン自身）が受け取り、Discord へ代理送信し、needs-approval のままそのサイクルを終える手順を書く。モード表の対話欄・曖昧な分割時の説明を同じ責務分担に揃える。`bats tests/develop-worker-question-proxy.bats` が exit 0 であることを確認する。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:300-310（実行モード）
- [x] 1.6 実装段でのみ変更記録を書き、質問 return と本体の代理送信、回帰テストを記録する。成果物の内容を確認し、バージョンを上げていないことを git diff で確認する。触る範囲: plugins/dev-workflow/changes/594.md（新規）

## 2. 受け入れ条件の統合検証

- [x] 2.1 `grep -rn -i discord plugins/dev-workflow/skills/develop/references/roles/worker/ plugins/dev-workflow/agents/worker.md` の全ヒットを確認し、W の直接送信指示が 0 件（ヒットするなら W は送らず本体が送る否定文脈のみ）であることと、agent の tools が `Read, Edit, Write, Bash, Grep, Glob, TaskStop` のままであることを確認する。ヒット無しの grep exit 1 は「0 件」として記録し、ツールエラーとは区別する。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/common.md:25-32、plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:74-82、plugins/dev-workflow/agents/worker.md:1-10（確認のみ）
- [ ] 2.2 新規 bats を git の追跡対象に入れ、`bats tests/develop-worker-question-proxy.bats` と、今回の受け入れ条件として指定された `./scripts/test.sh` を実行し、両方の exit 0 と実行対象を記録する。`openspec validate worker-question-proxy-discord --type change --strict` も exit 0 を確認する。SKILL.md の実行モード内に本体による代理送信があることを最終差分で確認する。触る範囲: tests/develop-worker-question-proxy.bats（新規）、plugins/dev-workflow/skills/develop/SKILL.md:300-310、openspec/changes/worker-question-proxy-discord/tasks.md（本ファイルのチェック更新）
