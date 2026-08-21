# 違反フィクスチャ: 引用符に囲まれたプラグイン内相対パス

シェルの引用符はトークンの区切りとして扱う（囲まれていても違反）。

- 単一引用符: `sh 'scripts/casting-check.sh' resolve .`
- 二重引用符とスキル: `cat "skills/casting/SKILL.md"`
