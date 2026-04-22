## Context

`wt-clean` スキル（`plugins/worktree/commands/wt-clean.md` および `plugins/worktree/skills/wt-clean/SKILL.md`）は現状、マージ済み worktree を全て削除する設計になっている。Step 7 で `git worktree remove` + `git branch -d` を実行し、ディレクトリを物理削除する。

一方、`wt-setup` では worktree 作成直後に以下のセットアップコストが発生する:
- `.worktreeinclude` に基づく `.env` 等のコピー
- `.claude/` 配下サブディレクトリの symlink 作成
- `npm install` の実行（Node.js プロジェクトの場合）

これらは冪等な処理だが、特に `npm install` は重く、次タスク開始時の体感を悪化させる。完全にマージ済みかつ dirty でない worktree は、ディレクトリを残してブランチだけ main に戻せば、これら全てをスキップして即座に次作業へ入れる。

本設計ではこの再利用挙動を `--keep` オプションとして追加する。

## Goals / Non-Goals

**Goals:**
- `--keep` 指定時、🟢 Safe worktree を削除せず再利用可能状態（main ブランチ上、元ブランチは削除済み）にする
- 既存の削除フロー（Step 1〜6）は変更せず、Step 7 のみモード分岐する
- サニティチェック（Step 6）FAIL 時は `--keep` でも安全側に倒して保留する
- 完了レポートで再利用可能化された worktree のパスと、次作業コマンドをユーザーに提示する
- オプション未指定時の挙動は完全に現状維持（後方互換）

**Non-Goals:**
- 🟡 Recoverable / 🔴 Active worktree の再利用化は行わない（事故リスク大のため常に従来動作）
- 新ブランチの作成・命名補助は行わない（ユーザーが `git checkout -b` する前提）
- `main` の自動 pull / 最新化は行わない（ユーザー責任）
- `wt-setup` の自動再実行はしない（冪等だが本スコープ外）
- untracked ファイルの自動掃除はしない（`node_modules` / `.env` / 作業中の試しファイル等を保護するため）
- 複数オプション（`--keep-worktree` 長形式、`-k` 短形式など）の同時提供は将来検討。まずは `--keep` のみ

## Decisions

### Decision 1: オプション名を `--keep` とする

**採用**: `--keep`

**代替案と却下理由**:
- `--keep-worktree`: 冗長。対象が worktree しかないので自明
- `--reuse`: 意図は明確だが「何を」が曖昧
- `--recycle`: 「完全リセットして作り直す」ニュアンスがあり、実装する軽量リセットと合わない
- `-k` 短形式のみ: 可読性低下

**根拠**: 短く、意図（ディレクトリを残す）が伝わる。将来 `-k` 短形式を別名として追加可能。

### Decision 2: 対象を 🟢 Safe worktree のみに限定する

**採用**: `--keep` は 🟢 Safe のみ再利用化。🟡 Recoverable / 🔴 Active は従来動作。

**代替案と却下理由**:
- 全カテゴリを再利用化: 🟡 の未コミット変更が `git checkout main` で消える事故が起こりうる
- 対話で個別選択: UX が複雑化。まずは最小スコープで価値検証

**根拠**: 再利用は「完全にクリーンでマージ済み」が前提。それ以外は削除フローで整理する方が事故が少ない。

### Decision 3: 実装は worktree 内で `git checkout main` + `git branch -d` のみ

**採用**:
```bash
git -C "$WORKTREE_PATH" checkout main   # または master
git branch -d "$BRANCH_NAME"            # メインリポから安全削除
```

**代替案と却下理由**:
- `git reset --hard main` を併用: untracked は残るが tracked 変更も消える。Step 6（サニティチェック）を通過した🟢ではそもそも変更が残っていないため不要
- `git clean -fd` で untracked 掃除: `node_modules` / `.env` / 作業中の試しファイルを消すリスク。保護優先
- `git pull --ff-only` を追加: 最新化の責務はユーザー側。余計な失敗ポイントを増やさない

**根拠**: 🟢 Safe の定義（マージ済み & dirty なし & LLM なし）により、checkout のみで main に安全に戻れる。最小実装で事故率を下げる。

### Decision 4: Step 6 サニティチェック FAIL 時は `--keep` でも保留する

**採用**: FAIL した worktree およびそれ以降のマージ分は削除も再利用化もしない。

**根拠**: サニティチェックはマージ結果が壊れていないかの検証。FAIL 時に再利用化すると「問題のあるマージを main に含んだまま作業継続」となり、調査が困難になる。現状の削除保留ロジックをそのまま流用する。

### Decision 5: 完了レポートで次作業コマンドを提示する

**採用**: 再利用化された worktree 毎に、以下を表示:
```
再利用可能化: feat-x
  ディレクトリ: /path/to/worktree-x
  現在ブランチ: main
  次の作業: cd /path/to/worktree-x && git checkout -b <new-branch>
```

**根拠**: ユーザーが「このworktreeをどう使えばいいか」即座に理解できる。`wt-setup` の再実行は不要（既にセットアップ済みのため）だが、`.worktreeinclude` が更新されていた場合は任意で実行可能。

### Decision 6: main / master のブランチ名自動検出

**採用**: 現状の Step 1 で使っている `git branch --merged master | grep` 方式を踏襲し、`master` ブランチが存在しない場合は `main` を使う。

**根拠**: 既存コード（commands/wt-clean.md 行32-35）と同じ検出ロジックを使い、一貫性を保つ。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| `git checkout main` で worktree 内に main ブランチの重複チェックアウト衝突が起きる | `git worktree list` で main がどの worktree にチェックアウトされているか事前確認。競合時は該当 worktree を `--keep` 対象から除外し、警告を出す |
| ユーザーが再利用 worktree を放置し、古い `node_modules` のまま次プロジェクトで作業する | 完了レポートで「package.json が変わっていれば npm install を実行してください」と注意表示する |
| `--keep` 指定だが 🟢 が 1つもない場合の UX | レポートに「再利用化対象なし（🟢 Safe worktree がない）」と明示し、従来の削除フローを実行 |
| main にチェックアウト済みの状態でユーザーが誤って main で作業を始めてしまう | 完了レポートで「必ず `git checkout -b <new-branch>` してから作業開始」と強調 |
| コマンド側とスキル側の記述が乖離する | commands/wt-clean.md と skills/wt-clean/SKILL.md の両方を同じ PR で更新する。plugin-editing.md ルールに従い marketplace 版のみ編集 |
| プラグインキャッシュにより `--keep` が反映されない | `plugin.json` のバージョンを 1.0.0 → 1.1.0 に上げてキャッシュ無効化する |

## Migration Plan

後方互換のため破壊的変更はない。段階的ロールアウトも不要。

1. commands/wt-clean.md に `--keep` 受付 + Step 7 分岐を追加
2. skills/wt-clean/SKILL.md に同じ変更を同期
3. plugin.json のバージョン bump
4. commit & push → `/reload-plugins` で反映確認

ロールバック: `--keep` 未指定時は従来動作なので、ロールバックは記述を戻すだけで可。

## Open Questions

なし。実装時に判断で良い論点:
- `git worktree list` のパース方法（既存スクリプトの書き方に合わせる）
- エラーメッセージの文言（実装時に自然な日本語で）
