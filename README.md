# TaskBoard

macOS 26 以降で動く、SwiftUI 製のタスク管理アプリ。カンバン（Inbox / Next Action / Done）でタスクを扱い、データはローカルの JSON として持つ。

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black) ![SwiftUI](https://img.shields.io/badge/SwiftUI-6-black)

## できること

- **カンバン** — Inbox / Next Action / Done の3列。ドラッグでステータス変更
- **サブタスク** — カードの下半分にドロップすると子になる。親の下に一段細いカードで並ぶ
- **手動の並べ替え** — カードの上半分・カードの隙間にドロップして順番を決める
- **プロファイル** — 仕事・大学などをSFシンボルと色で分ける。既定のプロファイルと既定時刻を設定できる
- **その場で編集** — カード上のタイトル・メモ・日時・重要度・繰り返し・プロファイルを直接変更できる
- **繰り返し** — 毎日 / 平日 / 毎週 / 毎月 / 毎年 / 曜日指定
- **期限** — 日時指定のほか「その日中（時刻なし）」に対応
- **Markdown 出力** — 期間を指定してクリップボードへ
- **外観** — ライト / ダーク、マット / リキッドグラス（`glassEffect`）を切替

## データの置き場所

初回起動時にフォルダを選ぶ。そこに次の3つを作る。

| ファイル | 役割 |
|---|---|
| `tasks.json` | **正データ**。外部から編集してよい（起動中でも自動で読み直す） |
| `tasks.md` | 読み取り用の写し。保存のたびに上書きされる |
| `CLAUDE.md` | `tasks.json` の書式。Claude Code などから編集するとき用 |

## ビルド

[XcodeGen](https://github.com/yonaskolb/XcodeGen) が要る。

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project TaskBoard.xcodeproj -scheme TaskBoard -configuration Release \
           -derivedDataPath .build build
open .build/Build/Products/Release/TaskBoard.app
```

## テスト

ドラッグ&ドロップの当たり判定は GUI なしで検証できる。詳細は [Tests/README.md](Tests/README.md)。

```bash
swiftc -O TaskBoard/Sources/Models.swift TaskBoard/Sources/BoardDrag.swift \
       Tests/DropRulesTests.swift -o /tmp/droptest && /tmp/droptest
```

## 構成

| ファイル | 役割 |
|---|---|
| `Models.swift` | Task / Profile / Status / Priority / Repeat |
| `Store.swift` | JSON の読み書き、外部編集の監視、サブタスクの索引 |
| `Filters.swift` | 期間・プロファイルの絞り込みと並べ替え |
| `BoardDrag.swift` | ドラッグ中の当たり判定（純粋関数・テスト対象） |
| `KanbanView.swift` | カンバン本体、インライン追加、複数選択 |
| `CardView.swift` | カード1枚。各要素がその場で編集できる |
| `SidebarView.swift` | 期間とプロファイル。並べ替えと右クリック編集 |
| `SettingsView.swift` | 設定（⌘,）7タブ |

## 制約

- macOS 26 以降専用（Liquid Glass の `glassEffect` を直接使うため）
- サンドボックス無効。App Store 配布は想定していない
- 個人利用を前提にした作りで、同期機能はない
