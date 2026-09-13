import Foundation

/// 1つの列に「画面へ出す順番」をまとめたもの。
/// 描画・ドロップ判定・並べ替えの3つが、必ずこの1本を見る。
/// 別々に組み直すと、片方を直したときにもう片方がずれる。
struct ColumnLayout {
    /// 画面に出る1行。親カードも子カードも同じ行として扱う。
    struct Row: Identifiable {
        let task: Task
        let isSubtask: Bool
        /// ここへ落としたとき、親リストの何番目に入るか
        let insertBefore: Int
        /// この行の手前に挿入線を出してよいか（同じ位置に二重に出さないため）
        let showsInsertionLine: Bool
        /// 親とその子をひとまとまりとみなしたときの、最後の行か
        let isGroupEnd: Bool
        /// この行が属するまとまりの親ID
        let groupParentID: UUID

        var id: UUID { task.id }
    }

    let status: Status
    /// 並べ替えの対象。子は含まない。
    let parents: [Task]
    /// 画面に出る順（親 → その子 → 次の親 …）
    let rows: [Row]

    var isEmpty: Bool { rows.isEmpty }

    /// 末尾に落としたときの添字
    var endIndex: Int { parents.count }

    init(status: Status, parents: [Task], children: (Task) -> [Task]) {
        self.status = status
        self.parents = parents

        var built: [Row] = []
        for (index, parent) in parents.enumerated() {
            let kids = children(parent)
            built.append(Row(task: parent, isSubtask: false,
                             insertBefore: index,
                             showsInsertionLine: true,
                             isGroupEnd: kids.isEmpty,
                             groupParentID: parent.id))
            for (k, child) in kids.enumerated() {
                // 子の位置に落としたら、その親の「次」に入る。
                // 挿入線は親の手前と重なるため、子では出さない。
                built.append(Row(task: child, isSubtask: true,
                                 insertBefore: index + 1,
                                 showsInsertionLine: false,
                                 isGroupEnd: k == kids.count - 1,
                                 groupParentID: parent.id))
            }
        }
        self.rows = built
    }
}
