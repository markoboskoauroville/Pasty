import SwiftUI

struct ClipCardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @State private var hovering = false
    private var store: ClipboardStore { ClipboardStore.shared }
    private var headerColor: Color { SourceColor.color(for: item.sourceBundleID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .frame(width: Theme.cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(borderColor, lineWidth: selected ? 2.5 : (item.pinned ? 1.5 : 1))
        )
        .shadow(color: .black.opacity(selected ? 0.35 : 0.18),
                radius: selected ? 12 : 5, y: selected ? 5 : 2)
        .scaleEffect(hovering && !selected ? 1.015 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        // One click pastes into the app you came from. No double click, no Return
        // needed. The pin button and the reorder arrows swallow their own taps.
        .onTapGesture { AppController.shared.pasteItem(item) }
        .contextMenu { menu }
    }

    private var borderColor: Color {
        if selected { return Theme.selection }
        if item.pinned { return Theme.pin.opacity(0.55) }
        return Theme.cardBorder
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            headerColor
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.headerText)
                    Text(item.createdAt.clipRelativeLong)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.headerSubText)
                }
                .lineLimit(1)
                Spacer(minLength: 2)
                pinButton
                appIconTile
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(height: Theme.headerHeight)
    }

    /// Every card carries its own pin. One click toggles it.
    private var pinButton: some View {
        Button {
            store.togglePin(item)
        } label: {
            Image(systemName: item.pinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.pinned ? Theme.pin : Color.white.opacity(hovering ? 0.75 : 0.4))
                .rotationEffect(.degrees(item.pinned ? 0 : 32))
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(item.pinned ? 0.28 : 0.16), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(item.pinned ? "Unpin" : "Pin to the front")
        .animation(.easeOut(duration: 0.15), value: item.pinned)
    }

    private var appIconTile: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.black.opacity(0.22))
            .frame(width: 34, height: 34)
            .overlay(
                Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
                    .resizable()
                    .frame(width: 26, height: 26)
            )
    }

    // MARK: - Body

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(.horizontal, 13)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBody)
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .image:
            if let img = store.loadImage(for: item) {
                Image(nsImage: img)
                    .resizable().interpolation(.medium).scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { placeholder("photo") }
        case .color:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: item.colorHex ?? "#000") ?? .black)
                Text(item.colorHex ?? "")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white).shadow(radius: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .file:
            VStack(spacing: 9) {
                Image(systemName: "doc.fill").font(.system(size: 32))
                    .foregroundStyle(headerColor)
                Text(item.displayTitle).font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .link:
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "safari").font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        default:
            Text(item.text ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                .lineLimit(10)
                .multilineTextAlignment(.leading)
        }
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 30))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if item.type == .link {
                Text(item.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary).lineLimit(1)
            }
            HStack(spacing: 6) {
                if item.pinned && hovering {
                    reorderArrows
                } else {
                    Text(metaLeft)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if index < 9 {
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 20)
        }
        .padding(.top, 8)
    }

    /// Click driven reordering for pinned cards. Appears on hover so a resting
    /// card stays quiet.
    private var reorderArrows: some View {
        HStack(spacing: 4) {
            arrow("chevron.left", delta: -1, help: "Move left")
            arrow("chevron.right", delta: 1, help: "Move right")
        }
    }

    private func arrow(_ symbol: String, delta: Int, help: String) -> some View {
        let enabled = store.canMovePinned(item, by: delta)
        return Button {
            store.movePinned(item, by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(enabled ? Theme.pin : Theme.textTertiary)
                .frame(width: 20, height: 18)
                .background(Theme.fieldBG, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }

    private var metaLeft: String {
        switch item.type {
        case .text, .richText:
            return "\(item.charCount) characters"
        case .link:
            return (item.text ?? "").replacingOccurrences(of: "https://", with: "")
                                    .replacingOccurrences(of: "http://", with: "")
        case .file:
            return "\(item.fileURLs.count) file\(item.fileURLs.count == 1 ? "" : "s")"
        case .image:
            return "Image"
        case .color:
            return item.colorHex ?? "Color"
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var menu: some View {
        Button("Paste") { AppController.shared.pasteItem(item) }
        Button("Copy") { AppController.shared.copyItem(item) }
        Divider()
        Button(item.pinned ? "Unpin" : "Pin") { store.togglePin(item) }
        if item.pinned {
            Button("Move Left") { store.movePinned(item, by: -1) }
                .disabled(!store.canMovePinned(item, by: -1))
            Button("Move Right") { store.movePinned(item, by: 1) }
                .disabled(!store.canMovePinned(item, by: 1))
        }
        Divider()
        Button("Edit Title…") {
            if let t = TextPrompt.run(title: "Edit Title", message: "Card title",
                                      defaultValue: item.customTitle ?? "") {
                store.setTitle(t, for: item)
            }
        }
        Divider()
        Button("Delete", role: .destructive) { store.delete(item) }
    }
}
