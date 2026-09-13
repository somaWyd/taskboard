# テスト

ドラッグ&ドロップの当たり判定（`BoardDrag.drop(at:)`）だけを、GUIなしで検証する。

```bash
cd "$(git rev-parse --show-toplevel)"
swiftc -O TaskBoard/Sources/Models.swift TaskBoard/Sources/BoardDrag.swift \
       Tests/main.swift -o /tmp/droptest && /tmp/droptest
```

全ケース通過で終了コード0、失敗があれば1を返す。
