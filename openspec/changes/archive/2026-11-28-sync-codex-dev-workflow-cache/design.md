# Design

## Context

動機は proposal.md を参照。sync.sh は rc を集約して配線を続ける POSIX sh。現在の rules-sync.bats は CLAUDE_CONFIG_DIR だけを隔離しているため、Codex 更新を足す前に HOME/CODEX_HOME も隔離する。
実運用は source_type=git、dev-workflow enabled=true。一時 HOME / codex-cli 0.163.0 のローカル Git fixture で、main を進めたあとの `plugin marketplace upgrade <name> --json` だけで native develop のバイト一致と旧 migrated command の除去を確認した（issue #1865 の分割判定コメント）。

## Goals / Non-Goals

Git 配布の更新を既存 sync に加える。初期インストール、local/worktree 登録の更新、実行中セッションの再読込、main 以外の ref を main に付け替える動作は含めない。

## Decisions

- **CLI に snapshot/cache/移行スキルを更新させる。** 実行元 `.claude-plugin/marketplace.json` の name と `codex plugin marketplace list --json` の marketplaces[].name / marketplaceSource.sourceType を照合し、対象 Git 登録だけに `codex plugin marketplace upgrade <name> --json` を実行する。手動コピーは変換済み skill の生成規則に依存し、plugin add は有効化設定を変えるため採らない。登録元と ref は CLI に任せる。
- **更新結果を rc に合流する。** CLI 不在は処理前に判定して従来の配線へ進む。CLI がある場合は jq で name/列挙結果/upgrade 結果を読む。jq 不在、読取不能、不正形式、コマンド非0、errors 非空を警告し rc=1 にする。対象 Git 登録なしは正常な省略。Codex 処理が失敗しても配線を止めない。
- **`--no-pull` でも Codex snapshot を更新する。** 実行元 clone の pull が済んでいても Codex snapshot は別なので、Codex 更新は独立させる。利用コメントの「symlink のみ」を修正し、Codex 更新ではネットワークを使いうることを明記する。

## Risks / Trade-offs

- [CLI の JSON/更新動作が変わる] → list/upgrade 対応 CLI が前提。実 CLI のローカル Git テストを残し、構造不一致を成功扱いしない。サポート外 CLI の自動導入はしない。
- [Codex upgrade は同一 marketplace の他の設定済み plugin も再生成しうる] → CLI の通常動作として受け入れるが、全 marketplace を対象にする引数省略形を使わない。有効無効設定は維持する。
- [一時 HOME の fake CLI だけでは変換の正しさが分からない] → fake CLI は選択/失敗分岐、実 CLI は native と generated skill の結果検証に使う。実 CLI の skip は未検証として報告する。

## Migration Plan

実装と bats は一時 HOME のみ。fixture の main へテスト対象スクリプトを入れ、別の marketplace clone と Codex snapshot/cache を旧版にして、remote main を進めてから実行する。default と --no-pull の経路、再実行、失敗/対象外を検証する。
変更記録 `plugins/dev-workflow/changes/1865.md` に同期方式とマージ後の実ホーム確認が未実施である旨を残す。マージ後の実ホーム実測は後続工程の担当が承認済み運用で記録し、この spec 工程では行わない。戻す場合は本変更を revert し、以降の Codex 更新は従来の手動運用に戻る。
