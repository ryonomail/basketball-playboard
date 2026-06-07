import Foundation
import CoreGraphics

struct Formation {
    // Landscape half: screen_x = court_x, screen_y = 1-court_y (ring at bottom)
    // Landscape full: screen_x = court_y, screen_y = court_x (ring at left)
    // facing: atan2(screen_dx, -screen_dy), 0=up on screen

    private static func facingHalf(_ from: CGPoint, _ target: CGPoint) -> Double {
        let dx = Double(target.x - from.x)
        let dy = Double(target.y - from.y)
        return atan2(dx, dy)
    }

    // facingFull for landscape full court: screen_x=court_y, screen_y=court_x
    private static func facingFull(_ from: CGPoint, _ target: CGPoint) -> Double {
        let sdx = Double(target.y - from.y)
        let sdy = Double(target.x - from.x)
        return atan2(sdx, -sdy)
    }

    private static let ring = CGPoint(x: 0.5, y: 0)

    // MARK: - Half court (y: 0=baseline/ring, 1=halfcourt)

    static func halfCourtPlayers() -> [Player] {
        let offense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.70)),  // Top (above 3P arc)
            ("2", CGPoint(x: 0.82, y: 0.52)),  // Right 45
            ("3", CGPoint(x: 0.18, y: 0.52)),  // Left 45
            ("4", CGPoint(x: 0.90, y: 0.22)),  // Right corner
            ("5", CGPoint(x: 0.10, y: 0.22)),  // Left corner
        ]
        let defense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.60)),
            ("2", CGPoint(x: 0.75, y: 0.45)),
            ("3", CGPoint(x: 0.25, y: 0.45)),
            ("4", CGPoint(x: 0.84, y: 0.18)),
            ("5", CGPoint(x: 0.16, y: 0.18)),
        ]
        var players: [Player] = []
        for (i, (num, pos)) in offense.enumerated() {
            players.append(Player(number: num, team: .home, position: pos,
                                  facing: facingHalf(pos, ring)))
            let (dNum, dPos) = defense[i]
            players.append(Player(number: dNum, team: .away, position: dPos,
                                  facing: facingHalf(dPos, offense[i].1)))
        }
        return players
    }

    // MARK: - Full court (y: 0=one baseline/ring, 1=other baseline)
    // Near-side half: y=0~0.5

    static func fullCourtPlayers() -> [Player] {
        let offense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.35)),  // Top
            ("2", CGPoint(x: 0.82, y: 0.26)),  // Right 45
            ("3", CGPoint(x: 0.18, y: 0.26)),  // Left 45
            ("4", CGPoint(x: 0.90, y: 0.11)),  // Right corner
            ("5", CGPoint(x: 0.10, y: 0.11)),  // Left corner
        ]
        let defense: [(String, CGPoint)] = [
            ("1", CGPoint(x: 0.50, y: 0.30)),
            ("2", CGPoint(x: 0.75, y: 0.225)),
            ("3", CGPoint(x: 0.25, y: 0.225)),
            ("4", CGPoint(x: 0.84, y: 0.09)),
            ("5", CGPoint(x: 0.12, y: 0.09)),
        ]
        var players: [Player] = []
        for (i, (num, pos)) in offense.enumerated() {
            players.append(Player(number: num, team: .home, position: pos,
                                  facing: facingFull(pos, ring)))
            let (dNum, dPos) = defense[i]
            players.append(Player(number: dNum, team: .away, position: dPos,
                                  facing: facingFull(dPos, offense[i].1)))
        }
        return players
    }

    static func allPlayers(for mode: CourtMode = .half) -> [Player] {
        mode == .half ? halfCourtPlayers() : fullCourtPlayers()
    }
}
