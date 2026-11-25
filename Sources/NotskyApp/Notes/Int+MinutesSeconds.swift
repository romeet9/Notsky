import Foundation

extension Int {
    /// Formats a count of seconds as zero-padded "mm:ss" (e.g. 125 becomes "02:05").
    var minutesSecondsString: String {
        let style = IntegerFormatStyle<Int>.number.grouping(.never).precision(.integerLength(2...))
        return "\((self / 60).formatted(style)):\((self % 60).formatted(style))"
    }
}
