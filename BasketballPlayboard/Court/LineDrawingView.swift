import SwiftUI

struct LineDrawingView: View {
    let lines: [DrawingLine]
    var isPortrait: Bool = false
    var isHalf: Bool = false

    var body: some View {
        Canvas { context, size in
            for line in lines {
                guard line.points.count >= 2 else { continue }
                let color = line.lineColor.color
                let pts = line.points.map { mapPoint($0, size: size) }

                switch line.type {
                case .plain:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                case .cut:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    drawArrowhead(context: context, points: pts, color: color)

                case .pass:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [10, 7]))
                    drawArrowhead(context: context, points: pts, color: color)

                case .dribble:
                    let trimmed = trimEnd(pts, by: 14)
                    let wavyPath = wavyLine(points: trimmed, amplitude: 4, wavelength: 10)
                    context.stroke(wavyPath, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    drawArrowhead(context: context, points: pts, color: color)

                case .screen:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    drawScreenBar(context: context, points: pts, color: color)
                }
            }
        }
    }

    private func mapPoint(_ p: CGPoint, size: CGSize) -> CGPoint {
        if isPortrait {
            return CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        } else if isHalf {
            return CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        } else {
            return CGPoint(x: p.y * size.width, y: p.x * size.height)
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i - 1].x + points[i].x) / 2,
                y: (points[i - 1].y + points[i].y) / 2
            )
            path.addQuadCurve(to: mid, control: points[i - 1])
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }

    private func trimEnd(_ points: [CGPoint], by distance: CGFloat) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        var remaining = distance
        var result = points
        while result.count >= 2 && remaining > 0 {
            let last = result[result.count - 1]
            let prev = result[result.count - 2]
            let segLen = hypot(last.x - prev.x, last.y - prev.y)
            if segLen <= remaining {
                remaining -= segLen
                result.removeLast()
            } else {
                let t = (segLen - remaining) / segLen
                result[result.count - 1] = CGPoint(
                    x: prev.x + (last.x - prev.x) * t,
                    y: prev.y + (last.y - prev.y) * t
                )
                break
            }
        }
        return result
    }

    private func drawArrowhead(context: GraphicsContext, points: [CGPoint], color: Color) {
        guard points.count >= 2 else { return }
        let tip = points.last!
        // Find a point far enough back for a stable angle
        var prev = points[points.count - 2]
        let minDist: CGFloat = 8
        for i in stride(from: points.count - 2, through: 0, by: -1) {
            let d = hypot(points[i].x - tip.x, points[i].y - tip.y)
            if d >= minDist { prev = points[i]; break }
        }
        let angle = atan2(tip.y - prev.y, tip.x - prev.x)
        let len: CGFloat = 12
        let spread: CGFloat = .pi / 5
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle - spread), y: tip.y - len * sin(angle - spread)))
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle + spread), y: tip.y - len * sin(angle + spread)))
        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func wavyLine(points: [CGPoint], amplitude: CGFloat, wavelength: CGFloat) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        // Walk along the polyline and oscillate perpendicular
        var totalDist: CGFloat = 0
        var segments: [(CGPoint, CGFloat)] = [(points[0], 0)]
        for i in 1..<points.count {
            let d = hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            totalDist += d
            segments.append((points[i], totalDist))
        }
        guard totalDist > 0 else { return path }

        let step: CGFloat = 2
        var first = true
        var dist: CGFloat = 0
        while dist <= totalDist {
            // Find segment
            var segIdx = 0
            for i in 1..<segments.count {
                if segments[i].1 >= dist { segIdx = i - 1; break }
            }
            let (p0, d0) = segments[segIdx]
            let (p1, d1) = segments[min(segIdx + 1, segments.count - 1)]
            let segLen = d1 - d0
            let t = segLen > 0 ? (dist - d0) / segLen : 0
            let baseX = p0.x + (p1.x - p0.x) * t
            let baseY = p0.y + (p1.y - p0.y) * t

            // Perpendicular direction
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let len = hypot(dx, dy)
            let nx = len > 0 ? -dy / len : 0
            let ny = len > 0 ? dx / len : 0

            let wave = sin(dist / wavelength * .pi * 2) * amplitude
            let px = baseX + nx * wave
            let py = baseY + ny * wave

            if first { path.move(to: CGPoint(x: px, y: py)); first = false }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
            dist += step
        }
        return path
    }

    private func drawScreenBar(context: GraphicsContext, points: [CGPoint], color: Color) {
        guard points.count >= 2 else { return }
        let tip = points.last!
        let prev = points[points.count - 2]
        let angle = atan2(tip.y - prev.y, tip.x - prev.x)
        let barLen: CGFloat = 10
        var bar = Path()
        bar.move(to: CGPoint(x: tip.x - barLen * cos(angle + .pi / 2), y: tip.y - barLen * sin(angle + .pi / 2)))
        bar.addLine(to: CGPoint(x: tip.x + barLen * cos(angle + .pi / 2), y: tip.y + barLen * sin(angle + .pi / 2)))
        context.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
    }
}
