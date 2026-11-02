import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        SafariView(url: URL(string: "https://learnalertapp.com/terms")!)
            .ignoresSafeArea()
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
    }
}
