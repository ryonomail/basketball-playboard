import SwiftUI

enum CourtMode: String, CaseIterable {
    case half
    case full

    var displayName: String {
        switch self {
        case .half: return "Half"
        case .full: return "Full"
        }
    }

    func aspectRatio(landscape: Bool) -> CGFloat {
        switch self {
        case .half:
            // Half: across(15m)→X, along(14m)→Y in both orientations
            return 15.0 / 14.0
        case .full:
            // Full landscape: along(28m)→X, across(15m)→Y
            // Full portrait: across(15m)→X, along(28m)→Y
            return landscape ? 28.0 / 15.0 : 15.0 / 28.0
        }
    }

    var courtLength: CGFloat {
        switch self {
        case .half: return 14.0
        case .full: return 28.0
        }
    }
}

struct CourtRenderer: Shape {
    let mode: CourtMode
    let isPortrait: Bool

    private var courtLen: CGFloat { mode.courtLength }

    // Map court coordinates (across: 0-15m, along: 0-courtLen) to screen point
    // Portrait half:   across→X, along→Y inverted (basket at bottom)
    // Landscape half:  across→X, along→Y inverted (basket at bottom)
    // Portrait full:   across→X, along→Y (baskets at top & bottom)
    // Portrait (half/full): across→X, along→Y inverted (near ring at bottom)
    // Landscape half:      across→X, along→Y inverted (near ring at bottom)
    // Landscape full:      along→X, across→Y (baskets at left & right)
    private func pt(_ across: CGFloat, _ along: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let ax = across / 15.0
        let ay = along / courtLen
        if isPortrait {
            return CGPoint(x: ax * w, y: (1 - ay) * h)
        } else if mode == .half {
            return CGPoint(x: ax * w, y: (1 - ay) * h)
        } else {
            return CGPoint(x: ay * w, y: ax * h)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Outline
        path.addRect(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))

        switch mode {
        case .half:
            drawHalf(&path, w: w, h: h, baseAlong: 0, dir: 1)
            // Half-court line
            addLine(&path, from: pt(0, 14, w, h), to: pt(15, 14, w, h))
            // Half center circle
            addArc(&path, center: (7.5, 14), radius: 1.8, startDeg: 0, endDeg: 180, dir: -1, w: w, h: h)

        case .full:
            drawHalf(&path, w: w, h: h, baseAlong: 0, dir: 1)
            drawHalf(&path, w: w, h: h, baseAlong: 28, dir: -1)
            // Center line
            addLine(&path, from: pt(0, 14, w, h), to: pt(15, 14, w, h))
            // Full center circle
            addCircle(&path, center: (7.5, 14), radius: 1.8, w: w, h: h)
        }

        return path
    }

    private func drawHalf(_ path: inout Path, w: CGFloat, h: CGFloat, baseAlong: CGFloat, dir: CGFloat) {
        func al(_ m: CGFloat) -> CGFloat { baseAlong + dir * m }

        let bx: CGFloat = 7.5 // basket across center
        let basketAlong = al(1.575)

        // --- Paint (4.9m wide × 5.8m from baseline, skip baseline edge to avoid double stroke) ---
        addLine(&path, from: pt(bx - 2.45, al(0), w, h), to: pt(bx - 2.45, al(5.8), w, h))
        addLine(&path, from: pt(bx - 2.45, al(5.8), w, h), to: pt(bx + 2.45, al(5.8), w, h))
        addLine(&path, from: pt(bx + 2.45, al(5.8), w, h), to: pt(bx + 2.45, al(0), w, h))

        // --- Free throw circle (1.8m radius at free throw line) ---
        addCircle(&path, center: (bx, al(5.8)), radius: 1.8, w: w, h: h)

        // --- Restricted area arc (1.25m from basket center) ---
        let raSegs = 30
        for i in 0...raSegs {
            let t = CGFloat(i) / CGFloat(raSegs)
            let angle = CGFloat.pi * t
            let ca = bx - 1.25 * cos(angle)
            let cl = al(1.575 + 1.25 * sin(angle))
            let sp = pt(ca, cl, w, h)
            if i == 0 { path.move(to: sp) } else { path.addLine(to: sp) }
        }

        // --- Basket ring (diameter 0.45m) ---
        let basketPt = pt(bx, basketAlong, w, h)
        let ringScreenR: CGFloat = 4
        path.addEllipse(in: CGRect(x: basketPt.x - ringScreenR, y: basketPt.y - ringScreenR,
                                   width: ringScreenR * 2, height: ringScreenR * 2))

        // --- Backboard (1.8m wide at 1.2m from baseline) ---
        addLine(&path, from: pt(bx - 0.9, al(1.2), w, h), to: pt(bx + 0.9, al(1.2), w, h))

        // --- Three-point line ---
        let threeR: CGFloat = 6.75
        let sideAcross: CGFloat = 0.9
        let distFromCenter = bx - sideAcross // 6.6

        // Arc meet point
        let meetAlongFromBase = 1.575 + sqrt(threeR * threeR - distFromCenter * distFromCenter)

        // Left straight
        addLine(&path, from: pt(sideAcross, al(0), w, h), to: pt(sideAcross, al(meetAlongFromBase), w, h))
        // Right straight
        addLine(&path, from: pt(15 - sideAcross, al(0), w, h), to: pt(15 - sideAcross, al(meetAlongFromBase), w, h))

        // Arc: parameterized as across = bx - R*cos(θ), along = 1.575 + R*sin(θ)
        // Left meeting:  cos(θ) = distFromCenter/R → θ = arcAngle (small, near 0)
        // Right meeting: cos(θ) = -distFromCenter/R → θ = π - arcAngle (near π)
        let arcAngle = acos(distFromCenter / threeR)
        let arcSegs = 50
        for i in 0...arcSegs {
            let t = CGFloat(i) / CGFloat(arcSegs)
            let angle = arcAngle + t * (CGFloat.pi - 2 * arcAngle)
            let ca = bx - threeR * cos(angle)
            let rawAlong = 1.575 + threeR * sin(angle)
            let sp = pt(ca, al(rawAlong), w, h)
            if i == 0 { path.move(to: sp) } else { path.addLine(to: sp) }
        }
    }

    // MARK: - Drawing Helpers

    private func addLine(_ path: inout Path, from: CGPoint, to: CGPoint) {
        path.move(to: from)
        path.addLine(to: to)
    }

    private func addCircle(_ path: inout Path, center: (CGFloat, CGFloat), radius: CGFloat, w: CGFloat, h: CGFloat) {
        let segs = 40
        for i in 0...segs {
            let angle = CGFloat.pi * 2 * CGFloat(i) / CGFloat(segs)
            let ca = center.0 + radius * cos(angle)
            let cl = center.1 + radius * sin(angle)
            let sp = pt(ca, cl, w, h)
            if i == 0 { path.move(to: sp) } else { path.addLine(to: sp) }
        }
    }

    private func addArc(_ path: inout Path, center: (CGFloat, CGFloat), radius: CGFloat, startDeg: CGFloat, endDeg: CGFloat, dir: CGFloat, w: CGFloat, h: CGFloat) {
        let segs = 30
        let startRad = startDeg * .pi / 180
        let endRad = endDeg * .pi / 180
        for i in 0...segs {
            let t = CGFloat(i) / CGFloat(segs)
            let angle = startRad + t * (endRad - startRad)
            let ca = center.0 + radius * cos(angle)
            let cl = center.1 + dir * radius * sin(angle)
            let sp = pt(ca, cl, w, h)
            if i == 0 { path.move(to: sp) } else { path.addLine(to: sp) }
        }
    }

    private func normalizedRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
