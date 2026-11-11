# Design

## Context

動機は proposal.md の Why。現状の要点:

- `model-tier-map.json` は `version`・`tiers`・`executors` の 3 キーだけで、`codex-develop.py` の `load_tier_map` が未知のキーを拒否する
- `codex-develop.py request` の profile 形式・自動選択では、書く役（spec・implement・finish）の要求の格は規則上 `上位` 止まりで、`tier_cap` は格を下げるだけなので、今の表では最上位にならない。一方、旧形式 `--account --model` は格の規則・残量モード・対応表を通らず、`--model astra` の implement もそのまま通る（要件「旧形式は格の規則を通らない」）。#424 の事故と同じ「実装役に最上位のモデルを指定する」操作が今通るのはこの経路
- `agent-model-guard.sh` は `fable` / `claude-fable-*` を `dev-workflow:decider` 以外で拒否する文字列判定で、表を読まない。macOS 標準の `python3`（3.9）でも動く必要がある

## Goals / Non-Goals

Goals: 役の上限の格を対応表の 1 か所に置き、Claude の Agent 呼び出しと `codex-develop.py request` が同じ値で拒否する。

Non-Goals:

- 上限を超えた格を上限まで下げて通すこと（拒否だけにする）
- `dev-workflow:reviewer`・`general-purpose` など、役の決まっていない種別を表で判定すること（今の Fable 判定のまま）
- 表を環境変数や引数で差し替える口を作ること

## Decisions

### 上限は対応表の `role_caps` に置く

`model-tier-map.json` に `"role_caps": {"spec-write": "上位", "implement": "上位"}` を足す。キーは profile の canonical role 名（`spec-write`・`spec-review`・`implement`・`impl-review`・`review`・`decider`・`explore`・`summarize`）のどれかで、値は 4 格のどれか。spec-write と implement は必須、ほかの役は書けば上限が付き、書かなければ上限なし。`version` は 1 のまま（同梱の表だけを読む内部の形式で、外から渡す口が無いので版を分ける必要がない）。

- 代替: profile（`codex-role-profiles.json`）に置く。profile は外部の `--profile-file` で差し替えられるので、上限も差し替えられてしまう。また Claude の Agent 呼び出しは profile を読まない。採らない
- 代替: 書く役の上限を `codex-develop.py` と guard のコード定数に置く。2 か所に書くことになり、受け入れ条件の「同じ表から来る」を満たさない。採らない
- spec-write と implement を必須にするのは、表の書き換えで上限が無言で消えないようにするため（#614 の「既定値に倒さない」と同じ考え）

### 上限超えは拒否する（下げない）

`codex-develop.py` は、profile 形式・自動選択では `executed_tier`（残量モードと profile の `tier_cap` を適用したあとの格）を、実際に動く entry の役（review が decider に切り替わったときは decider）の上限と比べ、超えたら `RuntimeError`（`status: blocked`・終了コード 2、依頼ファイルなし）にする。

- 代替: 上限まで下げて通す（`tier_cap` と同じ扱い）。Claude 側の guard は呼び出しを書き換えられず拒否しかできないので、Codex だけ下げると両者の判定が揃わない。また上限を超える格が出るのは表か規則の設定誤りなので、黙って下げるより止めて気づかせるほうがよい。採らない
- 今の同梱の表と規則では書く役の格は `上位` 止まりなので、profile 形式・自動選択でこの拒否が出るのは表の上限を `上位` より下げたときだけである。この判定は「表を変えると判定が変わる」ことの受け皿で、受け入れ条件の「最上位の拒否」は主に旧形式と Claude 側で効く

### 旧形式は、上限を持つ役でだけ model を格に戻して確かめる

旧形式の役（phase の役。旧形式は decider に切り替わらない）が `role_caps` に載っているときだけ、対応表を読み、指定された `--model` を codex の列で格に戻し、上限を超えたら拒否する。上限を持たない役（review・decider など）は今までどおり表を読まずに通す（壊れた表でも decider の旧形式は通る、という既存のテストを保つ）。上限を持つ役で表が読めないときは止める（`codex-develop.py` は表について fail-closed）。

