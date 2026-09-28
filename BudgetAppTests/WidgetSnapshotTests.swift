import Foundation
import SwiftData
import Testing
@testable import BudgetApp

@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    let calendar = TestDate.calendar
    /// 26 Sep 2026, 14:00 IST.
    let now = TestDate.make(2026, 9, 26, 14)

    /// 20–26 Sep at 100, 200, … 700, with ₹18,420 this month and a ₹25,000 budget.
    private func snapshot(budget: Int = 25_000, monthTotal: Int = 18_420) -> WidgetSnapshot {
        let days = (0..<7).map { offset in
            WidgetSnapshot.Day(start: TestDate.make(2026, 9, 20 + offset, 0), amount: (offset + 1) * 100)
        }
        return WidgetSnapshot(generatedAt: now, days: days, monthStart: TestDate.make(2026, 9, 1, 0),
                              monthTotal: monthTotal, monthlyBudget: budget, lastExpense: nil, highlight: "coral")
    }

    // MARK: Reading at a moment

    @Test func todayComesFromTheMatchingDay() {
        #expect(snapshot().spent(on: now, calendar: calendar) == 700)
    }

    @Test func afterMidnightTodayIsZero() {
        #expect(snapshot().spent(on: TestDate.make(2026, 9, 27, 0, 1), calendar: calendar) == 0)
    }

    @Test func lastDaysMoveOnWithTheDate() {
        let days = snapshot().lastDays(at: TestDate.make(2026, 9, 28, 9), calendar: calendar)
        #expect(days.map(\.start) == (22...28).map { TestDate.make(2026, 9, $0, 0) })
        #expect(days.map(\.amount) == [300, 400, 500, 600, 700, 0, 0])
    }

    @Test func aNewMonthStartsAtZero() {
        #expect(snapshot().monthSpent(at: now, calendar: calendar) == 18_420)
        #expect(snapshot().monthSpent(at: TestDate.make(2026, 10, 1, 8), calendar: calendar) == 0)
    }

    @Test func todaysAllowanceIsSetAtTheStartOfTheDay() throws {
        // ₹17,720 spent before today; ₹7,280 left for 5 days (26th–30th) is ₹1,456 a day.
        let snapshot = snapshot()
        #expect(snapshot.todayAllowance(at: now, calendar: calendar) == 1_456)
        let progress = try #require(snapshot.todayProgress(at: now, calendar: calendar))
        #expect(abs(progress - 700.0 / 1_456) < 0.0001)
    }

    @Test func budgetUsedUpBeforeTodayMeansAFullRing() {
        let snapshot = snapshot(budget: 10_000)
        #expect(snapshot.todayAllowance(at: now, calendar: calendar) == 0)
        #expect(snapshot.todayProgress(at: now, calendar: calendar) == 1)
    }

    @Test func noBudgetMeansNoRingOrPace() {
        let snapshot = snapshot(budget: 0)
        #expect(snapshot.todayAllowance(at: now, calendar: calendar) == nil)
        #expect(snapshot.todayProgress(at: now, calendar: calendar) == nil)
        #expect(snapshot.pace(at: now, calendar: calendar) == nil)
    }

    @Test func budgetLines() {
        #expect(snapshot(budget: 0).budgetLine(at: now) == "₹18,420 this month")
        #expect(snapshot(budget: 18_000).budgetLine(at: now) == "₹420 over budget")
    }

    @Test func highlightFallsBackToMint() {
        var snapshot = snapshot()
        #expect(snapshot.highlightColour == .coral)
        snapshot.highlight = "nonsense"
        #expect(snapshot.highlightColour == .mint)
    }

    @Test func savesAndLoadsAFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try snapshot().save(to: url)
        #expect(WidgetSnapshot.load(from: url) == snapshot())
    }

    @Test func sameContentIgnoresWhenItWasMade() {
        var later = snapshot()
        later.generatedAt = now.addingTimeInterval(60)
        #expect(snapshot().hasSameContent(as: later))
        later.monthTotal += 1
        #expect(!snapshot().hasSameContent(as: later))
    }

    // MARK: Compact amounts

    @Test(arguments: [(840, "₹840"), (8_420, "₹8,420"), (10_000, "₹10k"), (12_340, "₹12.3k"), (1_48_000, "₹1.5L")])
    func compactAmounts(amount: Int, text: String) {
        #expect(amount.compactINR == text)
    }

    // MARK: Building from the database

    @Test func buildsFromTheDatabase() throws {
        let db = try TestDatabase()
        let food = try db.makeCategory("Food", emoji: "🍔")
        let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests-\(UUID().uuidString)"))
        defaults.set(25_000, forKey: SettingsKey.monthlyBudget)
        defaults.set("sky", forKey: SettingsKey.highlight)

        try db.addExpense(420, to: food, merchant: "Zomato", on: TestDate.make(2026, 9, 26, 9))
        try db.addExpense(80, to: food, merchant: "Chai", on: TestDate.make(2026, 9, 26, 11))
        try db.addExpense(300, to: food, merchant: "Swiggy", on: TestDate.make(2026, 9, 21, 20))
        try db.addExpense(999, to: food, merchant: "Too old", on: TestDate.make(2026, 9, 10))    // this month, not this week
        try db.addExpense(555, to: food, merchant: "August", on: TestDate.make(2026, 8, 31, 22)) // neither
        try db.addExpense(50, to: food, merchant: "Later today", on: TestDate.make(2026, 9, 26, 20))

        let snapshot = try WidgetSync.makeSnapshot(context: db.context, defaults: defaults, now: now, calendar: calendar)

        #expect(snapshot.days.map(\.amount) == [0, 300, 0, 0, 0, 0, 550])
        #expect(snapshot.monthTotal == 420 + 80 + 300 + 999 + 50)
        #expect(snapshot.monthlyBudget == 25_000)
        #expect(snapshot.highlight == "sky")
        #expect(snapshot.lastExpense?.merchant == "Chai") // the latest one that isn't in the future
        #expect(snapshot.lastExpense?.emoji == "🍔")
    }

    @Test func savesAreMirroredIntoTheSnapshot() throws {
        let db = try TestDatabase()
        let food = try db.makeCategory("Food")
        let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests-\(UUID().uuidString)"))
        let url = FileManager.default.temporaryDirectory.appending(path: "snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let observer = WidgetSync.observeSaves(of: db.container, defaults: defaults, url: url)
        defer { NotificationCenter.default.removeObserver(observer) }

        try db.addExpense(260, to: food, merchant: "Swiggy")

        let snapshot = try #require(WidgetSnapshot.load(from: url))
        #expect(snapshot.spent(on: .now) == 260)
        #expect(snapshot.lastExpense?.merchant == "Swiggy")
    }
}
