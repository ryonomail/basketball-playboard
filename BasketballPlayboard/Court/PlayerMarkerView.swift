import SwiftUI

struct PlayerMarkerView: View {
    let player: Player
    let isSelected: Bool
    var onTapNumber: (() -> Void)? = nil

    private var teamColor: Color {
        player.team == .home ? .blue : .red
    }

    var body: some View {
        VStack(spacing: 0) {
            // Head
            Circle()
                .fill(teamColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.yellow : Color.black, lineWidth: isSelected ? 2 : 1)
                )

            // Body (trapezoid shape like a chess pawn)
            PawnBody()
                .fill(teamColor)
                .frame(width: 26, height: 20)
                .overlay(
                    PawnBody()
                        .stroke(isSelected ? Color.yellow : Color.black, lineWidth: isSelected ? 2 : 1)
                )
                .overlay(
                    Text(player.number)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .offset(y: 1)
                )
        }
        .onTapGesture {
            onTapNumber?()
        }
    }
}

struct PawnBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset: CGFloat = rect.width * 0.2
        path.move(to: CGPoint(x: topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - topInset, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
