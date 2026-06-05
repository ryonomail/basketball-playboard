import SwiftUI

enum EditorMode {
    case move
    case draw
}

struct CourtEditorView: View {
    @EnvironmentObject var playStore: PlayStore
    @State var play: Play
    @State private var currentFrameIndex = 0
    @State private var editorMode: EditorMode = .move
    @State private var selectedLineType: LineType = .cut
    @State private var selectedPlayerID: UUID? = nil
    @State private var currentDrawingLine: DrawingLine? = nil
    @State private var editingPlayerID: UUID? = nil
    @State private var editingNumber: String = ""
    @State private var showPlayback = false

    private var currentFrame: PlayFrame {
        guard play.frames.indices.contains(currentFrameIndex) else {
            return PlayFrame(players: [])
        }
        return play.frames[currentFrameIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            courtArea
            toolbar
            frameBar
        }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPlayback = true
                } label: {
                    Image(systemName: "play.circle")
                }
                .disabled(play.frames.count < 2)
            }
        }
        .sheet(isPresented: $showPlayback) {
            PlaybackView(play: play)
        }
        .alert("背番号を変更", isPresented: Binding(
            get: { editingPlayerID != nil },
            set: { if !$0 { editingPlayerID = nil } }
        )) {
            TextField("番号", text: $editingNumber)
                .keyboardType(.numberPad)
            Button("OK") {
                if let pid = editingPlayerID,
                   let fi = play.frames.indices.first(where: { $0 == currentFrameIndex }),
                   let pi = play.frames[fi].players.firstIndex(where: { $0.id == pid }) {
                    play.frames[fi].players[pi].number = editingNumber
                    playStore.updatePlay(play)
                }
                editingPlayerID = nil
            }
            Button("キャンセル", role: .cancel) { editingPlayerID = nil }
        }
    }

    private var courtArea: some View {
        GeometryReader { geo in
            let courtSize = courtSize(in: geo.size)
            let courtOrigin = CGPoint(
                x: (geo.size.width - courtSize.width) / 2,
                y: (geo.size.height - courtSize.height) / 2
            )

            ZStack {
                Color.white

                // Court lines
                CourtRenderer()
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: courtSize.width, height: courtSize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Drawn lines
                LineDrawingView(lines: currentFrame.lines)
                    .frame(width: courtSize.width, height: courtSize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Current drawing line
                if let drawingLine = currentDrawingLine {
                    LineDrawingView(lines: [drawingLine])
                        .frame(width: courtSize.width, height: courtSize.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Player markers
                ForEach(currentFrame.players) { player in
                    let pos = CGPoint(
                        x: courtOrigin.x + player.position.x * courtSize.width,
                        y: courtOrigin.y + player.position.y * courtSize.height
                    )
                    PlayerMarkerView(
                        player: player,
                        isSelected: selectedPlayerID == player.id,
                        onTapNumber: {
                            editingPlayerID = player.id
                            editingNumber = player.number
                        }
                    )
                    .position(pos)
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { value in
                                selectedPlayerID = player.id
                                updatePlayerPosition(
                                    playerID: player.id,
                                    to: CGPoint(
                                        x: (value.location.x - courtOrigin.x) / courtSize.width,
                                        y: (value.location.y - courtOrigin.y) / courtSize.height
                                    )
                                )
                            }
                            .onEnded { _ in
                                playStore.updatePlay(play)
                            }
                        : nil
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                editorMode == .draw ?
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let pt = CGPoint(
                            x: (value.location.x - courtOrigin.x) / courtSize.width,
                            y: (value.location.y - courtOrigin.y) / courtSize.height
                        )
                        if currentDrawingLine == nil {
                            currentDrawingLine = DrawingLine(type: selectedLineType, points: [pt])
                        } else {
                            currentDrawingLine?.points.append(pt)
                        }
                    }
                    .onEnded { _ in
                        if var line = currentDrawingLine, line.points.count >= 2 {
                            // Simplify the line to reduce points
                            line.points = simplifyPoints(line.points, tolerance: 0.005)
                            play.frames[currentFrameIndex].lines.append(line)
                            playStore.updatePlay(play)
                        }
                        currentDrawingLine = nil
                    }
                : nil
            )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Mode toggle
            Picker("モード", selection: $editorMode) {
                Image(systemName: "hand.draw").tag(EditorMode.move)
                Image(systemName: "pencil.tip").tag(EditorMode.draw)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            if editorMode == .draw {
                Divider().frame(height: 28)

                ForEach(LineType.allCases, id: \.self) { type in
                    Button {
                        selectedLineType = type
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 18))
                            Text(type.displayName)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(selectedLineType == type ? .blue : .secondary)
                    }
                }

                Spacer()

                Button {
                    if !currentFrame.lines.isEmpty {
                        play.frames[currentFrameIndex].lines.removeLast()
                        playStore.updatePlay(play)
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(currentFrame.lines.isEmpty)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var frameBar: some View {
        HStack {
            Text("フレーム \(currentFrameIndex + 1) / \(play.frames.count)")
                .font(.caption)

            Spacer()

            Button {
                if currentFrameIndex > 0 { currentFrameIndex -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentFrameIndex == 0)

            Button {
                if currentFrameIndex < play.frames.count - 1 {
                    currentFrameIndex += 1
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentFrameIndex >= play.frames.count - 1)

            Button {
                let newFrame = PlayFrame(
                    players: currentFrame.players,
                    lines: []
                )
                play.frames.insert(newFrame, at: currentFrameIndex + 1)
                currentFrameIndex += 1
                playStore.updatePlay(play)
            } label: {
                Image(systemName: "plus.circle")
            }

            Button {
                if play.frames.count > 1 {
                    play.frames.remove(at: currentFrameIndex)
                    if currentFrameIndex >= play.frames.count {
                        currentFrameIndex = play.frames.count - 1
                    }
                    playStore.updatePlay(play)
                }
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .disabled(play.frames.count <= 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func courtSize(in size: CGSize) -> CGSize {
        let courtAspect: CGFloat = 15.0 / 28.0 // width / height (full court)
        let availableAspect = size.width / size.height
        if availableAspect > courtAspect {
            let h = size.height * 0.95
            return CGSize(width: h * courtAspect, height: h)
        } else {
            let w = size.width * 0.95
            return CGSize(width: w, height: w / courtAspect)
        }
    }

    private func updatePlayerPosition(playerID: UUID, to position: CGPoint) {
        let clamped = CGPoint(
            x: max(0, min(1, position.x)),
            y: max(0, min(1, position.y))
        )
        if let index = play.frames[currentFrameIndex].players.firstIndex(where: { $0.id == playerID }) {
            play.frames[currentFrameIndex].players[index].position = clamped
        }
    }

    private func simplifyPoints(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 3 else { return points }
        var result: [CGPoint] = [points[0]]
        for i in 1..<points.count - 1 {
            let prev = result.last!
            let dx = points[i].x - prev.x
            let dy = points[i].y - prev.y
            if sqrt(dx * dx + dy * dy) >= tolerance {
                result.append(points[i])
            }
        }
        result.append(points.last!)
        return result
    }
}
