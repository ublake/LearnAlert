import SwiftUI
import SwiftData
import AuthenticationServices
import OSLog

struct CommunityAvatar: Codable, Equatable {
    var hair = 0
    var eyes = 0
    var mouth = 0
    var skinTone = 3

    static let skinTones: [Color] = [
        Color(red: 1, green: 0.95, blue: 0.90),
        Color(red: 1, green: 0.91, blue: 0.83),
        Color(red: 1, green: 0.85, blue: 0.73),
        Color(red: 1, green: 0.79, blue: 0.64),
        Color(red: 0.79, green: 0.57, blue: 0.41),
        Color(red: 0.55, green: 0.35, blue: 0.25),
        Color(red: 0.31, green: 0.20, blue: 0.15)
    ]

    init(hair: Int = 0, eyes: Int = 0, mouth: Int = 0, skinTone: Int = 3) {
        self.hair = hair; self.eyes = eyes; self.mouth = mouth; self.skinTone = skinTone
    }

    private enum CodingKeys: String, CodingKey { case hair, eyes, mouth, skinTone }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hair = try values.decode(Int.self, forKey: .hair)
        eyes = try values.decode(Int.self, forKey: .eyes)
        mouth = try values.decode(Int.self, forKey: .mouth)
        skinTone = try values.decodeIfPresent(Int.self, forKey: .skinTone) ?? 3
    }

    static let hairNames = ["Bedhead", "Noodle", "Sprout", "Side swoop", "Tiny crown", "Bald-ish"]
    static let eyeNames = ["Wide awake", "Sleepy", "Side-eye", "Tiny dots", "Wink", "Dizzy"]
    static let mouthNames = ["Big grin", "Oops", "Smirk", "Tiny fangs", "Mustache", "Bubblegum"]
}

struct CommunityProfile: Codable, Equatable {
    var handle: String
    var avatar: CommunityAvatar
    var isComplete: Bool
}

/// A small, deliberately silly character, rendered locally from three shared choices.
struct CommunityAvatarView: View {
    var avatar = CommunityAvatar()

