import Foundation
import CoreGraphics

struct Formation {
    // Offense (home): facing toward basket (facing = π = down)
    // Defense (away): facing toward offense (facing = 0 = up)
    // Court coords: x = sideline-to-sideline (0-1), y = baseline(0)-to-halfcourt(1)
    // Basket is near y=0

    static func defaultHomePlayers() -> [Player] {
        [
            // PG - Top
            Player(number: "1", team: .home, position: CGPoint(x: 0.50, y: 0.62), facing: .pi),
            // SG - Right 45
            Player(number: "2", team: .home, position: CGPoint(x: 0.78, y: 0.48), facing: .pi),
            // SF - Left 45
            Player(number: "3", team: .home, position: CGPoint(x: 0.22, y: 0.48), facing: .pi),
            // PF - Right corner
            Player(number: "4", team: .home, position: CGPoint(x: 0.93, y: 0.12), facing: .pi),
            // C - Left corner
            Player(number: "5", team: .home, position: CGPoint(x: 0.07, y: 0.12), facing: .pi),
        ]
    }

    static func defaultAwayPlayers() -> [Player] {
        [
            // PG - Top
            Player(number: "1", team: .away, position: CGPoint(x: 0.50, y: 0.55), facing: 0),
            // SG - Right 45
            Player(number: "2", team: .away, position: CGPoint(x: 0.73, y: 0.42), facing: 0),
            // SF - Left 45
            Player(number: "3", team: .away, position: CGPoint(x: 0.27, y: 0.42), facing: 0),
            // PF - Right corner
            Player(number: "4", team: .away, position: CGPoint(x: 0.88, y: 0.12), facing: 0),
            // C - Left corner
            Player(number: "5", team: .away, position: CGPoint(x: 0.12, y: 0.12), facing: 0),
        ]
    }

    static func allPlayers() -> [Player] {
        defaultHomePlayers() + defaultAwayPlayers()
    }
}
