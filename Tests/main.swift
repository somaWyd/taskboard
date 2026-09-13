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
// 列は画面の下まで伸びているので、下方向は制限しない（横位置で列が決まる）
expect("列の下の方 → その列の末尾",
       s.drop(at: CGPoint(x: 100, y: 900)), .insert(.inbox, 2))

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
expectCol("列の下の方はその列のまま", CGPoint(x: 320, y: 900), .next)
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


// --- 列の矩形が盤面いっぱいを隙間なく覆うか ---
print("\n--- 列の矩形の計算 ---")
var f7 = 0
func checkCols(_ label: String, _ ok: Bool) {
    if !ok { f7 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label)")
}
for (w, n) in [(900.0, 3), (1920.0, 3), (1200.0, 2), (400.0, 3)] {
    let rs = columnRects(boardWidth: w, boardHeight: 800, count: n)
    guard rs.count == n else { checkCols("幅\(Int(w)) 列\(n): 生成できない", false); continue }
    let leftOK = abs(rs[0].minX - 14) < 0.01
    let rightOK = abs(rs[n-1].maxX - (w - 14)) < 0.01
    var gapsOK = true
    for i in 1..<n { if abs(rs[i].minX - rs[i-1].maxX - 12) > 0.01 { gapsOK = false } }
    let sameWidth = rs.allSatisfy { abs($0.width - rs[0].width) < 0.01 }
    checkCols("幅\(Int(w)) 列\(n): 左端14pt/右端まで/間隔12pt/等幅",
              leftOK && rightOK && gapsOK && sameWidth)
}
// カードは必ず列の中に収まる（列の内側10ptに置かれる）
let r = columnRects(boardWidth: 1920, boardHeight: 800, count: 3)[1]
let card = CGRect(x: r.minX + 10, y: r.minY + 42, width: r.width - 20, height: 66)
checkCols("カードは列の内側に収まる", r.contains(card))
print(f7 == 0 ? "\n列の矩形: 全て通過" : "\n列の矩形: 失敗 \(f7) 件")


// --- 箱の中ならどこでもその列に入るか（縦位置に依存しない） ---
print("\n--- 箱の中はどこでも入る ---")
// 実際の運用と同じ形: 縦は「上端から下は全部」とみなす
func box(_ x: CGFloat, _ w: CGFloat) -> CGRect {
    CGRect(x: x, y: 14, width: w, height: 100_000)
}
let wide3 = BoardDrag(task: task("drag"), grabOffset: .zero, cardWidth: 200,
                      columns: [.inbox: box(14, 556), .next: box(582, 556),
                                .done: box(1150, 556)],
                      order: [.inbox: [], .next: [], .done: []],
                      parentCount: [.inbox: 0, .next: 0, .done: 0])
var f8 = 0
func expectBox(_ label: String, _ p: CGPoint, _ want: Status?) {
    var got: Status? = nil
    if case .insert(let s, _)? = wide3.drop(at: p) { got = s }
    let ok = got == want
    if !ok { f8 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label): \(String(describing: got))")
}
for y in [20.0, 200.0, 600.0, 1000.0, 3000.0] {
    expectBox("Next の中央 y=\(Int(y))", CGPoint(x: 860, y: y), .next)
}
expectBox("Next の左端", CGPoint(x: 583, y: 500), .next)
expectBox("Next の右端", CGPoint(x: 1137, y: 500), .next)
expectBox("Inbox の右端", CGPoint(x: 569, y: 500), .inbox)
expectBox("Done の左端", CGPoint(x: 1151, y: 500), .done)
expectBox("列より上（受け付けない）", CGPoint(x: 860, y: -100), nil)
expectBox("右にはみ出す → 近いDone", CGPoint(x: 2000, y: 500), .done)
print(f8 == 0 ? "\n箱の中はどこでも: 全て通過" : "\n箱の中はどこでも: 失敗 \(f8) 件")


// --- プロファイルの既定時刻は任意 ---
print("\n--- 既定の時刻（任意） ---")
var f9 = 0
func checkTime(_ label: String, _ ok: Bool) {
    if !ok { f9 += 1 }
    print("\(ok ? "OK  " : "NG  ") \(label)")
}
func prof(_ time: String) -> Profile {
    Profile(id: "p", name: "p", symbol: "c", colorHex: "#0A84FF", defaultTime: time)
}
checkTime("空欄 → 時刻なし", prof("").defaultHourMinute == nil)
checkTime("空白だけ → 時刻なし", prof("   ").defaultHourMinute == nil)
checkTime("09:30 → 9時30分", prof("09:30").defaultHourMinute.map { $0 == (9, 30) } ?? false)
checkTime("23:59 → 23時59分", prof("23:59").defaultHourMinute.map { $0 == (23, 59) } ?? false)
checkTime("24:00 → 不正なので時刻なし", prof("24:00").defaultHourMinute == nil)
checkTime("09:60 → 不正なので時刻なし", prof("09:60").defaultHourMinute == nil)
checkTime("9時 → 不正なので時刻なし", prof("9時").defaultHourMinute == nil)
checkTime("0:00 → 0時0分", prof("0:00").defaultHourMinute.map { $0 == (0, 0) } ?? false)
print(f9 == 0 ? "\n既定の時刻: 全て通過" : "\n既定の時刻: 失敗 \(f9) 件")

exit((failures + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9) == 0 ? 0 : 1)
