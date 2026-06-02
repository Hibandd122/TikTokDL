import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var vm = DownloadViewModel()
    @State private var showSettings = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    urlInput
                    if let preview = vm.preview { previewCard(preview) }
                    statusView
                }
                .padding()
            }
            .navigationTitle("TikTok DL")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.lastFileToShare != nil {
                        Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showShare) {
                if let url = vm.lastFileToShare { ShareSheet(items: [url]) }
            }
            .onAppear { vm.bind(settings) }
        }
    }

    private var urlInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Link TikTok").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                TextField("https://www.tiktok.com/@user/video/...", text: $vm.inputURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit { vm.fetchPreview() }
                Button {
                    if let s = UIPasteboard.general.string { vm.inputURL = s }
                } label: { Image(systemName: "doc.on.clipboard") }
                if !vm.inputURL.isEmpty {
                    Button { vm.inputURL = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))

            HStack {
                Button(action: vm.fetchPreview) {
                    Label("Phân tích", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

                Button(action: vm.clear) {
                    Label("Xoá", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)
            }
        }
    }

    @ViewBuilder
    private func previewCard(_ preview: TikTokPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preview.author).font(.headline)
            if !preview.desc.isEmpty {
                Text(preview.desc).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
            }

            switch preview.type {
            case .video:
                Button {
                    vm.download(kind: .video)
                } label: {
                    Label("Tải Video", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

            case .slideshow:
                Button {
                    vm.download(kind: .slideshow)
                } label: {
                    Label("Tải tất cả (.zip)", systemImage: "square.and.arrow.down.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

                Text("Từng ảnh:").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(preview.imageURLs.enumerated()), id: \.offset) { idx, url in
                            Button {
                                vm.download(kind: .singleImage, imageURL: url)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("#\(idx + 1)").font(.caption2)
                                }
                                .frame(width: 60, height: 60)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
                            }
                            .disabled(vm.isLoading)
                        }
                    }
                }
            }

            if preview.audioURL != nil {
                Button {
                    vm.download(kind: .audio)
                } label: {
                    Label("Tải Audio (.mp3)", systemImage: "music.note").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 8) {
            if vm.isLoading { ProgressView().controlSize(.small) }
            Text(vm.status).font(.footnote).foregroundStyle(.secondary)
        }
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
                    Text("Backend URL")
                } footer: {
                    Text("URL Flask backend chạy app HtmlWeb. Mặc định: \(AppSettings.defaultURL)")
                }

                Section {
                    Button("Khôi phục mặc định") {
                        settings.serverBaseURL = AppSettings.defaultURL
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}
