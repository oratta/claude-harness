# Longrun 判断ガイド

Agent を使うか否かの一般判断は Claude が default で行えるため、ここでは **longrun（自律実行ハーネス）を使うべきか** の判断基準だけを定める。

## longrun を使うべき時

- 複数の OpenSpec change を含む大きな実装
- Plan → Build → Verify → Feedback → Archive の完全フローが必要
- ユーザーが離席しても進行してほしい作業
- 4軸定量評価（機能性/品質/完成度/UX）で品質担保したい作業

## longrun を使わないべき時

- 単発の修正・調査・質問応答
- ユーザーとの対話が頻繁に必要な作業
- OpenSpec change が不要な軽微な変更
