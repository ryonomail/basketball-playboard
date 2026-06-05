import Foundation
import CoreGraphics

struct Formation {
    // facing angle: uses atan2(dx, -dy) in landscape-half screen space
    // 0=up on screen, π=down

    private static func facingToward(_ from: CGPoint, _ target: CGPoint) -> Double {
        let dx = Double(target.x - from.x)
        let dy = Double(from.y - target.y) // court dy (positive = toward baseline)
        return atan2(dx, dy)
    }

    // MARK: - Half court (y: 0=baseline, 1=halfcourt line)

    private static let halfRing = CGPoint(x: 0.5, y: 0)

    static func halfCourtPlayers() -> [Player] {
        let offense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.62)),
            ("2", CGPoint(x: 0.78, y: 0.48)),
            ("3", CGPoint(x: 0.22, y: 0.48)),
            ("4", CGPoint(x: 0.93, y: 0.12)),
            ("5", CGPoint(x: 0.07, y: 0.12)),
        ]
        let defense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.55)),
            ("2", CGPoint(x: 0.73, y: 0.42)),
            ("3", CGPoint(x: 0.27, y: 0.42)),
            ("4", CGPoint(x: 0.88, y: 0.12)),
            ("5", CGPoint(x: 0.12, y: 0.12)),
        ]
        var players: [Player] = []
        for (i, (num, pos)) in offense.enumerated() {
            players.append(Player(number: num, team: .home, position: pos, facing: facingToward(pos, halfRing)))
            let (dNum, dPos) = defense[i]
            players.append(Player(number: dNum, team: .away, position: dPos, facing: facingToward(dPos, offense[i].1)))
        }
        return players
    }

    // MARK: - Full court (y: 0=one baseline, 1=other baseline)
    // Place on the y=0 side half (lower half in portrait, left half in landscape)
    // Ring at (0.5, 0), positions in y: 0~0.5

    private static let fullRing = CGPoint(x: 0.5, y: 0)

    static func fullCourtPlayers() -> [Player] {
        // Scale half-court positions into y: 0~0.5 range
        let offense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.31)),  // Top
            ("2", CGPoint(x: 0.78, y: 0.24)),  // Right 45
            ("3", CGPoint(x: 0.22, y: 0.24)),  // Left 45
            ("4", CGPoint(x: 0.93, y: 0.06)),  // Right corner
            ("5", CGPoint(x: 0.07, y: 0.06)),  // Left corner
        ]
        let defense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.275)),
            ("2", CGPoint(x: 0.73, y: 0.21)),
            ("3", CGPoint(x: 0.27, y: 0.21)),
            ("4", CGPoint(x: 0.88, y: 0.06)),
            ("5", CGPoint(x: 0.12, y: 0.06)),
        ]
        var players: [Player] = []
        for (i, (num, pos)) in offense.enumerated() {
            players.append(Player(number: num, team: .home, position: pos, facing: facingToward(pos, fullRing)))
            let (dNum, dPos) = defense[i]
            players.append(Player(number: dNum, team: .away, position: dPos, facing: facingToward(dPos, offense[i].1)))
        }
        return players
    }

    static func allPlayers(for mode: CourtMode = .half) -> [Player] {
        mode == .half ? halfCourtPlayers() : fullCourtPlayers()
    }
}
