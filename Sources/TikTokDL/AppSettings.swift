import Foundation

final class AppSettings: ObservableObject {
    @Published var serverBaseURL: String {
        didSet {
            UserDefaults.standard.set(serverBaseURL, forKey: Self.urlKey)
        }
    }

    static let urlKey = "serverBaseURL"
    static let defaultURL = "https://mahirun.hicanh69.workers.dev"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.urlKey)
        self.serverBaseURL = (saved?.isEmpty == false ? saved! : Self.defaultURL)
    }

    func normalizedBaseURL() -> URL? {
        var raw = serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasSuffix("/") { raw.removeLast() }
        return URL(string: raw)
    }
}
