import SwiftUI
import UIKit
import UserNotifications

struct Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var inputURL: String = ""
    @Published var preview: TikTokPreview?
    @Published var isLoading: Bool = false
    @Published var status: String = ""
    @Published var lastFileToShare: URL?
    @Published var history: [DownloadHistoryItem] = []

    private let api = TikTokAPI()
    private weak var settings: AppSettings?
    private let historyKey = "download_history_v2"

    var isValidURL: Bool {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("tiktok.com") || trimmed.contains("douyin.com") || trimmed.contains("iesdouyin.com")
    }

    func bind(_ settings: AppSettings) { 
        self.settings = settings 
        NotificationManager.requestPermission()
        loadHistory()
    }

    func checkClipboardForLink() {
        guard inputURL.isEmpty else { return }
        if let s = UIPasteboard.general.string {
            let lowered = s.lowercased()
            if lowered.contains("tiktok.com") || lowered.contains("douyin.com") || lowered.contains("iesdouyin.com") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    inputURL = s
                }
                Haptics.impact()
            }
        }
    }

    func fetchPreview() {
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            Haptics.error()
            return
        }
        guard isValidURL else {
            status = "Vui lòng nhập link TikTok hoặc Douyin hợp lệ."
            Haptics.error()
            return
        }
        Task {
            withAnimation { isLoading = true }
            status = "Đang lấy thông tin..."
            defer { withAnimation { isLoading = false } }
            do {
                let info = try await api.fetchPreview(baseURL: baseURL, tiktokURL: inputURL)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.preview = info
                    self.status = "✓ \(info.author) — \(info.type == .slideshow ? "\(info.imageURLs.count) ảnh" : "video")"
                }
                addToHistory(preview: info)
                Haptics.success()
            } catch {
                withAnimation {
                    self.preview = nil
                    self.status = error.localizedDescription
                }
                Haptics.error()
            }
        }
    }

    func download(kind: DownloadKind, imageURL: String? = nil) {
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            Haptics.error()
            return
        }
        
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "DownloadMedia") {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        Task {
            withAnimation { isLoading = true }
            status = "Đang tải..."
            
            defer { 
                withAnimation { isLoading = false } 
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
            
            do {
                let (file, name, mime) = try await api.downloadMedia(baseURL: baseURL, kind: kind, imageURL: imageURL)
                let result = try await MediaSaver.save(fileURL: file, mime: mime)
                
                let successMsg: String
                switch result {
                case .savedToPhotos:
                    successMsg = "✓ Đã lưu vào Ảnh (Photos)."
                    lastFileToShare = nil
                case .savedToFiles(let url):
                    successMsg = "✓ Đã lưu. Nhấn icon Share để gửi đi."
                    lastFileToShare = url
                }
                
                withAnimation { status = successMsg }
                Haptics.success()
                
                if UIApplication.shared.applicationState == .background {
                    NotificationManager.send(title: "Tải thành công! 🎉", body: successMsg.replacingOccurrences(of: "✓ ", with: ""))
                }
                
            } catch {
                let errMsg = error.localizedDescription
                withAnimation { status = errMsg }
                Haptics.error()
                
                if UIApplication.shared.applicationState == .background {
                    NotificationManager.send(title: "Tải thất bại ❌", body: errMsg)
                }
            }
        }
    }

    func downloadAllImagesToPhotos() {
        guard let preview = preview, preview.type == .slideshow else { return }
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            Haptics.error()
            return
        }

        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "DownloadAllImages") {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }

        Task {
            withAnimation { isLoading = true }
            status = "Đang tải ảnh (0/\(preview.imageURLs.count))..."
            
            defer { 
                withAnimation { isLoading = false } 
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }

            var successCount = 0
            for (index, imageURL) in preview.imageURLs.enumerated() {
                do {
                    withAnimation {
                        status = "Đang tải ảnh (\(index + 1)/\(preview.imageURLs.count))..."
                    }
                    let (file, _, mime) = try await api.downloadMedia(baseURL: baseURL, kind: .singleImage, imageURL: imageURL)
                    let result = try await MediaSaver.save(fileURL: file, mime: mime)
                    if case .savedToPhotos = result {
                        successCount += 1
                    }
                } catch {
                    print("Failed to download image: \(error.localizedDescription)")
                }
            }

            let successMsg = "✓ Đã lưu \(successCount)/\(preview.imageURLs.count) ảnh vào Album."
            withAnimation { status = successMsg }
            Haptics.success()

            if UIApplication.shared.applicationState == .background {
                NotificationManager.send(title: "Tải thành công! 🎉", body: successMsg)
            }
        }
    }

    func clear() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            preview = nil
            inputURL = ""
            status = ""
            lastFileToShare = nil
        }
        Haptics.impact()
    }

    // MARK: - History Management

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([DownloadHistoryItem].self, from: data) {
            self.history = items
        }
    }

    func addToHistory(preview: TikTokPreview) {
        let newItem = DownloadHistoryItem(
            author: preview.author,
            desc: preview.desc,
            type: preview.type.rawValue,
            timestamp: Date(),
            videoURL: preview.videoURL,
            imageURLs: preview.imageURLs,
            audioURL: preview.audioURL
        )
        history.removeAll { $0.author == newItem.author && $0.desc == newItem.desc }
        history.insert(newItem, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        saveHistory()
    }

    func deleteHistoryItem(_ item: DownloadHistoryItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func loadFromHistory(_ item: DownloadHistoryItem) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            self.preview = TikTokPreview(
                type: item.type == "slideshow" ? .slideshow : .video,
                author: item.author,
                desc: item.desc,
                videoURL: item.videoURL,
                imageURLs: item.imageURLs,
                audioURL: item.audioURL
            )
            self.status = "✓ Đã tải từ lịch sử"
        }
        Haptics.impact()
    }
}
