# 独立 Claude 役の起動と計測（#1857 G002）

Codex 本体が解決済みの依頼を前景で渡す入口は `scripts/claude-role-launch.py`。
account は現在のログインと `CLAUDE_CONFIG_DIR` を継承し、切り替えない。汎用追加 argv は受けない。
担当と profile role は別入力で、対応は次のとおり。

| `--assignment` | `--role` | agent / ツール |
|---|---|---|
| W | spec-write / implement | worker: Read, Edit, Write, Bash, Grep, Glob, TaskStop |
| G | implement | gate-runner: Read, Bash, Grep, Glob, TaskStop |
| reviewer | impl-review / review | reviewer: Read, Bash, Grep, Glob, TaskStop |
| R1 | spec-review | spec-reviewer 本文と上記ツールの明示経路 |
| decider | decider | decider: Read, Grep, Glob |

model は同じ配布物の `tier_caps.py` / `model-tier-map.json` で検査する。W の上限は表の
role_caps、Fable は decider だけ。worker 定義の既定値による上書きは実機 probe のログでも照合する。
全経路に `--disallowedTools Agent` と正整数 `--max-turns` を渡す。`--mode explicit` は役本文を
読み込み、同じツール集合を `--tools` へ明示する。decider に Bash / Edit / Write を渡さない。

最初に小さい turn 上限の `--verify` を実行する。CLI の実体・版・plugin 全内容と担当・role・model・mode
に結び付く外部 verification を生成する。通常起動はこの一致を要求する。CLI / plugin が変われば再検証する。
probe は上限到達・ログの実効 model・実行ツールの許可集合・回収を機械照合するが、役本文の実読込、
全ツール集合と Agent 不在の照合、孫の不実行は本体が実機証跡で確認する。機械 probe の成功だけで
実機受入れや品質合格を宣言しない。定義経路が使えないときだけ明示経路で同じ実機確認を行う。
上限拒否・不作動なら起動不可または中断とし、上限を外した再試行はしない。

## 本体の登録と毎回の計測

初回計測の前に、自身の実 thread / rollout / home をリポジトリ外の JSONL に登録する。
以下は実値を渡す例（`PLUGIN` は作業ツリーの `plugins/dev-workflow` の絶対パス、`LEDGER` は外部パス）。
登録・指示・verification・会話ログ・証跡を作業 repo に置かない。持続的な会話ログ保存先を新設する場合は
`LLM_LOG_DIR` に従い、未設定なら本体が主へ確認する。一時証跡は `mktemp -d` の外部領域を使う。

```bash
python3 - "$PLUGIN" "$LEDGER" "$THREAD" "$ROLLOUT" "$CODEX_HOME" <<'PY'
import os,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(sys.argv[1])/'scripts'))
import importlib.util
spec=importlib.util.spec_from_file_location('launch',Path(sys.argv[1])/'scripts/claude-role-launch.py')
launch=importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)
common=subprocess.check_output(['git','rev-parse','--path-format=absolute','--git-common-dir'],text=True).strip()
launch.register(Path(sys.argv[2]),dict(schema_version=1,provider='codex',kind='coordinator',records=[1857],
    repo_common_dir=os.path.realpath(common),cwd=os.getcwd(),thread_id=sys.argv[3],
    log_path=str(Path(sys.argv[4]).resolve()),codex_home=str(Path(sys.argv[5]).resolve())))
PY
"$PLUGIN/scripts/pr-token-measure.sh" --repo oratta/claude-harness 1857 --session-records "$LEDGER"
```

`records` に PR が分かれば併記する。Claude 役は起動前に launcher が同じ JSONL へ原子的に追記する。
本体 thread/home が分からなければ欠損を記録し、空履歴を 0 消費としない。
既存 Claude subagent、独立 Claude session、Codex 本体を同じ上限で毎回測る。Claude は実体ログと session、
Codex は thread で重複排除する。数値コメントがあっても進行中 rollout を再読し、最大累計を採る。
独立役は `claude_sessions` に session_id / log_path / tokens / requests、既存 subagent は `agents` へ出す。
`agent_count` は既存 subagent 数。欠測は `session_unresolved` と `session_errors` / stderr に出る。
既知超過は exit 2、その他の明示欠測は exit 1、上限以内かつ欠測なしは exit 0。

```bash
python3 "$PLUGIN/scripts/claude-role-launch.py" --assignment W --role implement --model opus \
  --cwd "$WORKTREE" --instructions "$PROMPT" --max-turns 50 --record 1857 \
  --session-records "$LEDGER" --plugin-dir "$PLUGIN" --verification "$PROOF"
```

