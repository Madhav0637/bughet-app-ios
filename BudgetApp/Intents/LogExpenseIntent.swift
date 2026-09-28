import AppIntents
import SwiftData

/// The action behind Back Tap. Parameters are left empty in the Shortcut,
/// so the system asks for each one in declaration order, then saves silently.
struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense"
    static let description = IntentDescription("Quickly record an expense.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    // iOS draws text prompts in its standard style; the title is the hint shown inside the box.
    @Parameter(title: "On what?", requestValueDialog: "On what?")
    var merchant: String

    @Parameter(title: "Amount", requestValueDialog: "Amount (₹)")
    var amount: Int

    @Parameter(title: "Category", requestValueDialog: "Category")
    var category: CategoryEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = AppDatabase.shared.mainContext
        guard let category = try CategoryService(context: context).category(withID: category.id) else {
            throw ExpenseError.categoryNotFound
        }
        let alert = try BudgetService(context: context).alert {
            try ExpenseService(context: context).add(merchant: merchant, amount: amount, category: category)
        }
        // The save already refreshed the widgets; doing it again here is a no-op unless that was missed.
        WidgetSync.refresh(context: context)
        // Still silent unless this expense takes the month past 80% or 100% of the budget.
        if let alert { await BudgetNotifier.post(alert) }
        return .result()
    }
}
