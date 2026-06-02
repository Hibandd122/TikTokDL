import Foundation

actor TikTokAPI {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// Gọi POST /tiktok-downloader với action=preview để lấy media info.
    /// Backend dùng Flask-Session (cookie) để nhớ context cho lượt download tiếp theo.
    func fetchPreview(baseURL: URL, tiktokURL: String) async throws -> TikTokPreview {
        let endpoint = baseURL.appendingPathComponent("tiktok-downloader")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = "action=preview&url=\(tiktokURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        guard (200..<300).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String {
                throw APIError.server(err)
            }
            throw APIError.http(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding
        }

        if let err = json["error"] as? String { throw APIError.server(err) }

        let typeStr = (json["type"] as? String) ?? "video"
        let author = (json["author"] as? String) ?? "tiktok"
        let desc = (json["desc"] as? String) ?? ""
        let audio = json["audio"] as? String
        let dataField = json["data"]

        var videoURL: String?
        var images: [String] = []

        switch typeStr {
        case "slideshow":
            if let arr = dataField as? [String] { images = arr }
        default:
            if let s = dataField as? String { videoURL = s }
        }

        return TikTokPreview(
            type: typeStr == "slideshow" ? .slideshow : .video,
            author: author,
            desc: desc,
            videoURL: videoURL,
            imageURLs: images,
            audioURL: audio
        )
    }

    /// Yêu cầu server stream media về máy. Server đọc session đã có từ bước preview.
    /// Trả về (tempFileURL, suggestedFilename, mimeType).
    func downloadMedia(
        baseURL: URL,
        kind: DownloadKind,
        imageURL: String? = nil
    ) async throws -> (URL, String, String) {
        let endpoint = baseURL.appendingPathComponent("tiktok-downloader")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var parts = ["action=\(kind.rawValue)"]
        if let imageURL, kind == .singleImage {
            let encoded = imageURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            parts.append("img_url=\(encoded)")
        }
        req.httpBody = parts.joined(separator: "&").data(using: .utf8)

        let (tmpURL, response) = try await session.download(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200..<300).contains(http.statusCode) else {
            let data = (try? Data(contentsOf: tmpURL)) ?? Data()
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.server(msg)
        }

        let filename = Self.extractFilename(from: http) ?? "tiktok_\(Int(Date().timeIntervalSince1970)).bin"
        let mime = http.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"

        // Move ra file path mình kiểm soát được (URLSession xoá file sau khi handler return).
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + filename)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpURL, to: dest)
        return (dest, filename, mime)
    }

    private static func extractFilename(from http: HTTPURLResponse) -> String? {
        guard let cd = http.value(forHTTPHeaderField: "Content-Disposition") else { return nil }
        // Content-Disposition: attachment; filename=foo.mp4
        if let range = cd.range(of: "filename=") {
            let raw = cd[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if let semi = raw.firstIndex(of: ";") {
                return String(raw[..<semi]).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            }
            return raw
        }
        return nil
    }
}
