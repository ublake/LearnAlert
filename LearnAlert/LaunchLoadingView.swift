import SwiftUI
import SwiftData
import UIKit

/// Paint the saved appearance before opening the library, without prolonging launch.
struct AppLibraryLoader<Content: View>: View {
    let content: (SharedDatabase, URL?) -> Content
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var database: SharedDatabase?
    @State private var startupURL: URL?

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        Group {
            if let database {
                content(database, startupURL)
            } else {
                LaunchLoadingView(appearanceMode: appearanceMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
        // The loading view, app, onboarding and sheets share one appearance owner.
        .preferredColorScheme(preferredColorScheme)
        .onAppear { syncAppearance() }
        .onChange(of: appearanceMode) { _, _ in syncAppearance() }
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

    private func syncAppearance() {
        UserDefaults(suiteName: "group.com.learnalert.shared")?.set(appearanceMode, forKey: "appearanceMode")
    }
}

/// UIKit resolves named colors from the attached window's traits before drawing.
/// Avoid treating SwiftUI's initial, not-yet-attached light environment as System.
private struct LaunchLoadingView: UIViewRepresentable {
    let appearanceMode: String

    private var interfaceStyle: UIUserInterfaceStyle {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: .unspecified
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.overrideUserInterfaceStyle = interfaceStyle
        view.backgroundColor = UIColor(named: "LaunchBackground") ?? .systemBackground
        view.isAccessibilityElement = true
        view.accessibilityLabel = String(localized: "LearnAlert is loading")

        let logo = UIImageView(image: UIImage(named: "LearnAlertLogo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.layer.shadowColor = UIColor.black.cgColor
        logo.layer.shadowOpacity = 0.20
        logo.layer.shadowRadius = 10
        logo.layer.shadowOffset = CGSize(width: 0, height: 5)

        let title = UILabel()
        title.text = "LearnAlert"
        title.font = .boldSystemFont(ofSize: 36)
        title.textColor = UIColor(named: "LaunchWordmark") ?? .label
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.5

        let stack = UIStackView(arrangedSubviews: [logo, title])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 100),
            logo.heightAnchor.constraint(equalToConstant: 100),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.overrideUserInterfaceStyle = interfaceStyle
    }
}
