//
//  SharedDatabase.swift
//  LearnAlert
//
//  Created by Blake Miller on 2/19/26.
//


import Foundation
import SwiftData

@MainActor
class SharedDatabase {
    static let shared = SharedDatabase()

    static let appGroupIdentifier = "group.com.learnalert.shared"
    static let cloudKitContainerIdentifier = "iCloud.com.learnalert.app"
    
    let container: ModelContainer
    
    private init() {
        // 1. Point to the App Group folder, or fallback gracefully to Application Support
        let baseURL: URL
        if let sharedURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) {
            baseURL = sharedURL
        } else {
            baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        
        // 2. Name the database file
        let databaseURL = baseURL.appendingPathComponent("LearnAlert.sqlite")
        
        // 3. Configure SwiftData to use this shared file
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = Bundle.main.bundleURL.pathExtension == "appex"
            ? .none
            : .private(Self.cloudKitContainerIdentifier)
        let configuration = ModelConfiguration(
            url: databaseURL,
            cloudKitDatabase: cloudKitDatabase
        )
        
        do {
            // 4. Initialize the container with our Models (with CloudKit sync)
            container = try ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: configuration)
        } catch {
            // If CloudKit initialization fails (e.g. simulator without iCloud credentials), fallback gracefully to local container
            let fallbackConfiguration = ModelConfiguration(
                url: databaseURL,
                cloudKitDatabase: .none
            )
            if let fallbackContainer = try? ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: fallbackConfiguration) {
                container = fallbackContainer
            } else if let memoryContainer = try? ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
                container = memoryContainer
            } else {
                // Absolute fallback
                container = try! ModelContainer(for: Deck.self, DeckSection.self, Flashcard.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            }
        }
    }
}
