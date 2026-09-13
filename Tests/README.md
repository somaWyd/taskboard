# テスト

GUIなしで検証できるものだけを対象にする。

- ドラッグ&ドロップの当たり判定（`BoardDrag.drop(at:)`）
- サイドバーのプロファイル表示切替（`ProfileVisibility.toggle`）

```bash
cd "$(git rev-parse --show-toplevel)"
swiftc -O TaskBoard/Sources/Models.swift TaskBoard/Sources/Filters.swift \
       TaskBoard/Sources/BoardDrag.swift Tests/main.swift -o /tmp/droptest && /tmp/droptest
```

全ケース通過で終了コード0、失敗があれば1を返す。
