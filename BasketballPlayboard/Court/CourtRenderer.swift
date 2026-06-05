import SwiftUI

enum CourtMode: String, CaseIterable {
    case half
    case full

    var displayName: String {
        switch self {
        case .half: return "ハーフ"
        case .full: return "フル"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .half: return 15.0 / 14.0
        case .full: return 15.0 / 28.0
        }
    }
}

struct CourtRenderer: Shape {
    let mode: CourtMode

    // FIBA court: 28m x 15m
    // All positions normalized: x = across court (0-15m mapped to 0-1), y = along court (0-14m or 0-28m mapped to 0-1)
    // Basket at top (y=0 side)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Court outline
        path.addRect(CGRect(x: 0, y: 0, width: w, height: h))

        switch mode {
        case .half:
            drawHalfCourt(path: &path, w: w, h: h, basketY: 0, baselineY: 0, direction: 1)
            // Center line at bottom
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            // Half of center circle at bottom
            let centerCircleR = (1.8 / 14.0) * h
            path.addArc(
                center: CGPoint(x: w / 2, y: h),
                radius: centerCircleR,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )

        case .full:
            // Center line
            path.move(to: CGPoint(x: 0, y: h / 2))
            path.addLine(to: CGPoint(x: w, y: h / 2))
            // Center circle
            let centerCircleR = (1.8 / 28.0) * h
            path.addEllipse(in: CGRect(
                x: w / 2 - centerCircleR, y: h / 2 - centerCircleR,
                width: centerCircleR * 2, height: centerCircleR * 2
            ))
            // Top half (basket at top)
            drawHalfCourt(path: &path, w: w, h: h, basketY: 0, baselineY: 0, direction: 1)
            // Bottom half (basket at bottom)
            drawHalfCourt(path: &path, w: w, h: h, basketY: h, baselineY: h, direction: -1)
        }

        return path
    }

    private func drawHalfCourt(path: inout Path, w: CGFloat, h: CGFloat, basketY: CGFloat, baselineY: CGFloat, direction: CGFloat) {
        let courtLength: CGFloat = mode == .half ? 14.0 : 28.0

        func mY(_ meters: CGFloat) -> CGFloat {
            baselineY + direction * (meters / courtLength) * h
        }
        func mX(_ meters: CGFloat) -> CGFloat {
            (meters / 15.0) * w
        }

        let basketCenterY = mY(1.575)
        let basketCenterX = w / 2

        // --- Paint / Key (4.9m wide, 5.8m from baseline) ---
        let paintW = mX(4.9)
        let paintLeft = basketCenterX - paintW / 2
        let paintTop = baselineY
        let paintBottom = mY(5.8)
        let paintH = abs(paintBottom - paintTop)
        let paintRect = CGRect(
            x: paintLeft,
            y: min(paintTop, paintBottom),
            width: paintW,
            height: paintH
        )
        path.addRect(paintRect)

        // --- Free throw circle (radius 1.8m, centered at free throw line) ---
        let ftR = abs(mY(1.8) - mY(0))
        let ftCenterY = mY(5.8)
        path.addEllipse(in: CGRect(
            x: basketCenterX - ftR, y: ftCenterY - ftR,
            width: ftR * 2, height: ftR * 2
        ))

        // --- Restricted area arc (1.25m from basket center) ---
        let raR = abs(mY(1.25) - mY(0))
        let startDeg: Double = direction > 0 ? 0 : 180
        let endDeg: Double = direction > 0 ? 180 : 360
        path.addArc(
            center: CGPoint(x: basketCenterX, y: basketCenterY),
            radius: raR,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: direction < 0
        )

        // --- Basket ring (inner diameter 0.45m) ---
        let ringR = mX(0.45 / 2)
        path.addEllipse(in: CGRect(
            x: basketCenterX - ringR, y: basketCenterY - ringR,
            width: ringR * 2, height: ringR * 2
        ))

        // --- Backboard (1.8m wide, at 1.2m from baseline) ---
        let bbY = mY(1.2)
        let bbHalfW = mX(1.8 / 2)
        path.move(to: CGPoint(x: basketCenterX - bbHalfW, y: bbY))
        path.addLine(to: CGPoint(x: basketCenterX + bbHalfW, y: bbY))

        // --- Three-point line ---
        // Arc: 6.75m from basket center
        // Straight parts: 0.9m from sideline, from baseline to where arc begins
        let threeR = mX(6.75) // Use X scale for radius since it's a distance from center
        // But the arc is a circle in real court space, which gets distorted in our non-square mapping
        // To be accurate, we use separate x/y radii
        let threeRx = mX(6.75)
        let threeRy = abs(mY(6.75) - mY(0))

        let sideX = mX(0.9)
        let rightSideX = w - mX(0.9)

        // Calculate where the arc meets the straight line (at x = 0.9m and x = 14.1m from left)
        // Circle: (x - 7.5)^2 + (y - 1.575)^2 = 6.75^2
        // At x = 0.9: (0.9 - 7.5)^2 + (y - 1.575)^2 = 6.75^2
        // (y - 1.575)^2 = 6.75^2 - 6.6^2 = 45.5625 - 43.56 = 2.0025
        // y - 1.575 = 1.4151... → y ≈ 2.99m
        let arcMeetY = mY(2.99)

        // Left straight
        path.move(to: CGPoint(x: sideX, y: baselineY))
        path.addLine(to: CGPoint(x: sideX, y: arcMeetY))

        // Arc (using elliptical path for correct proportions)
        // Angle at the straight line meeting point
        let angleAtSide = asin((6.6) / 6.75) // angle from top of circle
        let startAngleRad = Double.pi / 2 + Double(angleAtSide)
        let endAngleRad = Double.pi / 2 - Double(angleAtSide)

        let arcSegments = 40
        for i in 0...arcSegments {
            let t = Double(i) / Double(arcSegments)
            let angle = startAngleRad + t * (endAngleRad - startAngleRad)
            let px = basketCenterX - CGFloat(cos(angle)) * threeRx
            let py = basketCenterY + direction * CGFloat(sin(angle)) * threeRy
            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                path.addLine(to: CGPoint(x: px, y: py))
            }
        }

        // Right straight
        path.move(to: CGPoint(x: rightSideX, y: baselineY))
        path.addLine(to: CGPoint(x: rightSideX, y: arcMeetY))
    }
}
