import SwiftData
import SwiftUI

/// The app's tabs, plus the theme, the shared toast banner, and links from the widgets and the Log Expense control.
struct RootView: View {
    enum AppTab: String { case home, activity, insights, settings }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = RootView.initialTab
    @State private var toasts = ToastCenter()
    /// Goes up by one each time something asks for Add Expense.
    @State private var addRequest = 0
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.highlight) private var highlight = Highlight.mint
    @AppStorage(SettingsKey.monthlyBudget) private var monthlyBudget = 0
    private let router = KokuRouter.shared

    var body: some View {
        #if DEBUG
        // For checking the widgets' look: launch with `-widgetGallery YES`.
        if UserDefaults.standard.bool(forKey: "widgetGallery") {
            WidgetGalleryView().kokuTheme()
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView(addRequest: addRequest) { selection = $0 }
            }
            Tab("Activity", systemImage: "list.bullet.rectangle.portrait", value: .activity) {
                ActivityView()
            }
            Tab("Insights", systemImage: "chart.bar.xaxis", value: .insights) {
                InsightsView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(toasts)
        .kokuTheme()
        .onAppear {
            WindowTheme.apply(appearance, highlight: highlight, animated: false)
            openPendingLink()
        }
        .onChange(of: appearance) { WindowTheme.apply(appearance, highlight: highlight, animated: true) }
        .onChange(of: highlight) {
            WindowTheme.apply(appearance, highlight: highlight, animated: false)
            WidgetSync.refresh(context: context)
        }
        .onChange(of: monthlyBudget) { WidgetSync.refresh(context: context) }
        .onChange(of: scenePhase) { if scenePhase == .active { WidgetSync.refresh(context: context) } }
        .task { WidgetSync.refresh(context: context) }
        .onOpenURL { url in
            if let link = KokuLink(url: url) { open(link) }
        }
        .onChange(of: router.pending) { openPendingLink() }
    }

    private func open(_ link: KokuLink) {
        switch link {
        case .home: selection = .home
        case .activity: selection = .activity
        case .insights: selection = .insights
        case .add:
            selection = .home
            addRequest += 1
        }
    }

    /// A control asked for a screen before (or while) the app opened.
    private func openPendingLink() {
        guard let link = router.pending else { return }
        router.pending = nil
        open(link)
    }

    private static var initialTab: AppTab {
        #if DEBUG
        // For screenshots: launch with `-startTab insights`.
        if let name = UserDefaults.standard.string(forKey: "startTab"), let tab = AppTab(rawValue: name) { return tab }
        #endif
        return .home
    }
}
