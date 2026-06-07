import AVFoundation
import SwiftUI
import UIKit

class VideoExporter {
    static func export(
        play: Play,
        courtMode: CourtMode,
        showHomeVision: Bool,
        showAwayVision: Bool,
        completion: @escaping (URL?) -> Void
    ) {
        let size = CGSize(width: 1080, height: 1080)
        let fps: Int32 = 30
        let duration = play.duration
        guard duration > 0 else { completion(nil); return }

        let safeName = play.name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)_\(Int(Date().timeIntervalSince1970)).mp4")

        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(nil); return
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "video.export")
        let totalFrames = Int(duration * Double(fps)) + 1

        input.requestMediaDataWhenReady(on: queue) {
            var frame = 0
            while input.isReadyForMoreMediaData && frame < totalFrames {
                let time = Double(frame) / Double(fps)
                let presentTime = CMTime(value: CMTimeValue(frame), timescale: fps)

                guard let snapshot = play.interpolated(at: time) else {
                    frame += 1; continue
                }

                if let buffer = Self.renderFrame(
                    snapshot: snapshot,
                    courtMode: courtMode,
                    showHomeVision: showHomeVision,
                    showAwayVision: showAwayVision,
                    size: size,
                    pool: adaptor.pixelBufferPool
                ) {
                    adaptor.append(buffer, withPresentationTime: presentTime)
                }
                frame += 1
            }

            input.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    completion(writer.status == .completed ? outputURL : nil)
                }
            }
        }
    }

    private static func renderFrame(
        snapshot: PlaySnapshot,
        courtMode: CourtMode,
        showHomeVision: Bool,
        showAwayVision: Bool,
        size: CGSize,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        if let pool = pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        }
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // Flip for UIKit coordinate system
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let w = size.width
            let h = size.height
            let margin: CGFloat = 40

            // Court area
            let ratio = courtMode.aspectRatio(landscape: false)
            let courtW: CGFloat
            let courtH: CGFloat
            let availW = w - margin * 2
            let availH = h - margin * 2
            if availW / availH > ratio {
                courtH = availH
                courtW = courtH * ratio
            } else {
                courtW = availW
                courtH = courtW / ratio
            }
            let ox = (w - courtW) / 2
            let oy = (h - courtH) / 2

            // Background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Court lines
            let courtRect = CGRect(x: ox, y: oy, width: courtW, height: courtH)
            UIColor(white: 0.95, alpha: 1).setFill()
            ctx.fill(courtRect)

            let courtPath = CourtRenderer(mode: courtMode, isPortrait: true)
                .path(in: CGRect(origin: .zero, size: CGSize(width: courtW, height: courtH)))
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: ox, y: oy)
            UIColor.black.setStroke()
            courtPath.cgPath.applyWithBlock { element in
                let pts = element.pointee
                switch pts.type {
                case .moveToPoint:
                    ctx.cgContext.move(to: pts.points[0])
                case .addLineToPoint:
                    ctx.cgContext.addLine(to: pts.points[0])
                case .closeSubpath:
                    ctx.cgContext.closePath()
                default: break
                }
            }
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.strokePath()
            ctx.cgContext.restoreGState()

            func courtToScreen(_ pos: CGPoint) -> CGPoint {
                CGPoint(x: ox + pos.x * courtW, y: oy + (1 - pos.y) * courtH)
            }

            // Vision cones
            let visiblePlayers = snapshot.players.filter {
                ($0.team == .home && showHomeVision) || ($0.team == .away && showAwayVision)
            }
            if !visiblePlayers.isEmpty {
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: CGRect(x: ox, y: oy, width: courtW, height: courtH))
                let metersPerPixel = courtW / 15.0
                let visionR = 10.0 * metersPerPixel
                let coneSpread: CGFloat = .pi / 3
                let rings = 20
                let segments = 30
                for player in visiblePlayers {
                    let center = courtToScreen(player.position)
                    let baseColor: UIColor = player.team == .home ? .systemBlue : .systemRed
                    for r in (0..<rings).reversed() {
                        let outerR = visionR * CGFloat(r + 1) / CGFloat(rings)
                        let innerR = visionR * CGFloat(r) / CGFloat(rings)
                        let alpha = 0.18 * (1.0 - CGFloat(r) / CGFloat(rings))
                        let path = UIBezierPath()
                        for i in 0...segments {
                            let t = CGFloat(i) / CGFloat(segments)
                            let angle = player.facing - coneSpread / 2 + t * coneSpread - .pi / 2
                            let pt = CGPoint(x: center.x + outerR * cos(angle), y: center.y + outerR * sin(angle))
                            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                        for i in (0...segments).reversed() {
                            let t = CGFloat(i) / CGFloat(segments)
                            let angle = player.facing - coneSpread / 2 + t * coneSpread - .pi / 2
                            let pt = CGPoint(x: center.x + innerR * cos(angle), y: center.y + innerR * sin(angle))
                            path.addLine(to: pt)
                        }
                        path.close()
                        baseColor.withAlphaComponent(alpha).setFill()
                        path.fill()
                    }
                }
                ctx.cgContext.restoreGState()
            }

            // Draw lines
            for line in snapshot.lines {
                guard line.points.count >= 2 else { continue }
                let pts = line.points.map { courtToScreen($0) }
                let uiColor = line.lineColor.color.uiColor
                uiColor.setStroke()

                switch line.type {
                case .plain:
                    let path = UIBezierPath()
                    path.move(to: pts[0])
                    for i in 1..<pts.count { path.addLine(to: pts[i]) }
                    path.lineWidth = 3
                    path.lineCapStyle = .round
                    path.stroke()

                case .cut:
                    let path = UIBezierPath()
                    path.move(to: pts[0])
                    for i in 1..<pts.count { path.addLine(to: pts[i]) }
                    path.lineWidth = 3
                    path.lineCapStyle = .round
                    path.stroke()
                    Self.drawArrowhead(ctx: ctx.cgContext, pts: pts, color: uiColor)

                case .pass:
                    let path = UIBezierPath()
                    path.move(to: pts[0])
                    for i in 1..<pts.count { path.addLine(to: pts[i]) }
                    path.lineWidth = 3
                    path.lineCapStyle = .round
                    path.setLineDash([12, 8], count: 2, phase: 0)
                    path.stroke()
                    Self.drawArrowhead(ctx: ctx.cgContext, pts: pts, color: uiColor)

                case .dribble:
                    Self.drawWavyLine(ctx: ctx.cgContext, pts: pts, color: uiColor, lineWidth: 3)
                    Self.drawArrowhead(ctx: ctx.cgContext, pts: pts, color: uiColor)

                case .screen:
                    let path = UIBezierPath()
                    path.move(to: pts[0])
                    for i in 1..<pts.count { path.addLine(to: pts[i]) }
                    path.lineWidth = 3.5
                    path.lineCapStyle = .round
                    path.stroke()
                    Self.drawScreenBar(ctx: ctx.cgContext, pts: pts, color: uiColor)
                }
            }

            // Draw players
            let bodySize: CGFloat = 28
            let armLen: CGFloat = 16
            let spread: CGFloat = .pi / 3.2

            for player in snapshot.players {
                let center = courtToScreen(player.position)
                let color: UIColor = player.team == .home ? .systemBlue : .systemRed

                // Arms
                color.setStroke()
                for side: CGFloat in [-1, 1] {
                    let angle = player.facing + spread * side
                    let startX = center.x + (bodySize/2) * sin(angle) * 0.8
                    let startY = center.y - (bodySize/2) * cos(angle) * 0.8
                    let endX = center.x + (bodySize/2 + armLen) * sin(angle)
                    let endY = center.y - (bodySize/2 + armLen) * cos(angle)
                    let arm = UIBezierPath()
                    arm.move(to: CGPoint(x: startX, y: startY))
                    arm.addLine(to: CGPoint(x: endX, y: endY))
                    arm.lineWidth = 4
                    arm.lineCapStyle = .round
                    arm.stroke()
                }

                // Body
                let bodyRect = CGRect(x: center.x - bodySize/2, y: center.y - bodySize/2,
                                      width: bodySize, height: bodySize)
                color.setFill()
                ctx.cgContext.fillEllipse(in: bodyRect)
                UIColor.white.setStroke()
                ctx.cgContext.setLineWidth(1.5)
                ctx.cgContext.strokeEllipse(in: bodyRect)

                // Number
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: UIColor.white,
                ]
                let numStr = player.number as NSString
                let numSize = numStr.size(withAttributes: attrs)
                numStr.draw(at: CGPoint(x: center.x - numSize.width/2,
                                        y: center.y - numSize.height/2),
                            withAttributes: attrs)
            }

            // Draw balls
            for ball in snapshot.balls {
                let center = courtToScreen(ball.position)
                let ballSize: CGFloat = 24
                let ballRect = CGRect(x: center.x - ballSize/2, y: center.y - ballSize/2,
                                      width: ballSize, height: ballSize)
                UIColor.orange.setFill()
                ctx.cgContext.fillEllipse(in: ballRect)
                UIColor(red: 0.6, green: 0.3, blue: 0, alpha: 1).setStroke()
                ctx.cgContext.setLineWidth(1)
                ctx.cgContext.strokeEllipse(in: ballRect)
            }
        }

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }

        return buffer
    }
    private static func drawArrowhead(ctx: CGContext, pts: [CGPoint], color: UIColor) {
        guard pts.count >= 2 else { return }
        let tip = pts.last!
        var prev = pts[pts.count - 2]
        for i in stride(from: pts.count - 2, through: 0, by: -1) {
            if hypot(pts[i].x - tip.x, pts[i].y - tip.y) >= 10 { prev = pts[i]; break }
        }
        let angle = atan2(tip.y - prev.y, tip.x - prev.x)
        let len: CGFloat = 14
        let spread: CGFloat = .pi / 5
        ctx.saveGState()
        color.setStroke()
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.move(to: tip)
        ctx.addLine(to: CGPoint(x: tip.x - len * cos(angle - spread), y: tip.y - len * sin(angle - spread)))
        ctx.move(to: tip)
        ctx.addLine(to: CGPoint(x: tip.x - len * cos(angle + spread), y: tip.y - len * sin(angle + spread)))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawWavyLine(ctx: CGContext, pts: [CGPoint], color: UIColor, lineWidth: CGFloat) {
        guard pts.count >= 2 else { return }
        var totalDist: CGFloat = 0
        var segments: [(CGPoint, CGFloat)] = [(pts[0], 0)]
        for i in 1..<pts.count {
            totalDist += hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y)
            segments.append((pts[i], totalDist))
        }
        guard totalDist > 0 else { return }
        ctx.saveGState()
        color.setStroke()
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let step: CGFloat = 2
        let amplitude: CGFloat = 5
        let wavelength: CGFloat = 12
        var dist: CGFloat = 0
        var first = true
        while dist <= totalDist - 16 {
            var segIdx = 0
            for i in 1..<segments.count {
                if segments[i].1 >= dist { segIdx = i - 1; break }
            }
            let (p0, d0) = segments[segIdx]
            let (p1, d1) = segments[min(segIdx + 1, segments.count - 1)]
            let segLen = d1 - d0
            let t = segLen > 0 ? (dist - d0) / segLen : 0
            let bx = p0.x + (p1.x - p0.x) * t
            let by = p0.y + (p1.y - p0.y) * t
            let dx = p1.x - p0.x, dy = p1.y - p0.y
            let len = hypot(dx, dy)
            let nx = len > 0 ? -dy / len : 0
            let ny = len > 0 ? dx / len : 0
            let wave = sin(dist / wavelength * .pi * 2) * amplitude
            let px = bx + nx * wave, py = by + ny * wave
            if first { ctx.move(to: CGPoint(x: px, y: py)); first = false }
            else { ctx.addLine(to: CGPoint(x: px, y: py)) }
            dist += step
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawScreenBar(ctx: CGContext, pts: [CGPoint], color: UIColor) {
        guard pts.count >= 2 else { return }
        let tip = pts.last!
        let prev = pts[pts.count - 2]
        let angle = atan2(tip.y - prev.y, tip.x - prev.x)
        let barLen: CGFloat = 12
        ctx.saveGState()
        color.setStroke()
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: tip.x - barLen * cos(angle + .pi/2), y: tip.y - barLen * sin(angle + .pi/2)))
        ctx.addLine(to: CGPoint(x: tip.x + barLen * cos(angle + .pi/2), y: tip.y + barLen * sin(angle + .pi/2)))
        ctx.strokePath()
        ctx.restoreGState()
    }
}

private extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
}
