import SwiftUI

struct PlayerMarkerView: View {
    let player: Player
    let isSelected: Bool
    var scale: CGFloat = 1.0
    var showArms: Bool = true

    private var teamColor: Color {
        player.team == .home ? .blue : .red
    }

    private var bodySize: CGFloat { 30 * scale }
    private var armsFrame: CGFloat { 40 * scale }
    private var outerFrame: CGFloat { 90 * scale }

    var body: some View {
        ZStack {
            if showArms {
                ArmsShape()
                    .stroke(teamColor, style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round))
                    .frame(width: armsFrame, height: armsFrame)
                    .rotationEffect(.radians(player.facing))
            }

            Circle()
                .fill(teamColor)
                .frame(width: bodySize, height: bodySize)
                .overlay(
                    Circle().stroke(isSelected ? Color.yellow : Color.white,
                                    lineWidth: isSelected ? 3 * scale : 1.5 * scale)
                )
                .overlay(
                    Text(player.number)
                        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 2 * scale, x: 0, y: 1)
        .frame(width: outerFrame, height: outerFrame)
    }
}

struct ArmsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let bodyR: CGFloat = rect.width * 0.37
        let armLen: CGFloat = rect.width * 0.55
        let spread: CGFloat = .pi / 3.2

        let lStartX = cx + bodyR * sin(-spread)
        let lStartY = cy - bodyR * cos(-spread)
        let lEndX = cx + (bodyR + armLen) * sin(-spread)
        let lEndY = cy - (bodyR + armLen) * cos(-spread)
        path.move(to: CGPoint(x: lStartX, y: lStartY))
        path.addLine(to: CGPoint(x: lEndX, y: lEndY))

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
    var scale: CGFloat = 1.0
    var interactive: Bool = true
    var showArms: Bool = true
    var onMove: ((CGPoint) -> Void)? = nil
    var onRotate: ((Double) -> Void)? = nil
    var onMoveEnd: (() -> Void)? = nil

    @State private var gestureMode: GestureMode = .undecided

    private enum GestureMode {
        case undecided, move, rotate
    }

    private var hitSize: CGFloat { 44 * scale }
    private var moveThreshold: CGFloat { 12 * scale }

    var body: some View {
        PlayerMarkerView(player: player, isSelected: isSelected, scale: scale, showArms: showArms)
            .position(screenPosition)
            .contentShape(Circle().size(width: hitSize, height: hitSize)
                .offset(x: screenPosition.x - hitSize / 2, y: screenPosition.y - hitSize / 2))
            .gesture(
                interactive ?
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if gestureMode == .undecided {
                            let startDist = hypot(
                                value.startLocation.x - screenPosition.x,
                                value.startLocation.y - screenPosition.y
                            )
                            gestureMode = startDist > moveThreshold ? .rotate : .move
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
                : nil
            )
            .allowsHitTesting(interactive)
    }
}

// Vision cone layer rendered on the court with proper 10m scale and gradient
struct VisionConeLayer: View {
    let players: [Player]
    let courtSize: CGSize
    let origin: CGPoint
    let isPortrait: Bool
    let courtMode: CourtMode

    private var visionRadius: CGFloat {
        let metersPerPixel: CGFloat
        if isPortrait {
            metersPerPixel = courtSize.width / 15.0
        } else if courtMode == .full {
            metersPerPixel = courtSize.height / 15.0
        } else {
            metersPerPixel = courtSize.width / 15.0
        }
        return 10.0 * metersPerPixel
    }

    private func screenPos(for player: Player) -> CGPoint {
        if isPortrait {
            return CGPoint(x: origin.x + player.position.x * courtSize.width,
                           y: origin.y + (1 - player.position.y) * courtSize.height)
        } else if courtMode == .half {
            return CGPoint(x: origin.x + player.position.x * courtSize.width,
                           y: origin.y + (1 - player.position.y) * courtSize.height)
        } else {
            return CGPoint(x: origin.x + player.position.y * courtSize.width,
                           y: origin.y + player.position.x * courtSize.height)
        }
    }

    var body: some View {
        Canvas { context, size in
            let spread: CGFloat = .pi / 3
            let segments = 30
            let rings = 20

            for player in players {
                let center = screenPos(for: player)
                let baseColor: Color = player.team == .home ? .blue : .red
                let facing = player.facing

                for r in (0..<rings).reversed() {
                    let outerR = visionRadius * CGFloat(r + 1) / CGFloat(rings)
                    let innerR = visionRadius * CGFloat(r) / CGFloat(rings)
                    let alpha = 0.18 * (1.0 - CGFloat(r) / CGFloat(rings))

                    var strip = Path()
                    for i in 0...segments {
                        let t = CGFloat(i) / CGFloat(segments)
                        let angle = facing - spread / 2 + t * spread - .pi / 2
                        let x = center.x + outerR * cos(angle)
                        let y = center.y + outerR * sin(angle)
                        if i == 0 { strip.move(to: CGPoint(x: x, y: y)) }
                        else { strip.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    for i in (0...segments).reversed() {
                        let t = CGFloat(i) / CGFloat(segments)
                        let angle = facing - spread / 2 + t * spread - .pi / 2
                        let x = center.x + innerR * cos(angle)
                        let y = center.y + innerR * sin(angle)
                        strip.addLine(to: CGPoint(x: x, y: y))
                    }
                    strip.closeSubpath()
                    context.fill(strip, with: .color(baseColor.opacity(alpha)))
                }
            }
        }
    }
}

struct BallView: View {
    let isSelected: Bool
    var scale: CGFloat = 1.0

    private var ballSize: CGFloat { 28 * scale }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.35, blue: 0.0)],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: ballSize * 0.64
                    )
                )
                .frame(width: ballSize, height: ballSize)

            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let r = size.width / 2 - 1
                let style = StrokeStyle(lineWidth: 1.0 * scale, lineCap: .round)
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
            .frame(width: ballSize, height: ballSize)

            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 3 * scale)
                    .frame(width: ballSize + 6 * scale, height: ballSize + 6 * scale)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2 * scale, x: 0, y: 1)
    }
}
