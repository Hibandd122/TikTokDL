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

    private let api = TikTokAPI()
    private weak var settings: AppSettings?

    var isValidTikTokURL: Bool {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("tiktok.com")
    }

    func bind(_ settings: AppSettings) { 
        self.settings = settings 
        NotificationManager.requestPermission()
    }

    func checkClipboardForTikTokLink() {
        guard inputURL.isEmpty else { return }
        if let s = UIPasteboard.general.string, s.lowercased().contains("tiktok.com") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                inputURL = s
            }
            Haptics.impact()
        }
    }

    func fetchPreview() {
        guard let baseURL = settings?.normalizedBaseURL() else {
            status = "Server URL chưa cấu hình."
            Haptics.error()
            return
        }
        guard isValidTikTokURL else {
            status = "Vui lòng nhập link TikTok hợp lệ."
            Haptics.error()
            return
        }
        Task {
            withAnimation { isLoading = true }
            status = "Đang lấy thông tin video..."
            defer { withAnimation { isLoading = false } }
            do {
                let info = try await api.fetchPreview(baseURL: baseURL, tiktokURL: inputURL)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.preview = info
                    self.status = "✓ \(info.author) — \(info.type == .slideshow ? "\(info.imageURLs.count) ảnh" : "video")"
                }
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
        
        // Bắt đầu Background Task để đảm bảo app không bị kill khi đang tải
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "DownloadMedia") {
            // Khi hết thời gian chạy nền cho phép, hệ thống gọi block này
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
                
                // Nếu app đang chạy ngầm, bắn thông báo cho người dùng
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

    func clear() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            preview = nil
            inputURL = ""
            status = ""
            lastFileToShare = nil
        }
        Haptics.impact()
    }
}
