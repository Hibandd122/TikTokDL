# TikTokDL — iOS app

App SwiftUI gọi backend Flask `downloadtiktok.py` (route `/tiktok-downloader`) để tải video/slideshow/audio TikTok về iPhone.

- Backend mặc định: `https://mahirun.hicanh69.workers.dev` (đổi được trong tab Settings của app)
- Cách build: **GitHub Actions trên runner macOS** (vì bạn dùng Windows) → tải IPA unsigned về sideload.

---

## Cấu trúc folder

```
ios-tiktok-app/
├── project.yml                       # XcodeGen — sinh .xcodeproj từ YAML, không commit .xcodeproj
├── Sources/TikTokDL/
│   ├── TikTokDLApp.swift             # @main entry
│   ├── ContentView.swift             # UI (URL input, preview card, settings sheet)
│   ├── DownloadViewModel.swift       # State machine
│   ├── TikTokAPI.swift               # URLSession client (giữ cookie Flask-Session)
│   ├── MediaSaver.swift              # Lưu Photos / Files
│   ├── Models.swift
│   ├── AppSettings.swift
│   └── Assets.xcassets/
└── .github/workflows/ios-build.yml   # CI build IPA
```

---

## Bước 1 — Đẩy folder này lên GitHub repo riêng

Trên Windows, mở PowerShell trong `ios-tiktok-app/`:

```powershell
cd D:\Anime\Web\HtmlWeb\ios-tiktok-app
git init
git add .
git commit -m "init TikTokDL iOS app"
git branch -M main
# Tạo repo trống tên TikTokDL trên github.com trước, rồi:
git remote add origin https://github.com/<your-username>/TikTokDL.git
git push -u origin main
```

> Workflow `.github/workflows/ios-build.yml` **chỉ chạy khi nằm ở root repo**. Đẩy folder này như repo riêng là cách đơn giản nhất.

## Bước 2 — Build tự động

Push xong, vào tab **Actions** của repo trên GitHub:
- Workflow **Build unsigned IPA** chạy ~3-5 phút trên `macos-14` runner.
- Bước **Upload IPA artifact** tạo file `TikTokDL-unsigned-ipa.zip`.

Có thể chạy thủ công: tab Actions → **Build unsigned IPA** → **Run workflow**.

Để cắt **release** (auto attach IPA vào release page):
```powershell
git tag v1.0.0
git push origin v1.0.0
```

## Bước 3 — Tải IPA về Windows

- Actions → run mới nhất → tải artifact `TikTokDL-unsigned-ipa.zip`
- Giải nén → có `TikTokDL-unsigned.ipa`

## Bước 4 — Sideload lên iPhone

IPA **chưa ký**, cần ký lại bằng Apple ID (free) hoặc paid developer account ($99/năm). Cách phổ biến trên Windows:

### Sideloadly (khuyên dùng, free, chạy trên Windows)
1. Tải [Sideloadly](https://sideloadly.io/) cho Windows.
2. Cắm iPhone qua USB → cài iTunes / driver Apple.
3. Mở Sideloadly → kéo file `TikTokDL-unsigned.ipa` vào.
4. Nhập Apple ID (free) → Start.
5. iPhone → Settings → General → VPN & Device Management → Trust developer.
6. App có hạn **7 ngày** với Apple ID free, sau đó mở Sideloadly resign lại. Apple Developer paid: 1 năm.

### AltStore
- Cần AltServer chạy nền trên PC. Nặng hơn Sideloadly nhưng tự re-sign mỗi 7 ngày khi cùng WiFi.

### Cài lên iPhone đã jailbreak (TrollStore, iOS 14.0 – 16.6.1)
- Mở TrollStore → Install → chọn IPA. App vĩnh viễn, không cần re-sign.

---

## Bước 5 — Backend phải reachable từ iPhone

Default `https://mahirun.hicanh69.workers.dev` đã public, không cần làm gì.
Nếu chỉ chạy local (`http://localhost:25120`), iPhone không truy cập được — phương án:
- Mở `python app.py` rồi expose qua [ngrok](https://ngrok.com/): `ngrok http 25120` → đổi Server URL trong app sang URL ngrok HTTPS.
- Hoặc deploy lên server thật (Cloudflare Worker, VPS, …) và cập nhật URL.

---

## Tự build trên Mac (nếu có Mac)

```bash
cd ios-tiktok-app
brew install xcodegen
xcodegen generate
open TikTokDL.xcodeproj
# Trong Xcode: chọn device → Run (Cmd+R)
```

Hoặc command line:
```bash
xcodebuild -project TikTokDL.xcodeproj -scheme TikTokDL \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO clean build
```

---

## Lưu ý kỹ thuật

- App dùng **`HTTPCookieStorage.shared`** vì backend Flask lưu state qua `Flask-Session` cookie giữa request `action=preview` và `action=download_*`.
- Video/ảnh → lưu vào Photos (cần quyền `NSPhotoLibraryAddUsageDescription`, đã khai trong `project.yml`).
- Audio/zip → lưu vào Documents → user mở Share Sheet để gửi ra Files / iCloud / Telegram.
- `NSAllowsArbitraryLoads = true` để dev local HTTP. Production nên đặt false + dùng HTTPS.
- App Store sẽ **từ chối** app loại này (vi phạm TOS TikTok). Chỉ dùng sideload cá nhân.
