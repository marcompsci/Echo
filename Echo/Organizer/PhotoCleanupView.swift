import SwiftUI
import Photos

struct PhotoCleanupView: View {
    @State private var model = PhotoCleanupModel()

    var body: some View {
        List {
            Section {
                Text("Echo groups photos and videos you may not need. Tap a group, pick what to remove or organize. Echo asks before deleting anything, and you can restore deletions from Recently Deleted for 30 days.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }
            .listRowBackground(Color.echoSurface)

            switch model.state {
            case .idle, .scanning:
                HStack { ProgressView(); Text("Looking through your library…").foregroundStyle(.echoTextSecondary) }
                    .listRowBackground(Color.echoSurface)
            case .needsAccess:
                Section {
                    Text("Echo needs access to your photos to help clean up.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                .listRowBackground(Color.echoSurface)
            case .ready, .working:
                Section("Groups") {
                    ForEach(PhotoBucket.allCases) { bucket in
                        NavigationLink {
                            PhotoBucketView(bucket: bucket, model: model)
                        } label: {
                            let items = model.buckets[bucket] ?? []
                            HStack {
                                Label(bucket.title, systemImage: bucket.icon)
                                Spacer()
                                Text("\(items.count) · \(ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.bytes }, countStyle: .file))")
                                    .font(.echoFootnote)
                                    .foregroundStyle(.echoTextTertiary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.echoSurface)
            }

            if let message = model.message {
                Section { Text(message).font(.echoFootnote) }
                    .listRowBackground(Color.echoSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.echoBackground)
        .navigationTitle("Photo Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .task { if model.state == .idle { await model.scan() } }
        .refreshable { await model.scan() }
    }
}

struct PhotoBucketView: View {
    let bucket: PhotoBucket
    @Bindable var model: PhotoCleanupModel
    @State private var confirmDelete = false

    private var items: [PhotoItem] { model.buckets[bucket] ?? [] }
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 4)]

    var body: some View {
        ScrollView {
            if items.isEmpty {
                Text("Nothing here — nice and tidy.")
                    .foregroundStyle(.echoTextSecondary)
                    .padding(.top, 60)
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(items) { item in
                    PhotoThumb(item: item, isSelected: model.selected.contains(item.id))
                        .onTapGesture {
                            if model.selected.contains(item.id) { model.selected.remove(item.id) } else { model.selected.insert(item.id) }
                        }
                }
            }
            .padding(4)
        }
        .background(Color.echoBackground)
        .navigationTitle(bucket.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(items.allSatisfy { model.selected.contains($0.id) } && !items.isEmpty ? "Clear" : "Select all") {
                    if items.allSatisfy({ model.selected.contains($0.id) }) { model.clearSelection() } else { model.selectAll(in: bucket) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.selected.isEmpty {
                HStack(spacing: EchoSpacing.sm) {
                    Button {
                        Task { await model.addSelected(toAlbum: bucket.albumName) }
                    } label: {
                        Label("Put in album", systemImage: "rectangle.stack.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.echoLavender)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete \(model.selected.count)", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.echoDestructive)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Delete \(model.selected.count) item\(model.selected.count == 1 ? "" : "s") (\(ByteCountFormatter.string(fromByteCount: model.selectedBytes, countStyle: .file)))?",
            isPresented: $confirmDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await model.deleteSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You chose these yourself. iOS will ask once more, and they stay in Recently Deleted for 30 days.")
        }
    }
}

private struct PhotoThumb: View {
    let item: PhotoItem
    let isSelected: Bool
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.echoSurface
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipped()
            if item.isVideo {
                Image(systemName: "video.fill")
                    .font(.caption2).foregroundStyle(.white).padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.echoLavender : Color.white)
                .shadow(radius: 2)
                .padding(5)
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.echoLavender : .clear, lineWidth: 3))
        .task {
            guard image == nil,
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil).firstObject else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 220, height: 220),
                                                  contentMode: .aspectFill, options: opts) { img, _ in
                if let img { Task { @MainActor in image = img } }
            }
        }
        .accessibilityLabel("\(item.isVideo ? "Video" : "Photo") \(item.date?.formatted(date: .abbreviated, time: .omitted) ?? "")\(isSelected ? ", selected" : "")")
    }
}