    var body: some View {
        Canvas { context, size in
            var g = context
            g.scaleBy(x: size.width / 100, y: size.height / 100)
            let ink = Color(red: 0.18, green: 0.21, blue: 0.27)
            let skin = CommunityAvatar.skinTones[min(max(avatar.skinTone, 0), CommunityAvatar.skinTones.count - 1)]
            let hair = Color(red: 0.33, green: 0.25, blue: 0.25)
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
            }
            func line(_ points: [CGPoint], color: Color = Color(red: 0.18, green: 0.21, blue: 0.27), width: CGFloat = 2.5) {
                var p = Path(); p.addLines(points)
                g.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func curve(_ start: CGPoint, _ end: CGPoint, _ c1: CGPoint, _ c2: CGPoint, color: Color = Color(red: 0.18, green: 0.21, blue: 0.27), width: CGFloat = 2.5) {
                var p = Path(); p.move(to: start); p.addCurve(to: end, control1: c1, control2: c2)
                g.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            g.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 24))
            g.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(LearnAlertStyle.appAccent.opacity(0.30)))
            oval(19, 78, 62, 43, Color(red: 0.44, green: 0.66, blue: 0.83))
            g.fill(Path(roundedRect: CGRect(x: 42, y: 70, width: 16, height: 16), cornerRadius: 5), with: .color(skin))
            oval(19, 42, 15, 19, skin); oval(66, 42, 15, 19, skin)
            oval(27, 23, 46, 55, skin)
            oval(31, 58, 8, 4, Color(red: 0.94, green: 0.55, blue: 0.51).opacity(0.55))
            oval(62, 58, 8, 4, Color(red: 0.94, green: 0.55, blue: 0.51).opacity(0.55))
            switch avatar.hair {
            case 0:
                var p = Path(); p.addLines([CGPoint(x: 27, y: 39), CGPoint(x: 23, y: 22), CGPoint(x: 35, y: 26), CGPoint(x: 34, y: 13), CGPoint(x: 46, y: 23), CGPoint(x: 54, y: 10), CGPoint(x: 58, y: 24), CGPoint(x: 75, y: 20), CGPoint(x: 70, y: 39), CGPoint(x: 61, y: 30), CGPoint(x: 40, y: 32)]); p.closeSubpath()
                g.fill(p, with: .color(hair))
            case 1:
                for x in stride(from: CGFloat(28), through: 68, by: 10) { oval(x, 21, 13, 15, hair) }
                curve(CGPoint(x: 44, y: 24), CGPoint(x: 52, y: 13), CGPoint(x: 31, y: 7), CGPoint(x: 64, y: 3), color: hair, width: 4)
            case 2:
                oval(26, 22, 49, 14, hair)
                curve(CGPoint(x: 50, y: 25), CGPoint(x: 50, y: 11), CGPoint(x: 46, y: 18), CGPoint(x: 54, y: 15), color: hair)
                oval(37, 10, 15, 8, Color(red: 0.37, green: 0.63, blue: 0.46)); oval(49, 7, 15, 8, Color(red: 0.48, green: 0.73, blue: 0.53))
            case 3:
                var p = Path(); p.move(to: CGPoint(x: 25, y: 40)); p.addCurve(to: CGPoint(x: 75, y: 36), control1: CGPoint(x: 23, y: 6), control2: CGPoint(x: 78, y: 9)); p.addCurve(to: CGPoint(x: 43, y: 25), control1: CGPoint(x: 57, y: 22), control2: CGPoint(x: 49, y: 42)); p.closeSubpath(); g.fill(p, with: .color(hair))
            case 4:
                oval(27, 25, 47, 10, hair)
                var p = Path(); p.addLines([CGPoint(x: 37, y: 25), CGPoint(x: 34, y: 11), CGPoint(x: 45, y: 17), CGPoint(x: 51, y: 7), CGPoint(x: 58, y: 17), CGPoint(x: 68, y: 11), CGPoint(x: 64, y: 25)]); p.closeSubpath(); g.fill(p, with: .color(Color(red: 0.99, green: 0.78, blue: 0.38)))
            default:
                for x in [CGFloat(45), 51, 57] { curve(CGPoint(x: x, y: 26), CGPoint(x: x - 5, y: 17), CGPoint(x: x + 2, y: 22), CGPoint(x: x - 3, y: 19), color: hair, width: 2) }
            }
            switch avatar.eyes {
            case 1:
                line([CGPoint(x: 34, y: 47), CGPoint(x: 43, y: 48)]); line([CGPoint(x: 57, y: 48), CGPoint(x: 66, y: 47)])
            case 2:
                oval(32, 41, 14, 13, .white); oval(55, 41, 14, 13, .white)
                oval(39, 43, 5, 7, ink); oval(62, 43, 5, 7, ink)
            case 3:
                oval(36, 44, 4, 5, ink); oval(61, 44, 4, 5, ink)
            case 4:
                oval(33, 40, 13, 15, .white); oval(39, 44, 5, 7, ink)
                line([CGPoint(x: 57, y: 47), CGPoint(x: 66, y: 46)])
            case 5:
                for x in [CGFloat(35), 58] { line([CGPoint(x: x, y: 42), CGPoint(x: x + 8, y: 51)]); line([CGPoint(x: x + 8, y: 42), CGPoint(x: x, y: 51)]) }
            default:
                oval(32, 39, 15, 17, .white); oval(55, 39, 15, 17, .white)
                oval(38, 44, 5, 7, ink); oval(59, 44, 5, 7, ink)
            }
            curve(CGPoint(x: 48, y: 53), CGPoint(x: 52, y: 57), CGPoint(x: 45, y: 58), CGPoint(x: 49, y: 58), color: Color(red: 0.80, green: 0.51, blue: 0.40), width: 1.5)
            switch avatar.mouth {
            case 1: oval(46, 62, 9, 10, ink)
            case 2: curve(CGPoint(x: 43, y: 65), CGPoint(x: 62, y: 62), CGPoint(x: 48, y: 70), CGPoint(x: 58, y: 68))
            case 3:
                oval(39, 61, 23, 10, ink)
                for x in [CGFloat(43), 55] { var p = Path(); p.addLines([CGPoint(x: x, y: 61), CGPoint(x: x + 4, y: 61), CGPoint(x: x + 2, y: 67)]); p.closeSubpath(); g.fill(p, with: .color(.white)) }
            case 4:
                oval(35, 59, 17, 7, hair); oval(49, 59, 17, 7, hair)
                curve(CGPoint(x: 43, y: 68), CGPoint(x: 59, y: 68), CGPoint(x: 47, y: 72), CGPoint(x: 55, y: 72), width: 2)
            case 5:
                oval(43, 62, 28, 25, Color(red: 0.96, green: 0.57, blue: 0.70)); oval(49, 66, 7, 4, .white.opacity(0.55))
            default:
                oval(40, 61, 22, 13, ink)
                g.fill(Path(roundedRect: CGRect(x: 43, y: 62, width: 16, height: 4), cornerRadius: 1), with: .color(.white))
                oval(46, 69, 11, 4, Color(red: 0.93, green: 0.46, blue: 0.54))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct CommunitySignInButton: View {
    let onSignedIn: () -> Void
    @ObservedObject private var session = CommunitySession.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            session.errorMessage = nil
            nonce = CommunitySession.makeNonce()
            request.nonce = CommunitySession.hashedNonce(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                    session.errorMessage = "Apple did not provide a sign-in token. Please try again."
                    return
                }
                let signInNonce = nonce
                Task {
                    if await session.signIn(identityToken: token, nonce: signInNonce, givenName: nil) { onSignedIn() }
                }
            case .failure(let error):
                handleFailure(error)
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 48)
        .disabled(session.isSigningIn)
    }

