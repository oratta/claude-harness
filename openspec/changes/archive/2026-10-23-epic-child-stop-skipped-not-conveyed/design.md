## Context

`mark stopped` の出力は `marked <N> stopped`・`skipped <N> no-workspace`・`skipped <N> not-linked`・`failed <N>` の 4 通り（`not-stopped` は `mark resumed` だけが出す）。出力と終了コードの正本は `dev-workflow-epic-state` の spec で、この change では変えない。動機は proposal.md の Why。

## Goals / Non-Goals

**Goals:**
- 子が止まりを親に伝えられなかったことを、子の側で主に伝える

**Non-Goals:**
- 親の側で記録の無い子の止まりを拾うこと（proposal.md の範囲外）
- `mark` の出力の語や終了コードを変えること

## Decisions

- **`skipped` で始まる出力をまとめて添える側に置く**（`no-workspace` だけに絞らない）。`not-linked` も親が見張る子の記録に印が付かず、親に伝わらない点で同じ。出力の語を 1 つずつ列挙して判定すると、出力の語が増えたときに「何もしない」側に落ちる。前置きの `skipped` で決めれば、印が付かなかった出力はすべて主に伝わる。代案として `no-workspace` だけに添える案があったが、`not-linked` で同じ取りこぼしが残るので採らない
- **スクリプトでなく手順書で扱う**。`mark` を exit 0 以外にして子を止める案は、`mark` を呼ぶ他の場面（`done`・`waiting`・`resumed`）や親の手順への影響が大きく、子は止まる直前で主に質問を書いている最中なので、1 行添えるだけで主に届く

## Risks / Trade-offs

- [記録が無いのが正常な子（手で起動した子）でも 1 行添えられ、主が気にする] → 文面は事実（親に伝わっていない）だけで、主は子のタブで返事をすればよい。誤って添えて失うものは 1 行の読み手の手間だけ
