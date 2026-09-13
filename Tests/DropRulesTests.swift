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

print(failures == 0 ? "\n全て通過" : "\n失敗 \(failures) 件")
exit(failures == 0 ? 0 : 1)
