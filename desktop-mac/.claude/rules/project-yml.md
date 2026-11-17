---
paths:
  - "project.yml"
---

# project.yml の書き方

- ターゲット・ファイル追加は `project.yml` を直す。Xcode 上で追加しない
- configuration は `Debug` / `Release-AppStore` / `Release-DeveloperID` の 3 つ。署名設定はここでしか切り替えない
- 変更したら `make gen`。PostToolUse フックが自動で呼ぶが、失敗したら止まる
