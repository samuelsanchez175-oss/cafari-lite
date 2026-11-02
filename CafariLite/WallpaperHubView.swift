import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct WallpaperHubView: View {
    var navigationTitleText = "Wallpaper & Ambient"

    @Bindable private var store = WallpaperStore.shared
    @Bindable private var idleLook = IdleLookStore.shared
    @Bindable private var ambientLoops = AmbientLoopStore.shared

    @State private var pickerItem: PhotosPickerItem?
    @State private var clipPickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isLoadingClip = false
    @State private var crop = CarWallpaperCrop.identity
    @State private var previewSize = CGSize(width: 360, height: 220)
    @State private var pinchBase: CGFloat = 1
    @State private var dragBase: CGSize = .zero
    @State private var applyFlash = false
    @State private var isPinchingPreview = false

    private let carAspect = WallpaperPreviewLayout.defaultCarAspect

    var body: some View {
        List {
            Section {
                idlePreview
                    .frame(height: 220)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.black)
            } footer: {
                Text("Yellow box matches the car screen shape. Pinch and drag wallpaper or clips before Apply.")
                    .font(.footnote)
            }

            Section {
                idleLookRow(.wallpaper, title: CarIdleLook.wallpaper.title)
                if idleLook.selectedLook == .wallpaper {
                    wallpaperSubmenu
                }

                ForEach(Array(CarIdleLook.builtIn.dropFirst())) { look in
                    idleLookRow(look, title: look.title)
                }

                ForEach(ambientLoops.customLoops) { loop in
                    idleLookRow(.clip(loop.id), title: loop.title)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if idleLook.selectedLook == .clip(loop.id) {
                                    idleLook.selectLook(.wallpaper)
                                }
                                ambientLoops.delete(loop)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if idleLook.selectedLook == .clip(loop.id) {
                        clipSubmenu(for: loop.id)
                    }
                }

                PhotosPicker(selection: $clipPickerItem, matching: .videos, photoLibrary: .shared()) {
                    Label(isLoadingClip ? "Loading clip…" : "Add Your Own Clip", systemImage: "plus.circle")
                }
                .disabled(isLoadingClip)
            } header: {
                Text("Car Idle")
            } footer: {
                Text("One look at a time: still wallpaper, a built-in scene, or your clip loops on the car home screen.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .scrollDisabled(isPinchingPreview)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { restoreCropForCurrentLook() }
        .onChange(of: idleLook.selectedLook) { _, _ in restoreCropForCurrentLook() }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await applyPickerItem(newItem) }
        }
        .onChange(of: clipPickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importClip(newItem) }
        }
    }

    private var wallpaperPresetBinding: Binding<String> {
        Binding(
            get: { store.isCustom ? "custom" : store.selectedPreset.rawValue },
            set: { raw in
                guard let preset = CarWallpaperPreset(rawValue: raw) else { return }
                store.selectPreset(preset)
                resetLocalCrop()
                idleLook.selectLook(.wallpaper)
            }
        )
    }

    private var wallpaperSubmenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Photo", selection: wallpaperPresetBinding) {
                ForEach(CarWallpaperPreset.allCases) { preset in
                    Text(preset.title).tag(preset.rawValue)
                }
                if store.isCustom {
                    Text("Your photo").tag("custom")
                }
            }
            .pickerStyle(.menu)
            .padding(.vertical, 8)

            Divider()

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .disabled(isLoadingPhoto)

            Divider()

            Button { applyWallpaper() } label: {
                Label("Apply Wallpaper", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .disabled(!canApplyWallpaper)
        }
    }

    private func clipSubmenu(for id: UUID) -> some View {
        Button { applyClipCrop(for: id) } label: {
            Label("Apply Clip", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
        .disabled(!canApplyClip)
    }

    private func idleLookRow(_ look: CarIdleLook, title: String) -> some View {
        Button {
            withAnimation(.snappy) { idleLook.selectLook(look) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                if idleLook.selectedLook == look {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private var idlePreview: some View {
        let size = previewSize
        let box = WallpaperPreviewLayout.yellowBox(in: size, carAspect: carAspect)
        return ZStack {
            Color.black
            previewContent(box: box)
                .frame(width: box.width, height: box.height)
                .clipped()
                .position(x: box.midX, y: box.midY)

            Color.black.opacity(0.45)
                .reverseMask {
                    Rectangle().frame(width: box.width, height: box.height)
                }
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.yellow, lineWidth: applyFlash ? 4 : 2.5)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text("Car screen preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.yellow.opacity(0.9))
                    .padding(.bottom, 8)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .highPriorityGesture(previewGestures, including: idleLook.selectedLook.allowsPinchCrop ? .gesture : .none)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { previewSize = $0 }
        .frame(height: 240)
    }

    @ViewBuilder
    private func previewContent(box: CGRect) -> some View {
        switch idleLook.selectedLook {
        case .wallpaper:
            wallpaperImage(in: box)
        case .fireplace, .rain, .colorWaves:
            if let scene = idleLook.selectedLook.ambientScene {
                Image(uiImage: scene.previewImage())
                    .resizable()
                    .scaledToFill()
            }
        case .clip(let id):
            if let url = ambientLoops.url(forID: id) {
                let media = ambientLoops.mediaSize(forID: id)
                let base = WallpaperPreviewLayout.baseImageSize(image: media, box: box)
                LoopingVideoView(url: url)
                    .frame(width: base.width * crop.scale, height: base.height * crop.scale)
                    .offset(crop.offset)
                    .allowsHitTesting(false)
            } else {
                Color.black
            }
        }
    }

    private func wallpaperImage(in box: CGRect) -> some View {
        let base = WallpaperPreviewLayout.baseImageSize(image: store.sourceImage.size, box: box)
        return Image(uiImage: store.sourceImage)
            .resizable()
            .frame(width: base.width * crop.scale, height: base.height * crop.scale)
            .offset(crop.offset)
    }

    private var previewGestures: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    isPinchingPreview = true
                    crop.scale = min(max(pinchBase * value, 1), 4)
                }
                .onEnded { _ in
                    pinchBase = crop.scale
                    isPinchingPreview = false
                },
            DragGesture()
                .onChanged { value in
                    crop.offset = CGSize(
                        width: dragBase.width + value.translation.width,
                        height: dragBase.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    dragBase = crop.offset
                }
        )
    }

    private var canApplyWallpaper: Bool {
        idleLook.selectedLook == .wallpaper && (store.hasUnappliedSource || crop != store.appliedCrop)
    }

    private var canApplyClip: Bool {
        if case .clip = idleLook.selectedLook { return true }
        return false
    }

    private func applyWallpaper() {
        let output = WallpaperPreviewLayout.outputSize(forCar: .zero)
        store.applyCrop(crop, preview: previewSize, carAspect: carAspect, outputSize: output)
        flashApply()
        resetLocalCrop(from: store.appliedCrop)
    }

    private func applyClipCrop(for id: UUID) {
        let box = WallpaperPreviewLayout.yellowBox(in: previewSize, carAspect: carAspect)
        let media = ambientLoops.mediaSize(forID: id)
        ambientLoops.applyCrop(crop.clamped, box: box, mediaSize: media, forID: id)
        flashApply()
    }

    private func flashApply() {
        withAnimation(.easeOut(duration: 0.2)) { applyFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { applyFlash = false }
        }
    }

    private func resetLocalCrop(from applied: CarWallpaperCrop = .identity) {
        crop = applied
        pinchBase = applied.scale
        dragBase = applied.offset
    }

    private func restoreCropForCurrentLook() {
        switch idleLook.selectedLook {
        case .wallpaper:
            resetLocalCrop(from: store.appliedCrop)
        case .clip(let id):
            resetLocalCrop(from: ambientLoops.crop(forID: id).previewCrop(in: .zero))
        default:
            resetLocalCrop()
        }
    }

    private func applyPickerItem(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            pickerItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            store.setCustom(image)
            resetLocalCrop()
            idleLook.selectLook(.wallpaper)
        }
    }

    private func importClip(_ item: PhotosPickerItem) async {
        isLoadingClip = true
        defer {
            isLoadingClip = false
            clipPickerItem = nil
        }
        guard let picked = try? await item.loadTransferable(type: PickedMovie.self) else { return }
        do {
            let loop = try await MainActor.run {
                try ambientLoops.importLoop(from: picked.url, title: picked.url.deletingPathExtension().lastPathComponent)
            }
            await MainActor.run {
                idleLook.selectLook(.clip(loop.id))
                resetLocalCrop()
            }
        } catch {
            Log.write("ambient import failed \(error.localizedDescription)")
        }
    }
}

private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

struct WallpaperSetupView: View {
    @Bindable private var store = WallpaperStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WallpaperHubView(navigationTitleText: "Pick your car wallpaper")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Use default") {
                            store.selectPreset(.hello)
                            finish()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { finish() }
                    }
                }
        }
    }

    private func finish() {
        WallpaperContract.setupDone = true
        WallpaperContract.announceWallpaper(source: "setup")
        dismiss()
    }
}

enum WallpaperHubFactory {
    static func makeNavigationHub() -> UINavigationController {
        let hub = UIHostingController(rootView: WallpaperHubView())
        let nav = UINavigationController(rootViewController: hub)
        nav.navigationBar.prefersLargeTitles = false
        return nav
    }

    static func makeSetupSheet() -> UIHostingController<WallpaperSetupView> {
        UIHostingController(rootView: WallpaperSetupView())
    }
}

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
