import SwiftUI

func task(_ t: String) -> Task { Task(title: t, profileID: "p", due: Date()) }

// 列: Inbox(x 0-200) / Next(x 220-420)。カードは高さ60、間隔10
let inbox = CGRect(x: 0, y: 0, width: 200, height: 600)
let next  = CGRect(x: 220, y: 0, width: 200, height: 600)
let a = UUID(), b = UUID(), c = UUID()
let rows: [(id: UUID, frame: CGRect, canBeParent: Bool)] = [
    (a, CGRect(x: 10, y: 10, width: 180, height: 60), true),
    (b, CGRect(x: 10, y: 80, width: 180, height: 60), true),
    (c, CGRect(x: 10, y: 150, width: 180, height: 60), false),   // サブタスク＝親にできない
]
let s = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 180,
                  columns: [.inbox: inbox, .next: next],
                  order: [.inbox: rows, .next: []])

var failures = 0
func expect(_ label: String, _ got: BoardDrag.Drop?, _ want: BoardDrag.Drop?) {
    let ok = got == want
    if !ok { failures += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(String(describing: got))")
}

expect("カードAの上半分 → Aの手前に挿入",
       s.drop(at: CGPoint(x: 100, y: 25)), .insert(.inbox, 0))
expect("カードAの下半分 → Aのサブタスク",
       s.drop(at: CGPoint(x: 100, y: 55)), .subtask(a))
expect("AとBの隙間 → Bの手前に挿入",
       s.drop(at: CGPoint(x: 100, y: 74)), .insert(.inbox, 1))
expect("カードBの上半分 → Bの手前に挿入",
       s.drop(at: CGPoint(x: 100, y: 95)), .insert(.inbox, 1))
expect("カードBの下半分 → Bのサブタスク",
       s.drop(at: CGPoint(x: 100, y: 125)), .subtask(b))
expect("サブタスクCの下半分 → 親にできないので挿入",
       s.drop(at: CGPoint(x: 100, y: 195)), .insert(.inbox, 3))
expect("いちばん下の余白 → 末尾に挿入",
       s.drop(at: CGPoint(x: 100, y: 400)), .insert(.inbox, 3))
expect("空の列 Next → 先頭に挿入",
       s.drop(at: CGPoint(x: 300, y: 300)), .insert(.next, 0))
expect("列の隙間(x=210) → 近いほうの列へ寄せる",
       s.drop(at: CGPoint(x: 210, y: 300)), .insert(.inbox, 3))
expect("盤外（遠く下） → なし",
       s.drop(at: CGPoint(x: 100, y: 900)), nil)

print(failures == 0 ? "\nドロップ種別: 全て通過" : "\nドロップ種別: 失敗 \(failures) 件")

// --- 列の当たり判定を、箱の全面で受けられているか ---
let wide = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 180,
                     columns: [.inbox: inbox, .next: next, .done: CGRect(x: 440, y: 0, width: 200, height: 600)],
                     order: [.inbox: rows, .next: [], .done: []])

func col(_ d: BoardDrag.Drop?) -> Status? {
    if case .insert(let s, _) = d { return s }
    return nil
}
var f2 = 0
func expectCol(_ label: String, _ p: CGPoint, _ want: Status?) {
    let got = col(wide.drop(at: p))
    let ok = got == want
    if !ok { f2 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(String(describing: got))")
}
print("\n--- 列の当たり判定 ---")
expectCol("Next の左端", CGPoint(x: 221, y: 300), .next)
expectCol("Next の中央", CGPoint(x: 320, y: 300), .next)
expectCol("Next の右端", CGPoint(x: 419, y: 300), .next)
expectCol("Next の最上部", CGPoint(x: 320, y: 2), .next)
expectCol("Next の最下部", CGPoint(x: 320, y: 598), .next)
expectCol("Next の少し上（箱の外）", CGPoint(x: 320, y: -30), .next)
expectCol("Inbox と Next の隙間（Next寄り）", CGPoint(x: 215, y: 300), .next)
expectCol("Inbox と Next の隙間（Inbox寄り）", CGPoint(x: 205, y: 300), .inbox)
expectCol("Done の中央", CGPoint(x: 540, y: 300), .done)
expectCol("盤の遥か下", CGPoint(x: 320, y: 900), nil)
print(f2 == 0 ? "\n列の判定: 全て通過" : "\n列の判定: 失敗 \(f2) 件")

// --- サイドバーのプロファイル表示切替 ---
print("\n--- プロファイルの表示切替 ---")
let all4 = ["a", "b", "c", "d"]
var f3 = 0
func expectSet(_ label: String, _ got: Set<String>, _ want: Set<String>) {
    let ok = got == want
    if !ok { f3 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(got.sorted())")
}
expectSet("全部表示中にaを押す → aだけ",
          ProfileVisibility.toggle(active: [], clicked: "a", all: all4), ["a"])
expectSet("aだけ表示中にaを押す → a以外ぜんぶ",
          ProfileVisibility.toggle(active: ["a"], clicked: "a", all: all4), ["b", "c", "d"])
expectSet("a,bを表示中にbを押す → aだけ",
          ProfileVisibility.toggle(active: ["a", "b"], clicked: "b", all: all4), ["a"])
expectSet("a,bを表示中にcを押す → a,b,c",
          ProfileVisibility.toggle(active: ["a", "b"], clicked: "c", all: all4), ["a", "b", "c"])
expectSet("a,b,cを表示中にdを押す → 全部表示（空集合）",
          ProfileVisibility.toggle(active: ["a", "b", "c"], clicked: "d", all: all4), [])
expectSet("b,c,dを表示中にaを押す → 全部表示（空集合）",
          ProfileVisibility.toggle(active: ["b", "c", "d"], clicked: "a", all: all4), [])
expectSet("プロファイルが1つだけなら全部表示のまま",
          ProfileVisibility.toggle(active: [], clicked: "a", all: ["a"]), [])
expectSet("1つだけのプロファイルを隠そうとしても維持",
          ProfileVisibility.toggle(active: ["a"], clicked: "a", all: ["a"]), ["a"])
expectSet("知らないIDは無視",
          ProfileVisibility.toggle(active: ["a"], clicked: "z", all: all4), ["a"])
print(f3 == 0 ? "\nプロファイル切替: 全て通過" : "\nプロファイル切替: 失敗 \(f3) 件")

exit((failures + f2 + f3) == 0 ? 0 : 1)
