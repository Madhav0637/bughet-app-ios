import Foundation

extension Int {
    /// Whole rupees with Indian digit grouping, e.g. ₹1,23,456.
    var inr: String {
        formatted(.currency(code: "INR").precision(.fractionLength(0)).locale(Locale(identifier: "en_IN")))
    }

    /// Indian digit grouping without the ₹, e.g. 1,23,456. Used where the ₹ is drawn separately.
    var indianGrouped: String {
        formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "en_IN")))
    }

    /// Short enough for the smallest widget: ₹840 and ₹8,420 in full, then ₹12.3k, then lakhs as ₹1.5L.
    var compactINR: String {
        let size = abs(self)
        guard size >= 10_000 else { return inr }
        let sign = self < 0 ? "-" : ""
        let (value, unit) = size < 1_00_000 ? (Double(size) / 1_000, "k") : (Double(size) / 1_00_000, "L")
        let number = value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "en_IN")))
        return "\(sign)₹\(number)\(unit)"
    }
}
