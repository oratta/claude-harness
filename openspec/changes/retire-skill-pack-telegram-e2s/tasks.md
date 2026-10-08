## 1. テストを先に書く（Red）

- [x] 1.1 `tests/skill-pack-telegram-e2s-retirement.bats` を作り、spec `skill-pack-telegram-e2s-retirement` の各 Scenario を検査する: 3 ディレクトリの不在（`git ls-files` 0 件）・marketplace の `plugins[]` と全 `bundles[].plugins[]` に 3 つが無い・`openspec/specs/experience-to-skill-jsonl-distillation` の不在・7 文字列の掃除（許容はパスの列挙: `openspec/changes/archive/`・`_longruns/`・`openspec/changes/retire-skill-pack-telegram-e2s/`・`README.md`・`tests/skill-pack-telegram-e2s-retirement.bats`・`openspec/specs/skill-pack-telegram-e2s-retirement/`）・README に 3 つの表の行が無く切り替え手順と代替の 6 文字列がある。テスト名は ASCII のみ。書き方は `tests/discord-plugin-retirement.bats` に倣う
  触る範囲: tests/skill-pack-telegram-e2s-retirement.bats（新規）
- [x] 1.2 `bats tests/skill-pack-telegram-e2s-retirement.bats` が撤去前の状態で落ちることを確認する

## 2. 撤去（Green）

- [x] 2.1 `git rm -r plugins/skill-pack plugins/telegram plugins/experience-to-skill`
  触る範囲: plugins/skill-pack/・plugins/telegram/・plugins/experience-to-skill/（削除）
- [x] 2.2 `.claude-plugin/marketplace.json` の `plugins[]` から 3 エントリを、`bundles[]` の `all` から `experience-to-skill`・`skill-pack` を外す。他エントリの差分が出ないことを `git diff` で確認する
  触る範囲: .claude-plugin/marketplace.json:10-20（telegram）、:91-115（experience-to-skill・skill-pack）、:236-245（bundles の all）
- [x] 2.3 ルート `README.md` のプラグイン一覧から 3 行を消し、「解散済みプラグイン」節に 3 プラグインの解散・理由・代替・`claude plugin uninstall <name>@oratta-claude-harness` を書く（spec の要件どおり。telegram は「リアクションをセッションへ届ける機能は不要と判断」を明記、`enabledPlugins` に残るキーは消す旨も書く）
  触る範囲: README.md:60-70（一覧の表）、:140 以降（解散済みプラグイン節）
- [x] 2.4 `plugins/dev-workflow/references/self-verification.md` の対象表から experience-to-skill の行と `e2s-distill` の補足を、対象外表から skill-pack・telegram（access・configure）の 3 行を消す。`plugins/dev-workflow/README.md` の self-verification の説明から experience-to-skill を外す。`plugins/dev-workflow/references/commit-and-pr-operations.md` の「過去作業のスキル化は `/e2s:distill`…」の 1 行を消す（「その他」の節に他の内容が無ければ見出しごと）
  あわせて同ファイル 33 行目の「7 スキルが対象」の記述に、2026-10 の 3 プラグイン解散（#841）で experience-to-skill を外して 6 スキルになったことを足す
  触る範囲: plugins/dev-workflow/references/self-verification.md:33・:44-59、plugins/dev-workflow/README.md:88、plugins/dev-workflow/references/commit-and-pr-operations.md:20-22
- [x] 2.5 `plugins/dev-workflow/tests/self-verification-sections.bats` の `TARGETS`・`_artifact_kw` の experience-to-skill の行と S40b を、`plugins/dev-workflow/tests/shared-references.bats` の `CONSUMERS`・対象一覧の experience-to-skill の行と「all eight consumers」のテスト名・件数（8 → 7）を直す。数の書き換え漏れも直す: `shared-references.bats:69` のテスト名「seven live skills」→ six、`self-verification-sections.bats:76` の S40 のテスト名「7 target skills」→ 6、同ファイル 8 行目のコメント「対象は 7 スキル」→ 6
  触る範囲: plugins/dev-workflow/tests/self-verification-sections.bats:15-45・:83-86、plugins/dev-workflow/tests/shared-references.bats:20-35・:70-90
