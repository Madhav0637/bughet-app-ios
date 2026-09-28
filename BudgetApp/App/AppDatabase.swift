import Foundation
import SwiftData

/// The single on-device store, shared by the app's screens and the Log Expense intent.
enum AppDatabase {
    static let shared: ModelContainer = {
        do {
            #if DEBUG
            // For screenshots and UI tests: launch with `-demoData` to use a throwaway store full of sample spending.
            if ProcessInfo.processInfo.arguments.contains("-demoData") {
                let container = try ModelContainer(for: Expense.self, Category.self,
                                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                try DemoData.seed(into: container.mainContext)
                WidgetSync.observeSaves(of: container)
                return container
            }
            #endif
            let container = try ModelContainer(for: Expense.self, Category.self)
            // Seeding here (not in the UI) means the Shortcut works even if the app was never opened.
            try CategoryService(context: container.mainContext).seedDefaultsIfNeeded()
            // Widgets follow every save, including ones made by the Log Expense intent.
            WidgetSync.observeSaves(of: container)
            return container
        } catch {
            fatalError("Could not open the database: \(error)")
        }
    }()
}
