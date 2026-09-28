import SwiftUI
import UIKit

// Koku's look: a quiet neutral canvas and one highlight colour, used only for the thing that matters on each
// screen (the add button, progress, the selected item, the peak of a chart). Emoji supply the rest of the colour.

/// Light, dark, or follow the iPhone. Chosen in Settings.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: Applying the theme

extension EnvironmentValues {
    @Entry var highlight: Highlight = .mint
}

/// Applies the chosen highlight colour and the rounded type to a view tree: the app, and each sheet.
struct KokuTheme: ViewModifier {
    @AppStorage(SettingsKey.highlight) private var highlight = Highlight.mint

    func body(content: Content) -> some View {
        content
            .environment(\.highlight, highlight)
            .tint(highlight.text)
            .fontDesign(.rounded)
    }
}

extension View {
    func kokuTheme() -> some View { modifier(KokuTheme()) }

    /// Koku colours for List and Form screens. Rows also need `.listRowBackground(Color.surface)`.
    func kokuList() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.canvas)
    }
}

/// Applies Light / Dark / System to whole windows rather than to SwiftUI views, so sheets, alerts and the share
/// sheet follow the choice too, and switching back to System reliably follows the iPhone again.
enum WindowTheme {
    static func apply(_ appearance: Appearance, highlight: Highlight, animated: Bool) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            let change = {
                window.overrideUserInterfaceStyle = appearance.interfaceStyle
                window.tintColor = UIColor(highlight.text)
            }
            if animated {
                UIView.transition(with: window, duration: 0.35,
                                  options: [.transitionCrossDissolve, .allowUserInteraction], animations: change)
            } else {
                change()
            }
        }
    }

    /// Navigation titles are drawn by UIKit, so they get the rounded font here.
    static func configureNavigationBars() {
        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(34, .bold)]
        bar.titleTextAttributes = [.font: rounded(17, .semibold)]
    }
}
