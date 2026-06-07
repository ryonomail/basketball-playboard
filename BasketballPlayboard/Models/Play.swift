import Foundation

struct PlayFrame: Identifiable, Codable {
    let id: UUID
    var players: [Player]
    var balls: [Ball]
    var lines: [DrawingLine]

    init(id: UUID = UUID(), players: [Player], balls: [Ball] = [Ball()], lines: [DrawingLine] = []) {
        self.id = id
        self.players = players
        self.balls = balls
        self.lines = lines
    }
}

struct Play: Identifiable, Codable {
    let id: UUID
    var name: String
    var frames: [PlayFrame]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, frames: [PlayFrame] = []) {
        self.id = id
        self.name = name
        self.frames = frames
        self.createdAt = Date()
    }
}
