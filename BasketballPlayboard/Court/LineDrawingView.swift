import SwiftUI

struct LineDrawingView: View {
    let lines: [DrawingLine]

    var body: some View {
        Canvas { context, size in
            for line in lines {
                guard line.points.count >= 2 else { continue }
                let color = line.lineColor.color
                let pts = line.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

                switch line.type {
                case .cut:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    drawArrowhead(context: context, points: pts, color: color)

                case .pass:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [10, 7]))
                    drawArrowhead(context: context, points: pts, color: color)

                case .dribble:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 5]))
                    drawArrowhead(context: context, points: pts, color: color)

                case .screen:
                    let path = smoothPath(points: pts)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    drawScreenBar(context: context, points: pts, color: color)
                }
            }
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
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }

    private func drawArrowhead(context: GraphicsContext, points: [CGPoint], color: Color) {
        guard points.count >= 2 else { return }
        let tip = points.last!
        let prev = points[points.count - 2]
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
