/// Crockford base32: no I, L, O, or U, so codes survive being read aloud or retyped.
enum CrockfordBase32 {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func digit(for character: Character) -> Int? {
        switch character.uppercased() {
        case "O": return 0
        case "I", "L": return 1
        default:
            guard let upper = character.uppercased().first else { return nil }
            return alphabet.firstIndex(of: upper)
        }
    }

    /// Uppercases, maps look-alikes, and drops separators. Nil if any other character is invalid.
    static func digits(from string: String) -> [Int]? {
        var digits: [Int] = []
        for character in string where character != "-" && !character.isWhitespace {
            guard let digit = digit(for: character) else { return nil }
            digits.append(digit)
        }
        return digits
    }

    /// Big-endian digits of `value`, left-padded to `count`.
    static func digits(of value: UInt64, count: Int) -> [Int] {
        (0..<count).reversed().map { Int((value >> (5 * UInt64($0))) & 31) }
    }

    static func value(of digits: some Collection<Int>) -> UInt64 {
        digits.reduce(0) { ($0 << 5) | UInt64($1) }
    }

    static func string(from digits: some Collection<Int>) -> String {
        String(digits.map { alphabet[$0] })
    }

    /// Weighted sum with odd weights mod 32. Every odd weight is invertible mod 32, so
    /// any single-symbol substitution changes the check digit and is always detected.
    static func checkDigit(for digits: [Int]) -> Int {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += (2 * index + 1) * digit
        }
        return sum % 32
    }
}
