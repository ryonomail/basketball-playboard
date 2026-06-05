import SwiftUI

enum EditorMode: String {
    case move
    case draw
}

struct CourtEditorView: View {
    @EnvironmentObject var playStore: PlayStore
    @Environment(\.horizontalSizeClass) var hSizeClass

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
    @State private var isLandscape = false

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color(.systemGray5).ignoresSafeArea()

                if landscape {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }
            }
            .onAppear { isLandscape = landscape }
            .onChange(of: geo.size) { isLandscape = geo.size.width > geo.size.height }
        }
        .ignoresSafeArea()
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

    // MARK: - Landscape Layout

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        ZStack {
            courtView(size: geo.size)

            if !isTouching {
                // Left side: actions
                HStack {
                    VStack(spacing: 14) {
                        floatingButton(icon: "square.and.arrow.down") { showSaveSheet = true }
                        floatingButton(icon: "folder") { showLoadSheet = true }
                        floatingButton(icon: "arrow.uturn.backward") { if !lines.isEmpty { lines.removeLast() } }
                        floatingButton(icon: "trash", color: .red) { resetBoard() }

                        Spacer()

                        courtModeToggle
                    }
                    .padding(.leading, geo.safeAreaInsets.leading + 8)
                    .padding(.vertical, geo.safeAreaInsets.top + 8)

                    Spacer()
                }

                // Right side: tools
                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        modeToggleVertical

                        if editorMode == .draw {
                            Divider().frame(width: 30)

                            ForEach(LineType.allCases, id: \.self) { type in
                                Button {
                                    selectedLineType = type
                                } label: {
                                    Image(systemName: type.systemImage)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(selectedLineType == type ? .white : .secondary)
                                        .frame(width: 36, height: 36)
                                        .background(selectedLineType == type ? Color.blue : Color.clear)
                                        .cornerRadius(8)
                                }
                            }

                            Divider().frame(width: 30)

                            ForEach(LineColor.allCases, id: \.self) { lc in
                                Circle()
                                    .fill(lc.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle().stroke(selectedLineColor == lc ? Color.white : Color.clear, lineWidth: 2.5)
                                    )
                                    .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.5) : .clear, radius: 4)
                                    .onTapGesture { selectedLineColor = lc }
                            }
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.trailing, geo.safeAreaInsets.trailing + 8)
                    .padding(.vertical, geo.safeAreaInsets.top + 8)
                }
            }
        }
    }

    // MARK: - Portrait Layout

    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if !isTouching {
                portraitTopBar
                    .padding(.top, geo.safeAreaInsets.top)
            }

            courtView(size: CGSize(
                width: geo.size.width,
                height: geo.size.height - (isTouching ? 0 : 90) - geo.safeAreaInsets.top
            ))

            if !isTouching {
                portraitToolBar
            }
        }
    }

    private var portraitTopBar: some View {
        HStack(spacing: 10) {
            floatingButton(icon: "square.and.arrow.down") { showSaveSheet = true }
            floatingButton(icon: "folder") { showLoadSheet = true }
            floatingButton(icon: "arrow.uturn.backward") { if !lines.isEmpty { lines.removeLast() } }
            floatingButton(icon: "trash", color: .red) { resetBoard() }
            Spacer()
            courtModeToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var portraitToolBar: some View {
        HStack(spacing: 8) {
            modeToggleHorizontal

            if editorMode == .draw {
                Divider().frame(height: 28)

                ForEach(LineType.allCases, id: \.self) { type in
                    Button {
                        selectedLineType = type
                    } label: {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 15))
                            .foregroundColor(selectedLineType == type ? .white : .secondary)
                            .frame(width: 32, height: 32)
                            .background(selectedLineType == type ? Color.blue : Color.clear)
                            .cornerRadius(6)
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
                        .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.5) : .clear, radius: 3)
                        .onTapGesture { selectedLineColor = lc }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Court View

    private func courtView(size: CGSize) -> some View {
        GeometryReader { geo in
            let cs = courtSize(in: geo.size)
            let origin = CGPoint(
                x: (geo.size.width - cs.width) / 2,
                y: (geo.size.height - cs.height) / 2
            )

            ZStack {
                // White court
                Rectangle()
                    .fill(Color.white)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                CourtRenderer(mode: courtMode)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                LineDrawingView(lines: lines)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

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
                                isTouching = true
                                draggingBall = true
                                ball.position = clampedNorm(v.location, origin: origin, size: cs)
                            }
                            .onEnded { _ in
                                isTouching = false
                                draggingBall = false
                            }
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
                                isTouching = true
                                selectedPlayerID = player.id
                                if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                    players[idx].position = clampedNorm(v.location, origin: origin, size: cs)
                                }
                            }
                            .onEnded { _ in isTouching = false }
                        : nil
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                editorMode == .draw ?
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        isTouching = true
                        let pt = normalizedPoint(v.location, origin: origin, size: cs)
                        if currentDrawing == nil {
                            currentDrawing = DrawingLine(type: selectedLineType, lineColor: selectedLineColor, points: [pt])
                        } else {
                            currentDrawing?.points.append(pt)
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

    // MARK: - Shared Components

    private func floatingButton(icon: String, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }

    private var courtModeToggle: some View {
        Picker("コート", selection: $courtMode) {
            ForEach(CourtMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(width: 110)
    }

    private var modeToggleVertical: some View {
        VStack(spacing: 6) {
            modeButton(icon: "hand.draw", mode: .move)
            modeButton(icon: "pencil.tip", mode: .draw)
        }
    }

    private var modeToggleHorizontal: some View {
        HStack(spacing: 4) {
            modeButton(icon: "hand.draw", mode: .move)
            modeButton(icon: "pencil.tip", mode: .draw)
        }
    }

    private func modeButton(icon: String, mode: EditorMode) -> some View {
        Button {
            editorMode = mode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(editorMode == mode ? .white : .secondary)
                .frame(width: 34, height: 34)
                .background(editorMode == mode ? Color.blue : Color(.systemGray5))
                .cornerRadius(8)
        }
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
                        for i in indexSet { playStore.delete(playStore.plays[i]) }
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
            return CGSize(width: size.height * ratio, height: size.height)
        } else {
            return CGSize(width: size.width, height: size.width / ratio)
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
