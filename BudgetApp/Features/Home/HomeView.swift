import SwiftData
import SwiftUI

/// The first tab: what's been spent this week, month or year, the monthly budget, the last 7 days,
/// where the money went and the latest expenses.
struct HomeView: View {
    /// Goes up by one each time a widget or control asks for Add Expense.
    var addRequest = 0
    /// Switches to another tab, for "Insights ›" and "See all ›".
    var openTab: (RootView.AppTab) -> Void = { _ in }

    @Query private var expenses: [Expense]
    @AppStorage(SettingsKey.homePeriod) private var period = Period.month
    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = 0
    @Environment(\.highlight) private var highlight

    @State private var form: ExpenseFormView.Mode?
    @State private var isEditingBudget = false

    var body: some View {
        let calculator = PeriodCalculator()
        let summary = SpendingSummary(expenses: expenses, in: calculator.range(of: period))
        let comparison = PeriodComparison(expenses: expenses, period: period, calculator: calculator)
        let lastWeek = PeriodInsights.lastDays(7, expenses: expenses, calculator: calculator)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                hero(total: summary.total, comparison: comparison)
                budgetCard(calculator: calculator)
                if lastWeek.contains(where: { $0.amount > 0 }) {
                    LastDaysChart(buckets: lastWeek)
                }
                if summary.total > 0 {
                    categories(summary)
                    recent(summary)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110) // room to scroll past the add button
            .animation(.snappy, value: period)
        }
        .scrollIndicators(.hidden)
        .background(Color.canvas)
        .overlay(alignment: .bottom) { FloatingActions { form = .add } }
        .sheet(item: $form) { ExpenseFormView(mode: $0) }
        .sheet(isPresented: $isEditingBudget) { BudgetView() }
        .onChange(of: addRequest) { form = .add }
        #if DEBUG
        // For screenshots: launch with `-openAdd YES`.
        .onAppear { if UserDefaults.standard.bool(forKey: "openAdd") { form = .add } }
        #endif
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 10) {
            KokuLogo(size: 34)
            Text("koku")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(.ink)
            Spacer()
            Menu {
                Picker("Period", selection: $period.animation(.snappy)) {
                    ForEach(Period.allCases) { Text($0.menuTitle).tag($0) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(period.menuTitle)
                    Image(systemName: "chevron.down").font(.caption2.weight(.heavy))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.surface2, in: .capsule)
                .contentTransition(.interpolate)
            }
            .accessibilityLabel("Period, \(period.phrase)")
        }
    }

    private func hero(total: Int, comparison: PeriodComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spent \(period.phrase)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.ink2)
            AmountText(amount: total, size: 60)
                .animation(.snappy, value: total)
            if let change = comparison.change {
                ChangePill(change: change, comparedWith: "same time \(period.previousPhrase)")
            }
        }
    }

    @ViewBuilder
    private func budgetCard(calculator: PeriodCalculator) -> some View {
        let month = calculator.range(of: .month)
        let monthName = month.lowerBound.formatted(.dateTime.month(.wide))
        if monthlyBudget > 0 {
            let spent = expenses.filter { month.contains($0.date) }.reduce(0) { $0 + $1.amount }
            let pace = BudgetPace(budget: monthlyBudget, spent: spent, month: month)
            Button { isEditingBudget = true } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("\(monthName) budget")
                        Spacer()
                        Text(monthlyBudget.inr).monospacedDigit()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.ink2)

                    ProgressBar(value: pace.progress, tint: pace.isOver ? .warning : highlight.fill)

                    HStack(alignment: .firstTextBaseline) {
                        Text(pace.isOver ? "\((-pace.remaining).inr) over" : "\(pace.remaining.inr) left")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(pace.isOver ? Color.warning : Color.ink)
                            .contentTransition(.numericText(value: Double(pace.remaining)))
                        Spacer()
                        if !pace.isOver, pace.daysLeft > 0 {
                            Text("≈ \(pace.perDay.inr)/day for \(pace.daysLeft.counted("day"))")
                                .font(.footnote)
                                .foregroundStyle(.ink2)
                        }
                    }
                    .monospacedDigit()
                }
                .card()
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Change the monthly budget")
        } else {
            Button { isEditingBudget = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.onHighlight)
                        .frame(width: 42, height: 42)
                        .background(highlight.fill, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set a monthly budget")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.ink)
                        Text("See what's safe to spend each day")
                            .font(.footnote)
                            .foregroundStyle(.ink2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.ink3)
                }
                .card(padding: 16)
            }
            .buttonStyle(.pressable)
        }
    }

    private func categories(_ summary: SpendingSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Where it went", actionTitle: "Insights") { openTab(.insights) }
            VStack(spacing: 18) {
                ForEach(summary.categoryTotals.prefix(3), id: \.category.id) { item in
                    HStack(spacing: 12) {
                        EmojiTile(emoji: item.category.emoji)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.category.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.ink)
                                Spacer()
                                Text(item.amount.inr)
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.ink)
                            }
                            HStack(spacing: 10) {
                                ProgressBar(value: summary.share(of: item), tint: .ink, height: 4)
                                Text(summary.share(of: item).formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(.ink2)
                                    .frame(minWidth: 34, alignment: .trailing)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }

    private func recent(_ summary: SpendingSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent", actionTitle: "See all") { openTab(.activity) }
            VStack(spacing: 0) {
                ForEach(Array(summary.recent.enumerated()), id: \.element.id) { index, expense in
                    if index > 0 { Divider().overlay(Color.hairline).padding(.leading, 54) }
                    Button { form = .edit(expense) } label: {
                        ExpenseRow(expense: expense, showsDay: true)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .card(padding: 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🪴").font(.system(size: 44))
            Text("Nothing spent \(period.phrase)")
                .font(.headline)
                .foregroundStyle(.ink)
            Text("Tap + to log an expense, or double-tap the back of your iPhone.")
                .font(.subheadline)
                .foregroundStyle(.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .card()
    }
}

/// Seven bars, today's in the highlight colour with its amount above it.
private struct LastDaysChart: View {
    let buckets: [PeriodInsights.Bucket]

    @Environment(\.highlight) private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let peak = max(buckets.map(\.amount).max() ?? 0, 1)
        let average = buckets.reduce(0) { $0 + $1.amount } / max(buckets.count, 1)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 days")
                    .font(.headline)
                    .foregroundStyle(.ink)
                Spacer()
                Text("avg \(average.inr)/day")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.ink2)
            }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                    let isToday = index == buckets.count - 1
                    VStack(spacing: 8) {
                        if isToday, bucket.amount > 0 {
                            Text(bucket.amount.inr)
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.canvas)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.ink, in: .capsule)
                                .fixedSize()
                        }
                        Capsule()
                            .fill(isToday ? highlight.fill : Color.chartBar)
                            .frame(width: 18, height: max(8, 96 * CGFloat(bucket.amount) / CGFloat(peak)))
                            .scaleEffect(y: grown ? 1 : 0.05, anchor: .bottom)
                            .animation(.spring(duration: 0.7, bounce: 0.2).delay(Double(index) * 0.04), value: grown)
                        Text(bucket.start.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? Color.ink : Color.ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(bucket.start.formatted(.dateTime.weekday(.wide))), \(bucket.amount.inr)")
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
        .card()
        .onAppear {
            if reduceMotion { grown = true } else { withAnimation { grown = true } }
        }
    }
}
