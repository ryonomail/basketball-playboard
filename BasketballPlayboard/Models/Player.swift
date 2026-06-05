import Foundation
import CoreGraphics

enum Team: String, Codable {
    case home
    case away
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

struct Ball: Codable, Equatable {
    var position: CGPoint

    init(position: CGPoint = CGPoint(x: 0.5, y: 0.35)) {
        self.position = position
    }
}
