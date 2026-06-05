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
    var facing: Double // radians, 0 = up

    init(id: UUID = UUID(), number: String, team: Team, position: CGPoint, facing: Double = 0) {
        self.id = id
        self.number = number
        self.team = team
        self.position = position
        self.facing = facing
    }
}

struct Ball: Codable, Equatable {
    var position: CGPoint

    init(position: CGPoint = CGPoint(x: 0.5, y: 0.35)) {
        self.position = position
    }
}
