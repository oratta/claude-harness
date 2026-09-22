## 1. Profile と resolver の Red

- [x] 1.1 [AC 1, 6] `test_codex_develop.py` に `claude-write-codex-review` の全 canonical role tuple と既存 executor/profile 検証を通る Red を追加する。
- [x] 1.2 [AC 1-4] Claude/Codex margin の四象限（+20/+10、Claude余裕/Codex -5、-5/+30、-5/-5）と境界 margin=0 の選択 Red を追加する。
- [x] 1.3 [AC 2, 5] Claude/Codex 欠測・age 300/301 秒・不正 reset/window と、明示 `--profile` が snapshot reader を一度も呼ばない Red を追加する。
- [x] 1.4 [AC 1, 2] `usage-account-registry` の active スロット判定を使い、起動環境が指す A と snapshot.active／トップレベルの B が食い違っても `accounts[A]` を読む Red を追加する。

## 2. Codex 複数 account snapshot

- [x] 2.1 [AC 2, 3] dev-workflow 内の Codex quota 取得について、account 別 cache 分離、identity、秘密/path/生応答を保存しないこと、statusline helper 未導入／旧版でも参照しないことの Red を追加する。
- [x] 2.2 [AC 2, 3] `codex-develop.py` に account 別 cache と App Server への並行取得を実装し、fresh な 10080 分 window の margin 最大、同点は宣言順、一 account の失敗は局所化する。
- [x] 2.3 [AC 2, 3] 取得失敗時は前回の window/fetched_at を更新せず保持し、A=失敗・age 200・margin +30 と B=成功・margin +10 なら A、失敗後 age=300 なら採用、age=301 なら欠測となる Red/Green を追加する。
- [x] 2.4 [AC 3, 6] 自動選択で代表 Codex account を `codex-standard` または hybrid の全 Codex role に束縛し、検証済み execution config/hash に固定する。

## 3. 自動 profile 選択

- [x] 3.1 [AC 1, 6] `codex-role-profiles.json` に `claude-write-codex-review` を追加し、spec-write/implement と explore/summarize を Claude、review/decider を gpt-6-astra/high にする。
- [x] 3.2 [AC 1-5] `codex-develop.py request` の profile/legacy 未指定経路へ freshness=300 秒、週経過率−使用率、design の選択表を実装する。明示指定の既存優先順位と snapshot 非読込を維持する。
- [x] 3.3 [AC 1-5, 7] resolver 戻り値へ秘密を含まない選択 evidence を追加し、coordinator の初回コメントと後続 phase dispatch 記録へ接続する。

## 4. 契約・文書・配布版

- [x] 4.1 [AC 7] develop SKILL、`references/codex-develop.md`、利用者向け docs に profile 未指定時の再評価、選択表、明示指定優先、工程途中は切替なし、記録形式を反映する。
- [x] 4.2 [AC 2] decision criteria と #374 の仕様が freshness `<=300` / stale `>300` で一致することを契約テストにし、#374 が未反映なら依存する follow-up として明記する。
- [x] 4.3 [AC 8] dev-workflow plugin version と CHANGELOG を更新し、statusline plugin の version/install を変更せず、常時注入予算を不要に増やさず `tests/injection-budget.txt` を変更しない。

## 5. 検証と実機証跡

- [x] 5.1 [AC 1-6] statusline plugin/helper を配置しないケースと旧 helper を置くケースを含め、`python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_codex_*.py'` を実行し、全ケース exit 0 を記録する。
- [ ] 5.2 [AC 7] `/develop` を `--profile` なしで一件実行し、最初のコメントの構成・margin・fetched_at・account と各 role の実投げ先を対応付ける。
- [ ] 5.3 [AC 8] `scripts/test.sh`、`openspec validate auto-select-develop-role-profile --strict --no-interactive`、`git diff --check` を実行し、コマンド・件数・exit code・対象 HEAD を記録する。
