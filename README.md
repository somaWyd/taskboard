# TaskBoard

macOS 26 以降で動く、SwiftUI 製のタスク管理アプリ。カンバン（Inbox / Next Action / Done）でタスクを扱い、データはローカルの JSON として持つ。

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black) ![SwiftUI](https://img.shields.io/badge/SwiftUI-6-black)

## できること

- **カンバン** — Inbox / Next Action / Done の3列。ドラッグでステータス変更
- **サブタスク** — カードの下半分にドロップすると子になる。親の下に一段細いカードで並ぶ
- **手動の並べ替え** — カードの上半分・カードの隙間にドロップして順番を決める
- **プロファイル** — 仕事・大学などをSFシンボルと色で分ける。クリックで表示・非表示を切り替える（全部隠すことも可能）。既定のプロファイルと既定時刻を設定できる
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

## インストール（dmg を作る）

`/Applications` へドラッグできる dmg を作る。Release ビルド → アドホック署名の付け直し → dmg 作成までを1本で行う。

```bash
./scripts/make-dmg.sh
open dist/
```

できた `dist/TaskBoard-<version>.dmg` を開き、`TaskBoard.app` を `Applications` フォルダへドラッグする。これで Launchpad と Spotlight から起動できるようになる。

### 初回起動で「開発元を確認できません」と言われたら

署名も公証もしていないため、Gatekeeper に止められることがある。**アプリを右クリック →「開く」**を選び、確認ダイアログで「開く」を押す（1度だけでよい）。

ネットワーク経由で受け取った dmg の場合は隔離属性が付いているので、先に外す。

```bash
xattr -dr com.apple.quarantine /Applications/TaskBoard.app
```

## テスト

ドラッグ&ドロップの当たり判定は GUI なしで検証できる。詳細は [Tests/README.md](Tests/README.md)。

```bash
swiftc -O TaskBoard/Sources/Models.swift TaskBoard/Sources/Filters.swift \
       TaskBoard/Sources/BoardDrag.swift Tests/main.swift -o /tmp/droptest && /tmp/droptest
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

## このアプリの前提（ビルドする前に読んでください）

**個人（作者）が自分のために作ったアプリです。** 配布を前提にした作りではないため、一般的なアプリとは違う点がいくつかあります。他の人が使う場合、以下を理解したうえで自己責任で扱ってください。

### 1. App Sandbox を無効にしている

macOS の App Sandbox を**切った状態**でビルドされます（`project.yml` の `ENABLE_APP_SANDBOX: NO`）。

- **なぜ切ったか** — タスクの保存先をユーザーが任意のフォルダ（例：Obsidian の vault の中）に置けるようにするためです。サンドボックス下でこれをやるには security-scoped bookmark の管理が必要で、個人利用には過剰でした
- **何を意味するか** — このアプリは**あなたのホームディレクトリ配下のファイルに、OSの制限なしで読み書きできます**。実際に書き込むのは選んだフォルダの `tasks.json` / `tasks.md` / `CLAUDE.md` の3つだけですが、その制限はコードが守っているだけで、OSが保証しているわけではありません
- **他人のコードを信用することになります** — ビルドして使う前に [Store.swift](TaskBoard/Sources/Store.swift) を読み、どこに何を書いているか自分の目で確かめてください

### 2. 署名も公証もしていない

Apple Developer ID による署名（codesign）も公証（notarization）も行っていません。`CODE_SIGN_IDENTITY: "-"` のアドホック署名です。

- 自分でビルドしたものは動きますが、ビルド済みのアプリを誰かから受け取って実行するのは避けてください
- 配布用のバイナリは用意していません。使う人が自分でビルドする前提です

### 3. データはローカルのJSONだけ。同期もバックアップもない

- 同期機能はありません。複数のMacで使うことは想定していません
- バックアップもアプリ側では取りません。保存先を Dropbox / iCloud Drive / Git 管理下のフォルダに置くなど、**バックアップは利用者の責任**です
- 保存は「一時ファイルに書いてから `rename` で置き換える」方式なので、書きかけのファイルを読ませることはありません。ただし**アプリを開いたまま外部から `tasks.json` を書き換えた場合、最後に書いた側が勝ちます**（アプリ側は変更を検知して読み直しますが、編集の衝突は解決しません）

### 4. macOS 26 以降でしか動かない

Liquid Glass の `glassEffect` を条件分岐なしで使っているため、最低要件が macOS 26 です。それより前の macOS では**ビルドが通りません**。動かしたい場合は [Theme.swift](TaskBoard/Sources/Theme.swift) の `glass` の分岐を `.ultraThinMaterial` に差し替え、`project.yml` の `deploymentTarget` を下げてください。

### 5. 日本語UIのみ

文言はすべて日本語のハードコードです。ローカライズの仕組み（String Catalog）は入れていません。

### 6. テストは一部だけ

GUIなしで検証できるのは、ドラッグ&ドロップの当たり判定（`BoardDrag`）のみです。それ以外の動作確認は手動で行っています。

---

## ライセンス

未定です。現時点では「作者の個人利用のために公開しているコード」という扱いで、再利用の可否については何も表明していません。
