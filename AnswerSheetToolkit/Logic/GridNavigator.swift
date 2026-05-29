import Foundation

/// Pure index math for navigating the answer grid.
///
/// All indices are 0-based internally. `count` is the total number of questions.
/// Navigation never moves out of bounds.
enum GridNavigator {
    /// Index after answering or pressing Tab. Advances by one but clamps at the last
    /// question (focus stays within bounds at the final question).
    static func next(from index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(index + 1, count - 1)
    }

    /// Index for Shift+Tab. Moves back one but never below the first question.
    static func previous(from index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(index - 1, 0)
    }

    /// Clamps an arbitrary index into valid range.
    static func clamp(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    /// Whether the given index is the final question.
    static func isLast(_ index: Int, count: Int) -> Bool {
        count > 0 && index == count - 1
    }
}
