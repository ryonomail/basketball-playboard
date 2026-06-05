import Foundation
import CoreGraphics

enum LineType: String, Codable, CaseIterable {
    case cut
    case pass
    case dribble
    case screen

    var displayName: String {
        switch self {
        case .cut: return "カット"
        case .pass: return "パス"
        case .dribble: return "ドリブル"
        case .screen: return "スクリーン"
        }
    }

    var iconName: String {
        switch self {
        case .cut: return "arrow.right"
        case .pass: return "arrow.right.dotted"
        case .dribble: return "water.waves"
        case .screen: return "hand.raised"
        }
    }
}

struct DrawingLine: Identifiable, Codable {
    let id: UUID
    var type: LineType
    var points: [CGPoint]

    init(id: UUID = UUID(), type: LineType, points: [CGPoint] = []) {
        self.id = id
        self.type = type
        self.points = points
    }
}
