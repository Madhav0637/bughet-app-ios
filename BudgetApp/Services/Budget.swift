import Foundation
import SwiftData

/// Where settings live in UserDefaults. Screens read them with @AppStorage; the Log Expense intent reads them directly.
enum SettingsKey {
    /// Kept from before the redesign, so the chosen period survives the update.
    static let homePeriod = "dashboardPeriod"
    static let insightsPeriod = "insightsPeriod"
    static let appearance = "appearance"
    static let highlight = "highlight"
    /// Whole rupees; 0 means no budget.
    static let monthlyBudget = "monthlyBudget"
    static let budgetAlerts = "budgetAlerts"
    /// The month ("yyyy-MM") and level (80 or 100) of the last budget alert, so each is sent once a month.
    static let lastAlertMonth = "budgetAlertMonth"
    static let lastAlertLevel = "budgetAlertLevel"
}

/// Decides when to warn about the monthly budget: once when 80% is used and once when it's all used, each at most
/// once a month. Remembers what it has sent in UserDefaults, so the app and the Log Expense intent share the record.
struct BudgetAlerts {
    enum Level: Int, Comparable {
        case nearly = 80
        case over = 100

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    struct Alert: Equatable {
        let level: Level
        let budget: Int
        let spent: Int
        /// Any date in the month the alert is about.
        let month: Date
    }

    var defaults: UserDefaults = .standard
    var calendar: Calendar = .current

    /// The highest level reached: 80% or more is `.nearly`, 100% or more is `.over`.
    static func level(budget: Int, spent: Int) -> Level? {
        guard budget > 0 else { return nil }
        if spent >= budget { return .over }
        if spent * 100 >= budget * 80 { return .nearly }
        return nil
    }

    /// Call after spending in `month` changed from `before` to `after`. Returns an alert when the increase reached a
    /// level not yet alerted this month, and records it. Going straight past 100% alerts only once, for 100%.
    func check(budget: Int, before: Int, after: Int, month: Date) -> Alert? {
        guard after > before, let level = Self.level(budget: budget, spent: after) else { return nil }
        let key = monthKey(for: month)
        let alreadySent = defaults.string(forKey: SettingsKey.lastAlertMonth) == key
            ? defaults.integer(forKey: SettingsKey.lastAlertLevel) : 0
        guard level.rawValue > alreadySent else { return nil }
        defaults.set(key, forKey: SettingsKey.lastAlertMonth)
        defaults.set(level.rawValue, forKey: SettingsKey.lastAlertLevel)
        return Alert(level: level, budget: budget, spent: after, month: month)
    }

    /// Forgets which alerts were sent, e.g. after the budget changes.
    func reset() {
        defaults.removeObject(forKey: SettingsKey.lastAlertMonth)
        defaults.removeObject(forKey: SettingsKey.lastAlertLevel)
    }

    /// The notification or banner text for an alert.
    static func message(for alert: Alert, calendar: Calendar = .current) -> (title: String, body: String) {
        let month = alert.month.formatted(Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).month(.wide))
        switch alert.level {
        case .nearly:
            let left = alert.budget - alert.spent
            return ("80% of your \(month) budget is used",
                    "\(alert.spent.inr) of \(alert.budget.inr) spent. \(left.inr) left for the rest of the month.")
        case .over:
            let over = alert.spent - alert.budget
            return ("You've gone over your \(month) budget",
                    over > 0 ? "\(alert.spent.inr) spent, \(over.inr) more than your \(alert.budget.inr) budget."
                             : "You've spent your whole \(alert.budget.inr) budget.")
        }
    }

    private func monthKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}

/// Reads the monthly budget and checks for alerts around a change to the expenses.
struct BudgetService {
    let context: ModelContext
    var defaults: UserDefaults = .standard
    var calculator = PeriodCalculator()

    var monthlyBudget: Int { max(0, defaults.integer(forKey: SettingsKey.monthlyBudget)) }
    /// On unless turned off in Settings.
    var alertsEnabled: Bool { defaults.object(forKey: SettingsKey.budgetAlerts) as? Bool ?? true }

    func spent(inMonthOf date: Date = .now) throws -> Int {
        let month = calculator.range(of: .month, containing: date)
        let start = month.lowerBound
        let end = month.upperBound
        let expenses = try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.date >= start && $0.date < end }))
        return expenses.reduce(0) { $0 + $1.amount }
    }

    /// Runs `change` (saving an expense), then returns the alert it triggered, if any. Only this month counts.
    func alert(now: Date = .now, around change: () throws -> Void) throws -> BudgetAlerts.Alert? {
        let before = try spent(inMonthOf: now)
        try change()
        guard alertsEnabled, monthlyBudget > 0 else { return nil }
        let after = try spent(inMonthOf: now)
        return BudgetAlerts(defaults: defaults, calendar: calculator.calendar)
            .check(budget: monthlyBudget, before: before, after: after, month: now)
    }
}