再開前も同じ ledger で計測する。その後 `--resume <session_id> --transcript <transcript_path>` を加える。
別 session の最新ログを代用しない。launcher は直前に `subagent-context.sh --file` を呼び、exit 2 は上限中断、
exit 1 は欠測中断で再開しない。fresh への手渡し判断は本体に残す。

結果の session_id / transcript_path / requested_model / applied_models（実ログの model）、cli_exit_code / termination_reason、role_return、cleanup、
phase_declaration を別々に読む。launcher の exit は 0=正常輸送と回収、1=起動不可、2=中断。
W / G は正本の `工程完了:` 宣言が必要。reviewer / R1 / decider の verdict は role_return を本体が判断する。
TERM → 猶予 → KILL → 生存確認は所有した専用 group だけに行う。親や他の役を名前検索で止めない。
launcher 自身の SIGKILL、OS 停止、group を離脱した子孫は回収保証の外で、結果欠損を完了としない。

## 本体による実機確認（実装 worker は起動しない）

`claude-role-live-check.py` は `--execute` を明示したときだけ実 CLI を起動する。
作業ツリーの plugin を `--plugin-dir` で読み、外部一時 repo に commit と未コミット変更を作る。
stdout は summary、stderr の `evidence_dir:` に外部証跡の場所が出る。証跡は自動削除しない。

```bash
python3 "$PLUGIN/scripts/claude-role-live-check.py" --execute --case capability --model sonnet
# 出力の verification を PROOF へ設定してから実行
python3 "$PLUGIN/scripts/claude-role-live-check.py" --execute --case normal --verification "$PROOF"
python3 "$PLUGIN/scripts/claude-role-live-check.py" --execute --case git-deny --verification "$PROOF"
python3 "$PLUGIN/scripts/claude-role-live-check.py" --execute --case resume-cap --verification "$PROOF"
python3 "$PLUGIN/scripts/claude-role-live-check.py" --execute --case lifecycle --verification "$PROOF"
```

- capability は担当ごとに `--assignment` / `--role` / `--model` を変えて確認する。W / G / reviewer / decider の
  定義読込と、R1 の明示経路を確認する。定義が使えなければ `--mode explicit` で再検証する。
- 通常起動の role_return とログで、役本文・全ツール集合を列挙させ、Agent 起動を要求しても孫が実行されないことを
  照合する。decider は Bash / Edit / Write の不在を確認する。許可 opus と拒否 fable の W も確認する。
  入力 prompt は各外部 evidence_dir の instructions.txt にある。追加試行は同じ launcher argv の指示ファイルだけ
  差し替え、別の外部結果ファイルへ保存する。自動 probe だけでこの観測を省略しない。
- git-deny は一時 repo のみで `git reset --hard HEAD` を一回要求する。summary の before / after 一致に加えて、
  transcript の tool_use と G001 hook の実行前 deny を確認する。コマンド不実行や単なる拒否の自己申告だけは合格にしない。
  permit や agent_id を作らず、役に再実行させない。
- resume-cap は実 session のログを外部へ保存後、その同じパスに固定の超過 usage を一時配置し、exit 2 / 再開なしを確認する。
  元ログは finally で復元する。`context.exit_code=2`、session の不変を照合する。
- lifecycle は通常終了・turn 上限・子 CLI の SIGKILL・launcher の INT / TERM を順に試す。
  同じ group の背景 sleep を役に要求し、cleanup.ok と外側の対照の生存を照合する。
  CLI 起動直後の signal では背景生成前の場合があるため、transcript に背景起動があったかも確認する。
- 本体の実 rollout と各 summary の sessions.jsonl を、開発 repo の git common dir / cwd へ勝手に書き換えず、
  実際の作業の帰属に合わせて登録して計測する。usage 四項を request ID ごと、Codex を累計最大で独立に手計算し、
  再計測・追記・重複登録で合計と件数を照合する。別 repo の probe を本番作業へ紛れ込ませない。

issue #1857 には CLI 版・plugin HEAD / 内容照合、コマンド、期待値、観測値、各 exit code、session と外部証跡の所在を
記録する。実機未実施の tasks 5.1–5.3 は未チェックのまま残す。
役からテストする場合は `DEVELOP_ROLE=implement scripts/test.sh <suite filters>` を使う。
runner が Bats の子環境でだけ印を解除し、外側の役と hook の印は保持する。直接 Bats の追加 suite は setup で解除し、
役 fixture が必要な印を明示設定する。shard と残留プロセス検査は従来どおり適用する。
