import SwiftUI
import SwiftData

/// Paint the saved appearance before opening the library, without prolonging launch.
struct AppLibraryLoader<Content: View>: View {
    let content: (SharedDatabase, URL?) -> Content
    @State private var database: SharedDatabase?
    @State private var startupURL: URL?

    var body: some View {
        Group {
            if let database {
                content(database, startupURL)
            } else {
                LaunchLoadingView()
            }
        }
        .onOpenURL { startupURL = $0 }
        .task {
            guard database == nil else { return }
            // Give the appearance-aware first frame a chance to reach the screen
            // before synchronous SwiftData initialization. No minimum splash time.
            do { try await Task.sleep(for: .milliseconds(16)) }
            catch { return }
            guard !Task.isCancelled else { return }
            database = SharedDatabase.shared
        }
    }
}

private struct LaunchLoadingView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Environment(\.colorScheme) private var systemColorScheme

    private var colorScheme: ColorScheme {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: systemColorScheme
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .light ? Color(red: 0.969, green: 0.977, blue: 0.986) : .black)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                LearnAlertLogoMark(size: 100)
                    .shadow(color: .black.opacity(colorScheme == .light ? 0.20 : 0), radius: 10, x: 0, y: 5)
                Text("LearnAlert")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(colorScheme == .light ? .black : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LearnAlert is loading")
    }
}
