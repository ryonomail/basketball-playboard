import SwiftUI

struct CourtRenderer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Court outline
        path.addRect(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))

        // Center line
        path.move(to: CGPoint(x: 0, y: h / 2))
        path.addLine(to: CGPoint(x: w, y: h / 2))

        // Center circle
        let centerCircleRadius = min(w, h) * 0.12
        path.addEllipse(in: CGRect(
            x: w / 2 - centerCircleRadius,
            y: h / 2 - centerCircleRadius,
            width: centerCircleRadius * 2,
            height: centerCircleRadius * 2
        ))

        // Top half court (basket at top)
        addHalfCourt(to: &path, rect: rect, top: true)

        // Bottom half court (basket at bottom)
        addHalfCourt(to: &path, rect: rect, top: false)

        return path
    }

    private func addHalfCourt(to path: inout Path, rect: CGRect, top: Bool) {
        let w = rect.width
        let h = rect.height

        let paintWidth = w * 0.4
        let paintHeight = h * 0.22
        let paintX = (w - paintWidth) / 2

        let paintY: CGFloat
        let freeThrowY: CGFloat
        let basketY: CGFloat
        let threePointBaseY: CGFloat
        let threePointArcCenterY: CGFloat

        if top {
            paintY = 0
            freeThrowY = paintHeight
            basketY = h * 0.05
            threePointBaseY = 0
            threePointArcCenterY = basketY
        } else {
            paintY = h - paintHeight
            freeThrowY = h - paintHeight
            basketY = h - h * 0.05
            threePointBaseY = h
            threePointArcCenterY = basketY
        }

        // Paint / key area
        path.addRect(CGRect(x: paintX, y: paintY, width: paintWidth, height: paintHeight))

        // Free throw circle
        let ftRadius = paintWidth / 2
        path.addEllipse(in: CGRect(
            x: w / 2 - ftRadius,
            y: freeThrowY - ftRadius,
            width: ftRadius * 2,
            height: ftRadius * 2
        ))

        // Basket (small circle)
        let basketRadius: CGFloat = 6
        path.addEllipse(in: CGRect(
            x: w / 2 - basketRadius,
            y: basketY - basketRadius,
            width: basketRadius * 2,
            height: basketRadius * 2
        ))

        // Backboard
        let backboardWidth: CGFloat = w * 0.1
        let backboardY = top ? basketY - basketRadius - 3 : basketY + basketRadius + 3
        path.move(to: CGPoint(x: w / 2 - backboardWidth / 2, y: backboardY))
        path.addLine(to: CGPoint(x: w / 2 + backboardWidth / 2, y: backboardY))

        // Three-point line
        let threePointSideX = w * 0.07
        let threePointRadius = w * 0.42

        if top {
            path.move(to: CGPoint(x: threePointSideX, y: 0))
            path.addLine(to: CGPoint(x: threePointSideX, y: h * 0.12))
            path.addArc(
                center: CGPoint(x: w / 2, y: threePointArcCenterY),
                radius: threePointRadius,
                startAngle: .degrees(180 - 12),
                endAngle: .degrees(12),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: w - threePointSideX, y: 0))
        } else {
            path.move(to: CGPoint(x: threePointSideX, y: h))
            path.addLine(to: CGPoint(x: threePointSideX, y: h - h * 0.12))
            path.addArc(
                center: CGPoint(x: w / 2, y: threePointArcCenterY),
                radius: threePointRadius,
                startAngle: .degrees(180 + 12),
                endAngle: .degrees(360 - 12),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: w - threePointSideX, y: h))
        }
    }
}
