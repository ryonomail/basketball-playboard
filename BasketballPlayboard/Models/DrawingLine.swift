import Foundation
import CoreGraphics
import SwiftUI

enum LineType: String, Codable, CaseIterable {
    case plain
    case cut
    case pass
    case dribble
    case screen

    var displayName: String {
        switch self {
        case .plain: return "ライン"
        case .cut: return "カット"
        case .pass: return "パス"
        case .dribble: return "ドリブル"
        case .screen: return "スクリーン"
        }
    }

    var systemImage: String {
        switch self {
        case .plain: return "line.diagonal"
        case .cut: return "arrow.right"
        case .pass: return "arrow.right.dotted"
        case .dribble: return "water.waves"
        case .screen: return "hand.raised"
        }
    }
}

enum LineColor: String, Codable, CaseIterable {
    case black
    case red
    case blue
    case green
    case orange

    var color: Color {
        switch self {
        case .black: return .black
        case .red: return .red
        case .blue: return .blue
        case .green: return Color(red: 0.2, green: 0.7, blue: 0.2)
        case .orange: return .orange
        }
    }
}

struct DrawingLine: Identifiable, Codable {
    let id: UUID
    var type: LineType
    var lineColor: LineColor
    var points: [CGPoint]

    init(id: UUID = UUID(), type: LineType, lineColor: LineColor = .black, points: [CGPoint] = []) {
        self.id = id
        self.type = type
        self.lineColor = lineColor
        self.points = points
    }
}
