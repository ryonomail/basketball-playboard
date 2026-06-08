import SwiftUI

enum EditorMode: String {
    case move
    case draw
    case erase
}

struct CourtEditorView: View {
    @EnvironmentObject var playStore: PlayStore

    @State private var players: [Player] = Formation.allPlayers(for: .half)
    @State private var balls: [Ball] = [Ball()]
    @State private var lines: [DrawingLine] = []
    @State private var courtMode: CourtMode = .half
    @State private var editorMode: EditorMode = .move
    @State private var selectedLineType: LineType = .cut
    @State private var selectedLineColor: LineColor = .black
    @State private var currentDrawing: DrawingLine? = nil
    @State private var selectedPlayerID: UUID? = nil
    @State private var draggingBallID: UUID? = nil
    enum HandSide { case left, right }
    @State private var ballAttachments: [UUID: (playerID: UUID, hand: HandSide, snapAngle: Double?)] = [:]
    @State private var editingPlayerID: UUID? = nil
    @State private var editingNumber: String = ""
    @State private var showSaveSheet = false
    @State private var showLoadSheet = false
    @State private var saveName: String = ""
    @State private var showHomeVision: Bool = true
    @State private var showAwayVision: Bool = true
    @State private var showArms: Bool = true

    // Recording
    @State private var isRecording = false
    @State private var recordingSnapshots: [PlaySnapshot] = []
    @State private var recordingStart: Date? = nil
    @State private var recordingTimer: Timer? = nil

    // Playback
    @State private var isPlaying = false
    @State private var playbackPlay: Play? = nil
    @State private var playbackTime: TimeInterval = 0
    @State private var playbackTimer: Timer? = nil

