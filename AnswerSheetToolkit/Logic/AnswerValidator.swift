import Foundation

/// Pure functions for validating and normalizing answer input.
///
/// Kept free of UI/AppKit dependencies so it can be unit tested in isolation.
enum AnswerValidator {
    /// Normalizes a raw key/character into a valid stored answer.
    ///
    /// - Returns: A single uppercase letter `A`...`Z` if the input is exactly one
    ///   alphabetic character; otherwise `nil` (numbers, symbols, whitespace, empty,
    ///   or multi-character strings are rejected).
    static func normalize(_ raw: String) -> String? {
        guard raw.count == 1, let scalar = raw.unicodeScalars.first else { return nil }
        // Only ASCII / latin letters are accepted.
        guard scalar.properties.isAlphabetic else { return nil }
        let upper = raw.uppercased()
        guard upper.count == 1,
              let u = upper.unicodeScalars.first,
              ("A"..."Z").contains(Character(u)) else {
            return nil
        }
        return upper
    }

    /// Whether a raw character represents a valid answer letter.
    static func isValidLetter(_ raw: String) -> Bool {
        normalize(raw) != nil
    }

    /// Normalizes `raw` and accepts it only if it falls within the first
    /// `optionCount` letters (counted from `A`). For example, `optionCount == 4`
    /// allows A–D and rejects E–Z. Returns `nil` for out-of-range or invalid input.
    static func normalize(_ raw: String, optionCount: Int) -> String? {
        guard let letter = normalize(raw), let scalar = letter.unicodeScalars.first else {
            return nil
        }
        let index = Int(scalar.value) - 65 // 'A' == 65
        return index < max(1, optionCount) ? letter : nil
    }
}
