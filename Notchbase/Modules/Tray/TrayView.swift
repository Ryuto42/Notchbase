import SwiftUI

struct TrayView: View {
    var model: NotchViewModel

    private var store: TrayStore { model.tray }

    var body: some View {
        HStack(spacing: 10) {
            if Preferences.shared.showAirDropZone {
                AirDropZone(model: model)
            }
            fileColumn
                .dropDestination(for: URL.self) { urls, _ in
                    store.add(urls)
                    return true
                } isTargeted: { targeted in
                    model.isDropTargeted = targeted
                }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var fileColumn: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                dropZone
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(store.items) { item in
                            TrayItemCell(model: model, item: item)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                }
                footer
            }
        }
    }

    private var dropZone: some View {
        let targeted = model.isDropTargeted
        return RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(targeted ? Theme.accent : Theme.stroke,
                          style: StrokeStyle(lineWidth: targeted ? 1.6 : 1, dash: [6, 5]))
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(targeted ? Theme.accent.opacity(0.09) : Color.clear)
            }
            .overlay {
                VStack(spacing: 5) {
                    Image(systemName: targeted ? "tray.and.arrow.down.fill" : "tray")
                        .font(.system(size: 18, weight: .light))
                    Text(targeted ? L.t("Release to stash") : L.t("Drop files here"))
                        .font(Typo.rounded(11.5, .semibold))
                    Text(L.t("Or drag anything to the top of the screen"))
                        .font(Typo.rounded(9.5))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .foregroundStyle(targeted ? Theme.accent : Theme.secondaryText)
            }
            .animation(Motion.quick, value: targeted)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L.count(store.items.count == 1 ? "%@ item" : "%@ items", store.items.count))
                .font(Typo.rounded(9.5, .medium))
                .foregroundStyle(Theme.tertiaryText)
            Spacer()
            TextButton(title: L.t("Clear all")) { store.clear() }
        }
        .padding(.leading, 3)
        .padding(.bottom, 2)
    }
}

private struct AirDropZone: View {
    var model: NotchViewModel

    @State private var targeted = false
    @State private var hovering = false

    private var trayURLs: [URL] {
        model.tray.items.compactMap { model.tray.url(for: $0) }
    }

    private var isActive: Bool { targeted || hovering }

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "dot.radiowaves.right")
                .font(.system(size: 19, weight: .regular))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(L.t("AirDrop"))
                    .font(Typo.rounded(11, .semibold))
                if !trayURLs.isEmpty && !targeted {
                    Text(L.count("Send %@", trayURLs.count))
                        .font(Typo.rounded(9))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .foregroundStyle(isActive ? Theme.accent : Theme.secondaryText)
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(targeted ? Theme.accent.opacity(0.14) : (hovering ? Theme.cardHover : Theme.card))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(targeted ? Theme.accent : Theme.stroke,
                              lineWidth: targeted ? 1.4 : 0.5)
        }
        .scaleEffect(targeted ? 1.03 : 1)
        .dropDestination(for: URL.self) { urls, _ in
            AirDrop.send(urls)
            return true
        } isTargeted: { targeted = $0 }
        .onHover { hovering = $0 }
        .onTapGesture { AirDrop.send(trayURLs) }
        .help(trayURLs.isEmpty
              ? "Drop files here to AirDrop them"
              : "Click to AirDrop everything in the tray, or drop files here")
        .animation(Motion.quick, value: targeted)
        .animation(Motion.quick, value: hovering)
    }
}

private struct TrayItemCell: View {
    var model: NotchViewModel
    var item: TrayItem

    @State private var hovering = false

    private var url: URL? { model.tray.url(for: item) }
    private var ext: String { URL(fileURLWithPath: item.name).pathExtension.uppercased() }

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
            Text(item.name)
                .font(Typo.rounded(9, .medium))
                .foregroundStyle(hovering ? Theme.secondaryText : Theme.tertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 64)
        }
        .scaleEffect(hovering ? 1.04 : 1)
        .animation(Motion.quick, value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.tray.open(item) }
        .draggable(url ?? URL(fileURLWithPath: "/dev/null")) {
            Image(nsImage: model.thumbnails.image(for: item, url: url))
                .resizable().frame(width: 52, height: 52)
        }
        .contextMenu {
            Button(L.t("Open")) { model.tray.open(item) }
            Button(L.t("Reveal in Finder")) { model.tray.reveal(item) }
            if let url {
                Button(L.t("AirDrop")) { AirDrop.send([url]) }
                if item.isDirectory {
                    Button(L.t("Open in Terminal")) {
                        model.tab = .terminal
                        TerminalSession.shared.send("cd \(url.path.replacingOccurrences(of: " ", with: "\\ "))\n")
                    }
                }
            }
            Divider()
            Button(L.t("Remove")) { model.tray.remove(item) }
        }
        .help("\(item.name) — \(Format.bytes(item.byteSize))")
    }

    private var thumbnail: some View {
        Image(nsImage: model.thumbnails.image(for: item, url: url))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .frame(width: 64, height: 64)
            .cardBackground(hovering: hovering, radius: 12)
            .overlay(alignment: .bottomTrailing) {
                if !ext.isEmpty && !item.isDirectory {
                    Text(ext.prefix(4))
                        .font(Typo.rounded(7.5, .bold))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1.5)
                        .background { RoundedRectangle(cornerRadius: 3.5).fill(.black.opacity(0.65)) }
                        .padding(4)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    model.tray.remove(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 19, height: 19)
                        .background { Circle().fill(.white.opacity(0.94)) }
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 9, y: -9)
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
            }
    }
}