    private func handleFailure(_ error: Error) {
        guard (error as? ASAuthorizationError)?.code != .canceled else { return }
        let detail = error as NSError
        let underlying = detail.userInfo[NSUnderlyingErrorKey] as? NSError
        // Log error identifiers only; never Apple credentials, identity tokens, or nonces.
        Logger(subsystem: "com.learnalert.app", category: "AppleSignIn").error(
            "Apple authorization failed: \(detail.domain, privacy: .public) code \(detail.code, privacy: .public); underlying \(underlying?.domain ?? "none", privacy: .public) code \(underlying?.code ?? 0, privacy: .public)"
        )
        #if targetEnvironment(simulator)
        session.errorMessage = "Apple sign-in couldn’t finish in the simulator. If retrying fails, try the app on your iPhone."
        #else
        session.errorMessage = "Apple sign-in could not finish. Please try again."
        #endif
    }
}

struct SettingsProfileCard: View {
    @ObservedObject private var session = CommunitySession.shared
    @State private var showingProfile = false

    var body: some View {
        VStack(spacing: 12) {
            if session.isSignedIn {
                Button { showingProfile = true } label: {
                    HStack(spacing: 16) {
                        CommunityAvatarView(avatar: session.profile.avatar).frame(width: 68, height: 68)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.needsProfileSetup ? "Finish your profile" : session.handle).font(.headline)
                            Text("Your community profile").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(LearnAlertStyle.textSecondary)
                    }
                    .foregroundStyle(LearnAlertStyle.textPrimary)
                    .padding(16)
                    .appCardSurface(cornerRadius: 20)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CommunityAvatarView().frame(width: 52, height: 52)
                        Text("Your profile").font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                    }
                    CommunitySignInButton { showingProfile = session.needsProfileSetup }
                    if let error = session.errorMessage { Text(error).font(.caption).foregroundStyle(LearnAlertStyle.destructiveRed) }
                }
                .padding(16)
                .appCardSurface(cornerRadius: 20)
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingProfile) { CommunityProfileSheet() }
        .task(id: session.token) { await session.refreshProfile() }
    }
}

