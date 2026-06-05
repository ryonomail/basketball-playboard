import SwiftUI

struct LineDrawingView: View {
    let lines: [DrawingLine]

    var body: some View {
        Canvas { context, size in
            for line in lines {
                guard line.points.count >= 2 else { continue }

                var path = Path()
                let pts = line.points

                switch line.type {
                case .cut:
                    path = smoothPath(points: pts)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2.5))
                    drawArrowhead(context: context, points: pts, color: .black)

                case .pass:
                    path = smoothPath(points: pts)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    drawArrowhead(context: context, points: pts, color: .black)

                case .dribble:
                    path = smoothPath(points: pts)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2.5, dash: [2, 4]))
                    drawArrowhead(context: context, points: pts, color: .black)

                case .screen:
                    path = smoothPath(points: pts)
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 3))
                    drawScreenEnd(context: context, points: pts)
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
        } else {
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
        }
        return path
    }

    private func drawArrowhead(context: GraphicsContext, points: [CGPoint], color: Color) {
        guard points.count >= 2 else { return }
        let last = points[points.count - 1]
        let prev = points[points.count - 2]
        let angle = atan2(last.y - prev.y, last.x - prev.x)
        let arrowLength: CGFloat = 12
        let arrowAngle: CGFloat = .pi / 6

        var arrow = Path()
        arrow.move(to: last)
        arrow.addLine(to: CGPoint(
            x: last.x - arrowLength * cos(angle - arrowAngle),
            y: last.y - arrowLength * sin(angle - arrowAngle)
        ))
        arrow.move(to: last)
        arrow.addLine(to: CGPoint(
            x: last.x - arrowLength * cos(angle + arrowAngle),
            y: last.y - arrowLength * sin(angle + arrowAngle)
        ))
        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func drawScreenEnd(context: GraphicsContext, points: [CGPoint]) {
        guard points.count >= 2 else { return }
        let last = points[points.count - 1]
        let prev = points[points.count - 2]
        let angle = atan2(last.y - prev.y, last.x - prev.x)
        let barLength: CGFloat = 10

        var bar = Path()
        bar.move(to: CGPoint(
            x: last.x - barLength * cos(angle + .pi / 2),
            y: last.y - barLength * sin(angle + .pi / 2)
        ))
        bar.addLine(to: CGPoint(
            x: last.x + barLength * cos(angle + .pi / 2),
            y: last.y + barLength * sin(angle + .pi / 2)
        ))
        context.stroke(bar, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}
