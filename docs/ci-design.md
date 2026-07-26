# CI 設計指針（将来 CI を追加するときの参考）

現状このリポジトリには `.github/workflows/` が無いが、追加する場合は **Draft PR では CI を skip するパターン** を使う:

```yaml
on:
  push:
  pull_request:
    types: [opened, reopened, ready_for_review, synchronize]

jobs:
  build:
    if: github.event_name == 'push' || github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    # ...
```

- 普通の push（feature branch への直接 push 含む）では走る
- Draft PR の push では skip
- Ready for Review に切り替えた瞬間に走る
- Preview deploy 系は Draft でも走らせて OK（プレビュー用途のため）
