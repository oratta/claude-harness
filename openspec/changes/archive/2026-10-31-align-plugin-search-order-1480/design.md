## 方針

#1152 の `plugins/statusline/commands/setup.md` と同じ形にする。`oratta-claude-harness` は marketplace の名前（`.claude-plugin/marketplace.json`）で固定値として書く。`installed_plugins.json` の `installPath` を読む案は、版の読み分けが増えるので採らない（#1152 と同じ判断）。

## 却下

- 探索をスクリプトに寄せる: 探索ブロックが無いと同じスクリプトを探せないので成立しない
- glob を消す: marketplace 名が違う環境（overlay 等）の最後の手段が無くなる
