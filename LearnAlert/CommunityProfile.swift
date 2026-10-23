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

    static let hairNames = ["Bedhead", "Noodle", "Sprout", "Side swoop", "Tiny crown", "Bald-ish", "Short crop", "Bob", "Space buns", "Cloud curls", "Ponytail", "Mohawk", "Braids", "Beanie", "Baseball cap", "Big bow"]
    static let eyeNames = ["Wide awake", "Sleepy", "Side-eye", "Tiny dots", "Wink", "Dizzy", "Heart eyes", "Starry", "Sunglasses", "Round glasses", "Delighted", "Curious", "Lashes", "Sparkly", "Monocle", "Focused"]
    static let mouthNames = ["Big grin", "Oops", "Smirk", "Tiny fangs", "Mustache", "Bubblegum", "Tongue out", "Whistle", "Wobbly", "Little smile", "Poker face", "Kiss", "Goatee", "One tooth", "Lopsided", "Cat smile"]
}

struct CommunityProfile: Codable, Equatable {
    var handle: String
    var avatar: CommunityAvatar
    var isComplete: Bool
    var authorID: String? = nil
    var accountStatus: String? = nil
    var restrictionMessage: String? = nil
    var hideStatsPublicly: Bool? = nil
    var profileCreatedAt: Int? = nil
    var stats: CommunityProfileStats? = nil
    var isDeveloper: Bool? = nil
    var allowAnkiUploads: Bool? = nil
}

/// Coordinated colors keep line-only features visible on every skin tone.
private struct CommunityAvatarPalette {
    let hair: Color
    let feature: Color
    let nose: Color
    let blush: Color
    let shirt: Color
    let background: Color

