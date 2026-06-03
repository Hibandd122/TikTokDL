import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct AmbientBackgroundView: View {
    @State private var animate = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            Circle()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.4 : 0.25))
                .frame(width: 350, height: 350)
                .offset(x: animate ? 120 : -120, y: animate ? -150 : 150)
                .blur(radius: 90)
            
            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.4 : 0.25))
                .frame(width: 300, height: 300)
                .offset(x: animate ? -150 : 150, y: animate ? 120 : -100)
                .blur(radius: 80)
                
            Circle()
                .fill(Color.pink.opacity(colorScheme == .dark ? 0.4 : 0.2))
                .frame(width: 400, height: 400)
                .offset(x: animate ? 50 : -100, y: animate ? 100 : -200)
                .blur(radius: 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .ignoresSafeArea()
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = DownloadViewModel()
    @State private var showSettings = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Animated Premium Background
                AmbientBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.cyan.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 90, height: 90)
                                    .blur(radius: 10)
                                
                                Image(systemName: "arrow.down.to.line.circle.fill")
                                    .font(.system(size: 68, weight: .bold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: .purple.opacity(0.5), radius: 15, y: 8)
                            }
                            .padding(.bottom, 4)
                            
                            Text("TikTok DL")
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 12)

                        urlInputCard
                        
                        if let preview = vm.preview {
                            previewCard(preview)
                                .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: 20)))
                        }
                        
                        // Extra spacing at bottom for floating status
                        Spacer().frame(height: 80)
                    }
                    .padding()
                }
                
                // Floating Status Toast
                if !vm.status.isEmpty {
                    floatingStatusToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Trang chủ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if vm.lastFileToShare != nil {
                            Button {
                                Haptics.impact()
                                showShare = true
                            } label: { 
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        Button {
                            Haptics.impact()
                            showSettings = true
                        } label: { 
                            Image(systemName: "gearshape.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showShare) {
                if let url = vm.lastFileToShare { ShareSheet(items: [url]) }
            }
            .onAppear { vm.bind(settings) }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    vm.checkClipboardForTikTokLink()
                }
            }
        }
    }

    private var urlInputCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                
                TextField("Dán link TikTok vào đây...", text: $vm.inputURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit {
                        if vm.isValidTikTokURL {
                            vm.fetchPreview()
                        }
                    }
                
                if !vm.inputURL.isEmpty {
                    Button { 
                        vm.inputURL = ""
                        Haptics.impact()
                    } label: { 
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary) 
                            .font(.system(size: 20))
                    }
                }
                
                Divider().frame(height: 24)
                
                Button {
                    if let s = UIPasteboard.general.string { 
                        withAnimation(.spring()) { vm.inputURL = s }
                        Haptics.success()
                    }
                } label: { 
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 20))
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, y: 8)

            HStack(spacing: 12) {
                Button {
                    vm.fetchPreview()
                } label: {
                    HStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles.tv")
                        }
                        Text(vm.isLoading ? "Đang xử lý..." : "Phân tích")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: vm.isValidTikTokURL ? [.blue, .purple] : [.gray.opacity(0.5), .gray.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: vm.isValidTikTokURL ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
                }
                .disabled(vm.isLoading || vm.inputURL.isEmpty)
                .animation(.easeInOut, value: vm.isValidTikTokURL)
                
                if !vm.inputURL.isEmpty || vm.preview != nil {
                    Button {
                        vm.clear()
                    } label: {
                        Image(systemName: "trash")
                            .fontWeight(.bold)
                            .padding()
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.red.opacity(0.2), lineWidth: 1))
                            .shadow(color: .red.opacity(0.15), radius: 8, y: 4)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func previewCard(_ preview: TikTokPreview) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Author and Info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    
                    Text(String(preview.author.prefix(1).uppercased()))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .shadow(color: .pink.opacity(0.3), radius: 8, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(preview.author)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: preview.type == .slideshow ? "photo.on.rectangle.angled" : "play.rectangle.fill")
                        Text(preview.type == .slideshow ? "\(preview.imageURLs.count) ảnh" : "Video TikTok")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            if !preview.desc.isEmpty {
                Text(preview.desc)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Slideshow Thumbnails
            if preview.type == .slideshow, !preview.imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(preview.imageURLs.enumerated()), id: \.offset) { idx, url in
                            ZStack(alignment: .bottomTrailing) {
                                AsyncImage(url: URL(string: url)) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                            .overlay(ProgressView())
                                    }
                                }
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                
                                // Gradient overlay for better button visibility
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                                
                                Button {
                                    vm.download(kind: .singleImage, imageURL: url)
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .ultraThinMaterial)
                                        .padding(8)
                                }
                            }
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Action Buttons
            VStack(spacing: 12) {
                if preview.type == .video {
                    actionButton(
                        title: "Lưu Video Mật Độ Cao", 
                        icon: "video.fill.badge.down", 
                        colors: [.pink, .red],
                        action: { vm.download(kind: .video) }
                    )
                } else if preview.type == .slideshow {
                    actionButton(
                        title: "Tải Tất Cả Ảnh (.zip)", 
                        icon: "square.and.arrow.down.on.square.fill", 
                        colors: [.pink, .red],
                        action: { vm.download(kind: .slideshow) }
                    )
                }
                
                if preview.audioURL != nil {
                    actionButton(
                        title: "Tải Nhạc Nền (.mp3)", 
                        icon: "music.note", 
                        colors: [Color.gray.opacity(0.8), Color.gray],
                        action: { vm.download(kind: .audio) }
                    )
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 25, y: 15)
    }

    private func actionButton(title: String, icon: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                Text(title).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: colors.last!.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(vm.isLoading)
        .opacity(vm.isLoading ? 0.6 : 1.0)
    }
    
    private var floatingStatusToast: some View {
        HStack(spacing: 12) {
            if vm.isLoading {
                ProgressView().tint(.white)
            } else if vm.status.contains("✓") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            }
            
            Text(vm.status.replacingOccurrences(of: "✓ ", with: ""))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.bottom, 16)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://your.server", text: $settings.serverBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Backend Server")
                } footer: {
                    Text("Nhập URL của Flask server đang chạy HtmlWeb.\nMặc định: \(AppSettings.defaultURL)")
                }

                Section {
                    Button(role: .destructive) {
                        withAnimation { settings.serverBaseURL = AppSettings.defaultURL }
                        Haptics.success()
                    } label: {
                        HStack {
                            Text("Khôi phục mặc định")
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

#Preview("ContentView") {
    ContentView()
        .environmentObject(AppSettings())
}

#Preview("SettingsView") {
    SettingsView()
        .environmentObject(AppSettings())
}
