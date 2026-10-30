## 1. 表示契約とテスト

- [x] 1.1 非 active のオフスロットが値の有無に関係なく 0 行になるテスト、active のオフスロットがライブ値で残るテスト、表示対象が 1 スロットのとき名前列と目印が消えるテストを更新・追加する。触る範囲: plugins/statusline/tests/statusline-multi-account.bats:963-1093（enabled のテスト群）
- [x] 1.2 オフの Codex が最終表示では 0 行になり、キャッシュに触れないテストへ更新する。helper が内部センチネル `off` を返すテストは維持する。触る範囲: plugins/statusline/tests/statusline.bats:186-225（Codex off）、plugins/statusline/tests/test_codex.py:235-257（描画テスト）
- [x] 1.3 登録簿全体から active を判定した後に表示対象の Claude スロット数と列幅を決め、非 active のオフスロットを描画しない。Codex の `off` センチネルは列幅計算より前に除外する。触る範囲: plugins/statusline/scripts/statusline.sh:398-418（登録簿）、plugins/statusline/scripts/statusline.sh:493-555（active・複数表示・列幅）、plugins/statusline/scripts/statusline.sh:740-855（描画）

## 2. 説明と登録手順

- [x] 2.1 statusline README のオフ時の表示、1 スロット表示、Codex 行の説明を更新する。登録手順は `CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定のシェルで既定アカウント A を B の追加前に登録し、既定アカウントを登録しないままだとその使用量が別スロットのものとして扱われることを書く。別シェルからの既存アカウント登録例は異なる id にし、各コードブロックのコマンドをそれだけで実行できるパスにする。触る範囲: plugins/statusline/README.md:103-180（登録・off・読み方）、plugins/statusline/README.md:224-232（Codex）
- [x] 2.2 dev-workflow README の `accounts.sh` を定義済み `CLAUDE_HARNESS_SCRIPTS` 付きで呼び、既定アカウントを未設定シェルで先に登録する理由と、未登録時に使用量が別スロットへ帰属することを書く。ステータスラインの Codex off 説明も合わせる。隔離した一時ディレクトリで README の登録順・呼び出しを試す。触る範囲: plugins/dev-workflow/README.md:82-101（登録例・Codex off）
- [x] 2.3 #976・#978 の古い `off` 行の説明が今回の変更で上書きされたことを statusline 側の新しい変更記録に書き、#980 に表示条件の変更をリンクで知らせる。触る範囲: plugins/statusline/changes/1112.md（新規）

## 3. 検証

- [x] 3.1 `bats plugins/statusline/tests/` と `python3 -m unittest discover -s plugins/statusline/tests -p 'test_*.py'` を実行して exit 0 を確認する。触る範囲: plugins/statusline/tests/statusline-multi-account.bats:963-1093、plugins/statusline/tests/statusline.bats:186-225、plugins/statusline/tests/test_codex.py:235-257
- [x] 3.2 反映手順（`/statusline:setup` の再実行）を README と変更記録に書く。実機確認はマージ後に主が行い、エピックに記録する。実ホームへの書き込みはこの worktree の実装・検証では行わない。触る範囲: plugins/statusline/README.md:152-180（反映手順の案内）
