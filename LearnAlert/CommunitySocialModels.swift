import Foundation

struct CommunityProfileStats: Codable, Equatable {
    let profileCreatedAt: Int?
    let createdDeckCount: Int
    let publishedDeckCount: Int
    let downloadCount: Int
    let receivedLikeCount: Int
    var hasReceivedLikes: Bool? = nil
}

struct CommunityPublicProfile: Decodable {
    let authorID: String
    let handle: String
    let avatar: CommunityAvatar
    let hideStatsPublicly: Bool
    let profileCreatedAt: Int?
    let stats: CommunityProfileStats?
}

struct CommunityPublicProfilePage: Decodable {
    let profile: CommunityPublicProfile
    let decks: [CommunityDeckPayload]
    let nextOffset: Int?
    let totalCount: Int
}

struct CommunityLikeResult: Decodable {
    let success: Bool
    let likeCount: Int
    let viewerHasLiked: Bool
}

struct CommunityReceivedLike: Decodable, Identifiable {
    let authorID: String
    let handle: String
    let avatar: CommunityAvatar
    let deckID: String
    let deckName: String
    let createdAt: Int
    var id: String { "\(deckID):\(authorID)" }
}

struct CommunityDeckLikeCount: Decodable, Identifiable {
    let deckID: String
    let deckName: String
    let likeCount: Int
    var id: String { deckID }
}

struct CommunityLikesPage: Decodable {
    let totalCount: Int
    let likes: [CommunityReceivedLike]
    let nextOffset: Int?
    let deckCounts: [CommunityDeckLikeCount]
}