struct CommunityProfileSheet: View {
    var saveTitle = "Save profile"
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var libraryDecks: [Deck]
    @ObservedObject private var session = CommunitySession.shared
    @State private var username = ""
    @State private var avatar = CommunityAvatar()
    @State private var loadedDraft = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var showingMyDecks = false
    @State private var deletingAccount = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CommunityAvatarView(avatar: avatar)
                        .frame(width: 184, height: 184)
                        .rotationEffect(.degrees(avatar.hair.isMultiple(of: 2) ? -3 : 3))
                        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.62), value: avatar)
                        .padding(.top, 8)
                    if session.isSignedIn {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username").font(.subheadline.weight(.medium)).foregroundStyle(LearnAlertStyle.textSecondary)
                            HStack(spacing: 4) {
                                Text("@").foregroundStyle(LearnAlertStyle.textSecondary)
                                TextField("your_username", text: $username)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .disabled(session.profile.isComplete || isSaving || deletingAccount)
                                    .foregroundStyle(session.profile.isComplete ? LearnAlertStyle.textSecondary : LearnAlertStyle.textPrimary)
                                if session.profile.isComplete {
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                                        .accessibilityLabel("Username is permanent")
                                }
                            }
                            .font(.body.weight(.medium)).padding(16).background(LearnAlertStyle.insetSurface, in: RoundedRectangle(cornerRadius: 14))
                            Text(session.profile.isComplete ? "Your username is permanent." : "3–24 letters, numbers or underscores. Permanent once saved.").font(.caption).foregroundStyle(LearnAlertStyle.textSecondary)
                        }
                        VStack(spacing: 0) {
                            skinTonePicker
                            Divider().padding(.horizontal, 16)
                            partPicker("Hair", selection: $avatar.hair, names: CommunityAvatar.hairNames)
                            Divider().padding(.horizontal, 16)
                            partPicker("Eyes", selection: $avatar.eyes, names: CommunityAvatar.eyeNames)
                            Divider().padding(.horizontal, 16)
                            partPicker("Mouth", selection: $avatar.mouth, names: CommunityAvatar.mouthNames)
                        }
                        .appCardSurface(cornerRadius: 20)
                        Button { Task { await save() } } label: {
                            HStack { if isSaving { ProgressView() }; Text(saveTitle) }.frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent).tint(LearnAlertStyle.appAccent).foregroundStyle(LearnAlertStyle.appAccentInk)
                        .disabled(isSaving || username.trimmingCharacters(in: .whitespaces).count < 3)
                    } else {
                        Text("Make yourself at home.").font(.title2.weight(.semibold))
                        CommunitySignInButton {
                            if session.profile.isComplete { onSave?(); dismiss() }
                            else { loadDraft() }
                        }
                        if session.isSigningIn { ProgressView("Signing in…") }
                    }
                    if let error = message ?? session.errorMessage { Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed) }
                }
                .foregroundStyle(LearnAlertStyle.textPrimary)
                .padding(24)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea())
            .navigationTitle("Your profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(isSaving || deletingAccount) }
                ToolbarItem(placement: .topBarTrailing) {
                    if session.isSignedIn {
                        Menu {
                            Button("My shared decks", systemImage: "rectangle.stack") { showingMyDecks = true }
                            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") { session.signOut(); dismiss() }
                            Button("Delete community account", role: .destructive) { confirmingDelete = true }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Profile options").disabled(isSaving || deletingAccount)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || deletingAccount)
            .sheet(isPresented: $showingMyDecks) { MySharedDecksSheet(libraryDecks: libraryDecks) }
            .task {
                if !loadedDraft { await session.refreshProfile(); loadDraft() }
            }
            .confirmationDialog("Delete your community account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete community account", role: .destructive) { Task { await deleteAccount() } }
            } message: { Text("Removes your profile and public decks. Your personal library stays on this device.") }
        }
    }

    private func loadDraft() {
        username = session.handle.hasPrefix("@") ? String(session.handle.dropFirst()) : session.handle
        avatar = session.profile.avatar
        loadedDraft = true
    }

    private var skinTonePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Skin tone").font(.subheadline.weight(.medium)).accessibilityHidden(true)
            GeometryReader { proxy in
                let travel = max(proxy.size.width - 28, 1)
                let selection = min(max(avatar.skinTone, 0), 6)
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: CommunityAvatar.skinTones, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 18).padding(.horizontal, 14)
                    Circle().fill(CommunityAvatar.skinTones[selection])
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.24), radius: 3, y: 1)
                        .frame(width: 28, height: 28)
                        .offset(x: travel * CGFloat(selection) / 6)
                }
                .frame(height: 44).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let selected = min(max(Int(((value.location.x - 14) / travel * 6).rounded()), 0), 6)
                    if avatar.skinTone != selected {
                        avatar.skinTone = selected
                        HapticFeedback.impact(.light)
                    }
                })
            }
            .frame(height: 44)
            .accessibilityElement(children: .ignore).accessibilityLabel("Skin tone")
            .accessibilityValue("Shade \(min(max(avatar.skinTone, 0), 6) + 1) of 7")
            .accessibilityAdjustableAction { direction in
                guard !isSaving, !deletingAccount else { return }
                switch direction {
                case .increment: avatar.skinTone = min(avatar.skinTone + 1, 6)
                case .decrement: avatar.skinTone = max(avatar.skinTone - 1, 0)
                @unknown default: break
                }
            }
            .allowsHitTesting(!isSaving && !deletingAccount)
            .disabled(isSaving || deletingAccount)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 4)
    }

    private func partPicker(_ title: String, selection: Binding<Int>, names: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.medium)).frame(width: 56, alignment: .leading)
            Button { change(selection, by: -1, count: names.count) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }.accessibilityLabel("Previous \(title.lowercased())")
            Text(names[min(max(selection.wrappedValue, 0), names.count - 1)]).font(.subheadline).frame(maxWidth: .infinity)
            Button { change(selection, by: 1, count: names.count) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }.accessibilityLabel("Next \(title.lowercased())")
        }
        .tint(LearnAlertStyle.appAccentForeground)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .disabled(isSaving || deletingAccount)
    }

    private func change(_ selection: Binding<Int>, by offset: Int, count: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.7)) {
            selection.wrappedValue = (selection.wrappedValue + offset + count) % count
        }
        HapticFeedback.impact(.light)
    }

    @MainActor private func save() async {
        isSaving = true; message = nil
        defer { isSaving = false }
        do {
            try await session.saveProfile(username: username, avatar: avatar)
            onSave?(); dismiss()
        } catch { message = error.localizedDescription }
    }

    @MainActor private func deleteAccount() async {
        guard let token = session.token else { return }
        deletingAccount = true; message = nil
        defer { deletingAccount = false }
        do {
            let mine = try await CommunityAPI().myDecks(token: token)
            try await CommunityAPI().deleteAccount(token: token)
            let ids = Set(mine.decks.map(\.id))
            for deck in libraryDecks where deck.publishedCommunityID.map({ ids.contains($0) }) == true { deck.publishedCommunityID = nil }
            try? context.save()
            session.signOut(); dismiss()
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); message = error.localizedDescription }
    }
}