- 格に戻せない model（表のどの名前にも当たらない）は上限を確かめずに通す。旧形式は版を固定するための口で、表に無い名前を止めると、その目的が壊れる
- 代替: 旧形式は今のまま上限を見ない。#424 と同じ指定が通り続け、Codex 側の強制が実質ない。採らない

### model 名から格を引く規則と文面を 1 つのモジュールに置く

新しい `scripts/tier_caps.py`（標準ライブラリだけ・Python 3.9 で動く書き方）に次を置き、`codex-develop.py` と guard の両方が import する。

- model 名から格を引く: model を小文字にして前後の空白を除き、それ自身、または `-` で区切った断片のどれかが、その executor の列のモデル名と一致する格のうち**いちばん低い格**をその model の格とする。例: `fable` / `claude-fable-5-1` → 最上位、`opus` → 上位、`gpt-6-astra` → 最上位、`gpt-5.6-sol` → 中位（codex の中位と上位はどちらも `sol` なので、低い方）。一致が無ければ格なし
- 拒否の文面: `役 <役>（<呼び出し元の補足>）に格 <要求された格> は付けられない。この役の上限は <上限の格>（plugins/dev-workflow/references/model-tier-map.json の role_caps）。` を共通の前半とし、guard はそのうしろに決める役の種別（`dev-workflow:decider`）・実行役の代替・規範を足す
- いちばん低い格に寄せる理由: 同じモデルが 2 つの格に載っているとき、そのモデルを動かせる最も低い格で判定すれば、上限以下で正当に動くモデルを止めない
- 代替: 両方に同じ関数を書く。照合規則がずれると「同じ表なのに判定が違う」が起き、受け入れ条件のテストでしか気づけない。採らない

### guard の種別と役の対応は guard に置く

`dev-workflow:worker` → spec-write・implement、`dev-workflow:gate-runner` → implement（W と G が implement を共有するのは `codex-develop.py` の PHASES と同じ）。複数の役を持つ種別は、その役の上限のうちいちばん低い格を上限にし、文面の役には `spec-write/implement` と並べる。対応は guard のコード定数にし、環境変数で足せる形にしない（`DECIDER_TYPES` と同じ理由）。

- この対応は Claude の種別名の話で、格からモデル名への表とは別の関心なので、表には入れない
- 判定の順序: 対応のある種別は表の判定を先に行い、上限を超えたら拒否する。表が読めない・壊れているときは表の判定を飛ばし、今の Fable 判定（決める役以外の Fable を拒否）に任せる。guard は今どおり fail-open だが、Fable の構造上の上限は表が壊れても残る
- 対応の無い種別（`dev-workflow:reviewer`・`general-purpose`・`Explore` など）は今の判定のまま

### テストの一時コピー

受け入れ条件の「表の上限を 1 段下げた一時コピー」は、`agent-model-guard.bats` に 1 件置く。`plugins/dev-workflow/scripts` と `plugins/dev-workflow/references` を一時ディレクトリに複製し、複製の表の spec-write・implement の上限を `中位` に下げてから、複製の guard に `dev-workflow:worker`・`model: opus` を、複製の `codex-develop.py` に `request --profile claude-default --phase implement --pre-class contract` を渡す。同梱の表では両方とも通り、複製では両方とも拒否されることを同じテストで確かめる。

- 両スクリプトは自分の置き場所から `../references/model-tier-map.json` を読むので、複製すれば差し替えの口を作らずに済む

## Risks / Trade-offs

- [model 名の断片照合が別のモデルに当たる（例: 将来 `sol` を含む別名）] → 照合は `-` で区切った断片の完全一致だけにし、部分文字列では見ない。当たり外れはテストの例で固定する
- [旧形式で表に無い名前（例: 綴り違いの `astr`）は上限を確かめずに通る] → 旧形式は版の固定の口で、表に無い名前を止めると目的が壊れる。守備範囲の段落に書いて穴として許す
- [`role_caps` を必須にしたことで、表を作るテストの fixture が壊れる] → 同梱の表を読んで直すテストは影響なし。表を一から書くテストだけ `role_caps` を足す
- [guard が表を読むようになり、hook の実行が遅くなる] → 小さな JSON を 1 回読むだけ

## Migration Plan

表・スクリプト・テストを 1 PR で入れる。戻すときは PR を revert すれば、表の `role_caps` と両方の判定が同時に戻る。
