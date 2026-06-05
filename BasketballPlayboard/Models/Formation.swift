import Foundation
import CoreGraphics

struct Formation: Identifiable, Codable {
    let id: UUID
    var name: String
    var players: [Player]

    init(id: UUID = UUID(), name: String, players: [Player]) {
        self.id = id
        self.name = name
        self.players = players
    }

    static let defaultHome = Formation(
        name: "ベーシック",
        players: [
            Player(number: "1", team: .home, position: CGPoint(x: 0.5, y: 0.25)),
            Player(number: "2", team: .home, position: CGPoint(x: 0.25, y: 0.35)),
            Player(number: "3", team: .home, position: CGPoint(x: 0.75, y: 0.35)),
            Player(number: "4", team: .home, position: CGPoint(x: 0.3, y: 0.5)),
            Player(number: "5", team: .home, position: CGPoint(x: 0.7, y: 0.5)),
        ]
    )

    static let defaultAway = Formation(
        name: "ベーシック",
        players: [
            Player(number: "1", team: .away, position: CGPoint(x: 0.5, y: 0.3)),
            Player(number: "2", team: .away, position: CGPoint(x: 0.2, y: 0.4)),
            Player(number: "3", team: .away, position: CGPoint(x: 0.8, y: 0.4)),
            Player(number: "4", team: .away, position: CGPoint(x: 0.35, y: 0.55)),
            Player(number: "5", team: .away, position: CGPoint(x: 0.65, y: 0.55)),
        ]
    )
}
