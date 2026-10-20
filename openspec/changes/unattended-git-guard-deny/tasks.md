## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 `git-destructive-guard.bats` の setup で `DEV_WORKFLOW_UNATTENDED` も unset する。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:7-14（setup）
- [ ] 1.2 無人のセッションの判定のテストを足す: Scenario「無人のセッションでは対象 9 種が deny」（「nine kinds」のテストと同じコマンドを `DEV_WORKFLOW_UNATTENDED=1`・`bypassPermissions` で渡し、どれも deny）／「無人のセッションでは確認画面が出るモードでも上書きの環境変数でも deny」／「印の値の読み方」／「対話のセッションでは今までどおり ask」（同じコマンドを印なし・`bypassPermissions` で渡し、どれも ask）／「無人のセッションの子は子の規則で決まる」／「off は無人のセッションでも全許可」。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:88-111（「nine kinds」のコマンド一覧を共有するなら配列に切り出す）、plugins/dev-workflow/tests/git-destructive-guard.bats:512-546（`# --- ask / deny ---` の節）
- [ ] 1.3 理由文のテストを足す: Scenario「無人のセッションの理由はチャンネルでオーナーに依頼するよう案内する」。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:546-583（`# --- 拒否理由 ---` の節）
- [ ] 1.4 ルール本文と README の行のテストを直す: 「hook との分担」節と README の `destructive-git-guard.md` の行に、画面を見ている人のいないセッションでも確認画面を出さずに拒否され、チャンネルで主に承認を求めることがあるか（rules/ の語は「主」）。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:838-849
- [ ] 1.5 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. hook の判定と理由文

- [ ] 2.1 決定部に印の判定を足す: 子 → 印（`DEV_WORKFLOW_UNATTENDED` の値の前後の空白を除き、空か `0` 以外なら印あり）→ FORCE → `permission_mode` の順。印のある主の呼び出しは `deny`。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:730-775（`agent_id` の判定と `decision` の決定部）
- [ ] 2.2 無人のセッションの主の呼び出しへの理由文を足す（実行していない／何を・なぜ・いつ実行するかをチャンネル（Discord など）でオーナーに伝えて承認を求める／承認されたらオーナーが自分で実行する／言い換えて再実行しない。確認画面の話を書かない）。`head` は共通のまま。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:777-799（`head` / `body` / `tail` の組み立て）
- [ ] 2.3 冒頭の「返す値」の説明に印の規則を書き足す。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:23-32
- [ ] 2.4 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` が全部通ることを確かめる（1.4 のルールのテストはまだ落ちてよい）

## 3. ルール本文と README

- [ ] 3.1 `rules/destructive-git-guard.md` の「hook との分担」節に、画面を見ている人のいないセッション（起動時に無人の印を付けたセッション）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求める旨の 1 文を足す。既存の文は変えない。`DEV_WORKFLOW_GIT_GUARD_FORCE` は書かない。触る範囲: rules/destructive-git-guard.md:22-24
- [ ] 3.2 `rules/README.md` の `destructive-git-guard.md` の行に同じ内容を足す。触る範囲: rules/README.md:35
- [ ] 3.3 `bats plugins/dev-workflow/tests/git-destructive-guard.bats tests/injection-budget.bats tests/always-on-injection-scope.bats` が通ることを確かめる。予算を超えたら予算ファイルを動かさず文を縮める

## 4. 記録と flatmate 側の起票

- [ ] 4.1 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1124.md（新規）
- [ ] 4.2 flatmate（genetta-inc/flatmate）に issue を起票する: 住人の起動（`boot.sh`）で claude の環境に `DEV_WORKFLOW_UNATTENDED=1` を入れる。受け入れ条件に、既定の引数列への退避の経路と再起動ループを含めて印が入ることをテストで確かめること、住人が tmux などで別に起動するセッションへの引き継ぎは claude-harness #1123・#1126 で扱うことを書く。起票した URL を claude-harness #1124 にコメントしてリンクする
- [ ] 4.3 エピック #1122 に、住人が別に起動したセッションには印が引き継がれない穴（design.md「Risks / Trade-offs」）を #1123・#1126 で扱うようコメントする
