import AppIntents
import Foundation
import Observation

/// Places in the app that widgets and controls can open, as `koku://home`, `koku://add` and so on.
enum KokuLink: String, AppEnum {
    case home, activity, insights, add

    static let scheme = "koku"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    static let caseDisplayRepresentations: [KokuLink: DisplayRepresentation] = [
        .home: "Home",
        .activity: "Activity",
        .insights: "Insights",
        .add: "Add Expense",
    ]

    var url: URL { URL(string: "\(Self.scheme)://\(rawValue)")! }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host(), let link = KokuLink(rawValue: host) else { return nil }
        self = link
    }
}

/// Where the app should go next. Set when a control opens the app; the root view reads it and switches screen.
@MainActor
@Observable
final class KokuRouter {
    static let shared = KokuRouter()

    var pending: KokuLink?
}

/// Opens Koku on a chosen screen. Used by the Log Expense control, which can't open custom URLs itself.
struct OpenKokuIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Koku"
    static let description = IntentDescription("Opens Koku on Home, Activity, Insights or Add Expense.")
    static let openAppWhenRun = true

    @Parameter(title: "Screen", default: .add)
    var screen: KokuLink

    init() {}

    init(screen: KokuLink) {
        self.screen = screen
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        KokuRouter.shared.pending = screen
        return .result()
    }
}
