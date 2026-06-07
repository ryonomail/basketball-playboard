import Foundation

struct PlaySnapshot: Codable {
    var players: [Player]
    var balls: [Ball]
    var lines: [DrawingLine]
    var timestamp: TimeInterval
}

struct Play: Identifiable, Codable {
    let id: UUID
    var name: String
    var snapshots: [PlaySnapshot]
    var createdAt: Date

    var duration: TimeInterval {
        snapshots.last?.timestamp ?? 0
    }

    init(id: UUID = UUID(), name: String, snapshots: [PlaySnapshot] = []) {
        self.id = id
        self.name = name
        self.snapshots = snapshots
        self.createdAt = Date()
    }

    func interpolated(at time: TimeInterval) -> PlaySnapshot? {
        guard !snapshots.isEmpty else { return nil }
        if time <= 0 { return snapshots.first }
        if time >= duration { return snapshots.last }

        var before = snapshots[0]
        var after = snapshots[0]
        for snap in snapshots {
            if snap.timestamp <= time { before = snap }
            if snap.timestamp >= time { after = snap; break }
        }

        let span = after.timestamp - before.timestamp
        guard span > 0 else { return before }
        let t = CGFloat((time - before.timestamp) / span)

        var result = after
        for i in result.players.indices {
            if let bi = before.players.firstIndex(where: { $0.id == result.players[i].id }) {
                let bp = before.players[bi]
                result.players[i].position.x = bp.position.x + (result.players[i].position.x - bp.position.x) * t
                result.players[i].position.y = bp.position.y + (result.players[i].position.y - bp.position.y) * t
                var df = after.players[i].facing - bp.facing
                while df > .pi { df -= 2 * .pi }
                while df < -.pi { df += 2 * .pi }
                result.players[i].facing = bp.facing + df * Double(t)
            }
        }
        for i in result.balls.indices {
            if let bi = before.balls.firstIndex(where: { $0.id == result.balls[i].id }) {
                let bb = before.balls[bi]
                result.balls[i].position.x = bb.position.x + (result.balls[i].position.x - bb.position.x) * t
                result.balls[i].position.y = bb.position.y + (result.balls[i].position.y - bb.position.y) * t
            }
        }
        result.lines = after.lines
        return result
    }
}
