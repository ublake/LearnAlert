//
//  LearnAlertApp.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//

import SwiftUI
import SwiftData

@main
struct LearnAlertApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // Initialize our custom shared database
    let sharedDatabase = SharedDatabase.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject it into the SwiftUI environment
                .modelContainer(sharedDatabase.container)
                .onAppear {
                    UserDefaults(suiteName: "group.com.learnalert.shared")?.set(true, forKey: "isAppInForeground")
                }
                .onChange(of: scenePhase) { _, newPhase in
                    UserDefaults(suiteName: "group.com.learnalert.shared")?.set(newPhase == .active, forKey: "isAppInForeground")
                }
        }
    }
}
