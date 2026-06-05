import Foundation
import CoreGraphics

struct Formation {
    static func defaultHomePlayers() -> [Player] {
        [
            Player(number: "1", team: .home, position: CGPoint(x: 0.50, y: 0.30)),
            Player(number: "2", team: .home, position: CGPoint(x: 0.20, y: 0.45)),
            Player(number: "3", team: .home, position: CGPoint(x: 0.80, y: 0.45)),
            Player(number: "4", team: .home, position: CGPoint(x: 0.30, y: 0.60)),
            Player(number: "5", team: .home, position: CGPoint(x: 0.70, y: 0.60)),
        ]
    }

    static func defaultAwayPlayers() -> [Player] {
        [
            Player(number: "1", team: .away, position: CGPoint(x: 0.50, y: 0.25)),
            Player(number: "2", team: .away, position: CGPoint(x: 0.25, y: 0.40)),
            Player(number: "3", team: .away, position: CGPoint(x: 0.75, y: 0.40)),
            Player(number: "4", team: .away, position: CGPoint(x: 0.35, y: 0.55)),
            Player(number: "5", team: .away, position: CGPoint(x: 0.65, y: 0.55)),
        ]
    }

    static func allPlayers() -> [Player] {
        defaultHomePlayers() + defaultAwayPlayers()
    }
}
