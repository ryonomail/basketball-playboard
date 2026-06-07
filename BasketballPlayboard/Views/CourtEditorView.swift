import SwiftUI

enum EditorMode: String {
    case move
    case draw
    case erase
}

struct CourtEditorView: View {
    @EnvironmentObject var playStore: PlayStore

    @State private var players: [Player] = Formation.allPlayers(for: .half)
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
    @State private var showHomeVision: Bool = true
    @State private var showAwayVision: Bool = true

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width

            ZStack {
                Color(.systemGray5).ignoresSafeArea(.all)

                if isPortrait {
                    portraitLayout(geo: geo)
                } else {
                    landscapeLayout(geo: geo)
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
            Button("削除", role: .destructive) {
                if let pid = editingPlayerID {
                    players.removeAll { $0.id == pid }
                }
                editingPlayerID = nil
            }
            Button("キャンセル", role: .cancel) { editingPlayerID = nil }
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .sheet(isPresented: $showLoadSheet) { loadSheet }
    }

    // MARK: - Landscape

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let compact = geo.size.height < 500
        let toolW: CGFloat = compact ? 46 : 52
        return HStack(spacing: 0) {
            // Left toolbar: actions + court mode
            VStack(spacing: compact ? 6 : 10) {
                actionButtons
                Spacer()
                courtModeToggle
            }
            .frame(width: toolW)
            .padding(.vertical, 6)
            .padding(.leading, 4)

            // Court
            courtView(isPortrait: false)

            // Right toolbar: draw tools
            drawToolbar(horizontal: false)
                .frame(width: toolW)
                .padding(.vertical, 6)
                .padding(.trailing, 4)
        }
    }

