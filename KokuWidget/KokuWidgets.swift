import AppIntents
import SwiftUI
import WidgetKit

@main
struct KokuWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        LogExpenseControl()
    }
}

// MARK: Today

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the snapshot the app keeps up to date. Adds an entry at each of the next few midnights, so "today" resets
/// to ₹0 on time even if the app isn't opened.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        // The widget gallery shows sample numbers until there's real spending to show.
        let snapshot = WidgetSnapshot.load() ?? (context.isPreview ? .sample() : .empty())
        completion(TodayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshot.load() ?? .empty(at: now)
        let calendar = Calendar.current
        var dates = [now]
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<3 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            dates.append(next)
            midnight = next
        }
        completion(Timeline(entries: dates.map { TodayEntry(date: $0, snapshot: snapshot) }, policy: .atEnd))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Spent Today")
        .description("Today's spending at a glance, with your budget and the last 7 days in the larger sizes.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .fontDesign(.rounded)
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium: TodayWidgetBackground(highlight: entry.snapshot.highlightColour)
                default: Color.clear
                }
            }
            // The one-tile and small sizes open Home; the sizes with the 7-day bars open Insights.
            .widgetURL(family == .accessoryRectangular || family == .systemMedium ? KokuLink.insights.url : KokuLink.home.url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular: TodayCircularView(snapshot: entry.snapshot, date: entry.date)
        case .accessoryRectangular: TodayRectangularView(snapshot: entry.snapshot, date: entry.date)
        case .accessoryInline: TodayInlineView(snapshot: entry.snapshot, date: entry.date)
        case .systemMedium: TodayMediumView(snapshot: entry.snapshot, date: entry.date)
        default: TodaySmallView(snapshot: entry.snapshot, date: entry.date)
        }
    }
}

// MARK: Log Expense control

/// A button for the Lock Screen's corners, Control Centre or the Action button that opens Add Expense.
struct LogExpenseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.madhav0637.budgetapp.logExpense") {
            ControlWidgetButton(action: OpenKokuIntent(screen: .add)) {
                Label("Log Expense", systemImage: "indianrupeesign.circle.fill")
            }
        }
        .displayName("Log Expense")
        .description("Opens Koku's Add Expense screen.")
    }
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample())
}

#Preview("Home Screen", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample())
}
