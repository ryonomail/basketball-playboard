import Foundation

class PlayStore: ObservableObject {
    @Published var plays: [Play] = []

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("saved_plays.json")
    }

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
        do {
            let data = try JSONEncoder().encode(plays)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("PlayStore save error: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            plays = try JSONDecoder().decode([Play].self, from: data)
        } catch {
            plays = []
        }
    }
}
