#!/usr/bin/env bats
# openspec-specs-format.bats — openspec/specs/*/spec.md が「現行仕様の正本」の形を保っているかの退行ガード
#
# openspec には形の違う 2 種類の spec.md がある:
#   - openspec/specs/<capability>/spec.md      現行仕様の正本。`## Purpose` と `## Requirements` を持つ
#   - openspec/changes/<id>/specs/.../spec.md  差分表現。`## ADDED Requirements` 等の delta 見出しを持つ
# archive 時に後者を前者へ変換する工程が抜けると、delta 形式のファイルが正本の置き場に残り、
# openspec のツールからは「要件ゼロの capability」に見える（実際に 22 件が取りこぼされていた: issue #156）。
# ここではその取りこぼしを 3 条件で機械検出する。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SPECS_DIR="$REPO_ROOT/openspec/specs"
}

@test "no spec.md under openspec/specs uses change delta headings" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    if grep -qE '^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements' "$f"; then
      offenders="$offenders $f"
    fi
  done
  [ -z "$offenders" ] || {
    echo "delta headings found in:$offenders" >&2
    echo "hint: convert to '## Requirements' and add a '## Purpose' section" >&2
    false
  }
}

@test "every spec.md has both Purpose and Requirements sections" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    grep -qE '^## Purpose' "$f" || { offenders="$offenders $f(no-Purpose)"; continue; }
    grep -qE '^## Requirements' "$f" || offenders="$offenders $f(no-Requirements)"
  done
  [ -z "$offenders" ] || {
    echo "missing sections in:$offenders" >&2
    false
  }
}

@test "every spec.md starts with a canonical title line and none claims to be a Delta" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    first="$(head -1 "$f")"
    case "$first" in
      "# "*Specification*) ;;
      *) offenders="$offenders $f(bad-title)"; continue ;;
    esac
    case "$first" in
      *"(Delta)"*) offenders="$offenders $f(delta-title)" ;;
    esac
  done
  [ -z "$offenders" ] || {
    echo "bad title lines in:$offenders" >&2
    echo "hint: the first line must be '# <capability> Specification' without '(Delta)'" >&2
    false
  }
}

# develop の SKILL.md から references/ へ移した節を、spec が「SKILL.md の節」として名指ししていないこと（#1241）。
# 節名の一覧は移設先（epic.md・epic-child-stop.md・handover.md・fix-check.md・channel.md）の見出し。
# SKILL.md に中身が残る節（ループの終わり等）はこの一覧に入れない。
# grep の終了コードは 0=一致あり（落とす）/ 1=一致ゼロ（通す）/ 2=検索エラー（落とす）と分ける。
@test "no spec names a moved develop section as a SKILL.md section" {
  # C ロケールだと [^。] が 1 バイトずつ数えられ、日本語の行に一致しなくなる。UTF-8 に固定する。
  local re='SKILL\.md[^。]{0,8}[「『](エピックの扱い|エピックの子が主の返事を待って止まるとき|保留で止まるときの引き継ぎ|レビューの周を主に聞かずに続ける|channel の聞き方|channel のリスク許容|channel の主への発言|新しいセッションでの再開|回し方|作り方|完了条件|条件)'
  # 見本の行に正規表現が一致すること（一致しない環境で常に通ってしまうのを防ぐ）
  printf 'SKILL.md の「エピックの扱い」\n' | LC_ALL=C.UTF-8 grep -qE "$re"
  run env LC_ALL=C.UTF-8 grep -rnE "$re" "$SPECS_DIR"
  if [ "$status" -eq 1 ]; then return 0; fi
  echo "grep status=$status (0=stale references found, 2=search error)" >&2
  echo "$output" | cut -c1-200 >&2
  false
}

@test "dev-workflow-develop depleted scenario heading states the cap and keeps cheapest roles" {
  f="$SPECS_DIR/dev-workflow-develop/spec.md"
  run grep -qF 'すべての要求を Sonnet に固定' "$f"
  [ "$status" -eq 1 ]
  grep -qF '#### Scenario: depleted は中位を上限にし、最安の役はそのままにする' "$f"
}

