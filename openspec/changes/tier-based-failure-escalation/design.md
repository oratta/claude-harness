# Design

## Context

動機は proposal.md の Why を参照。#614 のあと、`codex-develop.py request` は phase と格の入力（`--pre-class`・`--design-judgment`・`--failure first|executor|judgment`・`--unmanned`）と残量モードから格を決め、`references/model-tier-map.json` で executor ごとのモデル名に置き換えて返す。`--failure` の効果は `openspec/specs/model-tier-resolution/spec.md` の要件「格は役と入力だけから決める」が決めている:

- W の phase（`spec`・`implement`・`finish`）は `--failure executor` で上位に上がり、`first`・`judgment` では上がらない（下がりもしない）
- phase `decider` は `--failure first`・`executor` で上位、`judgment` か `--failure` なしで最上位
- 対応表は claude が 中位=`sonnet`・上位=`opus`・最上位=`fable`、codex が 中位=`sol`・上位=`sol`・最上位=`astra`

一方で文書は次のとおり #614 以前の形が残っている。

- `templates/escalation-tripwires.md` のラダーの表は列の値が `sonnet`・`opus`・`fable` で、`--failure` の値との対応が無い
- `skills/develop/SKILL.md`「モデル」節の昇格の段落は「decider の `model` の段は `templates/escalation-tripwires.md` を Read して従う」「W を `opus` で再開」と書き、同じ節の冒頭の「新しい起動の `model` を文章の規則で計算し直さない」と食い違う
- `references/codex-develop.md` は失敗ループに触れていない。再開前の格の比較は「返った `tier` が thread の格より低くないときだけ SendMessage」で、格が上がったときの扱いが無い。SendMessage の再開では model を変えられないので、`--failure executor` で上位が返っても中位の thread のまま再開され、昇格が黙って起きない
- `skills/develop/references/roles/worker/common.md`「昇格トリップワイヤー」も「W を `opus` で再開」と要約している

## Goals / Non-Goals

Goals:
- 失敗ループの各段で本体が `request` に何を渡し、返った値をどう使うかを、Claude と Codex のどちらの profile でも同じ文で読めるようにする
- 本体が profile・model・effort を手で差し替える経路を、規則の文として閉じる

Non-Goals:
- `request` や `agent-model-guard.sh` の判定を変えること。上位格のモデルを実行役に付けた依頼の拒否と、develop 開始後の profile 差し替えの機械的な拒否は #615 に寄せる
- `skills/pr-review-gate/stages/triage.md` の 2-2（修正サイクルのモデル昇格）の書き直し。同じ形の記述があるが、ゲートの修正サイクルは別の capability（`dev-workflow-pr-review-gate`）で、#424 の触るファイルに無い。必要なら別 issue にする

## Decisions

### ラダーの表は格と `--failure` の値で書く

表の列を「段階・`--failure` の値・決める役の格・実行役の格」にする。モデル名は「`references/model-tier-map.json` で引いた値」と書き、Claude での値は括弧書きで残す（hook 注入でテンプレートを読む本体自身は Claude で動くことが多く、括弧の値で読み替えずに済む）。

| 段階 | `--failure` | 決める役（phase `decider`） | 実行役（W の phase） |
|---|---|---|---|
| 初回 | なし | 仕様化判断と R1 レビュー | 既定の格（中位） |
| 1 回目の失敗 | `first` | 上位 | 格は変えない |
| 2 回目・実行側 | `executor` | 上位 | 上位（上限） |
| 2 回目・判断側 | `judgment` | 最上位 | 格は変えない |
| 最上位が決めて上位が実行しても落ちる | — | 人間へ | — |

案として「Claude 用と Codex 用の 2 つの表を並べる」も考えたが採らない。同じ規則を 2 か所に書くと片方が漏れ、Codex の表に上位=`sol` と書くことは対応表の値の再掲になる。格の表 1 つと対応表への参照なら、対応表を変えても文書を直さずに済む。

### 本体は `request` が返した model だけを使い、profile・model・effort を差し替えない

