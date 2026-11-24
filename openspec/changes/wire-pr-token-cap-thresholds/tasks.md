# Tasks

## 1. pr-token-budget.sh を共通の解決処理につなぐ

- [ ] 1.1 上限の既定 `cap="${DEV_WORKFLOW_PR_TOKEN_CAP:-30000000}"` と env の固定文の検査をやめ、`--cap` の値だけを持つ（`--cap` の ASCII 非負整数の検査は今のまま）。`SCRIPT_PATH="${BASH_SOURCE[0]}"` と `--cap` の有無を python に渡す。ヘッダの上限の説明（27 行目）を「`--cap` > `DEV_WORKFLOW_PR_TOKEN_CAP` > モデル別の表（token_thresholds.py）」に直し、ヘッダが伸びたら `--help` の `sed -n` の範囲も合わせる。触る範囲: plugins/dev-workflow/scripts/pr-token-budget.sh:27-32、plugins/dev-workflow/scripts/pr-token-budget.sh:39-41、plugins/dev-workflow/scripts/pr-token-budget.sh:51、plugins/dev-workflow/scripts/pr-token-budget.sh:58、plugins/dev-workflow/scripts/pr-token-budget.sh:64-69
- [ ] 1.2 重複除去後の各リクエストの `message.model` を `seen` に usage と並べて持ち（後の行を採る。欠落・非文字列・空白だけは None）、数えた体のリクエストのモデルの集合を作る。meta の `model` は使わない。Codex は集合に入れない。触る範囲: plugins/dev-workflow/scripts/pr-token-budget.sh:134-159（ループ内の `seen[key]` と agents.append）
- [ ] 1.3 合計を出したあと、`subagent-context.sh` の 164-211 行（main の該当箇所）と同じ形で `importlib` により配布物の `scripts/token_thresholds.py` を読み、集合の各モデル（空なら None を 1 回）を解決して `pr_token_cap` の最小値を `cap` にする。有効な `--cap` があれば env を渡さず `{"DEV_WORKFLOW_PR_TOKEN_CAP": <--cap>}` を渡し、無ければ env があるときだけそれを渡す。`ValueError` は stderr と `{"error": "<理由>"}`・exit 1、境界のその他の `Exception` と整数でない値は `resolver_unavailable`・exit 1。集合が空でないときだけ、`unknown_model` と `metric == "pr_token_cap"` の `revalidation_required` を `pr-token-budget: ` 付き・手順の絶対パス付き・重複なしで stderr に出す（取り出しと検証を終えてから出す）。stdout の JSON のキーは変えない。触る範囲: plugins/dev-workflow/scripts/pr-token-budget.sh:214-223、plugins/dev-workflow/scripts/subagent-context.sh:164-211（読むだけ）

## 2. テスト

- [ ] 2.1 既存の `run "$SCRIPT"` を `run --separate-stderr "$SCRIPT"` にそろえ、JSON を `$output` から読む形を保つ。`cap: a non-numeric --cap or env cap exits 1` は env の不正が `invalid_override` で exit 1 になることに合わせる。触る範囲: plugins/dev-workflow/tests/pr-token-budget.bats:109-224（cap の節と固定入力の節。その他の節は同じ置き換えだけ）
- [ ] 2.2 `arec` にモデルを渡せるようにし（既定は今の `claude-sonnet-5`）、cap の節の後ろに次を足す: 登録済み 2 モデルだけなら 30000000 で診断なし／未知モデルが混ざれば fallback と `unknown_model`・`対象=pr_token_cap` の再検証の行／`message.model` 欠落は不明扱いで meta の `model` を使わない／0 体なら診断なし／前後空白付き env・空白だけの env・不正 env（`invalid_override`）と `--cap` による遮り／`--cap` でも診断を出す／配布物の写し（scripts・references・skills/develop/references/token-thresholds.md を複製）で、手順の絶対パスが写しを指す・表を差し替えて最小値を採る・`token_thresholds.py` を除くと `resolver_unavailable`・表を壊すと `invalid_table`。写しの作り方は `tests/subagent-context.bats` の 460-470 行付近にならう。触る範囲: plugins/dev-workflow/tests/pr-token-budget.bats:45-55（arec）、plugins/dev-workflow/tests/pr-token-budget.bats:224 の後ろ（追加）、plugins/dev-workflow/tests/subagent-context.bats:460-470（読むだけ）
- [ ] 2.3 `bats plugins/dev-workflow/tests/pr-token-budget.bats plugins/dev-workflow/tests/pr-token-measure.bats` と `python3 -m pytest -q plugins/dev-workflow/tests/test_token_thresholds.py`（または同ファイルの実行方法）を通す。触る範囲: なし（実行だけ）

## 3. 文書

- [ ] 3.1 token-thresholds.md の「未配線」の段落を、3 経路（文脈の上限・強制停止・累計上限）へ接続済みで、モデルは各計測に採用したレコード（累計は数えた各リクエスト、値が分かれたら最小、Codex は集合に入れない、0 件なら診断なし）から取ること、と直す。31 行目の「hook 接続時の正数チェックは後続 change の責務」と 33 行目の「既存 hook の拒否へ結び付ける配線は今回行わない」を接続後の事実（hook は正数条件と fail-open、CLI は exit 1）に直す。数値の表は複製しない。触る範囲: plugins/dev-workflow/skills/develop/references/token-thresholds.md:7、plugins/dev-workflow/skills/develop/references/token-thresholds.md:31-33
- [ ] 3.2 decision-criteria.md の「累計の `pr-token-budget.sh` は未配線」を接続済みに直し、累計は数えた各リクエストのモデルで引くことと、CLI として `--cap` > env > モデル行 / fallback・失敗は exit 1 であることを 1〜2 文で足す（数値・env 名は再掲しない方針を守る）。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:38
- [ ] 3.3 pr-token-budget.md の上限の既定の説明を「既定はモデル別の表の値（今は 30,000,000）」に直し、新上限の「直前の計測で上限に使った値」を直前の計測の出力 `cap` にする。stderr の再検証の診断の扱い（止まらない・自分で再検証しない・最後の主への報告に書く）と、上限の解決の失敗も exit 1（計測できない）であることを足す。既定の上限を変えない旨（39 行目）は残す。触る範囲: plugins/dev-workflow/skills/develop/references/pr-token-budget.md:25-39

## 4. 記録

- [ ] 4.1 変更の記録 `plugins/dev-workflow/changes/<PR 番号>.md` を finish の段で書く（PR 番号は PR を作るまで分からない）。触る範囲: plugins/dev-workflow/changes/<PR 番号>.md（新規）
