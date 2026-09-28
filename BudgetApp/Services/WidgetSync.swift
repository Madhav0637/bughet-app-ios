import Foundation
import SwiftData
import WidgetKit

/// Keeps the widgets' snapshot current. It's rebuilt after every save to the database (from the app's screens or the
/// Log Expense intent), when the budget or highlight colour changes, and when the app comes to the front.
enum WidgetSync {
    /// The observer for the app's own database, kept for the life of the process.
    private static var observer: NSObjectProtocol?

    /// Everything the widgets show, worked out from the database and settings at `now`.
    static func makeSnapshot(context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now,
                             calendar: Calendar = .current) throws -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: today, duration: 86_400)
        let from = min(weekStart, month.start)
        let until = month.end
        let recent = try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.date >= from && $0.date < until }))

        var byDay: [Date: Int] = [:]
        var monthTotal = 0
        for expense in recent {
            byDay[calendar.startOfDay(for: expense.date), default: 0] += expense.amount
            if expense.date >= month.start { monthTotal += expense.amount }
        }
        let days = (0..<7).compactMap { offset -> WidgetSnapshot.Day? in
            calendar.date(byAdding: .day, value: offset - 6, to: today).map { WidgetSnapshot.Day(start: $0, amount: byDay[$0] ?? 0) }
        }

        var latest = FetchDescriptor<Expense>(predicate: #Predicate { $0.date <= now },
                                              sortBy: [SortDescriptor(\.date, order: .reverse)])
        latest.fetchLimit = 1
        let last = try context.fetch(latest).first.map {
            WidgetSnapshot.LastExpense(merchant: $0.merchant, amount: $0.amount, emoji: $0.category?.emoji ?? "❔", date: $0.date)
        }

        return WidgetSnapshot(generatedAt: now, days: days, monthStart: month.start, monthTotal: monthTotal,
                              monthlyBudget: max(0, defaults.integer(forKey: SettingsKey.monthlyBudget)),
                              lastExpense: last,
                              highlight: defaults.string(forKey: SettingsKey.highlight) ?? Highlight.mint.rawValue)
    }

    /// Rebuilds the snapshot; if anything changed, saves it and asks the widgets to redraw.
    static func refresh(context: ModelContext, defaults: UserDefaults = .standard,
                        url: URL? = WidgetSnapshot.fileURL) {
        guard let snapshot = try? makeSnapshot(context: context, defaults: defaults),
              WidgetSnapshot.load(from: url)?.hasSameContent(as: snapshot) != true else { return }
        do {
            try snapshot.save(to: url)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        } catch {
            // A widget showing slightly old numbers isn't worth interrupting anything for.
        }
    }

    /// Refreshes after every save of the app's database, so widgets follow changes wherever they come from.
    static func observeSaves(of container: ModelContainer) {
        guard observer == nil else { return }
        observer = observeSaves(of: container, defaults: .standard, url: WidgetSnapshot.fileURL)
    }

    /// The same, for any container and snapshot location. Returns the observer so tests can remove it.
    static func observeSaves(of container: ModelContainer, defaults: UserDefaults, url: URL?) -> NSObjectProtocol {
        // No queue: the refresh runs straight away, inside the save, so an intent that saves and then finishes
        // can't be suspended before the widgets hear about it.
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { note in
            guard let context = note.object as? ModelContext, context.container === container else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated { refresh(context: container.mainContext, defaults: defaults, url: url) }
            } else {
                Task { @MainActor in refresh(context: container.mainContext, defaults: defaults, url: url) }
            }
        }
    }
}

extension WidgetSnapshot {
    /// Equal apart from when it was made.
    func hasSameContent(as other: WidgetSnapshot) -> Bool {
        var copy = self
        copy.generatedAt = other.generatedAt
        return copy == other
    }
}
