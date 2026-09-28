import SwiftUI
import WidgetKit

// The faces of the Today widget in every size. Text uses the system's primary and secondary styles, so iOS can tint
// them on the Lock Screen and in the tinted and clear Home Screen styles; `widgetAccentable` marks what gets the accent.

/// One Lock Screen tile: today's total in the system's glass disc. With a budget, a ring fills as today's
/// safe-to-spend amount gets used.
struct TodayCircularView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let today = snapshot.spent(on: date)
        Group {
            if let progress = snapshot.todayProgress(at: date) {
                Gauge(value: min(max(progress, 0), 1)) {
                    Text("Today")
                } currentValueLabel: {
                    CircleLabel(amount: today)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    CircleLabel(amount: today)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spent today, \(today.inr)")
    }
}

private struct CircleLabel: View {
    let amount: Int

    var body: some View {
        VStack(spacing: -1) {
            Text("TODAY")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .opacity(0.75)
            Text(amount.compactINR)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
        }
        .padding(.horizontal, 5)
    }
}

/// Two Lock Screen tiles: today's total, what's left of the budget, and the last 7 days.
struct TodayRectangularView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .widgetAccentable()
                    Text("Today")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .opacity(0.85)
                Text(snapshot.spent(on: date).inr)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(snapshot.budgetLine(at: date))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            WeekBars(days: snapshot.lastDays(at: date), height: 30, barWidth: 4)
                .frame(width: 36)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One line above the clock.
struct TodayInlineView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let today = snapshot.spent(on: date).inr
        if let pace = snapshot.pace(at: date), !pace.isOver {
            Label("\(today) today · \(pace.remaining.inr) left", systemImage: "indianrupeesign.circle")
        } else {
            Label("\(today) spent today", systemImage: "indianrupeesign.circle")
        }
    }
}

/// Home Screen, small: today's total, the month's budget bar and a quick add button.
struct TodaySmallView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let highlight = snapshot.highlightColour
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                AddCircle(highlight: highlight)
            }
            Spacer(minLength: 2)
            Text(snapshot.spent(on: date).inr)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            if let pace = snapshot.pace(at: date) {
                BudgetBar(progress: pace.progress, colour: pace.isOver ? .warning : highlight.fill)
                    .padding(.top, 8)
                Text(pace.isOver ? "\((-pace.remaining).inr) over budget" : "\(pace.remaining.inr) left")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 5)
            } else {
                Text("\(snapshot.monthSpent(at: date).inr) this month")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
        }
    }
}

/// Home Screen, medium: the small widget plus the last expense and the last 7 days.
struct TodayMediumView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let highlight = snapshot.highlightColour
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(snapshot.spent(on: date).inr)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .widgetAccentable()
                    .padding(.top, 1)
                if let last = snapshot.lastExpense {
                    Text("\(last.emoji) \(last.merchant) · \(last.amount.inr)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                Spacer(minLength: 4)
                if let pace = snapshot.pace(at: date) {
                    BudgetBar(progress: pace.progress, colour: pace.isOver ? .warning : highlight.fill)
                }
                Text(snapshot.budgetLine(at: date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 5)
            }
            VStack(alignment: .trailing, spacing: 0) {
                AddCircle(highlight: highlight)
                Spacer(minLength: 4)
                WeekBars(days: snapshot.lastDays(at: date), height: 58, barWidth: 9, todayColour: highlight.fill,
                         showsLabels: true)
                    .frame(width: 128)
            }
        }
    }
}

/// The glassy backdrop of the Home Screen widgets: the Koku surface with a faint glow of the highlight colour and a
/// soft sheen from the top. iOS replaces it with real glass in the clear and tinted Home Screen styles.
struct TodayWidgetBackground: View {
    let highlight: Highlight

    var body: some View {
        ZStack {
            Color.surface
            RadialGradient(colors: [highlight.fill.opacity(0.30), .clear], center: .topTrailing,
                           startRadius: 0, endRadius: 190)
            LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
        }
    }
}

// MARK: Pieces

/// Seven small bars, today's the brightest.
struct WeekBars: View {
    let days: [WidgetSnapshot.Day]
    let height: CGFloat
    let barWidth: CGFloat
    /// Today's bar on the Home Screen. On the Lock Screen iOS draws everything in one colour, so it's left nil.
    var todayColour: Color?
    var showsLabels = false

    var body: some View {
        let peak = max(days.map(\.amount).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.start) { index, day in
                let isToday = index == days.count - 1
                VStack(spacing: 3) {
                    Capsule()
                        .fill(isToday ? (todayColour ?? .primary) : Color.primary.opacity(0.28))
                        .frame(width: barWidth, height: max(barWidth, height * CGFloat(day.amount) / CGFloat(peak)))
                        .frame(height: height, alignment: .bottom)
                        .widgetAccentable(isToday)
                    if showsLabels {
                        Text(day.start.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isToday ? .primary : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A thin bar showing how much of the month's budget is used.
private struct BudgetBar: View {
    let progress: Double
    let colour: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(colour)
                    .frame(width: max(5, geometry.size.width * min(max(progress, 0), 1)))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// The round "+" in the highlight colour. Opens Add Expense.
private struct AddCircle: View {
    let highlight: Highlight

    var body: some View {
        Link(destination: KokuLink.add.url) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.onHighlight)
                .frame(width: 28, height: 28)
                .background(highlight.fill, in: .circle)
        }
        .widgetAccentable()
        .accessibilityLabel("Add expense")
    }
}

extension WidgetSnapshot {
    var highlightColour: Highlight { Highlight(rawValue: highlight) ?? .mint }

    /// "₹6,580 left · ₹1,316/day", "₹340 over budget", or without a budget "₹18,420 this month".
    func budgetLine(at date: Date) -> String {
        guard let pace = pace(at: date) else { return "\(monthSpent(at: date).inr) this month" }
        if pace.isOver { return "\((-pace.remaining).inr) over budget" }
        return "\(pace.remaining.inr) left · \(pace.perDay.inr)/day"
    }
}
