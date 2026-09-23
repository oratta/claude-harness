## Why

develop が Codex に仕事を振るときの役割表 `plugins/dev-workflow/references/codex-role-profiles.json` はモデル ID を直書きしている（`gpt-5.6-sol` / `gpt-5.6-luna` / `gpt-6-astra`）。2026-09-22 に GPT-6 Sol / GPT-6 Luna が出たが、役割表は旧世代を指したままで、Codex 構成が選ばれると旧世代が呼ばれる。世代が上がるたびに役割表・テスト・仕様書を手で書き換える必要がある。Claude 側は `opus` / `sonnet` と書くだけで Claude Code が最新版を呼ぶので、Codex 側も同じ扱いにそろえる（記録先: issue #397、エピック #345）。

## What Changes

- 組み込み profile 4 つの Codex role の `model` を、モデル ID ではなく系統名（`astra` / `sol` / `luna`）で書く。
- Codex worker は委譲の直前（initialize と account 照合の後、thread/start の前）に、その account の `model/list` から系統名を解決する。hidden でないモデルのうち slug が `gpt-<版>-<系統名>` の形のものから、版が最も新しい 1 件を選ぶ。
- 該当する系統のモデルが 1 件も無いときは `model_not_available`、最新版が 1 件に決まらないときは `model_not_unique` で止まり、別モデルや別 provider に倒さない。
- 既存の effort 検証（`supportedReasoningEfforts`）は解決後のモデルに対して行い、thread/start と turn/start には解決後のモデル ID を渡す。
- worker の結果 JSON の `execution` に、要求した値・解決の種類・解決後の ID を持つ `model_resolution` を足す。develop の記録先コメントには要求した系統名と解決後の ID の両方を書く。
- 外部 profile-file と旧形式 `--model` では、従来どおり完全なモデル ID も受け付ける（版を固定したいとき用）。完全 ID は今までと同じ完全一致の照合を行う。
- `plugins/dev-workflow/references/codex-develop.md` に「新しいモデルが一覧に出るには Codex CLI の更新が要る」ことを一言書く（docs はこのファイルだけ。`docs/codex-develop.md` は作らない）。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-role-profiles`: 組み込み profile の Codex role の model を系統名で書き、Codex entry の model 値が系統名と完全 ID のどちらでもよいことを定める。記録先に要求値と解決後の ID を残す。
- `codex-worker`: model/list による系統名の解決規則、解決できないときの止まり方、解決後のモデルでの effort 検証と送信、結果 JSON への解決結果の記録を定める。

## Impact

- `plugins/dev-workflow/references/codex-role-profiles.json`
- `plugins/dev-workflow/scripts/codex-worker.py`（`advertised_model` と `run_turn`、`execution_metadata`）と `plugins/dev-workflow/tests/test_codex_worker.py`
- `plugins/dev-workflow/tests/test_codex_develop.py`（組み込み profile の期待値）
- `plugins/dev-workflow/references/codex-develop.md`（記録先に書く項目、CLI 更新の一言）
- `openspec/specs/codex-role-profiles/spec.md`、`openspec/specs/codex-worker/spec.md`
- `plugins/dev-workflow` の plugin.json version と CHANGELOG
- 範囲外: PR レビューの投げ先（#385 / PR #387）、Claude 側のエイリアス解決、Codex CLI の自動更新
