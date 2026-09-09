#!/usr/bin/env bats
#
# 手渡し規則の正本（`skills/develop/references/decision-criteria.md` の
# 「コンテキスト上限（サブエージェントの手渡し）」節）が①〜④を現に規定していることの検査
#
# 2026-09 の事故（バックグラウンドコマンド待ちで idle になっていた前任 W を「工程を終えた」と
# 誤認して手渡し、同じ worktree に新旧 2 人の W が並んだ）を受けて、判定材料を本体側の内容
# 判断から W / G 側の return 1 行目宣言に移した。その規則を 10 前後の面に言い換えて配ったことが
# 3 周続けての書き換え漏れを生んだので、本文を正本 1 箇所に畳み、他の面は参照だけを書く設計にした。
#
# 「本文が正本 1 箇所にしかない」ことはこのファイルでは検査しない。規則の言い換えを機械で
# 検出する試みは PR #253 で 7 周続けて fail-open で落ちており、機械検査が成立するかごと
# follow-up issue に切り出した（下の spec 参照）。再掲を捕まえるのは spec の MUST NOT と
# 仕様レビューである。
#
# このファイルが担う検査は 1 つ: 正本が①〜④を実際に規定していること（`criteria:` 系）。
# spec は①〜④の答えを再掲しないので、正本の答えが逆に書き換わったときに落ちるのはこのテストだけ。
#
# spec: dev-workflow-execution-strategy, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
}

# 「## <見出し>」から次の見出し（`## ` または `### `）までを切り出す。
# `## ` だけで止めると、節のあとに続く `### ` 小節まで巻き込む（正本の節では残量モードの 2 小節が
# 入り、正本の本文がその小節へ移動しても `criteria:` 系が緑のままになる。PR #253 のレビュー指摘）。
section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^#{2,3} /{f=0} f' "$1"; }
# decision-criteria.md のコンテキスト上限節（＝正本）
cap_sec() { section "$CRITERIA" 'コンテキスト上限（サブエージェントの手渡し）'; }
role_sec() { section "$SKILL" '本体の役割'; }

# ---------------------------------------------------------------------------
# 1. 正本が①〜④を規定していることの検査
#
# spec（dev-workflow-execution-strategy）は①〜④の答えを再掲しない（MUST NOT）ので、
# 正本が「上限超過なら即座に手渡してよい」に書き換わっても `openspec validate` は通る。
# 規範の中身を担保するのはこの節の検査だけなので、他の検査を外すときも一緒に落としてはならない。
# `grep` の引数として正本の断片を引用することは、spec が禁じる「言い換え」に当たらない
# （テストは読ませる面ではなく、正本の本文が壊れていないことを機械的に検査する面であるため）。
# ---------------------------------------------------------------------------

# ①送ってよい SendMessage と送ってはならない SendMessage
@test "criteria(1): exit-2 non-resume is unconditional and scoped to continuation SendMessage only" {
  cap_sec | grep -qF '再開の禁止は無条件'
  # 述語まで含めて固定する。話題語だけを見ると「送らない」→「送ってよい」の反転が素通りする
  cap_sec | grep -qF '作業の継続を指示する SendMessage（＝再開）を送らない'
  cap_sec | grep -qF '停止を指示する SendMessage は禁止の対象外'
}

# ②手渡しを行ってよい条件
@test "criteria(2): handoff is permitted only when the predecessor declared process-complete" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '手渡しの許可'
  # 「行ってよいのは…のいずれかだけ」を述語ごと固定する（限定が外れる反転を落とす）
  cap_sec | grep -qF 'を行ってよいのは、①前任の直近の return の 1 行目が'
  cap_sec | grep -qF '完全一致するとき'
  cap_sec | grep -qF 'のいずれかだけ'
}

@test "criteria(2): the cap alone is not a reason to swap the predecessor out right now" {
  cap_sec | grep -qF '「今すぐ交代させる」条件ではない'
}

# ③return の 1 行目の宣言（正本の③が規定する）
@test "criteria(3): process-suspended covers waiting on a self-started background command" {
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF 'バックグラウンドコマンド'
}

@test "criteria(3): appending an achievement list does not excuse declaring process-complete while the command is unfinished" {
  cap_sec | grep -qF '成果一覧を書いていても'
  # どちらの宣言が禁じられるかまで固定する。ここが入れ替わると、この PR が直した事故そのものが正本の
  # 指示になる（未完了でも「工程完了:」を宣言してよい状態）。語の存在だけを見ていると素通りする
  cap_sec | grep -qF '完了していなければ `工程完了:` を宣言してはならない（1 行目は `工程中断:` にする）'
}

# ③どちらの書式にも当てはまらない return の扱い（この書式を知らない W / G は展開直後に必ず現れる）
@test "criteria(3): a return matching neither literal is handled like the suspended declaration" {
  cap_sec | grep -qF 'どちらの書式にも'
  cap_sec | grep -qF '完全一致しない return は `工程中断:` と同じに扱う'
  cap_sec | grep -qF '読み替えない'
}

@test "criteria(3): idle while waiting is distinguished from a completed return" {
  cap_sec | grep -qF 'idle'
  cap_sec | grep -qF '工程の終わりではない'
}

# ④前任が動作中のまま交代させる手順と、その待ち方
@test "criteria(4): predecessor still running requires a stop instruction before handoff" {
  cap_sec | grep -qF '停止を指示'
  cap_sec | grep -qF '破壊的 git 操作'
  # 順序まで固定する。「停止確認」の語だけを見ると、spawn を先に許す反転が素通りする
  cap_sec | grep -qF 'を受け取ってから手渡し先を spawn する'
  cap_sec | grep -qF '停止確認を受け取る前に手渡し先を spawn しない'
}

@test "criteria(4): waiting for a stop confirmation is non-blocking, and unmanned ends the cycle instead of blocking" {
  cap_sec | grep -qF 'ブロックせず'
  cap_sec | grep -qE 'unmanned.*サイクルを終える|サイクルを終える.*unmanned'
}

# ④の待ちが①②と矛盾しないこと（前任が先に工程完了を返したら通常の手渡しに戻る）
@test "criteria(4): a process-complete return arriving first falls back to the ordinary handoff" {
  cap_sec | grep -qF '停止の手順は要らなくなり'
  cap_sec | grep -qF '通常の手渡しとして扱う'
}

# 書式リテラル（別エピックの子 issue がこの 2 つを前提にしている。spec が固定している）
@test "criteria: the two declaration literals are fixed and use the same format family as the spec decision" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF '仕様化判断: する|しない'
}

# 節の切り出しが次の見出しで止まること。止まらないと、正本の本文が後続の小節へ移動しても
# 上の `criteria:` 系が緑のまま通る（PR #253 のレビュー指摘）。
@test "criteria: the source section stops at the next heading, not at the next level-2 heading" {
  cap_sec | grep -qF 'コンテキスト上限（サブエージェントの手渡し）'
  local leaked
  for leaked in 'の自動導出（usage snapshot 契約）' 'モード不変ルール'; do
    if cap_sec | grep -qF "$leaked"; then
      echo "正本の節に後続の小節が混ざっている: $leaked"; return 1
    fi
  done
}

# 同一 worktree の同一役割は 1 人（dev-workflow-develop の別要件）
@test "skill: same-worktree same-role concurrency is capped at one" {
  role_sec | grep -qE '1 人|同時に動く同一役割'
  role_sec | grep -qF '別々の worktree'
}
