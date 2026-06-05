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
    @State private var isTouching = false

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width

            ZStack {
                Color(.systemGray5).ignoresSafeArea(.all)

                if isPortrait {
                    portraitLayout(geo: geo, isPortrait: true)
                } else {
                    landscapeLayout(geo: geo, isPortrait: false)
                }
            }
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

    // MARK: - Landscape

    private func landscapeLayout(geo: GeometryProxy, isPortrait: Bool) -> some View {
        ZStack {
            courtView(geoSize: geo.size, isPortrait: false)
                .ignoresSafeArea(.all)

            if !isTouching {
                HStack {
                    VStack(spacing: 12) {
                        floatingBtn("square.and.arrow.down") { showSaveSheet = true }
                        floatingBtn("folder") { showLoadSheet = true }
                        floatingBtn("arrow.uturn.backward") { if !lines.isEmpty { lines.removeLast() } }
                        floatingBtn("trash", color: .red) { resetBoard() }
                        Spacer()
                        courtModeToggle
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                HStack {
                    Spacer()
                    toolPanel(isPortrait: false)
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Portrait

    private func portraitLayout(geo: GeometryProxy, isPortrait: Bool) -> some View {
        VStack(spacing: 0) {
            if !isTouching {
                HStack(spacing: 8) {
                    floatingBtn("square.and.arrow.down") { showSaveSheet = true }
                    floatingBtn("folder") { showLoadSheet = true }
                    floatingBtn("arrow.uturn.backward") { if !lines.isEmpty { lines.removeLast() } }
                    floatingBtn("trash", color: .red) { resetBoard() }
                    Spacer()
                    courtModeToggle
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            courtView(geoSize: CGSize(
                width: geo.size.width,
                height: isTouching ? geo.size.height : geo.size.height - 80
            ), isPortrait: true)

            if !isTouching {
                toolStrip(isPortrait: true)
            }
        }
    }

    // MARK: - Court

    private func courtView(geoSize: CGSize, isPortrait: Bool) -> some View {
        GeometryReader { geo in
            let cs = courtSize(in: geo.size, isPortrait: isPortrait)
            let origin = CGPoint(
                x: (geo.size.width - cs.width) / 2,
                y: (geo.size.height - cs.height) / 2
            )

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                CourtRenderer(mode: courtMode, isPortrait: isPortrait)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                LineDrawingView(lines: lines, isPortrait: isPortrait, isLandscapeHalf: !isPortrait && courtMode == .half)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if let drawing = currentDrawing {
                    LineDrawingView(lines: [drawing], isPortrait: isPortrait, isLandscapeHalf: !isPortrait && courtMode == .half)
                        .frame(width: cs.width, height: cs.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Ball
                BallView(isSelected: draggingBall)
                    .position(courtToScreen(ball.position, cs: cs, origin: origin, isPortrait: isPortrait))
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { v in
                                isTouching = true
                                draggingBall = true
                                ball.position = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                            }
                            .onEnded { _ in isTouching = false; draggingBall = false }
                        : nil
                    )

                // Players
                ForEach(players) { player in
                    let screenPos = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
                    RotatablePlayerView(
                        player: player,
                        isSelected: selectedPlayerID == player.id,
                        screenPosition: screenPos,
                        onRotate: { angle in
                            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                players[idx].facing = angle
                            }
                        }
                    )
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { v in
                                isTouching = true
                                selectedPlayerID = player.id
                                if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                    players[idx].position = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                                }
                            }
                            .onEnded { _ in isTouching = false }
                        : nil
                    )
                    .onLongPressGesture {
                        editingPlayerID = player.id
                        editingNumber = player.number
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                editorMode == .draw ?
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        isTouching = true
                        let courtPt = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                        if currentDrawing == nil {
                            currentDrawing = DrawingLine(type: selectedLineType, lineColor: selectedLineColor, points: [courtPt])
                        } else {
                            currentDrawing?.points.append(courtPt)
                        }
                    }
                    .onEnded { _ in
                        isTouching = false
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

    // MARK: - Coordinate Mapping
    // Player coords: x = across (sideline-to-sideline 0-1), y = along (baseline-to-halfcourt 0-1)
    // Landscape: across→screenX, along→screenY
    // Portrait:  along→screenX, across→screenY

    private func courtToScreen(_ pos: CGPoint, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        if isPortrait {
            // across→X, along→Y
            return CGPoint(x: origin.x + pos.x * cs.width, y: origin.y + pos.y * cs.height)
        } else if courtMode == .half {
            // across→X, along→Y inverted (endline at bottom)
            return CGPoint(x: origin.x + pos.x * cs.width, y: origin.y + (1 - pos.y) * cs.height)
        } else {
            // along→X, across→Y (full court horizontal)
            return CGPoint(x: origin.x + pos.y * cs.width, y: origin.y + pos.x * cs.height)
        }
    }

    private func screenToCourt(_ screen: CGPoint, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        let raw: CGPoint
        if isPortrait {
            raw = CGPoint(
                x: (screen.x - origin.x) / cs.width,
                y: (screen.y - origin.y) / cs.height
            )
        } else if courtMode == .half {
            raw = CGPoint(
                x: (screen.x - origin.x) / cs.width,
                y: 1 - (screen.y - origin.y) / cs.height
            )
        } else {
            raw = CGPoint(
                x: (screen.y - origin.y) / cs.height,
                y: (screen.x - origin.x) / cs.width
            )
        }
        return CGPoint(x: max(0, min(1, raw.x)), y: max(0, min(1, raw.y)))
    }

    // MARK: - UI Components

    private func floatingBtn(_ icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }

    private var courtModeToggle: some View {
        Picker("", selection: $courtMode) {
            ForEach(CourtMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(width: 110)
    }

    private func modeBtn(_ icon: String, mode: EditorMode) -> some View {
        Button { editorMode = mode } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(editorMode == mode ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(editorMode == mode ? Color.blue : Color(.systemGray5))
                .cornerRadius(7)
        }
    }

    private func toolPanel(isPortrait: Bool) -> some View {
        VStack(spacing: 8) {
            modeBtn("hand.draw", mode: .move)
            modeBtn("pencil.tip", mode: .draw)

            if editorMode == .draw {
                Divider().frame(width: 28)
                ForEach(LineType.allCases, id: \.self) { type in
                    Button { selectedLineType = type } label: {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 14))
                            .foregroundColor(selectedLineType == type ? .white : .secondary)
                            .frame(width: 32, height: 32)
                            .background(selectedLineType == type ? Color.blue : Color.clear)
                            .cornerRadius(7)
                    }
                }
                Divider().frame(width: 28)
                ForEach(LineColor.allCases, id: \.self) { lc in
                    Circle().fill(lc.color).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(selectedLineColor == lc ? .white : .clear, lineWidth: 2))
                        .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.5) : .clear, radius: 3)
                        .onTapGesture { selectedLineColor = lc }
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private func toolStrip(isPortrait: Bool) -> some View {
        HStack(spacing: 6) {
            modeBtn("hand.draw", mode: .move)
            modeBtn("pencil.tip", mode: .draw)

            if editorMode == .draw {
                Divider().frame(height: 26)
                ForEach(LineType.allCases, id: \.self) { type in
                    Button { selectedLineType = type } label: {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 14))
                            .foregroundColor(selectedLineType == type ? .white : .secondary)
                            .frame(width: 30, height: 30)
                            .background(selectedLineType == type ? Color.blue : Color.clear)
                            .cornerRadius(6)
                    }
                }
                Divider().frame(height: 26)
                ForEach(LineColor.allCases, id: \.self) { lc in
                    Circle().fill(lc.color).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(selectedLineColor == lc ? .white : .clear, lineWidth: 2))
                        .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.5) : .clear, radius: 3)
                        .onTapGesture { selectedLineColor = lc }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Save / Load

    private var saveSheet: some View {
        NavigationStack {
            Form { TextField("プレイ名", text: $saveName) }
            .navigationTitle("保存").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { showSaveSheet = false } }
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
                    Text("保存されたプレイがありません").foregroundStyle(.secondary)
                } else {
                    ForEach(playStore.plays) { play in
                        Button {
                            if let frame = play.frames.first {
                                players = frame.players
                                ball = frame.ball
                                lines = frame.lines
                            }
                            showLoadSheet = false
                        } label: { Text(play.name) }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { playStore.delete(playStore.plays[i]) }
                    }
                }
            }
            .navigationTitle("読み込み").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showLoadSheet = false } }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func courtSize(in size: CGSize, isPortrait: Bool) -> CGSize {
        let ratio = courtMode.aspectRatio(landscape: !isPortrait)
        let available = size.width / size.height
        if available > ratio {
            return CGSize(width: size.height * ratio, height: size.height)
        } else {
            return CGSize(width: size.width, height: size.width / ratio)
        }
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
            let dx = points[i].x - prev.x, dy = points[i].y - prev.y
            if sqrt(dx * dx + dy * dy) >= tolerance { result.append(points[i]) }
        }
        result.append(points.last!)
        return result
    }
}
