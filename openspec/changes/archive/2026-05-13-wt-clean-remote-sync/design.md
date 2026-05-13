## Context

現状 `wt-clean` は以下の責務を持つ（`plugins/worktree/commands/wt-clean.md` / `plugins/worktree/skills/wt-clean/SKILL.md`）:

- メインリポのルートで実行する前提
- `git worktree list` で worktree を列挙
- `git branch --merged <main>` でマージ済みか判定 → 🟢/🟡/🔴 に分類
- LLM 保全 → サニティチェック → 削除 or 再利用化

問題はこの「マージ済み判定」が**ローカル `<main>` ベース**で行われる点。Issue-Driven workflow（このリポジトリでも採用）では feature ブランチは GitHub 側で PR マージされるため、ユーザーがローカル `<main>` を pull するまでは worktree が `🔴 Active` 扱いとなり、スキップされる。

ユーザーが手動で `git pull` してから `wt-clean` を叩けば回避できるが、これは「PR マージ → 片付け」の流れの中で頻繁に発生する 2 ステップ操作で、別スキル化（`longrun-pr-merge-sync`）の議論があった。本 change では別スキルを作らず、`wt-clean` 自体に remote 同期フェーズを組み込むことで責務を統合する。

なお `wt-clean` Step 7b には「`git pull` / `git fetch` — 最新化はユーザー責任」と明記されているが、これは Step 7b（**再利用化処理中**に worktree 内で実行すると tracked ファイルを巻き込んで破壊するリスクを避ける）という限定的な禁則であり、診断前のメインリポでの fetch/pull を禁じる意図ではない。今回の change ではこの文脈分離を spec 上明示する。

## Goals / Non-Goals

**Goals:**

- `wt-clean` 実行時、デフォルトでローカル `<main>` を `origin/<main>` に同期してから診断する
- PR マージ済みの feature ブランチが `🟢 Safe` として正しく分類される
- 既存の Step 1〜8 のロジックは可能な限り変更しない（前段に Step 0 を足すだけ）
- 同期を望まないケース（オフライン作業、意図的な古い main 維持）には `--no-sync` で対応
- `longrun-pr-merge-sync` という別スキルは作らない。重複と判断する

**Non-Goals:**

- GitHub PR の状態問い合わせ（`gh pr view` 等）はしない。`git branch --merged` で十分
- `git pull` 失敗時のリカバリ（rebase / merge 戦略の自動選択）はしない。`--ff-only` で失敗したら一旦中断しユーザーに委ねる
- `origin` 以外の remote 名対応はしない（必要になったら次の change で）
- ブランチ名検出は既存の main/master 検出ロジックを流用。新しいブランチ命名規則対応はしない
- `wt-setup` 側の挙動は変更しない（worktree 作成時の同期は別 change）

## Decisions

### Decision 1: デフォルト同期 ON、オプトアウトは `--no-sync`

**採用**: デフォルトで `git fetch origin` + 必要なら `git pull --ff-only origin <main>` を実行。`--no-sync` で従来挙動。

**代替案と却下理由**:

- デフォルト OFF、`--sync` でオプトイン: 後方互換性は最大だが、`wt-clean` を「PR マージ後の片付け」に使うユースケースが主流になりつつあるため、毎回 `--sync` を付ける負担が大きい。本来やりたいことのデフォルトに合わせる方が筋が良い
- 都度 `AskUserQuestion` で確認: 同期は冪等で副作用が小さい（fast-forward 不可なら失敗するだけ）ので、対話を挟む UX 損失の方が大きい

**根拠**: 「同期は wt-clean の責務」と spec で位置付ける以上、デフォルトに据えるのが整合的。オプトアウト経路だけ用意すれば足りる。

### Decision 2: `git pull --ff-only` を使う

**採用**: `git pull --ff-only origin <main>` で fast-forward マージのみ許可。

**代替案と却下理由**:

- `git pull` （デフォルト merge 戦略）: ローカル `<main>` に独自コミットがあると merge コミットが作られる。意図せず履歴が汚れる
- `git pull --rebase`: ローカル `<main>` 独自コミットを rebase してしまう。`<main>` で直接コミットしている運用は通常ありえないが、万一あれば履歴の改変は破壊的
- `git fetch` のみ + `git merge --ff-only origin/<main>`: 2 コマンドに分けてもやることは同じ。`git pull --ff-only` で十分

**根拠**: `<main>` は本来 PR 経由でしか進まないため fast-forward が成立する。`--ff-only` で失敗するのは「ローカル `<main>` に直接コミットしている」「force-push された」等の異常系で、自動回復を試みる方が危険。

### Decision 3: `--ff-only` 失敗時はエラー終了し、後続処理を実行しない

