import Foundation

class PlayStore: ObservableObject {
    @Published var plays: [Play] = []

    private let storageKey = "saved_plays_v2"

    init() {
        load()
    }

    func save(_ play: Play) {
        if let index = plays.firstIndex(where: { $0.id == play.id }) {
            plays[index] = play
        } else {
            plays.insert(play, at: 0)
        }
        persist()
    }

    func delete(_ play: Play) {
        plays.removeAll { $0.id == play.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(plays) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Play].self, from: data) {
            plays = decoded
        }
    }
}