- [x] 2.6 コメントの言及を直す: `plugins/cost-ledger/tests/fixtures.bats` の「前例: plugins/experience-to-skill/tests/sanitize.bats」を前例の文ごと外すか実在する前例に置き換え、`tests/injection-budget.bats` の「本文に `description:` を書いてあるファイルが実在する（plugins/experience-to-skill 配下）」を、テストは合成ファイルで検査しているので実在の主張を外した文にする
  触る範囲: plugins/cost-ledger/tests/fixtures.bats:7、tests/injection-budget.bats:682-686
- [x] 2.7 `plugins/dev-workflow/changes/841.md` を書く（何を消し、どこを直したか、戻し方は `git revert`）
  触る範囲: plugins/dev-workflow/changes/841.md（新規）
- [x] 2.8 ここまでを commit する（main spec の削除はまだ行わない）。**2.8〜4.3 の間に push すると Draft PR の CI は意図して赤になる**（living spec 4 本の delta が archive まで正本に入らず、`scripts/test.sh` が拾う新 bats の参照掃除が `openspec/specs/` 配下の行で落ちるため）。archive（4.3）までは直しに行かず、4.5 で緑になることを確かめる

## 3. 検証

- [x] 3.1 `bats tests/skill-pack-telegram-e2s-retirement.bats`（**この段階で落ちてよいのは 2 件だけ**: `experience-to-skill-jsonl-distillation` の spec ディレクトリの不在の検査と、参照掃除の検査。後者は living spec 4 本と main spec の行、つまり `openspec/specs/` 配下の行だけが当たる状態であること。それ以外が落ちたら実装の誤り）・`bats tests/marketplace-sync.bats`・`bats plugins/dev-workflow/tests/`・`bats plugins/cost-ledger/tests/` が pass する
- [x] 3.2 `bats tests/injection-budget.bats` で実測する。実測は 3 プラグインぶん（description 計 1,556 バイト）減る。予算 40,260 が実測の 1.1 倍を超えて下振れ判定で落ちたら、`tests/injection-budget.txt`（聖域）を実測以上かつ実測の 1.1 倍以下の値に更新し、PR 本文に「何を削ろうとして、なぜその値にするか」を書く。落ちなければ動かさない
  触る範囲: tests/injection-budget.txt:1
- [x] 3.3 PR 本文の受け入れ条件のうち、ディレクトリの不在・marketplace・README・注入予算の条件を実行して確認する（受け入れ条件 3 の「参照 0 件」は living spec が archive で更新されるまで満たせないので 4.5 の後で確認する）

## 4. main spec の整理と archive

- [ ] 4.1 archive の直前に `git rm -r openspec/specs/experience-to-skill-jsonl-distillation` を行い、解散の PR #841 を commit メッセージに書いて commit する（全要件 REMOVED の delta は archive が中断するため delta では表現しない）
- [ ] 4.2 `bats tests/openspec-specs-format.bats` が pass する。`bats tests/skill-pack-telegram-e2s-retirement.bats` は、spec ディレクトリの不在は pass し、参照掃除の検査だけが living spec 4 本の行（`openspec/specs/` 配下のみ）で落ちる状態であることを確認する
- [ ] 4.3 `openspec archive retire-skill-pack-telegram-e2s -y` で archive し、`openspec/specs/skill-pack-telegram-e2s-retirement/spec.md` ができ、4 つの MODIFIED/REMOVED が正本に反映されたことを確認する
- [ ] 4.4 生成された spec の `## Purpose` の `TBD - created by archiving change ...` を「harness から skill-pack・telegram・experience-to-skill の 3 プラグインを解散した状態を定める。代替は Claude Code 本体の機能と公式プラグイン・公式スキルなので、harness に同じ部品と仕様を残して正本が 2 つになることを防ぐ。」に書き換える
- [ ] 4.5 archive 後に `scripts/test.sh` をフォアグラウンドで再実行して exit 0 を確認する（参照掃除の検査が生成された main spec を許容場所として扱うことを含む）。続けて PR 本文の受け入れ条件 3（参照 0 件）を実行して確認する。ここで初めて全件 pass と参照 0 件を確かめ、Draft PR の CI が緑に戻ることを見る
