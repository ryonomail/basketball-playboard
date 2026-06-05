import SwiftUI

struct PlaybackView: View {
    let play: Play
    @Environment(\.dismiss) var dismiss
    @State private var currentFrameIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var animationProgress: CGFloat = 0
    @State private var timer: Timer? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let courtSize = courtSize(in: geo.size)
                    let courtOrigin = CGPoint(
                        x: (geo.size.width - courtSize.width) / 2,
                        y: (geo.size.height - courtSize.height) / 2
                    )

                    ZStack {
                        Color.white

                        CourtRenderer()
                            .stroke(Color.black, lineWidth: 1.5)
                            .frame(width: courtSize.width, height: courtSize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                        if play.frames.indices.contains(currentFrameIndex) {
                            let frame = play.frames[currentFrameIndex]

                            LineDrawingView(lines: frame.lines)
                                .frame(width: courtSize.width, height: courtSize.height)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)

                            ForEach(interpolatedPlayers(courtSize: courtSize, courtOrigin: courtOrigin)) { player in
                                PlayerMarkerView(player: player, isSelected: false)
                                    .position(
                                        x: courtOrigin.x + player.position.x * courtSize.width,
                                        y: courtOrigin.y + player.position.y * courtSize.height
                                    )
                            }
                        }
                    }
                }

                // Playback controls
                VStack(spacing: 12) {
                    // Progress
                    ProgressView(value: totalProgress)
                        .padding(.horizontal)

                    HStack(spacing: 24) {
                        Button {
                            goToPreviousFrame()
                        } label: {
                            Image(systemName: "backward.frame")
                                .font(.title2)
                        }
                        .disabled(currentFrameIndex == 0)

                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                        }

                        Button {
                            goToNextFrame()
                        } label: {
                            Image(systemName: "forward.frame")
                                .font(.title2)
                        }
                        .disabled(currentFrameIndex >= play.frames.count - 1)
                    }

                    // Speed control
                    HStack {
                        Text("速度:")
                            .font(.caption)
                        ForEach([0.5, 1.0, 2.0], id: \.self) { speed in
                            Button {
                                playbackSpeed = speed
                            } label: {
                                Text("\(speed, specifier: "%.1f")x")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(playbackSpeed == speed ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(playbackSpeed == speed ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Text("フレーム \(currentFrameIndex + 1) / \(play.frames.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("再生: \(play.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private var totalProgress: Double {
        guard play.frames.count > 1 else { return 0 }
        return (Double(currentFrameIndex) + Double(animationProgress)) / Double(play.frames.count - 1)
    }

    private func interpolatedPlayers(courtSize: CGSize, courtOrigin: CGPoint) -> [Player] {
        guard play.frames.indices.contains(currentFrameIndex) else { return [] }
        let current = play.frames[currentFrameIndex].players

        let nextIndex = currentFrameIndex + 1
        guard nextIndex < play.frames.count, animationProgress > 0 else {
            return current
        }

        let next = play.frames[nextIndex].players
        return current.enumerated().map { (i, player) in
            guard i < next.count else { return player }
            var interpolated = player
            let t = animationProgress
            interpolated.position = CGPoint(
                x: player.position.x + (next[i].position.x - player.position.x) * t,
                y: player.position.y + (next[i].position.y - player.position.y) * t
            )
            return interpolated
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true
        animationProgress = 0
        let interval = 0.03 / playbackSpeed
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            animationProgress += CGFloat(0.02 * playbackSpeed)
            if animationProgress >= 1.0 {
                animationProgress = 0
                if currentFrameIndex < play.frames.count - 1 {
                    currentFrameIndex += 1
                } else {
                    stopPlayback()
                }
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        animationProgress = 0
    }

    private func goToNextFrame() {
        stopPlayback()
        if currentFrameIndex < play.frames.count - 1 {
            currentFrameIndex += 1
        }
    }

    private func goToPreviousFrame() {
        stopPlayback()
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
        }
    }

    private func courtSize(in size: CGSize) -> CGSize {
        let courtAspect: CGFloat = 15.0 / 28.0
        let availableAspect = size.width / size.height
        if availableAspect > courtAspect {
            let h = size.height * 0.95
            return CGSize(width: h * courtAspect, height: h)
        } else {
            let w = size.width * 0.95
            return CGSize(width: w, height: w / courtAspect)
        }
    }
}
