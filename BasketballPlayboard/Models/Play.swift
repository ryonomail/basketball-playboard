import Foundation

struct PlayFrame: Identifiable, Codable {
    let id: UUID
    var players: [Player]
    var lines: [DrawingLine]

    init(id: UUID = UUID(), players: [Player], lines: [DrawingLine] = []) {
        self.id = id
        self.players = players
        self.lines = lines
    }
}

struct Play: Identifiable, Codable {
    let id: UUID
    var name: String
    var frames: [PlayFrame]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, frames: [PlayFrame] = []) {
        self.id = id
        self.name = name
        self.frames = frames
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