    init(tone: Int) {
        let index = min(max(tone, 0), 6)
        func color(_ hex: String) -> Color { Color(hex: hex) }
        hair = color(["#59413A", "#543C36", "#4D3430", "#4A332E", "#392821", "#E2B886", "#F0CEA3"][index])
        feature = color(["#343846", "#343846", "#353440", "#3B3035", "#332327", "#FFE2C6", "#FFEAD5"][index])
        nose = color(["#CF9980", "#C38C70", "#B77C5C", "#AD7051", "#875031", "#E2AB85", "#D79F79"][index])
        blush = color(["#E9A8A0", "#E7A099", "#DB9385", "#D58B78", "#C77363", "#C6836A", "#B67361"][index])
        shirt = color(["#7096BB", "#729BC0", "#739FC4", "#76A3C7", "#91B7D5", "#A2C5DC", "#ADD1E5"][index])
        background = color(["#DDEAF4", "#DCE9F3", "#DCE9F2", "#DBE8F1", "#D7E6F0", "#D1E3EF", "#C8DEED"][index])
    }
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
            let palette = CommunityAvatarPalette(tone: avatar.skinTone)
            let hair = palette.hair
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
            }
            func line(_ points: [CGPoint], color: Color? = nil, width: CGFloat = 2.5) {
                var p = Path(); p.addLines(points)
                g.stroke(p, with: .color(color ?? palette.feature), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func curve(_ start: CGPoint, _ end: CGPoint, _ c1: CGPoint, _ c2: CGPoint, color: Color? = nil, width: CGFloat = 2.5) {
                var p = Path(); p.move(to: start); p.addCurve(to: end, control1: c1, control2: c2)
                g.stroke(p, with: .color(color ?? palette.feature), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            func star(_ center: CGPoint, radius: CGFloat, color: Color) {
                var p = Path()
                for step in 0..<10 {
                    let angle = CGFloat(step) * .pi / 5 - .pi / 2
                    let r = step.isMultiple(of: 2) ? radius : radius * 0.44
                    let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                    if step == 0 { p.move(to: point) } else { p.addLine(to: point) }
                }
                p.closeSubpath(); g.fill(p, with: .color(color))
            }
            func heart(_ x: CGFloat, _ y: CGFloat) {
                var p = Path(); p.move(to: CGPoint(x: x + 7, y: y + 13))
                p.addCurve(to: CGPoint(x: x, y: y + 4), control1: CGPoint(x: x + 3, y: y + 10), control2: CGPoint(x: x - 2, y: y + 7))
                p.addCurve(to: CGPoint(x: x + 7, y: y + 3), control1: CGPoint(x: x, y: y - 1), control2: CGPoint(x: x + 5, y: y - 1))
                p.addCurve(to: CGPoint(x: x + 14, y: y + 4), control1: CGPoint(x: x + 9, y: y - 1), control2: CGPoint(x: x + 14, y: y - 1))
                p.addCurve(to: CGPoint(x: x + 7, y: y + 13), control1: CGPoint(x: x + 16, y: y + 7), control2: CGPoint(x: x + 11, y: y + 10))
                g.fill(p, with: .color(Color(hex: "#DA546B")))
            }
            g.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 24))
            g.fill(Path(CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(palette.background))
            oval(19, 78, 62, 43, palette.shirt)
            g.fill(Path(roundedRect: CGRect(x: 42, y: 70, width: 16, height: 16), cornerRadius: 5), with: .color(skin))
            oval(19, 42, 15, 19, skin); oval(66, 42, 15, 19, skin)
            oval(27, 23, 46, 55, skin)
            oval(31, 58, 8, 4, palette.blush.opacity(0.65))
            oval(62, 58, 8, 4, palette.blush.opacity(0.65))
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
            case 6:
                oval(27, 19, 46, 18, hair)
                line([CGPoint(x: 31, y: 33), CGPoint(x: 69, y: 33)], color: skin, width: 2)
            case 7:
                oval(23, 21, 54, 27, hair)
                oval(23, 36, 9, 30, hair); oval(68, 36, 9, 30, hair)
            case 8:
                oval(27, 22, 46, 14, hair)
                oval(17, 14, 23, 23, hair); oval(60, 14, 23, 23, hair)
                line([CGPoint(x: 22, y: 30), CGPoint(x: 32, y: 30)], color: palette.shirt)
                line([CGPoint(x: 67, y: 30), CGPoint(x: 77, y: 30)], color: palette.shirt)
            case 9:
                for point in [CGPoint(x: 27, y: 25), CGPoint(x: 36, y: 14), CGPoint(x: 49, y: 11), CGPoint(x: 61, y: 15), CGPoint(x: 70, y: 26)] { oval(point.x - 9, point.y - 7, 20, 22, hair) }
            case 10:
                oval(24, 24, 15, 42, hair); oval(27, 18, 46, 19, hair)
                oval(20, 27, 13, 8, palette.shirt)
            case 11:
                var p = Path(); p.addLines([CGPoint(x: 39, y: 33), CGPoint(x: 42, y: 8), CGPoint(x: 49, y: 14), CGPoint(x: 54, y: 5), CGPoint(x: 61, y: 33)]); p.closeSubpath(); g.fill(p, with: .color(hair))
            case 12:
                oval(27, 21, 46, 16, hair)
                for y in stride(from: CGFloat(35), through: 64, by: 8) { oval(23, y, 10, 12, hair); oval(67, y, 10, 12, hair) }
                oval(23, 67, 10, 5, palette.shirt); oval(67, 67, 10, 5, palette.shirt)
            case 13:
                oval(24, 13, 52, 36, palette.shirt)
                g.fill(Path(roundedRect: CGRect(x: 24, y: 28, width: 52, height: 11), cornerRadius: 4), with: .color(Color(hex: "#456384")))
                oval(43, 6, 14, 14, .white)
            case 14:
                oval(26, 17, 48, 23, Color(hex: "#456384"))
                oval(42, 31, 40, 8, palette.shirt)
                star(CGPoint(x: 47, y: 27), radius: 5, color: .white)
            case 15:
                oval(27, 22, 46, 14, hair)
                var p = Path(); p.addLines([CGPoint(x: 50, y: 22), CGPoint(x: 32, y: 9), CGPoint(x: 32, y: 28), CGPoint(x: 50, y: 22), CGPoint(x: 68, y: 9), CGPoint(x: 68, y: 28)]); p.closeSubpath(); g.fill(p, with: .color(Color(hex: "#D96B84")))
                oval(45, 17, 10, 10, Color(hex: "#F1ABC0"))
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
                oval(36, 44, 4, 5, palette.feature); oval(61, 44, 4, 5, palette.feature)
            case 4:
                oval(33, 40, 13, 15, .white); oval(39, 44, 5, 7, ink)
                line([CGPoint(x: 57, y: 47), CGPoint(x: 66, y: 46)])
            case 5:
                for x in [CGFloat(35), 58] { line([CGPoint(x: x, y: 42), CGPoint(x: x + 8, y: 51)]); line([CGPoint(x: x + 8, y: 42), CGPoint(x: x, y: 51)]) }
            case 6: heart(32, 41); heart(55, 41)
            case 7:
                for x in [CGFloat(39), 62] { oval(x - 8, 39, 16, 17, .white); star(CGPoint(x: x, y: 47), radius: 6, color: ink) }
            case 8:
                for x in [CGFloat(31), 54] {
                    g.fill(Path(roundedRect: CGRect(x: x, y: 41, width: 16, height: 12), cornerRadius: 4), with: .color(ink))
                    line([CGPoint(x: x + 3, y: 44), CGPoint(x: x + 7, y: 44)], color: .white, width: 1.5)
                }
                line([CGPoint(x: 47, y: 45), CGPoint(x: 54, y: 45)], color: ink)
            case 9:
                for x in [CGFloat(31), 54] {
                    oval(x, 39, 17, 17, .white); oval(x + 6, 44, 5, 7, ink)
                    g.stroke(Path(ellipseIn: CGRect(x: x, y: 39, width: 17, height: 17)), with: .color(ink), lineWidth: 2)
                }
                line([CGPoint(x: 48, y: 46), CGPoint(x: 54, y: 46)], color: ink, width: 2)
            case 10:
                for x in [CGFloat(34), 57] { curve(CGPoint(x: x, y: 48), CGPoint(x: x + 10, y: 48), CGPoint(x: x + 2, y: 40), CGPoint(x: x + 8, y: 40)) }
            case 11:
                oval(33, 41, 13, 15, .white); oval(55, 39, 14, 17, .white)
                oval(38, 45, 5, 7, ink); oval(60, 44, 5, 7, ink)
                curve(CGPoint(x: 54, y: 35), CGPoint(x: 68, y: 34), CGPoint(x: 58, y: 30), CGPoint(x: 64, y: 30))
            case 12:
                for x in [CGFloat(33), 56] {
                    oval(x, 41, 13, 14, .white); oval(x + 5, 45, 5, 7, ink)
                    line([CGPoint(x: x, y: 44), CGPoint(x: x - 2, y: 39)]); line([CGPoint(x: x + 4, y: 41), CGPoint(x: x + 3, y: 37)])
                }
            case 13:
                for x in [CGFloat(32), 55] { oval(x, 39, 15, 17, ink); oval(x + 3, 41, 6, 6, .white); oval(x + 9, 49, 3, 3, .white) }
            case 14:
                oval(33, 41, 13, 14, .white); oval(38, 44, 5, 7, ink)
                oval(55, 39, 17, 17, .white); oval(61, 44, 5, 7, ink)
                g.stroke(Path(ellipseIn: CGRect(x: 55, y: 39, width: 17, height: 17)), with: .color(Color(hex: "#BA873B")), lineWidth: 2.5)
                curve(CGPoint(x: 72, y: 49), CGPoint(x: 72, y: 76), CGPoint(x: 78, y: 63), CGPoint(x: 71, y: 70), color: Color(hex: "#BA873B"), width: 1)
            case 15:
                oval(35, 45, 5, 6, palette.feature); oval(60, 45, 5, 6, palette.feature)
                line([CGPoint(x: 32, y: 38), CGPoint(x: 44, y: 41)]); line([CGPoint(x: 56, y: 41), CGPoint(x: 68, y: 38)])
            default:
                oval(32, 39, 15, 17, .white); oval(55, 39, 15, 17, .white)
                oval(38, 44, 5, 7, ink); oval(59, 44, 5, 7, ink)
            }
            curve(CGPoint(x: 48, y: 53), CGPoint(x: 52, y: 57), CGPoint(x: 45, y: 58), CGPoint(x: 49, y: 58), color: palette.nose, width: 1.5)
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
            case 6:
                oval(40, 61, 22, 10, ink); oval(48, 65, 10, 12, Color(hex: "#ED8B9C"))
                line([CGPoint(x: 53, y: 68), CGPoint(x: 53, y: 72)], color: Color(hex: "#BF566A"), width: 1)
            case 7:
                oval(47, 62, 8, 8, palette.feature)
                curve(CGPoint(x: 58, y: 63), CGPoint(x: 65, y: 58), CGPoint(x: 59, y: 58), CGPoint(x: 63, y: 61), width: 1.5)
            case 8: line([CGPoint(x: 40, y: 65), CGPoint(x: 46, y: 62), CGPoint(x: 52, y: 67), CGPoint(x: 58, y: 62), CGPoint(x: 64, y: 65)], width: 2)
            case 9: curve(CGPoint(x: 42, y: 63), CGPoint(x: 60, y: 63), CGPoint(x: 46, y: 72), CGPoint(x: 56, y: 72))
            case 10: line([CGPoint(x: 42, y: 65), CGPoint(x: 60, y: 65)], width: 2)
            case 11:
                line([CGPoint(x: 47, y: 61), CGPoint(x: 54, y: 64), CGPoint(x: 47, y: 67)], color: Color(hex: "#D56B82"), width: 3)
                heart(61, 55)
            case 12:
                curve(CGPoint(x: 42, y: 63), CGPoint(x: 60, y: 63), CGPoint(x: 46, y: 69), CGPoint(x: 56, y: 69))
                var p = Path(); p.addLines([CGPoint(x: 44, y: 73), CGPoint(x: 58, y: 73), CGPoint(x: 51, y: 82)]); p.closeSubpath(); g.fill(p, with: .color(hair))
            case 13:
                oval(40, 61, 22, 13, ink)
                g.fill(Path(roundedRect: CGRect(x: 47, y: 61, width: 7, height: 6), cornerRadius: 1), with: .color(.white))
            case 14:
                curve(CGPoint(x: 42, y: 67), CGPoint(x: 62, y: 60), CGPoint(x: 52, y: 75), CGPoint(x: 64, y: 71))
                line([CGPoint(x: 61, y: 59), CGPoint(x: 64, y: 63)], width: 1.5)
            case 15:
                curve(CGPoint(x: 39, y: 64), CGPoint(x: 51, y: 64), CGPoint(x: 43, y: 71), CGPoint(x: 49, y: 70), width: 2)
                curve(CGPoint(x: 51, y: 64), CGPoint(x: 63, y: 64), CGPoint(x: 53, y: 70), CGPoint(x: 60, y: 71), width: 2)
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
                    let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                    if await session.signIn(identityToken: token, nonce: signInNonce, givenName: nil, authorizationCode: code, appleUserID: credential.user) { onSignedIn() }
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
                        if session.profile.isComplete {
                            CommunityAvatarView(avatar: session.profile.avatar).frame(width: 68, height: 68)
                        }
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
                    Text("Join the community").font(.headline).foregroundStyle(LearnAlertStyle.textPrimary)
                    Text("Sign in to create your character and share decks.").font(.subheadline).foregroundStyle(LearnAlertStyle.textSecondary)
                    CommunitySignInButton { showingProfile = session.needsProfileSetup }
                    if let error = session.errorMessage { Text(error).font(.caption).foregroundStyle(LearnAlertStyle.destructiveRed) }
                }
                .padding(16)
                .appCardSurface(cornerRadius: 20)
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingProfile) {
            if session.needsProfileSetup || session.profile.authorID == nil { CommunityProfileSheet() }
            else if let authorID = session.profile.authorID { CommunityPublicProfileView(authorID: authorID) }
        }
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
    @State private var showingDeletionSignIn = false
    @State private var showingBlockedUsers = false

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
                        .disabled(isSaving || session.isRestricted || username.trimmingCharacters(in: .whitespaces).count < 3)
                    } else {
                        Text("Make yourself at home.").font(.title2.weight(.semibold))
                        CommunitySignInButton {
                            if session.profile.isComplete { onSave?(); dismiss() }
                            else { loadDraft() }
                        }
                        if session.isSigningIn { ProgressView("Signing in…") }
                    }
                    if let error = message ?? session.profile.restrictionMessage ?? session.errorMessage { Text(error).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed) }
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
                            Button("Blocked authors", systemImage: "person.slash") { showingBlockedUsers = true }
                            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") { session.signOut(); dismiss() }
                            Button("Delete community account", role: .destructive) { confirmingDelete = true }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Profile options").disabled(isSaving || deletingAccount)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving || deletingAccount)
            .sheet(isPresented: $showingMyDecks) { MySharedDecksSheet(libraryDecks: libraryDecks) }
            .sheet(isPresented: $showingBlockedUsers) { CommunityBlockedAuthorsSheet() }
            .sheet(isPresented: $showingDeletionSignIn) {
                CommunityAccountDeletionSheet { reauthentication, userID in
                    try await deleteAccount(reauthentication: reauthentication, appleUserID: userID)
                }
            }
            .task {
                if !loadedDraft { await session.refreshProfile(); loadDraft() }
            }
            .confirmationDialog("Delete your community account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete community account", role: .destructive) { showingDeletionSignIn = true }
            } message: { Text("Removes your profile and public decks. Your personal library stays on this device.") }
        }
    }

    private func loadDraft() {
        username = session.handle.hasPrefix("@") ? String(session.handle.dropFirst()) : session.handle
        avatar = session.profile.avatar
        loadedDraft = true
    }

    private var skinTonePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skin tone").font(.subheadline.weight(.medium))
            ViewThatFits(in: .horizontal) {
                skinToneSwatches(size: 44)
                ScrollView(.horizontal) { skinToneSwatches(size: 44) }.scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .disabled(isSaving || deletingAccount)
    }

    private func skinToneSwatches(size: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(CommunityAvatar.skinTones.indices, id: \.self) { index in
                Button {
                    guard avatar.skinTone != index else { return }
                    avatar.skinTone = index
                    HapticFeedback.impact(.light)
                } label: {
                    Circle().fill(CommunityAvatar.skinTones[index])
                        .overlay { Circle().strokeBorder(LearnAlertStyle.textSecondary.opacity(0.30), lineWidth: 1) }
                        .padding(4)
                        .overlay {
                            if avatar.skinTone == index { Circle().strokeBorder(LearnAlertStyle.appAccentForeground, lineWidth: 2) }
                        }
                        .frame(width: size, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skin tone \(index + 1) of \(CommunityAvatar.skinTones.count)")
                .accessibilityAddTraits(avatar.skinTone == index ? .isSelected : [])
            }
        }
    }

    private func partPicker(_ title: String, selection: Binding<Int>, names: [String]) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.medium)).frame(width: 56, alignment: .leading)
            Button { change(selection, by: -1, count: names.count) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }.accessibilityLabel("Previous \(title.lowercased())")
            Menu {
                ForEach(names.indices, id: \.self) { index in
                    Button { change(selection, by: index - selection.wrappedValue, count: names.count) } label: {
                        if selection.wrappedValue == index { Label(names[index], systemImage: "checkmark") }
                        else { Text(names[index]) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(names[min(max(selection.wrappedValue, 0), names.count - 1)]).font(.subheadline)
                    Image(systemName: "chevron.down").font(.caption2)
                }.frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityLabel("\(title): \(names[min(max(selection.wrappedValue, 0), names.count - 1)])")
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

    @MainActor private func deleteAccount(reauthentication: CommunityAPI.AppleReauthentication, appleUserID: String) async throws {
        guard let token = session.token else { return }
        if let expectedID = session.credentials?.appleUserID, expectedID != appleUserID {
            throw CommunityAPIError(status: 403, message: "Use the Apple account you signed in with to delete this community account.")
        }
        deletingAccount = true; message = nil
        defer { deletingAccount = false }
        do {
            let mine = try await CommunityAPI().myDecks(token: token)
            try await CommunityAPI().deleteAccount(token: token, reauthentication: reauthentication)
            guard session.completeAccountDeletion(token: token) else { return }
            let ids = Set(mine.decks.map(\.id))
            for deck in libraryDecks where deck.publishedCommunityID.map({ ids.contains($0) }) == true { deck.publishedCommunityID = nil }
            try? context.save()
            showingDeletionSignIn = false
            dismiss()
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); throw error }
    }
}

private struct CommunityAccountDeletionSheet: View {
    let onAuthorize: (CommunityAPI.AppleReauthentication, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Confirm with Apple").font(.title2.weight(.semibold))
                Text("Use the same Apple account to finish deleting your community profile and submissions. Your personal library stays on this device.")
                    .font(.body).foregroundStyle(LearnAlertStyle.textSecondary)
                SignInWithAppleButton(.continue) { request in
                    nonce = CommunitySession.makeNonce()
                    request.nonce = CommunitySession.hashedNonce(nonce)
                    errorMessage = nil
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let identityData = credential.identityToken,
                              let identity = String(data: identityData, encoding: .utf8),
                              let codeData = credential.authorizationCode,
                              let code = String(data: codeData, encoding: .utf8) else {
                            errorMessage = "Apple did not provide confirmation. Please try again."
                            return
                        }
                        let confirmation = CommunityAPI.AppleReauthentication(identityToken: identity, authorizationCode: code, nonce: nonce)
                        isWorking = true
                        Task {
                            defer { isWorking = false }
                            do { try await onAuthorize(confirmation, credential.user) }
                            catch { errorMessage = error.localizedDescription }
                        }
                    case .failure(let error):
                        if (error as? ASAuthorizationError)?.code != .canceled { errorMessage = "Apple confirmation could not finish. Please try again." }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48).disabled(isWorking)
                if isWorking { ProgressView("Deleting your community account…") }
                if let errorMessage { Text(errorMessage).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed) }
                Spacer()
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary)
            .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isWorking) } }
            .interactiveDismissDisabled(isWorking)
        }
    }
}

struct CommunityBlockedAuthorsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var session = CommunitySession.shared
    @State private var users: [CommunityBlockedUser] = []
    @State private var isLoading = true
    @State private var changingID: String?
    @State private var message: String?
    @State private var loadID = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading { ProgressView("Loading blocked authors…").frame(minHeight: 120) }
                    else if users.isEmpty && message == nil { ContentUnavailableView("No blocked authors", systemImage: "person.slash") }
                    ForEach(users) { user in
                        HStack(spacing: 16) {
                            Text(user.handle).font(.body.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                            Button("Unblock") { Task { await unblock(user) } }.frame(minHeight: 44).disabled(changingID != nil)
                            if changingID == user.id { ProgressView() }
                        }
                        .padding(16).appCardSurface(cornerRadius: 20)
                    }
                    if let message {
                        Text(message).font(.subheadline).foregroundStyle(LearnAlertStyle.destructiveRed)
                        Button("Try again") { Task { await load() } }.frame(minHeight: 44)
                    }
                }.padding(20)
            }
            .background(LearnAlertStyle.courseCanvas.ignoresSafeArea()).foregroundStyle(LearnAlertStyle.textPrimary).tint(LearnAlertStyle.appAccentForeground)
            .navigationTitle("Blocked authors").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(changingID != nil) } }
            .task(id: "\(scenePhase)-\(session.token ?? "signed-out")") {
                guard session.token != nil else { loadID = UUID(); users = []; isLoading = false; return }
                if scenePhase == .active { await load() }
            }
            .refreshable { await load() }
            .interactiveDismissDisabled(changingID != nil)
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { users = []; isLoading = false; return }
        guard changingID == nil else { return }
        let id = UUID(); loadID = id
        isLoading = users.isEmpty; message = nil
        defer { if loadID == id { isLoading = false } }
        do {
            let rows = try await CommunityAPI().blockedUsers(token: token)
            guard session.token == token, loadID == id, !Task.isCancelled else { return }
            users = rows
        } catch {
            guard session.token == token, loadID == id, !Task.isCancelled else { return }
            session.handle(error); message = error.localizedDescription
        }
    }

    @MainActor private func unblock(_ user: CommunityBlockedUser) async {
        guard let token = session.token, changingID == nil else { return }
        loadID = UUID(); isLoading = false
        changingID = user.id; message = nil
        defer { changingID = nil }
        do {
            try await CommunityAPI().unblock(authorID: user.id, token: token)
            guard session.token == token else { return }
            users.removeAll { $0.id == user.id }
            NotificationCenter.default.post(name: .communityLibraryChanged, object: nil)
        } catch { session.handle(error); message = error.localizedDescription }
    }
}
