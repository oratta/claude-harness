# Proposal

## Why

失敗ループの昇格の決まりが Claude のモデル名（「W を `opus` で再開」「decider を `model: fable`」）でしか書かれておらず、Codex profile で develop を回したときに本体が「W を上げる」を「implement を一番強いモデルにする」と読み替えた。2026-09-23 の genetta-inc/flatmate#847 では、本体が外部 profile をその場で作って implement を gpt-6-astra / high に差し替え、1 回で約 376 万トークンを使って Codex の週次枠を使い切った（issue #424）。#614 で格（最安・中位・上位・最上位）と `codex-develop.py request` の `--failure first|executor|judgment` ができたので、昇格の決まりをその言葉で書き直せる。

## What Changes

- `templates/escalation-tripwires.md` の失敗ループのラダーを、Claude のモデル名ではなく格と `request` に渡す `--failure` の値で書く。モデル名は「対応表 `references/model-tier-map.json` で引いた値」とし、Claude での値は括弧書きの例に留める
- `references/codex-develop.md` に、失敗ループが起きたときの本体の手順を実行側・判断側それぞれ書く:
  - 実行側: `request --phase implement --failure executor` が返した格と model だけを使う。Codex の対応表では上位も `sol` なので実装役のモデルは変わらない。本体は profile を作り直さず、`--profile-file` を差し替えず、`request` が返した model と違う model を独自に指定・上書きせず、effort を変えない
  - 判断側: `request --phase decider --failure judgment` が返す構成の `decider` entry で決める役を立てる
  - 再開前の比較を 1 つの条件にまとめる: 返った `tier` が低くなく `model` が同じときだけ SendMessage、それ以外（降格と model が変わる昇格）は返った model の新しい thread に手渡す（SKILL.md「Role profile の選択」の再開の段落も同じ条件にする）
- `references/codex-develop.md` に、develop 開始時に決めた profile の指定（`--profile` / `--profile-file` / 旧形式 / 無指定）を工程の途中で変えない規則と、変えるならオーナーの承認を記録先に記録する規則を書く（機械的な拒否は作らない。#615 に寄せる）
- `skills/develop/SKILL.md`「モデル」節の昇格の段落を、`--failure` の各値がどの失敗の段に当たるかで書き、decider の model を escalation-tripwires.md の文面から読む形をやめて `request` が返す値を使う形にする
- 上の文を固定する bats を足し、旧文言を固定していた bats を新しい文言に合わせる

範囲外（#615 に寄せる）: 上位格のモデルを implement / spec-write に付けた依頼を `request` が拒否する仕組みとそのテスト、develop 開始後の profile 差し替えを機械的に拒否する仕組みとそのテスト。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: 要件「昇格トリップワイヤー3本の定義」の失敗ループのラダーを格と `--failure` の値で書く
- `manual-codex-develop`: 失敗ループで本体が profile と実装役の model・effort を差し替えない要件と、develop 開始時の profile の指定を工程の途中で変えない要件を足し、要件「委譲は前景実行の 3 手順で行う」の再開の条件を昇格・同格・降格で 1 つにまとめる（MODIFIED）
- `dev-workflow-develop`: SKILL.md「モデル」節が `--failure` の各値と失敗の段の対応を書き、decider の model を `request` の返り値から取る要件を足す

## Impact

- 文書: `plugins/dev-workflow/templates/escalation-tripwires.md`（SessionStart hook で全セッションに注入される）、`plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/worker/common.md`（同じラダーの要約がある）
- テスト: `plugins/dev-workflow/tests/develop-skill.bats`、`plugins/dev-workflow/tests/tripwire-hook.bats`、`plugins/dev-workflow/tests/model-escalation-policy.bats`（文言の固定）
- コード（`codex-develop.py`・`agent-model-guard.sh`・`model-tier-map.json`）は変えない
- 常時注入の予算（`tests/injection-budget.bats`）の対象（`rules/` / `CLAUDE.md` / `output-styles/` / `description`）には触れない
- 変更の記録: `plugins/dev-workflow/changes/424.md`
