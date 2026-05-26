import Foundation

struct CellEditSnapshot: Equatable {
    let index: CellIndex
    let value: Int?
    let notes: Set<Int>
}
