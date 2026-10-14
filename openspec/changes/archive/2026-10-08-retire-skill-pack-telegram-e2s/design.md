## Context

3 プラグインはいずれも `hooks/` を持たず、他プラグインの実行時の依存先でもない（参照は README・docs・spec・テストの列挙だけ）。解散の構成は `discord-plugin-retirement`（#314）に倣う。ここでは撤去の手順に残る小さな判断だけを記録する。

## Goals / Non-Goals

**Goals:**
- 3 プラグインのディレクトリ・marketplace 登録・bundles 登録・参照を harness から無くす
- 解散の状態を bats で検査し、install 済みの環境向けの手順と代替を README に残す

**Non-Goals:**
- `bundles` の `all` に入っていないプラグインがある件（#708）の解決。この PR は解散対象 3 つを外すところまで
- 過去の記録（`openspec/changes/archive/`、`_longruns/`、`plugins/dev-workflow/CHANGELOG.md`、`plugins/daily-report/README.md` の版履歴）の書き換え
- `openspec/specs/discord-plugin-retirement/spec.md`（「dev-workflow・casting・telegram の文中」の一般名詞の記述）と `openspec/specs/retirement-handoff-docs/spec.md`（過去の解散で skill-pack の convention に言及する記述）は、7 文字列に当たらない過去の解散の記録なので直さず残す
- ユーザーへの連絡手段としての一般名詞「Telegram」を含む文の書き換え（該当があれば）

## Decisions

### experience-to-skill-jsonl-distillation は main spec を `git rm` で直接消す

全要件が experience-to-skill プラグインのファイルの存在を規定しているので、capability ごと廃止する。REMOVED の delta だと archive が中断する（`remove-discord-plugin` と同じ事情）ため、archive の直前に `git rm -r openspec/specs/experience-to-skill-jsonl-distillation` を行い、commit メッセージに解散の PR 番号を書く。`openspec archive` は delta 側の変更だけを適用する。

### repo-root-cleanup は要件単位で REMOVED、cooking 要件は MODIFIED

「skill-pack に skillOverrides の適用範囲注記」と「e2s の `$0` 解決」は要件ごと対象が消えるので REMOVED（Reason と Migration を書く）。「cooking 残骸を掃除する」は skill-pack 以外の掃除（`docs/cooking-mvp-mode-plan.md` の削除、`.gitignore` コメント）が残るので、skill-pack の Scenario と本文の言及だけを外した MODIFIED にする。

### 自己検証リファレンスと bats は対象から外すだけ

`self-verification.md` の対象表は experience-to-skill を外して 6 スキルにし、補足（`e2s-distill` はコマンド名であって skill ディレクトリ名ではない）も消す。対象外表は skill-pack・telegram 計 3 行を消す（網羅性テストは「実在する SKILL.md が載っていること」の一方向だけを見るので、消しても落ちない）。`tests/self-verification-sections.bats` の `TARGETS`・`_artifact_kw`、`tests/shared-references.bats` の `CONSUMERS` と対象一覧の列挙は experience-to-skill の行だけを消す。`self-verification-sections.bats` の S40b（`skills/e2s-distill/` という実在しないパスを書かないこと）は検査対象の記述ごと無くなるため消す。

### 撤去検査の許容場所はパスの列挙で書く

`discord-plugin-retirement.bats` と同じく、参照掃除は文字列の許容ではなく許容パスの列挙にする。検査する文字列は `plugins/skill-pack`・`plugins/telegram`・`plugins/experience-to-skill`・`skill-pack@oratta-claude-harness`・`telegram@oratta-claude-harness`・`experience-to-skill@oratta-claude-harness`・`experience-to-skill-jsonl-distillation` の 7 つ。許容は (a) `openspec/changes/archive/` と `_longruns/`、(b) 作業中の change `openspec/changes/retire-skill-pack-telegram-e2s/`、(c) 解散の記録を書くルート `README.md`、(d) この bats 自身、(e) archive で生成される `openspec/specs/skill-pack-telegram-e2s-retirement/`。`/e2s:distill`・`skill-pack` の語だけの版履歴の行（`daily-report/README.md`、dev-workflow の CHANGELOG・changes）は上の 7 文字列に当たらないので許容に入れず、書き換えない。

### 公式プラグイン名を README の代替として書く

telegram の代替は `telegram@claude-plugins-official`。切り替え手順は uninstall と、`enabledPlugins` に `telegram@claude-plugins-official` を入れる 2 手順にとどめ、公式側の設定（Bot トークンの置き場など）は公式の README に委ねてリンクせず名前だけ示す。skill-pack は `/skills` 画面・`skillOverrides`・`claude plugin enable|disable --scope`、experience-to-skill は公式 skill-creator スキルを代替として書く。

### version bump と変更の記録

削除したプラグインは bump 検査の対象外。dev-workflow は version を書かない運用なので bump なしで、`plugins/dev-workflow/changes/841.md` に記録する。

## Risks / Trade-offs

- [これらを入れている環境が marketplace 更新でプラグインを失う] → 利用者は主の環境が中心。README に uninstall 手順と代替を残す。`enabledPlugins` に残るキーは uninstall で消えない場合があるので、手順に「残っていれば消す」を書く
- [telegram の代替で「リアクションをセッションへ届ける」機能が無くなる] → 主が不要と判断済み（理由として README に書く）
- [注入予算の下振れ判定に掛かる] → 減少は 1,556 バイト。実装時に `bats tests/injection-budget.bats` で実測し、掛かれば予算ファイルを更新して PR 本文に理由を書く
- [同時期の別 PR との衝突] → 触る living spec が 5 つあるため、マージ直前に origin/main へ取り込み `bats tests/` を取り直す
