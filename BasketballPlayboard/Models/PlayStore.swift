import Foundation

class PlayStore: ObservableObject {
    @Published var plays: [Play] = []
    @Published var formations: [Formation] = []

    private let playsKey = "saved_plays"
    private let formationsKey = "saved_formations"

    init() {
        load()
        if formations.isEmpty {
            formations = [Formation.defaultHome]
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(plays) {
            UserDefaults.standard.set(data, forKey: playsKey)
        }
        if let data = try? JSONEncoder().encode(formations) {
            UserDefaults.standard.set(data, forKey: formationsKey)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: playsKey),
           let decoded = try? JSONDecoder().decode([Play].self, from: data) {
            plays = decoded
        }
        if let data = UserDefaults.standard.data(forKey: formationsKey),
           let decoded = try? JSONDecoder().decode([Formation].self, from: data) {
            formations = decoded
        }
    }

    func addPlay(_ play: Play) {
        plays.insert(play, at: 0)
        save()
    }

    func deletePlay(_ play: Play) {
        plays.removeAll { $0.id == play.id }
        save()
    }

    func updatePlay(_ play: Play) {
        if let index = plays.firstIndex(where: { $0.id == play.id }) {
            plays[index] = play
            plays[index].updatedAt = Date()
            save()
        }
    }
}
