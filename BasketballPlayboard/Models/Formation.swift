import Foundation
import CoreGraphics

struct Formation {
    // Ring is at baseline center (0.5, 0)
    // facing angle: 0=up on screen, π=down, uses atan2(dx, -dy) in landscape-half screen space

    private static func facingToward(_ from: CGPoint, _ target: CGPoint) -> Double {
        // In landscape-half: screen_x = court_x, screen_y = 1 - court_y
        let dx = Double(target.x - from.x)
        let dy = Double((1 - target.y) - (1 - from.y)) // screen dy
        return atan2(dx, -dy)
    }

    private static let ring = CGPoint(x: 0.5, y: 0)

    static func defaultHomePlayers() -> [Player] {
        let positions: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.62)), // PG - Top
            ("2", CGPoint(x: 0.78, y: 0.48)), // SG - Right 45
            ("3", CGPoint(x: 0.22, y: 0.48)), // SF - Left 45
            ("4", CGPoint(x: 0.93, y: 0.12)), // PF - Right corner
            ("5", CGPoint(x: 0.07, y: 0.12)), // C - Left corner
        ]
        return positions.map { (num, pos) in
            Player(number: num, team: .home, position: pos, facing: facingToward(pos, ring))
        }
    }

    static func defaultAwayPlayers() -> [Player] {
        let home = defaultHomePlayers()
        let positions: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.55)),
            ("2", CGPoint(x: 0.73, y: 0.42)),
            ("3", CGPoint(x: 0.27, y: 0.42)),
            ("4", CGPoint(x: 0.88, y: 0.12)),
            ("5", CGPoint(x: 0.12, y: 0.12)),
        ]
        return positions.enumerated().map { (i, pair) in
            let (num, pos) = pair
            let target = home[i].position
            return Player(number: num, team: .away, position: pos, facing: facingToward(pos, target))
        }
    }

    static func allPlayers() -> [Player] {
        defaultHomePlayers() + defaultAwayPlayers()
    }
}
