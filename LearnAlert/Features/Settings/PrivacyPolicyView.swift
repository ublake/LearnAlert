import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        SafariView(url: URL(string: "https://learnalertapp.com/privacy-policy")!)
            .ignoresSafeArea()
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
    }
}