    // MARK: - Portrait

    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top bar: actions + court mode
            HStack(spacing: 8) {
                actionButtons
                Spacer()
                courtModeToggle
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Court
            courtView(isPortrait: true)

            // Bottom bar: draw tools
            drawToolbar(horizontal: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Shared UI

    private var actionButtons: some View {
        Group {
            floatingBtn("square.and.arrow.down") { showSaveSheet = true }
            floatingBtn("folder") { showLoadSheet = true }
            floatingBtn("arrow.uturn.backward") { if !lines.isEmpty { lines.removeLast() } }
            floatingBtn("trash", color: .red) { resetBoard() }
            addPlayerBtn(team: .home)
            addPlayerBtn(team: .away)
            Button {
                showHomeVision.toggle()
            } label: {
                Image(systemName: showHomeVision ? "eye" : "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(showHomeVision ? Color.blue : Color.blue.opacity(0.3))
                    .cornerRadius(8)
            }
            Button {
                showAwayVision.toggle()
            } label: {
                Image(systemName: showAwayVision ? "eye" : "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(showAwayVision ? Color.red : Color.red.opacity(0.3))
                    .cornerRadius(8)
            }
        }
    }

    private func addPlayerBtn(team: Team) -> some View {
        Button {
            let count = players.filter { $0.team == team }.count
            let number = "\(count + 1)"
            let pos = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: 0.3...0.7))
            players.append(Player(number: number, team: team, position: pos))
        } label: {
            ZStack {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(team == .home ? Color.blue : Color.red)
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func drawToolbar(horizontal: Bool) -> some View {
        let content = Group {
            modeBtn("hand.draw", mode: .move)
            modeBtn("pencil.tip", mode: .draw)
            modeBtn("eraser", mode: .erase)

            if editorMode == .draw {
                if horizontal {
                    Divider().frame(height: 26)
                } else {
                    Divider().frame(width: 28)
                }

                ForEach(LineType.allCases, id: \.self) { type in
                    Button { selectedLineType = type } label: {
                        LinePreview(type: type)
                            .frame(width: 38, height: 38)
                            .background(selectedLineType == type ? Color.blue.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedLineType == type ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                            .cornerRadius(6)
                    }
                }

                if horizontal {
                    Divider().frame(height: 26)
                } else {
                    Divider().frame(width: 28)
                }

                ForEach(LineColor.allCases, id: \.self) { lc in
                    Circle().fill(lc.color).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(selectedLineColor == lc ? .white : .clear, lineWidth: 2))
                        .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.6) : .clear, radius: 3)
                        .onTapGesture { selectedLineColor = lc }
                }
            }
        }

        if horizontal {
            HStack(spacing: 6) { content }
        } else {
            VStack(spacing: 6) { content }
        }
    }

    // MARK: - Court

    private func courtView(isPortrait: Bool) -> some View {
        GeometryReader { geo in
            let cs = courtSize(in: geo.size, isPortrait: isPortrait)
            let origin = CGPoint(
                x: (geo.size.width - cs.width) / 2,
                y: (geo.size.height - cs.height) / 2
            )
            // Scale factor: base design is for ~400px court width
            let courtW = isPortrait ? cs.width : (courtMode == .full ? cs.height : cs.width)
            let uiScale = max(0.6, min(1.5, courtW / 400))

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                CourtRenderer(mode: courtMode, isPortrait: isPortrait)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Vision cones (10m range, gradient fade, clipped to court)
                if showHomeVision || showAwayVision {
                    let visiblePlayers = players.filter {
                        ($0.team == .home && showHomeVision) || ($0.team == .away && showAwayVision)
                    }
                    VisionConeLayer(
                        players: visiblePlayers,
                        courtSize: cs,
                        origin: origin,
                        isPortrait: isPortrait,
                        courtMode: courtMode
                    )
                    .clipShape(Rectangle().size(width: cs.width, height: cs.height)
                        .offset(x: origin.x, y: origin.y))
                    .allowsHitTesting(false)
                }

                LineDrawingView(lines: lines, isPortrait: isPortrait, isLandscapeHalf: !isPortrait && courtMode == .half)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if let drawing = currentDrawing {
                    LineDrawingView(lines: [drawing], isPortrait: isPortrait, isLandscapeHalf: !isPortrait && courtMode == .half)
                        .frame(width: cs.width, height: cs.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Ball
                BallView(isSelected: draggingBall, scale: uiScale)
                    .position(courtToScreen(ball.position, cs: cs, origin: origin, isPortrait: isPortrait))
                    .gesture(
                        editorMode == .move ?
                        DragGesture()
                            .onChanged { v in
                                draggingBall = true
                                ball.position = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                            }
                            .onEnded { _ in draggingBall = false }
                        : nil
                    )

                // Players
                ForEach(players) { player in
                    let screenPos = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
                    InteractivePlayerView(
                        player: player,
                        isSelected: selectedPlayerID == player.id,
                        screenPosition: screenPos,
                        scale: uiScale,
                        interactive: editorMode == .move,
                        onMove: editorMode == .move ? { location in
                            selectedPlayerID = player.id
                            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                players[idx].position = screenToCourt(location, cs: cs, origin: origin, isPortrait: isPortrait)
                            }
                        } : nil,
                        onRotate: { angle in
                            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                players[idx].facing = angle
                            }
                        },
                        onMoveEnd: {}
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                editingPlayerID = player.id
                                editingNumber = player.number
                            }
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                editorMode == .draw ?
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        let courtPt = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                        if currentDrawing == nil {
                            currentDrawing = DrawingLine(type: selectedLineType, lineColor: selectedLineColor, points: [courtPt])
                        } else {
                            currentDrawing?.points.append(courtPt)
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
            .gesture(
                editorMode == .erase ?
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let courtPt = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                        eraseLineNear(courtPt)
                    }
                : nil
            )
        }
    }

    // MARK: - Coordinate Mapping

    private func courtToScreen(_ pos: CGPoint, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        if isPortrait {
            return CGPoint(x: origin.x + pos.x * cs.width, y: origin.y + pos.y * cs.height)
        } else if courtMode == .half {
            return CGPoint(x: origin.x + pos.x * cs.width, y: origin.y + (1 - pos.y) * cs.height)
        } else {
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }

    private var courtModeToggle: some View {
        Button {
            let newMode: CourtMode = courtMode == .half ? .full : .half
            courtMode = newMode
            players = Formation.allPlayers(for: newMode)
            ball = Ball()
            lines = []
        } label: {
            Text(courtMode == .half ? "ハーフ" : "フル")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 50, height: 40)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }

    private func modeBtn(_ icon: String, mode: EditorMode) -> some View {
        Button { editorMode = mode } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(editorMode == mode ? .white : .secondary)
                .frame(width: 38, height: 38)
                .background(editorMode == mode ? Color.blue : Color(.systemGray5))
                .cornerRadius(7)
        }
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
        players = Formation.allPlayers(for: courtMode)
        ball = Ball()
        lines = []
        selectedPlayerID = nil
    }

    private func eraseLineNear(_ courtPt: CGPoint) {
        let threshold: CGFloat = 0.03
        lines.removeAll { line in
            line.points.contains { pt in
                hypot(pt.x - courtPt.x, pt.y - courtPt.y) < threshold
            }
        }
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

// MARK: - Line Preview (shows actual line style instead of abstract icons)

struct LinePreview: View {
    let type: LineType

    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            let inset: CGFloat = 4
            var path = Path()
            path.move(to: CGPoint(x: inset, y: y))
            path.addLine(to: CGPoint(x: size.width - inset, y: y))

            let color: Color = .primary
            switch type {
            case .cut:
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                drawArrow(context: context, at: CGPoint(x: size.width - inset, y: y), angle: 0, color: color)
            case .pass:
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 4]))
                drawArrow(context: context, at: CGPoint(x: size.width - inset, y: y), angle: 0, color: color)
            case .dribble:
                // Wavy line preview
                var wavy = Path()
                let waveAmp: CGFloat = 3.5
                let waveLen: CGFloat = 8
                let startX = inset
                let endX = size.width - inset
                wavy.move(to: CGPoint(x: startX, y: y))
                var cx = startX
                while cx <= endX {
                    let wave = sin((cx - startX) / waveLen * .pi * 2) * waveAmp
                    wavy.addLine(to: CGPoint(x: cx, y: y + wave))
                    cx += 1
                }
                context.stroke(wavy, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                drawArrow(context: context, at: CGPoint(x: size.width - inset, y: y), angle: 0, color: color)
            case .screen:
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                var bar = Path()
                let bx = size.width - inset
                bar.move(to: CGPoint(x: bx, y: y - 6))
                bar.addLine(to: CGPoint(x: bx, y: y + 6))
                context.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }

    private func drawArrow(context: GraphicsContext, at tip: CGPoint, angle: CGFloat, color: Color) {
        let len: CGFloat = 7
        let spread: CGFloat = .pi / 4
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle - spread), y: tip.y - len * sin(angle - spread)))
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x - len * cos(angle + spread), y: tip.y - len * sin(angle + spread)))
        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}
