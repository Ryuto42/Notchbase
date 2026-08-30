import SwiftUI

struct ClipboardView: View {
    var store: ClipboardStore
    var onPaste: () -> Void

    @State private var query = ""
    @State private var needsAccessibility = false

    var body: some View {
        VStack(spacing: 7) {
            searchField
            if store.filtered.isEmpty {
                PlaceholderView(symbol: store.entries.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                                title: store.entries.isEmpty ? L.t("History is empty") : L.t("No matches"),
                                detail: store.entries.isEmpty
                                    ? L.t("Anything you copy shows up here.")
                                    : nil)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(store.filtered.prefix(120)) { entry in
                            ClipRow(store: store, entry: entry) {
                                if store.paste(entry) {
                                    onPaste()
                                } else {
                                    needsAccessibility = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.bottom, 9)
        .onChange(of: query) { _, new in store.query = new }
    }

    private var accessibilityNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("Allow Notchbase under Privacy & Security › Accessibility to paste")
                .font(Typo.rounded(9.5, .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.warm)
        .padding(.horizontal, 12)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
            TextField(L.t("Search"), text: $query)
                .textFieldStyle(.plain)
                .font(Typo.rounded(11))
                .foregroundStyle(Theme.primaryText)
            if !store.entries.isEmpty {
                TextButton(title: L.t("Clear")) { store.clear() }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .cardBackground(radius: 9)
        .padding(.horizontal, 12)
        .padding(.top, 7)
    }
}

private struct ClipRow: View {
    var store: ClipboardStore
    var entry: ClipEntry
    var paste: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            icon
                .frame(width: 22, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(entry.pinned ? Theme.accent.opacity(0.16) : Theme.card)
                }

            Text(entry.preview)
                .font(entry.kind == .text ? .system(size: 11) : Typo.rounded(11))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if entry.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                Text(Format.relative(entry.createdAt))
                    .font(Typo.digits(9.5, .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .opacity(hovering ? 0 : 1)
            .overlay(alignment: .trailing) {
                HStack(spacing: 0) {
                    GlyphButton(symbol: entry.pinned ? "pin.fill" : "pin", size: 10) {
                        store.togglePin(entry)
                    }
                    GlyphButton(symbol: "trash", size: 10) {
                        store.remove(entry)
                    }
                }
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .cardBackground(hovering: hovering, radius: 8)
        .overlay(alignment: .leading) {
            if entry.pinned {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2, height: 16)
                    .padding(.leading, 1)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(perform: paste)
        .animation(Motion.quick, value: hovering)
    }

    @ViewBuilder
    private var icon: some View {
        switch entry.kind {
        case .text:
            Image(systemName: "textformat.abc")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
        case .fileURL:
            Image(systemName: "doc.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
        case .image:
            if let image = store.image(for: entry) {
                Image(nsImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
