# usage-snapshot-multi-account — 設計

## Context

Claude Code 本体（v2.1.259）の Keychain サービス名生成関数は次のロジックで、コード確認済み:

```js
function Gx(n = "") {
  let e = process.env.CLAUDE_SECURESTORAGE_CONFIG_DIR,
      t = e !== undefined ? !e : !process.env.CLAUDE_CONFIG_DIR,
      r = e !== undefined ? e.normalize("NFC") : configDir(),
      c = t ? "" : `-${sha256(r).substring(0, 8)}`;
  return `Claude Code-credentials${n}${c}`;
}
```

つまり `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定または**空文字**なら既定の `Claude Code-credentials`、値があれば `Claude Code-credentials-<sha256(NFC 正規化した値) の先頭 8 桁>` になる。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を使うと `CLAUDE_CONFIG_DIR`（設定・履歴・プラグイン）を共有したまま認証情報だけを分離できる。

実測で確認済みの事実:

- `CLAUDE_SECURESTORAGE_CONFIG_DIR=$HOME/.claude-b claude auth status` → `loggedIn: false` かつ `projectsDirectory` は `~/.claude/projects` のまま（環境共有・認証のみ分離）
- SessionStart フックのサブプロセスには `CLAUDE_SECURESTORAGE_CONFIG_DIR` と `CC_ACCOUNT` の両方がそのまま伝わる（`claude --settings <一時ファイル> -p` で env をダンプするフックを仕込んで検証）
- **statusline サブプロセスへの env 伝播は未検証**

現行の制約:

- `plugins/dev-workflow/scripts/usage-probe.sh` は Keychain サービス名を `Claude Code-credentials` にハードコードしている
- `/api/oauth/usage` のレスポンスには `five_hour` / `seven_day` / `limits[]`（モデル別 weekly）が含まれ、1 アカウント分の全数字が 1 リクエストで取れる。現行 probe は `seven_day.utilization` と `limits[]` の Fable weekly しかパースしていない
- snapshot の唯一の機械的な読み手は `scripts/session-tripwires.sh`（`FABLE_BUDGET_MODE` 導出）と `plugins/statusline/scripts/statusline.sh`（Fable weekly 表示）
- ユーザーは 2 つ目のアカウントをまだ契約していない

## Goals / Non-Goals

**Goals:**

- スロットが 1 つ（＝レジストリ不在。現在のユーザー環境）のとき、probe の出力も statusline の表示も**現行と完全に同一**であること
- 複数スロットのとき、スロットごとに使用量を取得し、statusline がアカウント別に表示できること
- snapshot の既存読み手（`session-tripwires.sh`）を**無改修**で動かすこと
- 非 active アカウントのフェッチが常態的に失敗しても、そのスロットの前回値が消えないこと

**Non-Goals:**

- `refresh_token` を使ったアクセストークンの更新（後述の決定で明示的に除外）
- アカウントの切り替え操作そのもの（シェル側の env 設定であり、このスコープ外）
- `~/.claude/.rate-limit-snapshot` の扱い（statusline が書くだけで読み手が存在しない。grep 確認済み）
- レジストリの GUI / TUI 編集（雛形と手順の提供までとする）

## Decisions

### D1: アカウント定義をレジストリファイルに外出しし、不在時は既定スロット 1 つに縮退する

`~/.claude/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）にスロットを列挙する。スロットは id / label / securestorage パスを持ち、securestorage が null または空文字なら既定アカウントを指す。

**ファイルが存在しない・読めない・パースできない場合は「既定スロット 1 つだけのレジストリ」として扱う**。これによりユーザーが 2 つ目のアカウントを契約するまで、この変更は挙動を一切変えない。

*代替案*: env（`CLAUDE_ACCOUNTS` に区切り文字列）でスロットを渡す案は、label と securestorage パスの 2 値を持つ必要があり、パスに空白が入りうるためエスケープ規則を発明することになる。JSON ファイルなら `jq` / `python3` で素直に読め、statusline と probe の両方から同じ読み方ができる。

### D2: snapshot を schema 2 に「追加のみ」で拡張し、トップレベルの従来キーを active スロットの値でミラーする

schema 2 は `accounts`（スロット id → 値）と `active`（現在のスロット id）を**追加**し、従来のトップレベルキー（`fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch`）は active スロットの値をミラーして残す。

*代替案*: schema 2 に一本化して読み手（`session-tripwires.sh`）を同時に直す案は、snapshot の生産者（dev-workflow）と消費者が別のタイミングで更新されうるプラグイン構成では、片方だけ更新された環境で `FABLE_BUDGET_MODE` が黙って `conserve` に落ちる。ミラーを残せば、古い読み手も新しい読み手も同じ snapshot で動く。ミラーの重複は数バイトのコストにすぎない。

### D3: fail-open の粒度をスロット単位にする

非 active アカウントは OAuth アクセストークンが期限切れでフェッチが落ちるのが**常態**である（トークンのリフレッシュは、そのアカウントで Claude Code を実際に動かしたときにしか起きない）。全体 fail-open のままだと、非 active スロットが 1 つでも失敗した時点で active スロットの新しい値も書けなくなり、常に snapshot が更新されなくなる。

