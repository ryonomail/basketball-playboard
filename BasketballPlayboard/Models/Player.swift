import Foundation
import CoreGraphics

enum Team: String, Codable {
    case home
    case away

    var displayName: String {
        switch self {
        case .home: return "ホーム"
        case .away: return "アウェイ"
        }
    }
}

struct Player: Identifiable, Codable {
    let id: UUID
    var number: String
    var team: Team
    var position: CGPoint

    init(id: UUID = UUID(), number: String, team: Team, position: CGPoint) {
        self.id = id
        self.number = number
        self.team = team
        self.position = position
    }
}