    // Export
    @State private var isExporting = false
    @State private var exportedVideoURL: URL? = nil
    @State private var showShareSheet = false

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
        .alert("Edit Number", isPresented: Binding(
            get: { editingPlayerID != nil },
            set: { if !$0 { editingPlayerID = nil } }
        )) {
            TextField("Number", text: $editingNumber)
                .keyboardType(.numberPad)
            Button("OK") { applyNumberEdit() }
            Button("Delete", role: .destructive) {
                if let pid = editingPlayerID {
                    players.removeAll { $0.id == pid }
                }
                editingPlayerID = nil
            }
            Button("Cancel", role: .cancel) { editingPlayerID = nil }
        }
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .sheet(isPresented: $showLoadSheet) { loadSheet }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedVideoURL {
                ShareSheet(items: [url])
            }
        }
        .onDisappear {
            recordingTimer?.invalidate()
            recordingTimer = nil
            playbackTimer?.invalidate()
            playbackTimer = nil
        }
    }

    // MARK: - Landscape

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        let compact = geo.size.height < 500
        let btnSize: CGFloat = compact ? 34 : 40
        let toolW: CGFloat = btnSize + 12
        return HStack(spacing: 0) {
            // Left toolbar: actions + court mode
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: compact ? 4 : 6) {
                    courtModeToggle(size: btnSize)
                    actionButtons(size: btnSize)
                }
            }
            .frame(width: toolW)
            .padding(.vertical, 6)
            .padding(.leading, 4)

            // Court
            courtView(isPortrait: false)

            // Right toolbar: playback controls or draw tools
            if playbackPlay != nil {
                playbackBar(btnSize: btnSize, horizontal: false)
                    .frame(width: toolW + 40)
                    .padding(.vertical, 6)
                    .padding(.trailing, 4)
            } else {
                drawToolbar(horizontal: false, btnSize: btnSize)
                    .frame(width: toolW)
                    .padding(.vertical, 6)
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Portrait

    private func portraitLayout(geo: GeometryProxy) -> some View {
        let btnSize: CGFloat = geo.size.width < 400 ? 32 : 38
        return VStack(spacing: 0) {
            // Top bar: court mode (fixed) + actions (scrollable)
            HStack(spacing: 4) {
                courtModeToggle(size: btnSize)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        actionButtons(size: btnSize)
                    }
                }
            }
            .padding(.horizontal, 6)
            .frame(height: btnSize + 8)

            // Court
            courtView(isPortrait: true)

            // Bottom bar: playback controls or draw tools
            if playbackPlay != nil {
                playbackBar(btnSize: btnSize)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    drawToolbar(horizontal: true, btnSize: btnSize)
                        .padding(.horizontal, 6)
                }
                .frame(height: btnSize + 8)
            }
        }
    }

    // MARK: - Shared UI

    @ViewBuilder
    private func actionButtons(size: CGFloat) -> some View {
        // REC / STOP
        if isRecording {
            Button { stopRecording() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size, height: size)
                    .background(Color.red)
                    .cornerRadius(size * 0.2)
            }
        } else {
            Button { startRecording() } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .frame(width: size, height: size)
                    .background(.ultraThinMaterial)
                    .cornerRadius(size * 0.2)
            }
            .disabled(playbackPlay != nil)
        }

        floatingBtn("folder", size: size) { showLoadSheet = true }
            .disabled(isRecording)
        floatingBtn("arrow.uturn.backward", size: size) { if !lines.isEmpty { lines.removeLast() } }
            .disabled(isRecording)
        floatingBtn("trash", color: .red, size: size) { resetBoard() }
            .disabled(isRecording)
        addPlayerBtn(team: .home, size: size)
            .disabled(isRecording)
        addPlayerBtn(team: .away, size: size)
            .disabled(isRecording)
        Button {
            let pos = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: 0.3...0.7))
            balls.append(Ball(position: pos))
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Color.orange)
                .cornerRadius(size * 0.2)
        }
        .disabled(isRecording)
        Button {
            showArms.toggle()
            if !showArms {
                showHomeVision = false
                showAwayVision = false
            }
        } label: {
            Image(systemName: showArms ? "hand.raised.fill" : "hand.raised.slash")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(showArms ? Color.gray : Color.gray.opacity(0.3))
                .cornerRadius(size * 0.2)
        }
        Button {
            showHomeVision.toggle()
            if showHomeVision { showArms = true }
        } label: {
            Image(systemName: showHomeVision ? "eye" : "eye.slash")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(showHomeVision ? Color.blue : Color.blue.opacity(0.3))
                .cornerRadius(size * 0.2)
        }
        Button {
            showAwayVision.toggle()
            if showAwayVision { showArms = true }
        } label: {
            Image(systemName: showAwayVision ? "eye" : "eye.slash")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(showAwayVision ? Color.red : Color.red.opacity(0.3))
                .cornerRadius(size * 0.2)
        }
    }

    private func addPlayerBtn(team: Team, size: CGFloat) -> some View {
        Button {
            let count = players.filter { $0.team == team }.count
            let number = "\(count + 1)"
            let pos = CGPoint(x: CGFloat.random(in: 0.3...0.7), y: CGFloat.random(in: 0.3...0.7))
            players.append(Player(number: number, team: team, position: pos))
        } label: {
            Image(systemName: "plus")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(team == .home ? Color.blue : Color.red)
                .cornerRadius(size * 0.2)
        }
    }

    @ViewBuilder
    private func drawToolbar(horizontal: Bool, btnSize: CGFloat) -> some View {
        let colorSize = btnSize * 0.58
        let content = Group {
            modeBtn("hand.draw", mode: .move, size: btnSize)
            modeBtn("pencil.tip", mode: .draw, size: btnSize)
            modeBtn("eraser", mode: .erase, size: btnSize)

            if editorMode == .draw {
                if horizontal {
                    Divider().frame(height: btnSize * 0.7)
                } else {
                    Divider().frame(width: btnSize * 0.7)
                }

                ForEach(LineType.allCases, id: \.self) { type in
                    Button { selectedLineType = type } label: {
                        LinePreview(type: type)
                            .frame(width: btnSize, height: btnSize)
                            .background(selectedLineType == type ? Color.blue.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: btnSize * 0.15)
                                    .stroke(selectedLineType == type ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                            .cornerRadius(btnSize * 0.15)
                    }
                }

                if horizontal {
                    Divider().frame(height: btnSize * 0.7)
                } else {
                    Divider().frame(width: btnSize * 0.7)
                }

                ForEach(LineColor.allCases, id: \.self) { lc in
                    Circle().fill(lc.color).frame(width: colorSize, height: colorSize)
                        .overlay(Circle().stroke(selectedLineColor == lc ? .white : .clear, lineWidth: 2))
                        .shadow(color: selectedLineColor == lc ? lc.color.opacity(0.6) : .clear, radius: 3)
                        .onTapGesture { selectedLineColor = lc }
                }
            }
        }

        if horizontal {
            HStack(spacing: 4) { content }
        } else {
            VStack(spacing: 4) { content }
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

                LineDrawingView(lines: lines, isPortrait: isPortrait, isHalf: courtMode == .half)
                    .frame(width: cs.width, height: cs.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if let drawing = currentDrawing {
                    LineDrawingView(lines: [drawing], isPortrait: isPortrait, isHalf: courtMode == .half)
                        .frame(width: cs.width, height: cs.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Balls
                ForEach(balls) { ball in
                    BallView(isSelected: draggingBallID == ball.id, scale: uiScale)
                        .position(courtToScreen(ball.position, cs: cs, origin: origin, isPortrait: isPortrait))
                        .allowsHitTesting(playbackPlay == nil)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    draggingBallID = ball.id
                                    ballAttachments[ball.id] = nil
                                    if let idx = balls.firstIndex(where: { $0.id == ball.id }) {
                                        balls[idx].position = screenToCourt(v.location, cs: cs, origin: origin, isPortrait: isPortrait)
                                    }
                                }
                                .onEnded { _ in
                                    snapBallToNearestPlayer(ballID: ball.id, cs: cs, origin: origin, isPortrait: isPortrait)
                                    draggingBallID = nil
                                }
                        )
                        .onTapGesture(count: 3) {
                            if balls.count > 1 {
                                balls.removeAll { $0.id == ball.id }
                                ballAttachments.removeValue(forKey: ball.id)
                            }
                        }
                }

                // Players
                ForEach(players) { player in
                    let screenPos = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
                    InteractivePlayerView(
                        player: player,
                        isSelected: selectedPlayerID == player.id,
                        screenPosition: screenPos,
                        scale: uiScale,
                        interactive: playbackPlay == nil,
                        showArms: showArms,
                        onMove: { location in
                            selectedPlayerID = player.id
                            let newPos = screenToCourt(location, cs: cs, origin: origin, isPortrait: isPortrait)
                            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                players[idx].position = newPos
                                updateAttachedBalls(playerID: player.id, cs: cs, origin: origin, isPortrait: isPortrait)
                            }
                        },
                        onRotate: { angle in
                            if let idx = players.firstIndex(where: { $0.id == player.id }) {
                                players[idx].facing = angle
                                updateAttachedBalls(playerID: player.id, cs: cs, origin: origin, isPortrait: isPortrait)
                            }
                        },
                        onMoveEnd: {}
                    )
                    .onTapGesture(count: 3) {
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
            .onAppear {
                updateFacingsIfNeeded(isPortrait: isPortrait)
                snapBallToPlayer1(cs: cs, origin: origin, isPortrait: isPortrait)
            }
            .onChange(of: courtMode) { _ in
                DispatchQueue.main.async {
                    updateFacingsIfNeeded(isPortrait: isPortrait)
                    snapBallToPlayer1(cs: cs, origin: origin, isPortrait: isPortrait)
                }
            }
            .onChange(of: geo.size.width) { _ in
                updateFacingsIfNeeded(isPortrait: isPortrait)
                updateAttachedBallsAll(cs: cs, origin: origin, isPortrait: isPortrait)
            }
        }
    }

    // MARK: - Coordinate Mapping

    private func courtToScreen(_ pos: CGPoint, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        if isPortrait {
            return CGPoint(x: origin.x + pos.x * cs.width, y: origin.y + (1 - pos.y) * cs.height)
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
                y: 1 - (screen.y - origin.y) / cs.height
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

    // MARK: - Playback Bar

    @ViewBuilder
    private func playbackBar(btnSize: CGFloat, horizontal: Bool = true) -> some View {
        let duration = playbackPlay?.duration ?? 1
        if horizontal {
            HStack(spacing: 8) {
                Button { togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: btnSize * 0.4))
                        .foregroundColor(.primary)
                        .frame(width: btnSize, height: btnSize)
                        .background(.ultraThinMaterial)
                        .cornerRadius(btnSize * 0.2)
                }
                Slider(value: $playbackTime, in: 0...max(duration, 0.01)) { editing in
                    if editing { stopPlayback() }
                    applySnapshot(at: playbackTime)
                }
                Text(String(format: "%.1fs", playbackTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                Button { exportVideo() } label: {
                    if isExporting {
                        ProgressView()
                            .frame(width: btnSize, height: btnSize)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: btnSize * 0.35))
                            .foregroundColor(.primary)
                            .frame(width: btnSize, height: btnSize)
                            .background(.ultraThinMaterial)
                            .cornerRadius(btnSize * 0.2)
                    }
                }
                .disabled(isExporting)
                Button {
                    stopPlayback()
                    playbackPlay = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: btnSize * 0.35))
                        .foregroundColor(.primary)
                        .frame(width: btnSize, height: btnSize)
                        .background(.ultraThinMaterial)
                        .cornerRadius(btnSize * 0.2)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: btnSize + 8)
        } else {
            VStack(spacing: 6) {
                Button { togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: btnSize * 0.4))
                        .foregroundColor(.primary)
                        .frame(width: btnSize, height: btnSize)
                        .background(.ultraThinMaterial)
                        .cornerRadius(btnSize * 0.2)
                }
                Text(String(format: "%.1fs", playbackTime))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button { exportVideo() } label: {
                    if isExporting {
                        ProgressView()
                            .frame(width: btnSize, height: btnSize)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: btnSize * 0.35))
                            .foregroundColor(.primary)
                            .frame(width: btnSize, height: btnSize)
                            .background(.ultraThinMaterial)
                            .cornerRadius(btnSize * 0.2)
                    }
                }
                .disabled(isExporting)
                Button {
                    stopPlayback()
                    playbackPlay = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: btnSize * 0.35))
                        .foregroundColor(.primary)
                        .frame(width: btnSize, height: btnSize)
                        .background(.ultraThinMaterial)
                        .cornerRadius(btnSize * 0.2)
                }
            }
        }
    }

    private func exportVideo() {
        guard let play = playbackPlay, !isExporting else { return }
        stopPlayback()
        isExporting = true
        VideoExporter.export(
            play: play,
            courtMode: courtMode,
            showHomeVision: showHomeVision,
            showAwayVision: showAwayVision
        ) { url in
            isExporting = false
            if let url = url {
                exportedVideoURL = url
                showShareSheet = true
            }
        }
    }

    private func togglePlayback() {
        guard let play = playbackPlay else { return }
        if isPlaying {
            stopPlayback()
        } else {
            if playbackTime >= play.duration { playbackTime = 0 }
            startPlayback(play)
        }
    }

    // MARK: - UI Components

    private func floatingBtn(_ icon: String, color: Color = .primary, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial)
                .cornerRadius(size * 0.2)
        }
    }

    private func courtModeToggle(size: CGFloat) -> some View {
        Button {
            let newMode: CourtMode = courtMode == .half ? .full : .half
            courtMode = newMode
            players = Formation.allPlayers(for: newMode)
            balls = [Ball()]
            ballAttachments = [:]
            needsSnap = true
            needsFacingUpdate = true
            lines = []
        } label: {
            Text(courtMode == .half ? "Half" : "Full")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: size * 1.3, height: size)
                .background(.ultraThinMaterial)
                .cornerRadius(size * 0.2)
        }
        .disabled(isRecording || playbackPlay != nil)
    }

    private func modeBtn(_ icon: String, mode: EditorMode, size: CGFloat) -> some View {
        Button { editorMode = mode } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundColor(editorMode == mode ? .white : .secondary)
                .frame(width: size, height: size)
                .background(editorMode == mode ? Color.blue : Color(.systemGray5))
                .cornerRadius(size * 0.18)
        }
    }

    // MARK: - Save / Load

    private var saveSheet: some View {
        NavigationStack {
            Form { TextField("Play Name", text: $saveName) }
            .navigationTitle("Save").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recordingSnapshots = []
                        showSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let play = Play(
                            name: saveName.isEmpty ? "Play \(playStore.plays.count + 1)" : saveName,
                            snapshots: recordingSnapshots
                        )
                        playStore.save(play)
                        recordingSnapshots = []
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
                    Text("No saved plays").foregroundStyle(.secondary)
                } else {
                    ForEach(playStore.plays) { play in
                        Button {
                            showLoadSheet = false
                            playbackTime = 0
                            playbackPlay = play
                            applySnapshot(at: 0)
                        } label: {
                            HStack {
                                Text(play.name)
                                Spacer()
                                Text(String(format: "%.1fs", play.duration))
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { playStore.delete(playStore.plays[i]) }
                    }
                }
            }
            .navigationTitle("Load").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { showLoadSheet = false } }
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
        balls = [Ball()]
        ballAttachments = [:]
        needsSnap = true
        needsFacingUpdate = true
        lines = []
        selectedPlayerID = nil
    }

    private func handPosition(for player: Player, hand: HandSide, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        let spread: CGFloat = .pi / 3.2
        let armReach: CGFloat = 0.92 // (bodyR 0.37 + armLen 0.55) normalized
        let armsFrame: CGFloat = 40.0
        let pixelDist = armReach * armsFrame
        let handAngle = hand == .left ? player.facing - spread : player.facing + spread
        let screenCenter = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
        let sx = screenCenter.x + pixelDist * sin(handAngle)
        let sy = screenCenter.y - pixelDist * cos(handAngle)
        return screenToCourt(CGPoint(x: sx, y: sy), cs: cs, origin: origin, isPortrait: isPortrait)
    }

    private func snapBallToNearestPlayer(ballID: UUID, cs: CGSize, origin: CGPoint, isPortrait: Bool) {
        guard let bi = balls.firstIndex(where: { $0.id == ballID }) else { return }
        let ballPos = balls[bi].position
        let snapDist: CGFloat = 0.06

        if showArms {
            var closest: (UUID, HandSide, CGFloat)?
            for player in players {
                for hand in [HandSide.left, .right] {
                    let hp = handPosition(for: player, hand: hand, cs: cs, origin: origin, isPortrait: isPortrait)
                    let d = hypot(hp.x - ballPos.x, hp.y - ballPos.y)
                    if d < snapDist && (closest == nil || d < closest!.2) {
                        closest = (player.id, hand, d)
                    }
                }
            }
            if let (playerID, hand, _) = closest {
                ballAttachments[ballID] = (playerID: playerID, hand: hand, snapAngle: nil)
                guard let snapPlayer = players.first(where: { $0.id == playerID }) else { return }
                let hp = handPosition(for: snapPlayer, hand: hand, cs: cs, origin: origin, isPortrait: isPortrait)
                balls[bi].position = hp
            }
        } else {
            var closest: (UUID, CGFloat)?
            for player in players {
                let d = hypot(player.position.x - ballPos.x, player.position.y - ballPos.y)
                if d < snapDist && (closest == nil || d < closest!.1) {
                    closest = (player.id, d)
                }
            }
            if let (playerID, _) = closest {
                guard let snapPlayer = players.first(where: { $0.id == playerID }) else { return }
                let angle = calcSnapAngle(for: snapPlayer, ballPos: ballPos, cs: cs, origin: origin, isPortrait: isPortrait)
                ballAttachments[ballID] = (playerID: playerID, hand: .right, snapAngle: angle)
                balls[bi].position = bodySnapPositionFromAngle(for: snapPlayer, angle: angle, cs: cs, origin: origin, isPortrait: isPortrait)
            }
        }
    }

    private func calcSnapAngle(for player: Player, ballPos: CGPoint, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> Double {
        let screenCenter = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
        let screenBall = courtToScreen(ballPos, cs: cs, origin: origin, isPortrait: isPortrait)
        let dx = screenBall.x - screenCenter.x
        let dy = screenBall.y - screenCenter.y
        return atan2(Double(dx), Double(-dy))
    }

    private func bodySnapPositionFromAngle(for player: Player, angle: Double, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        let screenCenter = courtToScreen(player.position, cs: cs, origin: origin, isPortrait: isPortrait)
        let offset: CGFloat = 34
        let snapScreen = CGPoint(
            x: screenCenter.x + offset * CGFloat(sin(angle)),
            y: screenCenter.y - offset * CGFloat(cos(angle))
        )
        return screenToCourt(snapScreen, cs: cs, origin: origin, isPortrait: isPortrait)
    }

    @State private var needsSnap = true
    @State private var needsFacingUpdate = true
    @State private var lastFacingPortrait: Bool? = nil

    private func updateFacingsIfNeeded(isPortrait: Bool) {
        let orientationChanged = lastFacingPortrait != nil && lastFacingPortrait != isPortrait && courtMode == .full
        guard needsFacingUpdate || orientationChanged else { return }
        needsFacingUpdate = false
        lastFacingPortrait = isPortrait
        let ring = CGPoint(x: 0.5, y: 0)
        let isLandscapeFull = !isPortrait && courtMode == .full
        for i in players.indices {
            let pos = players[i].position
            let target: CGPoint
            if players[i].team == .home {
                target = ring
            } else {
                if let matchup = players.first(where: { $0.team == .home && $0.number == players[i].number }) {
                    target = matchup.position
                } else {
                    target = ring
                }
            }
            if isLandscapeFull {
                let sdx = Double(target.y - pos.y)
                let sdy = Double(target.x - pos.x)
                players[i].facing = atan2(sdx, -sdy)
            } else {
                let dx = Double(target.x - pos.x)
                let dy = Double(target.y - pos.y)
                players[i].facing = atan2(dx, dy)
            }
        }
    }

    private func snapBallToPlayer1(cs: CGSize, origin: CGPoint, isPortrait: Bool) {
        guard needsSnap else { return }
        needsSnap = false
        if let pg = players.first(where: { $0.team == .home && $0.number == "1" }),
           let bi = balls.indices.first {
            if showArms {
                balls[bi].position = handPosition(for: pg, hand: .right, cs: cs, origin: origin, isPortrait: isPortrait)
            } else {
                let angle = calcSnapAngle(for: pg, ballPos: balls[bi].position, cs: cs, origin: origin, isPortrait: isPortrait)
                balls[bi].position = bodySnapPositionFromAngle(for: pg, angle: angle, cs: cs, origin: origin, isPortrait: isPortrait)
                ballAttachments[balls[bi].id] = (playerID: pg.id, hand: .right, snapAngle: angle)
                return
            }
            ballAttachments[balls[bi].id] = (playerID: pg.id, hand: .right, snapAngle: nil)
        }
    }

    private func attachedBallPosition(for player: Player, hand: HandSide, snapAngle: Double?, cs: CGSize, origin: CGPoint, isPortrait: Bool) -> CGPoint {
        if showArms {
            return handPosition(for: player, hand: hand, cs: cs, origin: origin, isPortrait: isPortrait)
        } else {
            let angle = snapAngle ?? Double(player.facing)
            return bodySnapPositionFromAngle(for: player, angle: angle, cs: cs, origin: origin, isPortrait: isPortrait)
        }
    }

    private func updateAttachedBallsAll(cs: CGSize, origin: CGPoint, isPortrait: Bool) {
        for (ballID, attachment) in ballAttachments {
            if let bi = balls.firstIndex(where: { $0.id == ballID }),
               let player = players.first(where: { $0.id == attachment.playerID }) {
                balls[bi].position = attachedBallPosition(for: player, hand: attachment.hand, snapAngle: attachment.snapAngle, cs: cs, origin: origin, isPortrait: isPortrait)
            }
        }
    }

    private func updateAttachedBalls(playerID: UUID, cs: CGSize, origin: CGPoint, isPortrait: Bool) {
        for (ballID, attachment) in ballAttachments where attachment.playerID == playerID {
            if let bi = balls.firstIndex(where: { $0.id == ballID }),
               let player = players.first(where: { $0.id == playerID }) {
                balls[bi].position = attachedBallPosition(for: player, hand: attachment.hand, snapAngle: attachment.snapAngle, cs: cs, origin: origin, isPortrait: isPortrait)
            }
        }
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

    // MARK: - Recording

    private func startRecording() {
        recordingSnapshots = []
        recordingStart = Date()
        isRecording = true
        captureSnapshot()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            captureSnapshot()
        }
    }

    private func captureSnapshot() {
        guard let start = recordingStart else { return }
        let t = Date().timeIntervalSince(start)
        recordingSnapshots.append(PlaySnapshot(players: players, balls: balls, lines: lines, timestamp: t))
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        captureSnapshot()
        isRecording = false
        saveName = ""
        showSaveSheet = true
    }

    // MARK: - Playback

    private func startPlayback(_ play: Play) {
        playbackPlay = play
        playbackTime = 0
        applySnapshot(at: 0)
        isPlaying = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            guard let p = playbackPlay else { return }
            playbackTime += 1.0 / 30.0
            if playbackTime >= p.duration {
                playbackTime = p.duration
                stopPlayback()
            }
            applySnapshot(at: playbackTime)
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }

    private func applySnapshot(at time: TimeInterval) {
        guard let play = playbackPlay,
              let snap = play.interpolated(at: time) else { return }
        players = snap.players
        balls = snap.balls
        lines = snap.lines
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
            case .plain:
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
