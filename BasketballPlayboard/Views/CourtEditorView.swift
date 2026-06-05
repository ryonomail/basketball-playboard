import SwiftUI

enum EditorMode: String {
    case move
    case draw
}

struct CourtEditorView: View {
    @EnvironmentObject var playStore: PlayStore

    @State private var players: [Player] = Formation.allPlayers()
    @State private var ball: Ball = Ball()
    @State private var lines: [DrawingLine] = []
    @State private var courtMode: CourtMode = .half
    @State private var editorMode: EditorMode = .move
    @State private var selectedLineType: LineType = .cut
    @State private var selectedLineColor: LineColor = .black
    @State private var currentDrawing: DrawingLine? = nil
    @State private var selectedPlayerID: UUID? = nil
    @State private var draggingBall = false
    @State private var editingPlayerID: UUID? = nil
    @State private var editingNumber: String = ""
    @State private var showSaveSheet = false
    @State private var showLoadSheet = false
    @State private var saveName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            courtArea
            toolBar
        }
        .alert("背番号を変更", isPresented: Binding(
            get: { editingPlayerID != nil },
            set: { if !$0 { editingPlayerID = nil } }
        )) {
            TextField("番号", text: $editingNumber)
                .keyboardType(.numberPad)
            Button("OK") { applyNumberEdit() }
            Button("キャンセル", role: .cancel) { editingPlayerID = nil }
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .sheet(isPresented: $showLoadSheet) { loadSheet }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { showSaveSheet = true } label: {
                Image(systemName: "square.and.arrow.down")
            }
            Button { showLoadSheet = true } label: {
                Image(systemName: "folder")
            }

            Spacer()

            Picker("コート", selection: $courtMode) {
                ForEach(CourtMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 130)

            Spacer()

            Button {
                if !lines.isEmpty { lines.removeLast() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(lines.isEmpty)

            Button { resetBoard() } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Court

    private var courtArea: some View {
        GeometryReader { geo in
            let cs = courtSize(in: geo.size)
            let origin = CGPoint(
                x: (geo.size.width - cs.width) / 2,
                y: (geo.size.height - cs.height) / 2
            )

            ZStack {
                Color(.systemGray5)

                // White court background
                Rectangle()
                    .fill(Color.white)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Court lines
                CourtRenderer(mode: courtMode)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Drawn lines
                LineDrawingView(lines: lines)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Current drawing
                if let drawing = currentDrawing {
                    LineDrawingView(lines: [drawing])
                        .frame(width: cs.width, height: cs.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Ball
                BallView(isSelected: draggingBall)
                    .position(
                        x: origin.x + ball.position.x * cs.width,
                        y: origin.y + ball.position.y * cs.height
                    )
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { v in
                                draggingBall = true
                                ball.position = clampedNorm(v.location, origin: origin, size: cs)
                            }
                            .onEnded { _ in draggingBall = false }
                        : nil
                    )

                // Players
                ForEach(players) { player in
                    PlayerMarkerView(
                        player: player,
                        isSelected: selectedPlayerID == player.id,
                        onTapNumber: {
                            editingPlayerID = player.id
                            editingNumber = player.number
                        }
                    )
                    .position(
                        x: origin.x + player.position.x * cs.width,
                        y: origin.y + player.position.y * cs.height
                    )
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { v in
                                selectedPlayerID = player.id
                                if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                    players[idx].position = clampedNorm(v.location, origin: origin, size: cs)
                                }
                            }
                            .onEnded { _ in }
                        : nil
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                editorMode == .draw ?
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        let pt = normalizedPoint(v.location, origin: origin, size: cs)
                        if currentDrawing == nil {
                            currentDrawing = DrawingLine(type: selectedLineType, lineColor: selectedLineColor, points: [pt])
                        } else {
                            currentDrawing?.points.append(pt)
                        }
                    }
                    .onEnded { _ in
                        if var line = currentDrawing, line.points.count >= 2 {
                            line.points = simplify(line.points, tolerance: 0.004)
                            lines.append(line)
                        }
                        currentDrawing = nil
                    }
                : nil
            )
        }
    }

    // MARK: - Tool Bar

    private var toolBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
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
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 16))
                                Text(type.displayName)
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(selectedLineType == type ? .blue : .secondary)
                        }
                    }

                    Divider().frame(height: 28)

                    ForEach(LineColor.allCases, id: \.self) { lc in
                        Circle()
                            .fill(lc.color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(selectedLineColor == lc ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Circle().stroke(selectedLineColor == lc ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedLineColor == lc ? 3 : 1)
                            )
                            .onTapGesture { selectedLineColor = lc }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Save / Load

    private var saveSheet: some View {
        NavigationStack {
            Form {
                TextField("プレイ名", text: $saveName)
            }
            .navigationTitle("保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let frame = PlayFrame(players: players, ball: ball, lines: lines)
                        let play = Play(name: saveName.isEmpty ? "プレイ \(playStore.plays.count + 1)" : saveName, frames: [frame])
                        playStore.save(play)
                        saveName = ""
                        showSaveSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var loadSheet: some View {
        NavigationStack {
            List {
                if playStore.plays.isEmpty {
                    Text("保存されたプレイがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playStore.plays) { play in
                        Button {
                            if let frame = play.frames.first {
                                players = frame.players
                                ball = frame.ball
                                lines = frame.lines
                            }
                            showLoadSheet = false
                        } label: {
                            Text(play.name)
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            playStore.delete(playStore.plays[i])
                        }
                    }
                }
            }
            .navigationTitle("読み込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showLoadSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func courtSize(in size: CGSize) -> CGSize {
        let ratio = courtMode.aspectRatio
        let availableRatio = size.width / size.height
        if availableRatio > ratio {
            let h = size.height * 0.94
            return CGSize(width: h * ratio, height: h)
        } else {
            let w = size.width * 0.94
            return CGSize(width: w, height: w / ratio)
        }
    }

    private func normalizedPoint(_ point: CGPoint, origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / size.width, y: (point.y - origin.y) / size.height)
    }

    private func clampedNorm(_ point: CGPoint, origin: CGPoint, size: CGSize) -> CGPoint {
        let n = normalizedPoint(point, origin: origin, size: size)
        return CGPoint(x: max(0, min(1, n.x)), y: max(0, min(1, n.y)))
    }

    private func applyNumberEdit() {
        if let pid = editingPlayerID, let idx = players.firstIndex(where: { $0.id == pid }) {
            players[idx].number = editingNumber
        }
        editingPlayerID = nil
    }

    private func resetBoard() {
        players = Formation.allPlayers()
        ball = Ball()
        lines = []
        selectedPlayerID = nil
    }

    private func simplify(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
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
