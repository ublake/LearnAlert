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
    
    // Initialize our custom shared database
    let sharedDatabase = SharedDatabase.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject it into the SwiftUI environment
                .modelContainer(sharedDatabase.container)

        }
    }
}
