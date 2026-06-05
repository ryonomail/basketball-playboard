import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playStore: PlayStore
    @State private var showNewPlay = false

    var body: some View {
        NavigationStack {
            List {
                if playStore.plays.isEmpty {
                    ContentUnavailableView(
                        "プレイがありません",
                        systemImage: "sportscourt",
                        description: Text("＋ボタンで新しいプレイを作成")
                    )
                } else {
                    ForEach(playStore.plays) { play in
                        NavigationLink(destination: CourtEditorView(play: play)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(play.name)
                                    .font(.headline)
                                Text("\(play.frames.count) フレーム")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            playStore.deletePlay(playStore.plays[index])
                        }
                    }
                }
            }
            .navigationTitle("Basketball Playboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewPlay = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewPlay) {
                NewPlaySheet()
            }
        }
    }
}

struct NewPlaySheet: View {
    @EnvironmentObject var playStore: PlayStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("プレイ名", text: $name)
            }
            .navigationTitle("新規プレイ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        let homePlayers = Formation.defaultHome.players
                        let awayPlayers = Formation.defaultAway.players
                        let allPlayers = homePlayers + awayPlayers
                        let frame = PlayFrame(players: allPlayers)
                        var play = Play(name: name.isEmpty ? "新規プレイ" : name, frames: [frame])
                        play.frames = [frame]
                        playStore.addPlay(play)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
