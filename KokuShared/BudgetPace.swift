import Foundation

/// How this month's spending compares with the monthly budget.
struct BudgetPace: Equatable {
    let budget: Int
    let spent: Int
    /// Days left in the month, counting today.
    let daysLeft: Int

    init(budget: Int, spent: Int, month: Range<Date>, now: Date = .now, calendar: Calendar = .current) {
        self.budget = budget
        self.spent = spent
        let today = max(calendar.startOfDay(for: now), month.lowerBound)
        let days = calendar.dateComponents([.day], from: today, to: month.upperBound).day ?? 0
        daysLeft = max(0, days)
    }

    /// Negative once over budget.
    var remaining: Int { budget - spent }
    var isOver: Bool { spent > budget }
    /// How much of the budget is used: 0.74 is 74%. Goes above 1 when over budget.
    var progress: Double { budget > 0 ? Double(spent) / Double(budget) : 0 }
    /// What can be spent on each remaining day (including today) to finish the month on budget.
    var perDay: Int { daysLeft > 0 && remaining > 0 ? remaining / daysLeft : 0 }
}