# #1695: PR #1690 の追加段落は、シナリオではなく同じ要件の本文に置く。
# CLI が無い CI でも、openspec show の text / rawText の境界を検査する。
@test "epic reference paragraphs belong to requirement text before scenarios" {
  python3 - "$SPECS_DIR" <<'PYTHON'
import json
import sys
from pathlib import Path

cases = json.loads(r'''[
  [
    "dev-workflow-develop",
    "エピックの条件・作り方・回し方・完了条件を規定する",
    "回し方の本文は `references/epic-loop.md`（通常の進行）と `references/epic-subagent.md`（サブエージェント方式）、停止の解決は `references/epic-stop.md` に置く（MUST）。入口に親の起動・片付け・見張りの操作本文を残してはならない（MUST NOT）。"
  ],
  [
    "dev-workflow-develop",
    "エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ",
    "注意書きに従う投稿者の検査と nested の子側の処理は epic.md、親の投稿失敗への対処は epic-loop.md に置く（MUST）。子が注意書きを受けるだけで親の起動手順まで読むようにしてはならない（MUST NOT）。"
  ],
  [
    "dev-workflow-develop",
    "親は枠が空いたら後回しの子を起動し、サブエージェント方式でも同じ上限を当てる",
    "別セッション方式の後回しの子の通常進行は epic-loop.md、手順 8 の停止処理後の起動し直しは epic-stop.md、サブエージェント方式の枠・手渡し・再開の優先順は epic-worker-slots.md に置く（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う",
    "手順書では epic-loop.md の「主への報告」に共通の宣言を一度だけ置き、他の親向け文書はそこを読むよう指示する（MUST）。各手順末に同じ宣言を繰り返すことは要求しない。場面固有の例外・問いをなしで上書きしない条件は維持する（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "親は主の委任を、定型の委任の記録への主の直接の確認で受ける",
    "委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "親は委任の確認の場所をエピックに残す",
    "委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "主の委任は取り消しと新しい記録とエピックの終わりで切れる",
    "委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "親は有効な委任が効く止まりにだけ、委任で許容を送る",
    "委任の定型と有効性・種類別の適用条件の正本は `references/epic-delegation.md` とし、この親の操作手順から適用前に読む（MUST）。"
  ],
  [
    "dev-workflow-develop",
    "親が長く待ったあとは親の表で続けるか起動し直すかを決める",
    "親の時間分類の操作規則は reply-after-idle.md に一度だけ置き、epic-loop.md の起床時・手順 5・9 はそこを先に読む案内にする（MUST）。"
  ],
  [
    "owner-question-style",
    "主に問いを返す各所は正本を参照し、固有の事柄だけを残す",
    "エピックの親の共通の書き分けは epic-loop.md の「主への報告」に一度宣言し、停止・マージ待ち・サブエージェント方式の手順はこの宣言を読むよう指示する（MUST）。各手順末に同じ宣言を複写することは要求しない。"
  ],
  [
    "dev-workflow-develop",
    "時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める",
    "根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻、および同じファイルを `plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>` で測った会話量 N である。事実を読めない場合は、上の自動判定の要件と同じく確認できた条件だけで決め、どちらも真と確認できなければそのまま送ると書く（MUST）。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic-loop.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。"
  ],
  [
    "dev-workflow-develop",
    "親が長く待ったあとは親の表で続けるか起動し直すかを決める",
    "親の状態はエピックと子 issue のコメント・依存グラフ・子の状態記録から復元できると書く（SHALL）。`回し方:`、`子 #N マージ → 残り k 件` / `子 #N 見送り`、`後で別に起動するエピック:`、`子 #N のワークツリーを残した`、`親の判断: 子 #N 通した` と停止記録 URL の対応、`pending-owner` の確認を残す。比較する相手は手順書と引き継ぎを読む新セッションであり、要約と手順書再読み込みを二重に払う親の方針を #1385 で覆したと書く（SHALL）。監視停止が compact のせいだったとは断定しない。古い集計のリンクは履歴として残せるが、親の idle 閾値の再集計を現行の宿題にしない。"
  ]
]''')
errors = []
for capability, title, paragraph in cases:
    spec = (Path(sys.argv[1]) / capability / "spec.md").read_text()
    requirement = spec.split("### Requirement: " + title + "\n", 1)[1].split("\n### Requirement:", 1)[0]
    text, separator, scenarios = requirement.partition("#### Scenario:")
    if not separator or text.count(paragraph) != 1 or paragraph in scenarios:
        errors.append(f"{capability}: {title}: paragraph must appear once in text and never in scenarios")
assert not errors, "\n".join(errors)
print(f"{len(cases)} paragraphs in requirement text; none in scenario rawText")
PYTHON
}

@test "epic child argument scope names both same-repo and multirepo procedures" {
  python3 - "$SPECS_DIR/dev-workflow-epic-state/spec.md" <<'PYTHON'
import sys
from pathlib import Path

spec = Path(sys.argv[1]).read_text()
requirement = spec.split("### Requirement: 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く\n", 1)[1].split("\n### Requirement:", 1)[0]
text = requirement.split("#### Scenario:", 1)[0]
scope = next(p for p in text.split("\n\n") if p.startswith("この要件の守備範囲"))
for reference in ("references/epic-loop.md", "references/epic-multirepo.md"):
    assert f"`{reference}`" in scope, f"missing argument source: {reference}"
PYTHON
}