**採用**: `git pull --ff-only` が失敗したらエラーメッセージを表示して即座に中断。worktree 診断・削除には進まない。

**代替案と却下理由**:

- 警告を出して同期スキップ → 診断は実行: 「同期できなかった」状態で診断するとマージ判定が古いまま走るため、PR マージ済みの worktree が `🔴 Active` 扱いになる。ユーザーが「同期されているはず」と誤解した状態で削除確認が出ると事故リスク
- 自動で `--rebase` にフォールバック: Decision 2 の根拠と矛盾

**根拠**: 同期失敗は通常 worktree が抱える状況とは独立の問題（ローカル `<main>` を汚した／remote が force-push された）。これは `wt-clean` のスコープ外なので、ユーザーに解決を委ねる。

### Decision 4: `--no-sync` を提供する

**採用**: `wt-clean --no-sync` で Step 0 を完全にスキップ。

**代替案と却下理由**:

- 環境変数で制御: 一時的なオプトアウトには重い
- 提供しない: オフライン作業、意図的に古い `<main>` 維持で削除確認したい等のニッチユースケースに対応できない

**根拠**: 破壊的変更に対する safety net として、明示的な opt-out 経路を 1 つ用意する。利用頻度は低いが提供コストも低い。

### Decision 5: `--keep` と `--no-sync` は併用可能

**採用**: `wt-clean --keep --no-sync` のように両オプション併用を許可する。

**根拠**: 直交する関心事（同期 vs 再利用モード）なので併用を制限する理由がない。

### Decision 6: 完了レポートに同期結果を 1 行で表示

**採用**: Step 8 完了レポートの先頭付近に以下のいずれかを表示:

```
Remote 同期: ✅ pulled 3 commits (origin/main → main)
Remote 同期: ✅ already up-to-date
Remote 同期: -- skipped (--no-sync)
```

**根拠**: ユーザーが「今回マージ判定が新しい/古い `<main>` のどちらを使ったか」を一目で判別できる。トラブルシュート時の手がかりにもなる。

### Decision 7: `longrun-pr-merge-sync` は作らない

**採用**: 別スキルとして作成せず、backlog にキャンセル理由を残す。

**根拠**: 本 change で wt-clean に統合済み。残すと「同じことをするスキルが 2 つある」状態になり、利用者が迷う。前回会話で「wt-clean 統合の方が筋」とユーザー判断済み。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| デフォルト挙動変更でユーザーが意図せず remote と同期する | レポートで `pulled N commits` を明示表示。`--no-sync` で容易にオプトアウト可能。破壊的操作（rebase, force）は使わないので最悪でも fast-forward の追加コミットのみ |
| `git pull --ff-only` 失敗で wt-clean が中断する | エラーメッセージで原因（ローカル `<main>` が divergeしている等）と対処（`git status` / `git log` で確認）を案内する |
| 既存の `wt-clean --keep` 利用者が同期 ON で挙動が変わる | `--keep` 利用時も Step 0 は同期 ON。レポートで明示するため気付きやすい。`--no-sync` で従来挙動 |
| `<main>` 検出ロジックが間違って `master` を pull してしまう | 既存の検出ロジック（`git show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true`）を流用。新しいロジックは導入しない |
| `origin` remote が存在しないリポジトリで失敗する | Step 0 冒頭で `git remote get-url origin` を確認。`origin` がなければ `Remote 同期: -- skipped (no origin remote)` と表示してスキップ（エラーにしない） |
| commands 版 / skills 版が乖離する | wt-clean-keep-option change と同様、両ファイルを同じ PR で更新する |
| プラグインキャッシュにより新挙動が反映されない | `plugin.json` のバージョンを 1.1.0 → 1.2.0 に bump（既存 wt-clean-reuse change と同じ手法） |

## Migration Plan

1. `commands/wt-clean.md` に Step 0 + `--no-sync` 受付を追加
2. `skills/wt-clean/SKILL.md` に同じ変更を同期し、frontmatter の `version` / `description` を更新
3. `plugin.json` / `marketplace.json` のバージョン bump
4. `openspec/backlog.md` に `longrun-pr-merge-sync` キャンセル記録を追記
5. commit & push → `/reload-plugins` で反映確認
6. ユーザーが実際の worktree クリーンアップで動作確認

ロールバック: Step 0 の記述を削除すれば従来挙動に戻る。`--no-sync` オプション記述も削除すれば完全に Decision 反転前の状態。

## Open Questions

なし。実装時に判断で良い論点:

- 同期スキップ条件の表示文言（「up-to-date」「skipped」等の細かい言い回し）
- `git fetch` 単体で失敗した場合の扱い（remote 到達不能等）→ `--ff-only` と同じくエラー中断で良い見込み。実装時に最終決定
