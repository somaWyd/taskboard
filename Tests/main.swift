import SwiftUI

func task(_ t: String) -> Task { Task(title: t, profileID: "p", due: Date()) }

// 列: Inbox(x 0-200) / Next(x 220-420)。カードは高さ60、間隔10
let inbox = CGRect(x: 0, y: 0, width: 200, height: 600)
let next  = CGRect(x: 220, y: 0, width: 200, height: 600)
let a = UUID(), b = UUID(), c = UUID()
let rows: [BoardDrag.Row] = [
    .init(id: a, frame: CGRect(x: 10, y: 10, width: 180, height: 60),
          canBeParent: true, insertBefore: 0),
    .init(id: b, frame: CGRect(x: 10, y: 80, width: 180, height: 60),
          canBeParent: true, insertBefore: 1),
    .init(id: c, frame: CGRect(x: 10, y: 150, width: 180, height: 60),
          canBeParent: false, insertBefore: 2),   // b のサブタスク
]
let s = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 180,
                  columns: [.inbox: inbox, .next: next],
                  order: [.inbox: rows, .next: []],
                  parentCount: [.inbox: 2, .next: 0])

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
       s.drop(at: CGPoint(x: 100, y: 195)), .insert(.inbox, 2))
expect("いちばん下の余白 → 末尾に挿入",
       s.drop(at: CGPoint(x: 100, y: 400)), .insert(.inbox, 2))
expect("空の列 Next → 先頭に挿入",
       s.drop(at: CGPoint(x: 300, y: 300)), .insert(.next, 0))
expect("列の隙間(x=210) → 近いほうの列へ寄せる",
       s.drop(at: CGPoint(x: 210, y: 300)), .insert(.inbox, 2))
expect("盤外（遠く下） → なし",
       s.drop(at: CGPoint(x: 100, y: 900)), nil)

print(failures == 0 ? "\nドロップ種別: 全て通過" : "\nドロップ種別: 失敗 \(failures) 件")

// --- 列の当たり判定を、箱の全面で受けられているか ---
let wide = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 180,
                     columns: [.inbox: inbox, .next: next,
                               .done: CGRect(x: 440, y: 0, width: 200, height: 600)],
                     order: [.inbox: rows, .next: [], .done: []],
                     parentCount: [.inbox: 2, .next: 0, .done: 0])

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


// --- サブタスクの行が判定に含まれているか（今回の不具合の再発防止） ---
print("\n--- 親と子が混ざった列 ---")
let pA = UUID(), sA = UUID(), pB = UUID()
let mixed: [BoardDrag.Row] = [
    .init(id: pA, frame: CGRect(x: 10, y: 10,  width: 180, height: 60),
          canBeParent: true,  insertBefore: 0),   // 親A（親リストの0番）
    .init(id: sA, frame: CGRect(x: 40, y: 80,  width: 150, height: 50),
          canBeParent: false, insertBefore: 1),   // Aの子 → 落とすとAの次
    .init(id: pB, frame: CGRect(x: 10, y: 140, width: 180, height: 60),
          canBeParent: true,  insertBefore: 1),   // 親B（親リストの1番）
]
let m = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 180,
                  columns: [.inbox: inbox], order: [.inbox: mixed],
                  parentCount: [.inbox: 2])
var f4 = 0
func expectMix(_ label: String, _ got: BoardDrag.Drop?, _ want: BoardDrag.Drop?) {
    let ok = got == want
    if !ok { f4 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(String(describing: got))")
}
expectMix("親Aの下半分 → Aのサブタスク", m.drop(at: CGPoint(x: 100, y: 55)), .subtask(pA))
expectMix("子の上半分 → 親Aの次(1)", m.drop(at: CGPoint(x: 100, y: 90)), .insert(.inbox, 1))
expectMix("子の下半分 → 親Aの次(1)", m.drop(at: CGPoint(x: 100, y: 120)), .insert(.inbox, 1))
expectMix("親Bの上半分 → Bの手前(1)", m.drop(at: CGPoint(x: 100, y: 155)), .insert(.inbox, 1))
expectMix("親Bの下半分 → Bのサブタスク", m.drop(at: CGPoint(x: 100, y: 185)), .subtask(pB))
print(f4 == 0 ? "\n親子混在: 全て通過" : "\n親子混在: 失敗 \(f4) 件")

exit((failures + f2 + f3 + f4) == 0 ? 0 : 1)