実行側の失敗では、本体は `request --phase implement --failure executor` を呼び、返った `model` で実行役を起こす。profile を作り直すこと、`--profile` / `--profile-file` を開始時と違う値にすること、`model` を明示することは、失敗ループの昇格の手段にしない。Codex では上位も `sol` なので実装役のモデルは変わらない。これが issue #424 の「実行側の失敗では implement のモデルを変えない」を、格の言葉で満たす形になる。

effort は上げない。effort は profile の entry の値で、`request` は格の入力で effort を動かさない。案として「実行側の失敗で effort だけ 1 段上げる」も考えたが採らない。flatmate#847 の事故は astra と high の組み合わせで、effort の上げ下げを本体の判断に残すと、モデルを据え置いても同じ形の消費が起きうる。effort を変えたいなら profile を変える扱いになり、下の「profile の指定を途中で変えない」に従う。

### 格が上がって model が変わるときは fresh thread に手渡す

再開前の比較に「上がった場合」を足す。返った `tier` が thread の格より高く、返った `model` が thread の起動時の applied model と違うときは、SendMessage せず、返った model で新しい thread を起こし、前任の return と成果物を手渡す。`model` が同じ（Codex の 中位→上位、`tier_cap` で同じ格に下がる構成）なら SendMessage で再開してよい。Codex role は委譲ごとに fresh なので、この比較は Claude role にだけ効く。

比較の基準を `tier` だけにする案（「高ければ常に fresh」）も考えたが採らない。model が変わらないのに thread を捨てると、成果の手渡しの手間だけが増える。SendMessage で変えられないのは model なので、model の差で分ける。

### decider の格は `request` の返り値から取る

SKILL.md「モデル」節は、`--failure` の各値と失敗の段の対応（`first` = 1 回目の失敗、`executor` = 2 回目で実行側、`judgment` = 2 回目で判断側）だけを書き、decider の model は `request --phase decider --failure <値>` が返した値を使う、と書く。escalation-tripwires.md を Read して model を決める指示はやめる（判断側・実行側の分類の定義を読む先としては残す）。

今のラダーにある「本体が opus 以上ならその場で」「本体が fable ならその場で」（決める役を起こさず本体が自分で決める）の但し書きは消す。本体のモデルは profile と格の外にあり、残すと `request` を通らない経路が残るため。

### develop 開始時の profile の指定を工程の途中で変えない

開始時の指定（`--profile NAME`・`--profile-file PATH`・旧形式・無指定のどれか）を、develop の終わりまで同じ値で `request` に渡す。無指定は phase ごとに構成を選び直すのが既存の規則で、それ自体は変えない（無指定から明示に、明示から別の明示に変えることを禁じる）。変える必要があるときは、主に承認を求め、記録先に `profile 変更: <変更前の指定> → <変更後の指定>` の行と主の承認の発言を引いたコメントを残してから変える。

機械的な拒否は作らない。`request` は呼び出しごとに状態を持たず、開始時の指定と比べるには記録先の開始コメントを読む仕組みが要る。#615 が作る `request` 側の検証と同じ場所に置くほうが重複しないので、#615 に寄せる。

## Risks / Trade-offs

- [文の規則だけでは本体が profile を差し替えるのを止められない] → #615 の機械的な拒否が入るまでの間は文だけが歯止めになる。codex-develop.md の文に「失敗ループの昇格の手段にしない」と明記し、bats で文を固定する
- [テンプレートは全セッションに注入されるので、表の書き換えで develop 以外の読み手が戸惑う] → Claude での値を括弧で残し、既存の「`dev-workflow:decider` に固定し model だけ切り替える」「実行役の上限は上位（`opus`）」の文は残す
- [編集するファイルが文書 4 つ・bats 2〜3 つ・変更の記録で 5 を超える] → 編集は文言の書き換えで、作業項目は tasks.md の範囲で固定する。実装で増えたら規模超過として return する

## Migration Plan

文書とテストの変更だけで、配布後に本体が読み直すだけで効く。戻すときは PR を revert する。
