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

// --- プロファイルの絞り込み（nil=全部 / 集合=そのぶんだけ / 空=0件） ---
print("\n--- プロファイルの絞り込み ---")
let ps = (0..<3).map {
    Profile(id: "p\($0)", name: "p\($0)", symbol: "c", colorHex: "#0A84FF", defaultTime: "09:00")
}
let sample = (0..<6).map { i in
    Task(title: "t\(i)", status: .inbox, profileID: ps[i % 3].id, due: Date())
}
var f3 = 0
func expectCount(_ label: String, _ ids: Set<String>?, _ want: Int) {
    var f = Filter(period: .all, calendar: .current, sort: .dateManual,
                   profileOrder: ps.map(\.id))
    f.profileIDs = ids
    let got = f.count(sample)
    let ok = got == want
    if !ok { f3 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(got)件")
}
expectCount("nil → 絞らない", nil, 6)
expectCount("p0 だけ表示", ["p0"], 2)
expectCount("p0 と p1 を表示", ["p0", "p1"], 4)
expectCount("全部表示", ["p0", "p1", "p2"], 6)
expectCount("全部非表示 → 0件", [], 0)
print(f3 == 0 ? "\nプロファイルの絞り込み: 全て通過" : "\nプロファイルの絞り込み: 失敗 \(f3) 件")

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


// --- 描画の並びと判定表が一致しているか（今回の作り直しの要） ---
print("\n--- ColumnLayout と判定表の一致 ---")
var f5 = 0
func check(_ label: String, _ ok: Bool) {
    if !ok { f5 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label)")
}

let pa = Task(title: "親A", status: .inbox, profileID: "p", due: Date())
let pb = Task(title: "親B", status: .inbox, profileID: "p", due: Date())
var c1 = Task(title: "子1", status: .inbox, profileID: "p", due: Date()); c1.parentID = pa.id
var c2 = Task(title: "子2", status: .inbox, profileID: "p", due: Date()); c2.parentID = pa.id
let kids: [UUID: [Task]] = [pa.id: [c1, c2], pb.id: []]

let layout = ColumnLayout(status: .inbox, parents: [pa, pb]) { kids[$0.id] ?? [] }

check("行数 = 親2 + 子2 = 4", layout.rows.count == 4)
check("並びは 親A → 子1 → 子2 → 親B",
      layout.rows.map(\.task.title) == ["親A", "子1", "子2", "親B"])
check("親Aの添字は0", layout.rows[0].insertBefore == 0)
check("子の添字は親Aの次(1)",
      layout.rows[1].insertBefore == 1 && layout.rows[2].insertBefore == 1)
check("親Bの添字は1", layout.rows[3].insertBefore == 1)
check("挿入線を出すのは親の行だけ",
      layout.rows.map(\.showsInsertionLine) == [true, false, false, true])
check("まとまりの終わりは 子2 と 親B",
      layout.rows.map(\.isGroupEnd) == [false, false, true, true])
check("末尾の添字は親の数と同じ", layout.endIndex == layout.parents.count)

// 同じ layout から判定表を作り、添字が親リストの範囲に収まることを確かめる
var y: CGFloat = 0
let built: [BoardDrag.Row] = layout.rows.map { row in
    let r = BoardDrag.Row(id: row.task.id,
                          frame: CGRect(x: 0, y: y, width: 200, height: 60),
                          canBeParent: !row.isSubtask,
                          insertBefore: row.insertBefore)
    y += 70
    return r
}
let bd = BoardDrag(task: Task(title: "運ぶ", profileID: "p", due: Date()),
                   grabOffset: .zero, cardWidth: 200,
                   columns: [.inbox: CGRect(x: 0, y: 0, width: 220, height: 400)],
                   order: [.inbox: built],
                   parentCount: [.inbox: layout.parents.count])

var allInRange = true
for probe in stride(from: CGFloat(0), to: 400, by: 5) {
    if case .insert(_, let i)? = bd.drop(at: CGPoint(x: 100, y: probe)) {
        if i < 0 || i > layout.parents.count { allInRange = false }
    }
}
check("盤面のどこに落としても添字が親リストの範囲に収まる", allInRange)
check("子の行は親候補にならない", built.filter(\.canBeParent).count == 2)

print(f5 == 0 ? "\n並びの一致: 全て通過" : "\n並びの一致: 失敗 \(f5) 件")


// --- 列の境目で取り違えないか（間隔12ptを片側6ptずつ埋める） ---
print("\n--- 列の境目 ---")
let L = CGRect(x: 0,   y: 0, width: 200, height: 600)
let R = CGRect(x: 212, y: 0, width: 200, height: 600)   // 間隔12pt
let edge = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 200,
                     columns: [.inbox: L, .next: R],
                     order: [.inbox: [], .next: []],
                     parentCount: [.inbox: 0, .next: 0])
var f6 = 0
func expectEdge(_ label: String, _ x: CGFloat, _ want: Status) {
    var got: Status? = nil
    if case .insert(let s, _)? = edge.drop(at: CGPoint(x: x, y: 300)) { got = s }
    let ok = got == want
    if !ok { f6 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label)(x=\(Int(x))): \(String(describing: got))")
}
expectEdge("左列の内側", 199, .inbox)
expectEdge("隙間の左寄り", 203, .inbox)
expectEdge("隙間の中央より右", 208, .next)
expectEdge("右列の内側", 213, .next)
print(f6 == 0 ? "\n列の境目: 全て通過" : "\n列の境目: 失敗 \(f6) 件")

exit((failures + f2 + f3 + f4 + f5 + f6) == 0 ? 0 : 1)
