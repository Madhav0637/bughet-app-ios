import Foundation

/// What the widgets show. The app writes this small file into the shared App Group container whenever expenses or
/// settings change; the widgets only ever read it, so they never open the app's database. Everything that depends on
/// the time (a new day, a new month) is worked out when the widget draws, so midnight needs no help from the app.
struct WidgetSnapshot: Codable, Equatable {
    struct Day: Codable, Equatable {
        /// Midnight at the start of the day.
        let start: Date
        let amount: Int
    }

    struct LastExpense: Codable, Equatable {
        let merchant: String
        let amount: Int
        let emoji: String
        let date: Date
    }

    var generatedAt: Date
    /// Spending on each day of the 7 days that ended with `generatedAt`'s day, oldest first.
    var days: [Day]
    var monthStart: Date
    /// Everything logged in the month that starts at `monthStart`.
    var monthTotal: Int
    /// Whole rupees; 0 when there's no budget.
    var monthlyBudget: Int
    var lastExpense: LastExpense?
    /// The highlight colour chosen in Settings.
    var highlight: String

    static let appGroup = "group.com.madhav0637.budgetapp"
    static let widgetKind = "KokuToday"

    /// Where the app writes the snapshot and the widgets read it.
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget-snapshot.json")
    }

    // MARK: Reading at a given moment

    /// What was spent on the day containing `date`; zero once that day isn't in the snapshot (e.g. after midnight).
    func spent(on date: Date, calendar: Calendar = .current) -> Int {
        days.first { calendar.isDate($0.start, inSameDayAs: date) }?.amount ?? 0
    }

    /// The 7 days ending with the day of `date`, oldest first. Days the snapshot doesn't cover count as zero.
    func lastDays(at date: Date, calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: date)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return Day(start: day, amount: spent(on: day, calendar: calendar))
        }
    }

    /// This month's total at `date`: zero once a new month has started.
    func monthSpent(at date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(monthStart, equalTo: date, toGranularity: .month) ? monthTotal : 0
    }

    /// Budget pace for the month containing `date`, or nil without a budget.
    func pace(at date: Date, calendar: Calendar = .current) -> BudgetPace? {
        guard monthlyBudget > 0, let month = calendar.dateInterval(of: .month, for: date) else { return nil }
        return BudgetPace(budget: monthlyBudget, spent: monthSpent(at: date, calendar: calendar),
                          month: month.start..<month.end, now: date, calendar: calendar)
    }

    /// What was safe to spend today, judged at the start of the day (so it doesn't shrink as today's spending grows),
    /// or nil without a budget. Zero once the month's budget was used up before today.
    func todayAllowance(at date: Date, calendar: Calendar = .current) -> Int? {
        guard monthlyBudget > 0, let month = calendar.dateInterval(of: .month, for: date) else { return nil }
        let beforeToday = monthSpent(at: date, calendar: calendar) - spent(on: date, calendar: calendar)
        return BudgetPace(budget: monthlyBudget, spent: beforeToday, month: month.start..<month.end,
                          now: date, calendar: calendar).perDay
    }

    /// How much of today's allowance is used, from 0 (nothing) up; above 1 means over. Nil without a budget.
    func todayProgress(at date: Date, calendar: Calendar = .current) -> Double? {
        guard let allowance = todayAllowance(at: date, calendar: calendar) else { return nil }
        let today = spent(on: date, calendar: calendar)
        guard allowance > 0 else { return today > 0 ? 1 : 0 }
        return Double(today) / Double(allowance)
    }

    // MARK: Storage

    static func load(from url: URL? = fileURL) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Readable after the phone's first unlock, so Lock Screen widgets can show it while locked.
    func save(to url: URL? = WidgetSnapshot.fileURL) throws {
        guard let url else { return }
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: Examples

    /// Nothing logged yet.
    static func empty(at date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: date, days: [], monthStart: calendar.dateInterval(of: .month, for: date)?.start ?? date,
                       monthTotal: 0, monthlyBudget: 0, lastExpense: nil, highlight: "mint")
    }

    /// Made-up numbers for the widget gallery and placeholders.
    static func sample(at date: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: date)
        let amounts = [1_240, 860, 2_310, 410, 1_780, 3_120, 840]
        let days = amounts.enumerated().compactMap { index, amount in
            calendar.date(byAdding: .day, value: index - 6, to: today).map { Day(start: $0, amount: amount) }
        }
        return WidgetSnapshot(generatedAt: date, days: days,
                              monthStart: calendar.dateInterval(of: .month, for: date)?.start ?? today,
                              monthTotal: 18_420, monthlyBudget: 25_000,
                              lastExpense: LastExpense(merchant: "Zomato", amount: 420, emoji: "🍔", date: date),
                              highlight: "mint")
    }
}
