# テスト

GUIなしで検証できるものだけを対象にする。

- ドラッグ&ドロップの当たり判定（`BoardDrag.drop(at:)`）
- プロファイルの絞り込み（`Filter`）
- 列の並びと判定表の一致（`ColumnLayout`）

```bash
cd "$(git rev-parse --show-toplevel)"
swiftc -O TaskBoard/Sources/Models.swift TaskBoard/Sources/Filters.swift \
       TaskBoard/Sources/ColumnLayout.swift TaskBoard/Sources/BoardDrag.swift \
       Tests/ColumnRectsMirror.swift Tests/ZoomMirror.swift Tests/main.swift -o /tmp/droptest && /tmp/droptest
```

全ケース通過で終了コード0、失敗があれば1を返す。
