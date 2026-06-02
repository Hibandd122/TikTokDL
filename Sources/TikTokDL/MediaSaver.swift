import Foundation
import Photos
import UIKit

enum SaveResult {
    case savedToPhotos
    case savedToFiles(URL)
}

enum MediaSaver {
    /// Lưu file media: video/ảnh thì vào Photos, audio/zip thì giữ ở Files (Documents) để user mở qua Share Sheet.
    static func save(fileURL: URL, mime: String) async throws -> SaveResult {
        if mime.hasPrefix("video/") {
            try await ensurePhotoAuth()
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }
            return .savedToPhotos
        }
        if mime.hasPrefix("image/") {
            try await ensurePhotoAuth()
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            }
            return .savedToPhotos
        }

        // audio / zip / khác: copy vào Documents để user truy cập từ Files app
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dest = docs.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: fileURL, to: dest)
        return .savedToFiles(dest)
    }

    private static func ensurePhotoAuth() async throws {
        let status = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in cont.resume(returning: s) }
        }
        guard status == .authorized || status == .limited else {
            throw NSError(
                domain: "MediaSaver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cần quyền lưu vào Photos. Bật trong Settings."]
            )
        }
    }
}
