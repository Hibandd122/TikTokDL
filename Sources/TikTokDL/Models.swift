import Foundation

struct TikTokPreview: Codable, Equatable {
    enum MediaType: String, Codable {
        case video
        case slideshow
    }

    let type: MediaType
    let author: String
    let desc: String
    let videoURL: String?
    let imageURLs: [String]
    let audioURL: String?

    static let empty = TikTokPreview(type: .video, author: "", desc: "", videoURL: nil, imageURLs: [], audioURL: nil)
}

enum DownloadKind: String {
    case video = "download_video"
    case audio = "download_audio"
    case slideshow = "download_zip"
    case singleImage = "download_single"
}

enum APIError: LocalizedError {
    case badURL
    case server(String)
    case decoding
    case http(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .badURL: return "Server URL không hợp lệ."
        case .server(let msg): return msg
        case .decoding: return "Không giải mã được phản hồi từ server."
        case .http(let code): return "HTTP \(code)"
        case .noData: return "Server không trả về dữ liệu."
        }
    }
}

struct DownloadHistoryItem: Identifiable, Codable, Equatable {
    var id: String { timestamp.description + author }
    let author: String
    let desc: String
    let type: String
    let timestamp: Date
    let videoURL: String?
    let imageURLs: [String]
    let audioURL: String?
}
