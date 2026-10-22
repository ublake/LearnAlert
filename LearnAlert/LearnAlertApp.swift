//
//  LearnAlertApp.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import SwiftUI
import Combine
import SwiftData
import UIKit
import AuthenticationServices
#if TIKTOK_TRACKING_AVAILABLE
import AppTrackingTransparency
import TikTokBusinessSDK
#endif

@main
struct LearnAlertApp: App {
    #if TIKTOK_TRACKING_AVAILABLE
    @UIApplicationDelegateAdaptor(LearnAlertAppDelegate.self) private var appDelegate
    #endif
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Initialize our custom shared database
    let sharedDatabase = SharedDatabase.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .safeAreaInset(edge: .top, spacing: 0) { CourseProgressRecoveryBanner() }
                // Inject it into the SwiftUI environment
                .modelContainer(sharedDatabase.container)
                .task(id: hasCompletedOnboarding && scenePhase == .active) {
                    #if TIKTOK_TRACKING_AVAILABLE
                    guard TikTokTracking.isEnabled, hasCompletedOnboarding,
                          scenePhase == .active else { return }
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }
                    guard UIApplication.shared.applicationState == .active,
                          ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
                    TikTokBusiness.requestTrackingAuthorization { _ in }
                    #endif
                }
                .onAppear {
                    UserDefaults(suiteName: "group.com.learnalert.shared")?.set(true, forKey: "isAppInForeground")
                }
                .onChange(of: scenePhase) { _, newPhase in
                    UserDefaults(suiteName: "group.com.learnalert.shared")?.set(newPhase == .active, forKey: "isAppInForeground")
                }
                .task(id: scenePhase == .active) {
                    guard scenePhase == .active else { return }
                    await CommunitySession.shared.validateAppleCredential()
                }
                .task(id: scenePhase == .active) {
                    guard scenePhase == .active else { return }
                    // Let Home render before maintaining enrolled course decks.
                    do { try await Task.sleep(for: .milliseconds(250)) }
                    catch { return }
                    // Assign stable source IDs before installing a remote rename.
                    await syncManagedCourseDecks()
                    while !Task.isCancelled {
                        await ManagedCatalogStore.shared.refresh()
                        do { try await Task.sleep(for: .seconds(60)) }
                        catch { return }
                    }
                }
                .onReceive(ManagedCatalogStore.shared.$revision.dropFirst()) { _ in
                    Task { await syncManagedCourseDecks() }
                }
                .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
                    CommunitySession.shared.appleCredentialRevoked()
                }
        }
    }

    @MainActor private func syncManagedCourseDecks() async {
        let manager = CourseProgressManager.shared
        manager.reloadFromSharedDefaults()
        for course in manager.allEnrolledCourses {
            await Task.yield()
            guard !Task.isCancelled else { return }
            manager.syncManagedCourseDeckIfNeeded(for: course, in: sharedDatabase.container.mainContext)
            manager.reconcilePendingNotifications(for: course)
        }
    }
}

// Disabled by default. Re-enable with LEARNALERT_ENABLE_TIKTOK=1 pod install.
enum TikTokTracking {
    static var isEnabled: Bool {
        guard let setting = Bundle.main.object(forInfoDictionaryKey: "TikTokTrackingEnabled") as? String else {
            return false
        }
        return ["YES", "TRUE", "1"].contains(setting.uppercased())
    }
}

#if TIKTOK_TRACKING_AVAILABLE
final class LearnAlertAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Do not initialize the SDK or collect/send TikTok events while disabled.
        guard TikTokTracking.isEnabled else { return true }
        guard let appSecret = Bundle.main.object(forInfoDictionaryKey: "TikTokAppSecret") as? String,
              !appSecret.isEmpty, !appSecret.hasPrefix("$("),
              let config = TikTokConfig(
                accessToken: appSecret,
                appId: "6813841439",
                tiktokAppId: "7693169404888039445"
              ) else {
            NSLog("TikTok SDK configuration is missing or invalid.")
            return true
        }
        #if DEBUG
        config.enableDebugMode()
        #endif
        TikTokBusiness.initializeSdk(config) { success, _ in
            NSLog(success ? "TikTok SDK initialized successfully." : "TikTok SDK initialization failed.")
        }
        return true
    }
}
#endif
