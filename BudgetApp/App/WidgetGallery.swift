#if DEBUG
import SwiftData
import SwiftUI
import WidgetKit

/// Every widget size on wallpaper-like backdrops, for checking the widgets' look without adding them by hand.
/// Launch with `-widgetGallery YES` (add `-demoData` for sample spending). The Lock Screen tiles are drawn in white,
/// as iOS draws them over a dark wallpaper.
struct WidgetGalleryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @State private var snapshot = WidgetSnapshot.sample()

    var body: some View {
        let now = Date.now
        var noBudget = snapshot
        noBudget.monthlyBudget = 0

        return ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    TodayInlineView(snapshot: snapshot, date: now)
                        .font(.system(size: 15, weight: .semibold))
                    Text("9:41")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .padding(.bottom, 4)
                    HStack(spacing: 10) {
                        TodayCircularView(snapshot: snapshot, date: now)
                            .frame(width: 72, height: 72)
                        TodayRectangularView(snapshot: snapshot, date: now)
                            .frame(width: 160, height: 72)
                        TodayCircularView(snapshot: noBudget, date: now)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(.white.opacity(0.16)))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(lockWallpaper, in: .rect(cornerRadius: 32, style: .continuous))

                ForEach([colorScheme], id: \.self) { scheme in
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            homeTile(TodaySmallView(snapshot: snapshot, date: now), width: 162)
                            homeTile(TodaySmallView(snapshot: noBudget, date: now), width: 162)
                        }
                        homeTile(TodayMediumView(snapshot: snapshot, date: now), width: 338)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(homeWallpaper(scheme), in: .rect(cornerRadius: 32, style: .continuous))
                    .environment(\.colorScheme, scheme)
                }
            }
            .padding(16)
        }
        .background(Color.canvas)
        .onAppear { WindowTheme.apply(appearance, highlight: snapshot.highlightColour, animated: false) }
        .task {
            // Real numbers when something's been spent today (e.g. with -demoData); otherwise the made-up sample.
            if let real = try? WidgetSync.makeSnapshot(context: context), real.spent(on: .now) > 0 { snapshot = real }
        }
    }

    private func homeTile(_ content: some View, width: CGFloat) -> some View {
        content
            .padding(16)
            .frame(width: width, height: 162)
            .background(TodayWidgetBackground(highlight: snapshot.highlightColour))
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var lockWallpaper: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x1D2B53), Color(hex: 0x3B2A5E), Color(hex: 0x0E1A2B)],
                       startPoint: .top, endPoint: .bottom)
    }

    private func homeWallpaper(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [Color(hex: 0x1B1B2F), Color(hex: 0x0B0B0C)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: 0xC9D6FF), Color(hex: 0xE2E2E2)], startPoint: .top, endPoint: .bottom)
    }
}
#endif