そこでスロットごとに「今回取れた値 → 無ければ既存 snapshot の同スロットの前回値 → それも無ければ欠測」の順で埋める。既存の全体 fail-open 契約（パース不能・書き込み不能時に snapshot 全体を壊さない）はそのまま維持する。

*代替案*: 失敗スロットを snapshot から落とす案は、statusline の行が消えたり出たりして視覚的に不安定になる。前回値＋取得時刻を残せば「いつ時点の数字か」を表示側で判断できる。

### D4: `refresh_token` によるトークン更新を実装しない

Keychain に入っている `refreshToken` を使えば非 active アカウントのアクセストークンを更新でき、常に新鮮な数字が取れる。しかし**リフレッシュはトークンをローテートする**ため、Claude Code 本体が同じ refresh_token でリフレッシュを試みたときに無効化され、そのアカウントがログアウト状態になりうる。使用量表示のために認証を壊すのは割に合わない。

代わりに、非 active スロットは前回値を保持し、statusline の行末に取得からの経過時間（例 `2h前`）を出して鮮度をユーザーに委ねる。

*この判断はコードコメントにも残す*（将来「なぜリフレッシュしないのか」を再発明させないため）。

### D5: active スロット判定は `CLAUDE_SECURESTORAGE_CONFIG_DIR` 優先、snapshot の `active` にフォールバック

SessionStart フックへの env 伝播は実測済みだが、**statusline サブプロセスへの伝播は未検証**。statusline で env が取れなかった場合に既定スロットへ倒すと、B アカウントのセッションで A の行がライブ値として描かれ、取り違えが起きる。

そこで「env が取れればそれで判定、取れなければ snapshot の `active`（probe が env から書いた値）を使う」の二段にする。A と B のセッションを同時に開いても、probe 側の env は伝播が確認済みなので `active` は正しく書かれる。

*代替案*: env だけに頼る案は伝播が確認できていないため採れない。snapshot だけに頼る案は、statusline が probe より先に走る場合（初回・TTL 内でアカウントを切り替えた直後）に古い `active` を使ってしまう。

### D6: statusline のバー描画ロジックは作り直さず、既存の `bar_seg` / `bar2` をそのまま使う

行の左端にスロット label 列を足し、行の生成をスロットのループに包むだけにする。色分け・日程線・分母表示（`82%/74%`）の意味論は現行と同じものを維持する。

**スロットが 1 つのときは label 列自体を出さない**ため、1 スロット時の出力は現行と 1 バイトも変わらない。

### D7: `five_hour` も取得対象に加える

`/api/oauth/usage` は 1 リクエストで `five_hour` も返すため、追加のネットワークコストはゼロ。非 active スロットの 5h 行を snapshot から描くために必要になる（active スロットは従来どおり stdin のライブ値を使う）。

## Risks / Trade-offs

- **[非 active スロットの数字が古くなる]** → D4 の意図的な帰結。取得時刻を snapshot に持ち、statusline の行末に経過時間を併記して、ユーザーが鮮度を判断できるようにする。
- **[スロット数に比例して probe の実行時間が伸びる]** → スロットごとに 1 リクエスト。TTL（既定 300 秒）キャッシュは snapshot 単位で維持し、`--max-time 10` の上限も据え置くため、最悪ケースはスロット数 × 10 秒。現実的なスロット数（2〜3）では問題にならない。
- **[レジストリの securestorage パスがユーザーの実環境と食い違うと、無言で既定アカウントの値を取る]** → サービス名の導出は本体と同じロジックを使うため、パスが正しければ一致する。パスが誤っていれば Keychain の項目が存在せずフェッチが失敗し、スロット単位 fail-open で欠測として扱われる（既定アカウントの値が混入することはない）。
- **[statusline への env 伝播が実は無い場合、`active` の判定が snapshot 頼りになる]** → D5 のフォールバックで動作は保たれる。TTL 内でアカウントを切り替えた直後だけ 1 サイクル分の遅れが出る。
- **[schema 2 のミラーが active スロットの値と食い違う]** → ミラーは常に active スロットの値から機械的に生成し、独立に計算しない。テストで両者の一致を検証する。

## Migration Plan

1. probe を schema 2 に更新する。既存の schema 1 の snapshot が残っていても、次回の probe 実行で schema 2 に置き換わる（`accounts` が無い snapshot からは前回値を引き継げないが、TTL 経過後の初回フェッチで埋まる）。
2. statusline を更新する。schema 1 の snapshot を読んだ場合はトップレベルキーのみが存在するため、既定スロット 1 つとして現行どおり描画する（前方互換）。
3. ロールバックは両スクリプトを戻すだけで済む。schema 2 の snapshot はトップレベルの従来キーを持つため、古い probe / statusline / `session-tripwires.sh` から読んでも壊れない。

## Open Questions

- statusline サブプロセスへの `CLAUDE_SECURESTORAGE_CONFIG_DIR` 伝播の有無（D5 のフォールバックで両対応済みのため、実装をブロックしない）。実機で 2 アカウント運用を始めた時点で確認し、伝播があるなら snapshot フォールバックは保険として残す。
