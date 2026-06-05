import SwiftUI

struct PlayerMarkerView: View {
    let player: Player
    let isSelected: Bool

    private var teamColor: Color {
        player.team == .home ? .blue : .red
    }

    var body: some View {
        ZStack {
            // Vision cone
            VisionCone()
                .fill(teamColor.opacity(0.18))
                .frame(width: 60, height: 50)
                .offset(y: -30)
                .rotationEffect(.radians(player.facing))

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
}

struct VisionCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let bottom = rect.maxY
        let spreadAngle: CGFloat = .pi / 3 // 60 degree cone
        let length = rect.height

        path.move(to: CGPoint(x: cx, y: bottom))
        path.addLine(to: CGPoint(
            x: cx + length * sin(spreadAngle / 2),
            y: bottom - length * cos(spreadAngle / 2)
        ))
        path.addArc(
            center: CGPoint(x: cx, y: bottom),
            radius: length,
            startAngle: .radians(-.pi / 2 + Double(spreadAngle / 2)),
            endAngle: .radians(-.pi / 2 - Double(spreadAngle / 2)),
            clockwise: true
        )
        path.closeSubpath()
        return path
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
            // Ball body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.35, blue: 0.0)],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .frame(width: 22, height: 22)

            // Seam lines
            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r = size.width / 2 - 1
                let style = StrokeStyle(lineWidth: 0.8, lineCap: .round)
                let color: Color = .black.opacity(0.45)

                // Vertical seam
                var vLine = Path()
                vLine.move(to: CGPoint(x: cx, y: cy - r))
                vLine.addLine(to: CGPoint(x: cx, y: cy + r))
                context.stroke(vLine, with: .color(color), style: style)

                // Horizontal seam
                var hLine = Path()
                hLine.move(to: CGPoint(x: cx - r, y: cy))
                hLine.addLine(to: CGPoint(x: cx + r, y: cy))
                context.stroke(hLine, with: .color(color), style: style)

                // Left curve
                var leftCurve = Path()
                leftCurve.move(to: CGPoint(x: cx - r * 0.45, y: cy - r))
                leftCurve.addQuadCurve(
                    to: CGPoint(x: cx - r * 0.45, y: cy + r),
                    control: CGPoint(x: cx - r * 0.85, y: cy)
                )
                context.stroke(leftCurve, with: .color(color), style: style)

                // Right curve
                var rightCurve = Path()
                rightCurve.move(to: CGPoint(x: cx + r * 0.45, y: cy - r))
                rightCurve.addQuadCurve(
                    to: CGPoint(x: cx + r * 0.45, y: cy + r),
                    control: CGPoint(x: cx + r * 0.85, y: cy)
                )
                context.stroke(rightCurve, with: .color(color), style: style)
            }
            .frame(width: 22, height: 22)

            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2.5)
                    .frame(width: 26, height: 26)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}
