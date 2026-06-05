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

            // Arms that rotate with facing
            ArmsShape()
                .stroke(teamColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.radians(player.facing))

            // Body circle
            Circle()
                .fill(teamColor)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(isSelected ? Color.yellow : Color.white, lineWidth: isSelected ? 2.5 : 1.2)
                )
                .overlay(
                    Text(player.number)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .frame(width: 80, height: 80)
        .contentShape(Circle().size(width: 80, height: 80))
    }
}

// Two arms extending from the body circle, pointing in the "up" direction (facing=0)
struct ArmsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let bodyR: CGFloat = rect.width * 0.37
        let armLen: CGFloat = rect.width * 0.42
        let spread: CGFloat = .pi / 3.2 // angle from forward direction

        // Left arm: from body edge, angled forward-left
        let lStartX = cx + bodyR * sin(-spread)
        let lStartY = cy - bodyR * cos(-spread)
        let lEndX = cx + (bodyR + armLen) * sin(-spread)
        let lEndY = cy - (bodyR + armLen) * cos(-spread)
        path.move(to: CGPoint(x: lStartX, y: lStartY))
        path.addLine(to: CGPoint(x: lEndX, y: lEndY))

        // Right arm: from body edge, angled forward-right
        let rStartX = cx + bodyR * sin(spread)
        let rStartY = cy - bodyR * cos(spread)
        let rEndX = cx + (bodyR + armLen) * sin(spread)
        let rEndY = cy - (bodyR + armLen) * cos(spread)
        path.move(to: CGPoint(x: rStartX, y: rStartY))
        path.addLine(to: CGPoint(x: rEndX, y: rEndY))

        return path
    }
}

struct InteractivePlayerView: View {
    let player: Player
    let isSelected: Bool
    let screenPosition: CGPoint
    var onMove: ((CGPoint) -> Void)? = nil
    var onRotate: ((Double) -> Void)? = nil
    var onMoveEnd: (() -> Void)? = nil

    @State private var gestureMode: GestureMode = .undecided

    private enum GestureMode {
        case undecided, move, rotate
    }

    var body: some View {
        PlayerMarkerView(player: player, isSelected: isSelected)
            .position(screenPosition)
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if gestureMode == .undecided {
                            let startDist = hypot(
                                value.startLocation.x - screenPosition.x,
                                value.startLocation.y - screenPosition.y
                            )
                            gestureMode = startDist > 18 ? .rotate : .move
                        }

                        switch gestureMode {
                        case .move:
                            onMove?(value.location)
                        case .rotate:
                            let dx = value.location.x - screenPosition.x
                            let dy = value.location.y - screenPosition.y
                            let angle = atan2(dx, -dy)
                            onRotate?(angle)
                        case .undecided:
                            break
                        }
                    }
                    .onEnded { _ in
                        if gestureMode == .move {
                            onMoveEnd?()
                        }
                        gestureMode = .undecided
                    }
            )
    }
}

struct VisionCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let bottom = rect.maxY
        let spread: CGFloat = .pi / 3
        let length = rect.height

        path.move(to: CGPoint(x: cx, y: bottom))
        path.addArc(
            center: CGPoint(x: cx, y: bottom),
            radius: length,
            startAngle: .radians(Double(-CGFloat.pi / 2 + spread / 2)),
            endAngle: .radians(Double(-CGFloat.pi / 2 - spread / 2)),
            clockwise: true
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
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.35, blue: 0.0)],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .frame(width: 22, height: 22)

            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r = size.width / 2 - 1
                let style = StrokeStyle(lineWidth: 0.8, lineCap: .round)
                let color: Color = .black.opacity(0.45)

                var vLine = Path()
                vLine.move(to: CGPoint(x: cx, y: cy - r))
                vLine.addLine(to: CGPoint(x: cx, y: cy + r))
                context.stroke(vLine, with: .color(color), style: style)

                var hLine = Path()
                hLine.move(to: CGPoint(x: cx - r, y: cy))
                hLine.addLine(to: CGPoint(x: cx + r, y: cy))
                context.stroke(hLine, with: .color(color), style: style)

                var leftCurve = Path()
                leftCurve.move(to: CGPoint(x: cx - r * 0.45, y: cy - r))
                leftCurve.addQuadCurve(
                    to: CGPoint(x: cx - r * 0.45, y: cy + r),
                    control: CGPoint(x: cx - r * 0.85, y: cy)
                )
                context.stroke(leftCurve, with: .color(color), style: style)

                var rightCurve = Path()
                rightCurve.move(to: CGPoint(x: cx + r * 0.45, y: cy - r))
                rightCurve.addQuadCurve(
                    to: CGPoint(x: cx + r * 0.45, y: cy + r),
                    control: CGPoint(x: cx + r * 0.85, y: cy)
                )
                context.stroke(rightCurve, with: .color(color), style: style)
            }
            .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2.5)
                    .frame(width: 26, height: 26)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}
