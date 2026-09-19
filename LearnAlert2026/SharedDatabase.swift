import Foundation
import SwiftData

@MainActor
class SharedDatabase {
    static let shared = SharedDatabase()
    
    let container: ModelContainer
    
    private init() {
        // 1. Point to the App Group folder you created in Step 1
        let appGroupIdentifier = "group.com.learnalert.shared"
        
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            fatalError("Failed to find App Group container. Did you enable the App Groups capability in Xcode for BOTH targets?")
        }
        
        // 2. Name the database file
        let databaseURL = sharedURL.appendingPathComponent("LearnAlert.sqlite")
        
        // 3. Configure SwiftData to use this shared file
        let configuration = ModelConfiguration(url: databaseURL)
        
        do {
            // 4. Initialize the container with our Models
            container = try ModelContainer(for: Deck.self, Flashcard.self, configurations: configuration)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }
}