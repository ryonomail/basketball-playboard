import SwiftUI

struct PlayerMarkerView: View {
    let player: Player
    let isSelected: Bool

    private var teamColor: Color {
        player.team == .home ? .blue : .red
    }

    var body: some View {
        VStack(spacing: -2) {
            // Head
            Circle()
                .fill(teamColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().stroke(isSelected ? Color.yellow : Color.white, lineWidth: isSelected ? 2.5 : 1)
                )

            // Body
            PawnBody()
                .fill(teamColor)
                .frame(width: 24, height: 18)
                .overlay(
                    PawnBody().stroke(isSelected ? Color.yellow : Color.white, lineWidth: isSelected ? 2.5 : 1)
                )
                .overlay(
                    Text(player.number)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .offset(y: 1)
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

struct PawnBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.18
        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: rect.width - inset, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width - inset / 2, y: rect.height * 0.5)
        )
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: inset, y: 0),
            control: CGPoint(x: inset / 2, y: rect.height * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

struct BallView: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 22, height: 22)

            // Horizontal seam
            Ellipse()
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
                .frame(width: 20, height: 8)

            // Vertical seam
            Ellipse()
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
                .frame(width: 8, height: 20)

            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2.5)
                    .frame(width: 24, height: 24)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}
