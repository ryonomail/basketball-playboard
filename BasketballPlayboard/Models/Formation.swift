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

    private static func facingFull(_ from: CGPoint, _ target: CGPoint) -> Double {
        let sdx = Double(target.y - from.y)
        let sdy = Double(target.x - from.x)
        return atan2(sdx, -sdy)
    }

    private static let ring = CGPoint(x: 0.5, y: 0)

    // MARK: - Half court (y: 0=baseline/ring, 1=halfcourt)

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
            ("1", CGPoint(x: 0.50, y: 0.31)),
            ("2", CGPoint(x: 0.78, y: 0.24)),
            ("3", CGPoint(x: 0.22, y: 0.24)),
            ("4", CGPoint(x: 0.93, y: 0.06)),
            ("5", CGPoint(x: 0.07, y: 0.06)),
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
