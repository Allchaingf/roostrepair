//
//  PhotoMarkupView.swift — Screen 15: Photo Notes
//
//  Attach a coop/area photo from camera or library, tap to mark the problem
//  spot, link it to a zone and save. Images are stored on-device in Documents.
//

import SwiftUI

struct PhotoMarkupView: View {
    @EnvironmentObject var store: FarmStore
    @State private var showSourceChoice = false
    @State private var pickerSource: ImagePicker.Source = .library
    @State private var showPicker = false
    @State private var pickedImage: UIImage?
    @State private var showEditor = false
    @State private var toast: Toast?

    var body: some View {
        DetailScaffold(title: "Photo Notes", trailingIcon: "camera.fill", trailingAction: { showSourceChoice = true }) {
            PrimaryButton(title: "Attach Photo", icon: "photo.on.rectangle.angled") { showSourceChoice = true }

            if store.photos.isEmpty {
                RoostCard { EmptyState(symbol: "photo", title: "No photo notes",
                                       message: "Capture a coop or area and mark the problem spot.") }
            } else {
                ForEach(store.photos) { photo in photoCard(photo) }
            }
        }
        .actionSheet(isPresented: $showSourceChoice) {
            var buttons: [ActionSheet.Button] = []
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                buttons.append(.default(Text("Camera")) { pickerSource = .camera; showPicker = true })
            }
            buttons.append(.default(Text("Photo Library")) { pickerSource = .library; showPicker = true })
            buttons.append(.cancel())
            return ActionSheet(title: Text("Attach Photo"), buttons: buttons)
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(source: pickerSource) { image in
                pickedImage = image
                // Defer presenting the editor until the picker dismisses.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let image = pickedImage {
                PhotoMarkupEditor(image: image) { toast = Toast(message: "Photo note saved") }
                    .environmentObject(store)
            }
        }
        .toast($toast)
    }

    private func photoCard(_ photo: PhotoNote) -> some View {
        RoostCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        if let img = ImageStore.load(photo.fileName) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: geo.size.width, height: 180)
                                .clipped()
                                .cornerRadius(Metric.radiusSmall)
                            if photo.hasMarker {
                                marker
                                    .position(x: geo.size.width * CGFloat(photo.markerX),
                                              y: 180 * CGFloat(photo.markerY))
                            }
                        } else {
                            RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background)
                                .frame(height: 180)
                                .overlay(Image(systemName: "photo").foregroundColor(Theme.textFaint))
                        }
                    }
                    .frame(height: 180)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photo.caption.isEmpty ? "Photo note" : photo.caption)
                            .font(.roost(15, .semibold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        Text("\(store.zoneName(photo.zoneID)) · \(FarmStore.shortDate(photo.date))")
                            .font(.roostCaption).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Button { store.deletePhoto(photo) } label: {
                        Image(systemName: "trash").foregroundColor(Theme.danger).frame(width: 30, height: 30)
                    }
                }
            }
        }
    }

    private var marker: some View {
        ZStack {
            Circle().fill(Theme.danger.opacity(0.25)).frame(width: 34, height: 34)
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 22, height: 22)
            Circle().fill(Theme.danger).frame(width: 12, height: 12)
        }
    }
}

// MARK: - Markup editor

struct PhotoMarkupEditor: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var image: UIImage
    var onSave: () -> Void

    @State private var markerX: Double = 0.5
    @State private var markerY: Double = 0.5
    @State private var hasMarker = false
    @State private var markMode = true
    @State private var caption = ""
    @State private var zoneID: UUID?

    var body: some View {
        SheetScaffold(title: "Photo Note", onSave: save,
                      onClose: { presentationMode.wrappedValue.dismiss() }) {
            Text(markMode ? "Tap the photo to mark the problem area." : "Marking off — tap to enable.")
                .font(.roostCaption).foregroundColor(Theme.textSecondary)

            GeometryReader { geo in
                let h: CGFloat = 260
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: h)
                        .clipped().cornerRadius(Metric.radius)
                    if hasMarker {
                        markerView
                            .position(x: geo.size.width * CGFloat(markerX), y: h * CGFloat(markerY))
                    }
                }
                .frame(width: geo.size.width, height: h)
                .contentShape(Rectangle())
                // DragGesture(minimumDistance: 0) captures the tap location on iOS 14
                // (onTapGesture's location parameter is iOS 16+).
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    guard markMode else { return }
                    let location = value.location
                    withAnimation(Metric.spring) {
                        markerX = Double(min(max(location.x / geo.size.width, 0), 1))
                        markerY = Double(min(max(location.y / h, 0), 1))
                        hasMarker = true
                    }
                })
            }
            .frame(height: 260)

            HStack(spacing: 10) {
                PillButton(title: markMode ? "Marking On" : "Mark Area", icon: "scope",
                           tint: Theme.danger, filled: markMode) { markMode.toggle() }
                if hasMarker {
                    PillButton(title: "Clear Mark", icon: "xmark.circle") { withAnimation { hasMarker = false } }
                }
                Spacer()
            }

            RoostField(title: "Caption", placeholder: "e.g. Torn mesh by nest box", text: $caption, icon: "text.justify")

            Text("LINK TO ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }
        }
    }

    private var markerView: some View {
        ZStack {
            Circle().fill(Theme.danger.opacity(0.25)).frame(width: 44, height: 44)
            Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 28, height: 28)
            Circle().fill(Theme.danger).frame(width: 14, height: 14)
        }
    }

    private func save() {
        guard let fileName = ImageStore.save(image) else {
            presentationMode.wrappedValue.dismiss(); return
        }
        store.addPhoto(PhotoNote(fileName: fileName, caption: caption.trimmingCharacters(in: .whitespaces),
                                 zoneID: zoneID, markerX: markerX, markerY: markerY, hasMarker: hasMarker))
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
