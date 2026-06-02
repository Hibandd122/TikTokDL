import SwiftUI
import UIKit

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var inputURL: String = ""
    @Published var preview: TikTokPreview?
    @Published var isLoading: Bool = false
    @Published var status: String = ""
    @Published var lastFileToShare: URL?

    private let api = TikTokAPI()
    private weak var settings: AppSettings?

    func bind(_ settings: AppSettings) { self.settings = settings }

    func fetchPreview() {
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            return
        }
        guard !inputURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            status = "Nhập link TikTok trước."
            return
        }
        Task {
            isLoading = true
            status = "Đang lấy thông tin video..."
            defer { isLoading = false }
            do {
                let info = try await api.fetchPreview(baseURL: baseURL, tiktokURL: inputURL)
                self.preview = info
                self.status = "✓ \(info.author) — \(info.type == .slideshow ? "\(info.imageURLs.count) ảnh" : "video")"
            } catch {
                self.preview = nil
                self.status = error.localizedDescription
            }
        }
    }

    func download(kind: DownloadKind, imageURL: String? = nil) {
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            return
        }
        Task {
            isLoading = true
            status = "Đang tải..."
            defer { isLoading = false }
            do {
                let (file, name, mime) = try await api.downloadMedia(baseURL: baseURL, kind: kind, imageURL: imageURL)
                let result = try await MediaSaver.save(fileURL: file, mime: mime)
                switch result {
                case .savedToPhotos:
                    status = "✓ \(name) đã lưu vào Photos."
                    lastFileToShare = nil
                case .savedToFiles(let url):
                    status = "✓ \(name) lưu vào Files. Mở Share Sheet để gửi đi."
                    lastFileToShare = url
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func clear() {
        preview = nil
        inputURL = ""
        status = ""
        lastFileToShare = nil
    }
}
