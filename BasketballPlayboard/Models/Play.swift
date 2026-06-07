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

        var result = before
        for i in result.players.indices {
            if i < after.players.count {
                result.players[i].position.x = before.players[i].position.x + (after.players[i].position.x - before.players[i].position.x) * t
                result.players[i].position.y = before.players[i].position.y + (after.players[i].position.y - before.players[i].position.y) * t
                result.players[i].facing = before.players[i].facing + (after.players[i].facing - before.players[i].facing) * Double(t)
            }
        }
        for i in result.balls.indices {
            if i < after.balls.count {
                result.balls[i].position.x = before.balls[i].position.x + (after.balls[i].position.x - before.balls[i].position.x) * t
                result.balls[i].position.y = before.balls[i].position.y + (after.balls[i].position.y - before.balls[i].position.y) * t
            }
        }
        result.lines = after.lines
        return result
    }
}
